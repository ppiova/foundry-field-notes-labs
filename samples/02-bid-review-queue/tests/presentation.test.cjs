"use strict";

const assert = require("node:assert/strict");
const { readFileSync, existsSync, readdirSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const sample = path.resolve(__dirname, "..");
const site = path.resolve(sample, "..", "..", "docs", "site", "labs", "002");
const html = readFileSync(path.join(site, "index.html"), "utf8");
const script = readFileSync(path.join(site, "guide.js"), "utf8");
const dataScript = readFileSync(path.join(site, "case-data.js"), "utf8");
const source = {};
vm.runInNewContext(dataScript, source);
const data = JSON.parse(JSON.stringify(source.bidReviewCase));

function page(caseData = data) {
  const elements = new Map();
  function element(id) {
    if (!elements.has(id)) elements.set(id, {
      value: id === "threshold" ? "90" : "",
      checked: id === "second-opinion",
      disabled: id === "policy-controls",
      hidden: id === "experiment-error",
      textContent: "",
      dataset: {},
      listeners: {},
      addEventListener(event, callback) { this.listeners[event] = callback; },
      querySelector(selector) { return element(`${id}:${selector}`); },
    });
    return elements.get(id);
  }
  vm.runInNewContext(script, {
    bidReviewCase: caseData,
    document: { getElementById: element, querySelectorAll: () => [] },
  });
  return {
    element,
    threshold(value) {
      element("threshold").value = String(value);
      element("threshold").listeners.input();
    },
    second(checked) {
      element("second-opinion").checked = checked;
      element("second-opinion").listeners.change();
    },
    route: () => element("route-result").dataset.route,
  };
}

test("the published projection contains only selected synthetic recording fields", () => {
  assert.deepEqual(Object.keys(data), ["number", "description", "unit", "decisionRecordedAt", "secondOpinionRecordedAt", "model", "secondModel", "answers"]);
  assert.equal(data.number, "13");
  const records = file => readFileSync(path.join(sample, "src", "BidReviewQueue", "Data", "recordings", file), "utf8")
    .trim().split(/\r?\n/).map(line => JSON.parse(line))
    .filter(r => !r.reverseOptions && r.description === data.description && r.unit === data.unit);
  const decisions = records("demo-run.jsonl");
  const seconds = records("escalation-demo-run.jsonl");
  assert.equal(decisions.length, 1);
  assert.equal(seconds.length, 1);
  const original = JSON.parse(decisions[0].response);
  const secondBody = JSON.parse(seconds[0].response);
  const secondChoices = JSON.parse(secondBody.output.filter(o => o.type === "message").flatMap(o => o.content).filter(c => c.type === "output_text").map(c => c.text).join(""));
  for (const answer of data.answers) {
    assert.equal(answer.choice, original.answers[answer.name].choice);
    assert.deepEqual(answer.probabilities, original.answers[answer.name].probabilities);
    assert.equal(answer.secondChoice, secondChoices[answer.name]);
  }
  assert.equal(new Date(data.decisionRecordedAt).getTime(), new Date(decisions[0].recordedAtUtc).getTime());
  assert.equal(new Date(data.secondOpinionRecordedAt).getTime(), new Date(seconds[0].recordedAtUtc).getTime());
});

test("the prose and displayed probabilities remain true of item 13", () => {
  const [system, work] = data.answers;
  assert.equal(system.name, "system");
  assert.equal(system.choice, "force_main");
  assert.equal(system.secondChoice, "sanitary_gravity");
  assert.equal(system.probabilities[system.choice].toFixed(4), "0.7078");
  assert.equal(work.name, "work_type");
  assert.equal(work.choice, "support_work");
  assert.equal(work.secondChoice, "support_work");
  assert.equal(work.probabilities[work.choice].toFixed(4), "0.9954");
  assert.ok(html.includes(data.description));
  for (const answer of data.answers) assert.ok(html.includes(answer.probabilities[answer.choice].toFixed(4)));
  assert.equal(data.model, "microsoft-decision-1");
  assert.equal(data.secondModel, "gpt-6-luna");
  assert.ok(html.includes(data.secondModel));
  for (const date of [data.decisionRecordedAt, data.secondOpinionRecordedAt]) assert.equal(new Date(date).toISOString().slice(0, 10), "2026-10-14");
  const css = readFileSync(path.resolve(site, "..", "..", "styles.css"), "utf8");
  assert.ok(css.includes(`width: ${(system.probabilities[system.choice] * 100).toFixed(2)}%`));
});

test("every threshold step uses the recorded probabilities, without rounding before comparison", () => {
  const p = page();
  assert.equal(p.element("policy-controls").disabled, false);
  for (let value = 50; value <= 99; value++) {
    p.threshold(value);
    assert.equal(p.route(), value <= 70 ? "rule" : "person", `threshold ${value}`);
    assert.equal(p.element("threshold-value").textContent, (value / 100).toFixed(2));
  }
  p.threshold(70);
  assert.match(p.element("route-reason").textContent, /disagreement still exists/);
  p.threshold(71);
  assert.equal(p.route(), "person");
});

test("second-opinion toggle and reset never change the original evidence", () => {
  const original = JSON.stringify(data);
  const p = page();
  assert.equal(p.route(), "person");
  p.second(false);
  assert.match(p.element("route-reason").textContent, /excluded/);
  p.threshold(70);
  assert.equal(p.route(), "rule");
  p.element("reset-policy").listeners.click();
  assert.equal(p.element("threshold").value, "90");
  assert.equal(p.element("second-opinion").checked, true);
  assert.equal(p.route(), "person");
  assert.equal(JSON.stringify(data), original);
});

test("abstention and a non-top choice cannot become automatically accepted", () => {
  const abstaining = structuredClone(data);
  abstaining.answers[0].choice = "unclear";
  const p = page(abstaining);
  p.threshold(50);
  assert.equal(p.route(), "person");
  const nonTop = structuredClone(data);
  nonTop.answers[0].choice = "general";
  assert.equal(page(nonTop).route(), "person");
});

test("agreement only settles eligible low-probability answers when included", () => {
  const agreeing = structuredClone(data);
  for (const answer of agreeing.answers) answer.secondChoice = answer.choice;
  const p = page(agreeing);
  assert.equal(p.route(), "agreement");
  p.second(false);
  assert.equal(p.route(), "person");
  p.second(true);
  p.threshold(70);
  assert.equal(p.route(), "rule");
  agreeing.answers[0].choice = agreeing.answers[0].secondChoice = "unclear";
  assert.equal(page(agreeing).route(), "person");
});

test("missing or invalid evidence disables the experiment with a visible error", () => {
  const invalidCases = [null, {}, { ...data, number: "15" }];
  for (const change of [
    d => { d.answers[0] = null; },
    d => { d.answers[0].probabilities.force_main = NaN; },
    d => { d.answers[0].probabilities.force_main = 1.5; },
    d => { d.answers[0].probabilities.force_main = 0.1; },
    d => { d.answers[0].choice = "invented"; },
    d => { d.answers[0].secondChoice = "invented"; },
    d => { d.answers[1].name = "system"; },
  ]) {
    const modified = structuredClone(data);
    change(modified);
    invalidCases.push(modified);
  }
  for (const invalid of invalidCases) {
    const p = page(invalid);
    assert.equal(p.element("policy-controls").disabled, true);
    assert.equal(p.element("experiment-error").hidden, false);
    assert.ok(p.element("experiment-error").textContent.length > 20);
    assert.equal(p.element("route-result").hidden, true);
  }
});

test("invalid thresholds never produce success-shaped routes", () => {
  for (const value of ["NaN", "Infinity", 49, 100]) {
    const p = page();
    p.threshold(value);
    assert.equal(p.element("experiment-error").hidden, false);
    assert.equal(p.element("policy-controls").disabled, true);
    assert.equal(p.element("route-result").hidden, true);
  }
});

test("C# excerpts still match the actual source", () => {
  const snippets = [...html.matchAll(/<code data-source="([^"]+)">([\s\S]*?)<\/code>/g)];
  assert.equal(snippets.length, 2);
  for (const [, file, encoded] of snippets) {
    const snippet = encoded.replaceAll("&amp;", "&").replaceAll("&lt;", "<").replaceAll("&gt;", ">");
    const lines = snippet.trim().split(/\r?\n/).map(line => line.trim()).join("\n");
    const source = readFileSync(path.join(sample, "src", "BidReviewQueue", file), "utf8")
      .split(/\r?\n/).map(line => line.trim()).join("\n");
    assert.ok(source.includes(lines), `Outdated excerpt: ${file}`);
  }
});

test("assets and navigation work under a GitHub Pages repository subpath", () => {
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length, "Duplicate HTML ids");
  const base = new URL("https://example.test/foundry-field-notes-labs/labs/002/");
  for (const [, target] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (target.startsWith("https://")) {
      const url = new URL(target);
      if (url.hostname === "learn.microsoft.com") assert.deepEqual(url.searchParams.getAll("wt.mc_id"), ["AI-MVP-5004753"]);
      continue;
    }
    if (target.startsWith("#")) {
      assert.ok(ids.includes(target.slice(1)), `Missing anchor ${target}`);
      continue;
    }
    assert.ok(target.startsWith("./") || target.startsWith("../"), `Asset is not relative: ${target}`);
    assert.ok(existsSync(path.join(site, target.split("#")[0])));
    assert.ok(new URL(target, base).pathname.startsWith("/foundry-field-notes-labs/"));
  }
  assert.deepEqual(readdirSync(site).sort(), ["case-data.js", "guide.js", "index.html"]);
});

test("the guide is offline, progressively enhanced, and uses text-only evidence rendering", () => {
  assert.match(html, /connect-src 'none'/);
  assert.match(html, /<html lang="en-US">/);
  assert.match(html, /<fieldset id="policy-controls" disabled>/);
  assert.match(html, /<noscript>/);
  assert.match(html, /aria-live="polite"/);
  assert.match(html, /No live inference/);
  assert.doesNotMatch(script, /innerHTML|fetch\(|XMLHttpRequest|WebSocket|localStorage/);
  assert.match(script, /getElementById\("recorded-json"\)\.textContent/);
  assert.doesNotMatch(html, /<script[^>]+src="https?:/);
});
