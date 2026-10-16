"use strict";

const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const sample = path.resolve(__dirname, "..");
const site = path.resolve(sample, "..", "..", "docs", "site", "labs", "001");
const html = readFileSync(path.join(site, "index.html"), "utf8");
const script = readFileSync(path.join(site, "guide.js"), "utf8");
const application = readFileSync(path.join(sample, "src", "SupportSignal", "Program.cs"), "utf8");
const appScript = readFileSync(path.join(sample, "src", "SupportSignal", "wwwroot", "app.js"), "utf8");
const request = html.match(/<blockquote id="support-request">([^<]+)<\/blockquote>/)[1];
const initial = html.match(/<textarea[^>]+id="evidence-text"[^>]*>([^<]+)<\/textarea>/)[1];
const examples = [...html.matchAll(/data-evidence="([^"]+)"/g)].map(match => match[1]);

function page(input = request) {
  const elements = new Map();
  function element(id) {
    if (!elements.has(id)) elements.set(id, {
      value: id === "evidence-text" ? initial : "",
      textContent: id === "support-request" ? input : "",
      disabled: id === "evidence-controls",
      hidden: id === "experiment-error",
      dataset: {},
      listeners: {},
      addEventListener(event, callback) { this.listeners[event] = callback; },
    });
    return elements.get(id);
  }
  const buttons = examples.map((text, i) => {
    const button = element(`example-${i}`);
    button.dataset.evidence = text;
    return button;
  });
  vm.runInNewContext(script, { document: {
    getElementById: element,
    querySelectorAll: selector => selector === "[data-evidence]" ? buttons : [],
  } });
  return {
    element, buttons,
    edit(value) {
      element("evidence-text").value = value;
      element("evidence-text").listeners.input();
    },
    result: () => element("evidence-result").dataset.result,
  };
}

test("the static request is the actual synthetic outage fixture", () => {
  assert.equal(request, appScript.match(/outage: '([^']+)'/)[1]);
  assert.ok(request.length <= 180, "The page claims simulation quotes the whole fixture");
  assert.ok(request.includes(initial));
  assert.equal(examples.length, 2);
  assert.ok(request.includes(examples[0]));
  assert.ok(!request.includes(examples[1]));
  assert.ok(application.includes('Has("unavailable", "error 500", "service down", "outage") ? "Reliability"'));
  assert.ok(application.includes('category == "Reliability" && Has("all users", "production")'));
  assert.ok(application.includes("input[..Math.Min(input.Length, 180)]"));
  for (const text of [
    "Possible service disruption; scope not yet verified.",
    "Verify service status and scope before escalating to the on-call team.",
  ]) {
    assert.ok(application.includes(text));
    assert.ok(html.includes(text));
  }
});

test("exact quotation passes only the membership check, never human review", () => {
  const p = page();
  assert.equal(p.element("evidence-controls").disabled, false);
  assert.equal(p.result(), "found");
  assert.match(p.element("evidence-title").textContent, /interpretation not verified/);
  assert.match(p.element("evidence-reason").textContent, /Human review is still required/);
  p.edit(request);
  assert.equal(p.result(), "found");
});

test("invented, differently cased, and whitespace-modified quotes are rejected", () => {
  const p = page();
  for (const quote of [examples[1], initial.toUpperCase(), `  ${initial}  `, "error  500"]) {
    p.edit(quote);
    assert.equal(p.result(), "rejected", quote);
    assert.match(p.element("evidence-reason").textContent, /No proposal has been approved/);
  }
  p.edit("error 500");
  assert.equal(p.result(), "found");
  p.edit(` ${initial} `);
  assert.equal(p.result(), "found", "Surrounding spaces that actually occur in the request are valid evidence");
});

test("empty and oversized evidence fail, with the same 3,000-character bound as C#", () => {
  assert.ok(application.includes("string.IsNullOrWhiteSpace(x) || x.Length > 3000"));
  const p = page("a".repeat(3001));
  for (const quote of ["", " \t\n"]) {
    p.edit(quote);
    assert.equal(p.result(), "rejected");
    assert.match(p.element("evidence-reason").textContent, /empty or whitespace-only/);
  }
  p.edit("a".repeat(3000));
  assert.equal(p.result(), "found");
  p.edit("a".repeat(3001));
  assert.equal(p.result(), "rejected");
  assert.match(p.element("evidence-reason").textContent, /3,000-character/);
});

test("example controls recover from rejected evidence without changing the request", () => {
  const p = page();
  p.buttons[1].listeners.click();
  assert.equal(p.result(), "rejected");
  p.buttons[0].listeners.click();
  assert.equal(p.result(), "found");
  assert.equal(p.element("support-request").textContent, request);
});

test("a missing fixture disables the exercise and shows an explicit error", () => {
  const p = page("");
  assert.equal(p.element("evidence-controls").disabled, true);
  assert.equal(p.element("experiment-error").hidden, false);
  assert.equal(p.element("evidence-result").hidden, true);
  assert.match(p.element("experiment-error").textContent, /unavailable/);
});

test("C# excerpts and preview dependency metadata match the actual application", () => {
  const snippets = [...html.matchAll(/<code data-source="Program.cs">([\s\S]*?)<\/code>/g)];
  assert.equal(snippets.length, 2);
  const normalized = application.split(/\r?\n/).map(line => line.trim()).join("\n");
  for (const [, code] of snippets) {
    const decoded = code.replaceAll("&amp;", "&").replaceAll("&lt;", "<").replaceAll("&gt;", ">");
    assert.ok(normalized.includes(decoded.split(/\r?\n/).map(line => line.trim()).join("\n")));
  }
  const project = readFileSync(path.join(sample, "src", "SupportSignal", "SupportSignal.csproj"), "utf8");
  const version = project.match(/Include="Microsoft.Agents.AI.Foundry" Version="([^"]+)"/)[1];
  assert.ok(html.includes(version));
  const sdk = JSON.parse(readFileSync(path.resolve(sample, "..", "..", "global.json"), "utf8")).sdk.version;
  assert.ok(html.includes(sdk));
});

test("the exercise is text-only and explicitly distinct from simulation execution and replay", () => {
  assert.match(html, /not a saved model response/);
  assert.match(html, /does not classify the request or run the .NET validator/);
  assert.match(html, /<fieldset id="evidence-controls" disabled>/);
  assert.match(html, /<noscript>/);
  assert.match(html, /aria-live="polite"/);
  assert.doesNotMatch(script, /innerHTML|fetch\(|XMLHttpRequest|WebSocket|localStorage/);
  assert.match(script, /String|textContent/);
});
