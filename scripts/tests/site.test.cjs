"use strict";

const assert = require("node:assert/strict");
const { readFileSync, readdirSync, lstatSync, existsSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");
const root = path.resolve(__dirname, "..", "..");
const site = path.join(root, "docs", "site");
const pages = ["index.html", "labs/001/index.html", "labs/002/index.html"];
const home = readFileSync(path.join(site, "index.html"), "utf8");
const readme = readFileSync(path.join(root, "README.md"), "utf8");

test("shared palette keeps text and controls readable across guide surfaces", () => {
  const css = readFileSync(path.join(site, "styles.css"), "utf8");
  const tokens = Object.fromEntries([...css.matchAll(/--([\w-]+):\s*(#[0-9a-f]{6});/gi)].map(([, name, value]) => [name, value]));
  function luminance(hex) {
    const channels = hex.slice(1).match(/../g).map(channel => {
      const value = parseInt(channel, 16) / 255;
      return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    });
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
  }
  function check(foreground, background, minimum) {
    assert.ok(tokens[foreground] && tokens[background], `Missing palette token: ${foreground} / ${background}`);
    const a = luminance(tokens[foreground]), b = luminance(tokens[background]);
    const contrast = (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    assert.ok(contrast >= minimum, `${foreground} on ${background}: ${contrast.toFixed(2)} < ${minimum}`);
  }
  for (const surface of ["paper", "surface", "soft-accent", "soft-blue", "soft-coral", "soft-success", "soft-amber", "soft-danger"]) {
    check("ink", surface, 4.5);
    check("muted", surface, 4.5);
    check("blue", surface, 3);
  }
  for (const [text, surface] of [
    ["accent", "paper"], ["accent", "soft-accent"], ["blue", "soft-blue"],
    ["amber", "soft-amber"], ["danger", "soft-danger"],
    ["surface", "accent"], ["surface", "accent-strong"],
    ["surface", "blue"], ["surface", "coral"],
    ["code-ink", "code-background"], ["code-muted", "code-background"],
  ]) check(text, surface, 4.5);
  check("strong-line", "paper", 3);
  check("strong-line", "surface", 3);
  for (const stop of ["blue", "accent", "coral"]) check(stop, "paper", 3);
  assert.match(css, /@media \(forced-colors: active\)/);
  assert.match(css, /-webkit-text-fill-color: CanvasText/);
  assert.match(css, /-webkit-text-fill-color: currentColor/);
  assert.doesNotMatch(css, /var\(--(?:green|lime|soft-green)\)/);
});

test("chapter highlighting follows jumps, return to top, and resized headers", () => {
  let scroll = 0, headerBottom = 85, anchorOffset = 102;
  const callbacks = {}, frames = [];
  const sections = ["start", "labs", "next"].map((id, index) => ({
    id, getBoundingClientRect: () => ({ top: 200 + index * 1500 - scroll }),
  }));
  const links = sections.map(section => ({
    hash: `#${section.id}`, current: null,
    setAttribute(name, value) { if (name === "aria-current") this.current = value; },
    removeAttribute(name) { if (name === "aria-current") this.current = null; },
  }));
  vm.runInNewContext(readFileSync(path.join(site, "navigation.js"), "utf8"), {
    document: {
      querySelectorAll: selector => selector.startsWith(".chapter-nav") ? links : sections,
      querySelector: () => ({ getBoundingClientRect: () => ({ bottom: headerBottom }) }),
    },
    addEventListener: (event, callback) => { callbacks[event] = callback; },
    requestAnimationFrame: callback => frames.push(callback),
    getComputedStyle: () => ({ scrollPaddingTop: `${anchorOffset}px` }),
  });
  const selected = () => links.filter(link => link.current === "location").map(link => link.hash);
  assert.deepEqual(selected(), ["#start"]);
  scroll = 1600;
  callbacks.scroll();
  callbacks.scroll();
  assert.equal(frames.length, 1, "Scroll events share one animation frame");
  frames.shift()();
  assert.deepEqual(selected(), ["#labs"]);
  scroll = 3100;
  callbacks.scroll();
  frames.shift()();
  assert.deepEqual(selected(), ["#next"]);
  scroll = 0;
  callbacks.scroll();
  frames.shift()();
  assert.deepEqual(selected(), ["#start"]);
  scroll = 1550;
  headerBottom = 150;
  callbacks.resize();
  frames.shift()();
  assert.deepEqual(selected(), ["#labs"]);
  headerBottom = 72;
  anchorOffset = 96;
  scroll = 1603.6;
  callbacks.resize();
  frames.shift()();
  assert.deepEqual(selected(), ["#labs"], "Fractional mobile fragment offsets still select the destination chapter");
});

function files(directory, prefix = "") {
  return readdirSync(directory).flatMap(name => {
    const full = path.join(directory, name);
    const stat = lstatSync(full);
    assert.ok(!stat.isSymbolicLink(), `Do not publish a symlink: ${full}`);
    return stat.isDirectory() ? files(full, `${prefix}${name}/`) : [`${prefix}${name}`];
  }).sort();
}

test("publication contains only the static portal and two guides", () => {
  assert.deepEqual(files(site), [
    "index.html",
    "labs/001/guide.js", "labs/001/index.html",
    "labs/002/case-data.js", "labs/002/guide.js", "labs/002/index.html",
    "navigation.js", "styles.css",
  ]);
  const workflow = readFileSync(path.join(root, ".github", "workflows", "publish-pages.yml"), "utf8");
  assert.match(workflow, /workflow_dispatch:/);
  assert.doesNotMatch(workflow, /^\s+(push|pull_request|schedule):/m);
  assert.match(workflow, /default: false/);
  assert.match(workflow, /if: inputs\.publish && github\.repository == 'ppiova\/foundry-field-notes-labs'/);
  assert.match(workflow, /path: docs\/site/);
});

test("catalog availability and planned titles match the repository, without fake guide links", () => {
  const cards = [...home.matchAll(/<article[^>]+data-lab="(\d{3})" data-status="([^"]+)"[^>]*>([\s\S]*?)<\/article>/g)];
  assert.equal(cards.length, 8);
  assert.deepEqual(cards.filter(([, , status]) => status === "available").map(([, number]) => number), ["001", "002"]);
  assert.deepEqual(cards.filter(([, , status]) => status === "planned").map(([, number]) => number), ["003", "004", "005", "006", "007", "008"]);
  for (const [, number, status, body] of cards) {
    const name = body.match(/<h3>([^<]+)<\/h3>/)[1];
    assert.ok(readme.includes(`${number} \u2014 ${name}`), `Catalog drift: ${name}`);
    if (status === "planned") {
      assert.doesNotMatch(body, /<a\b|<button\b/);
      assert.match(body, /PLANNED/);
      assert.ok(!existsSync(path.join(site, "labs", number)), `Do not imply a planned lab is implemented: ${number}`);
    }
  }
  assert.match(home, /deterministic simulation/);
  assert.match(home, /recorded Foundry responses/);
  assert.match(home, /not available guides, release dates/);
});

for (const file of pages) {
  test(`${file}: links, anchors, accessibility landmarks, and offline assets`, () => {
    const html = readFileSync(path.join(site, file), "utf8");
    const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
    assert.equal(new Set(ids).size, ids.length, "Duplicate HTML ids");
    assert.match(html, /<html lang="en-US">/);
    assert.match(html, /<main id="main">/);
    assert.match(html, /class="skip-link"/);
    assert.match(html, /connect-src 'none'/);
    assert.doesNotMatch(html, /<(?:script|link)[^>]+(?:src|href)="https?:/);
    assert.doesNotMatch(html, /\son(?:click|input|load|error)=/);
    for (const [, target] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
      if (target.startsWith("https://")) {
        const url = new URL(target);
        if (url.hostname === "learn.microsoft.com") assert.deepEqual(url.searchParams.getAll("wt.mc_id"), ["AI-MVP-5004753"]);
        continue;
      }
      assert.ok(!target.startsWith("/") && !target.includes("://"), `Non-relative local target: ${target}`);
      const url = new URL(target, `https://example.test/foundry-field-notes-labs/${file}`);
      assert.ok(url.pathname.startsWith("/foundry-field-notes-labs/"));
      const relative = url.pathname.slice("/foundry-field-notes-labs/".length);
      const destination = path.join(site, relative);
      assert.ok(existsSync(destination), `Missing local link: ${file} -> ${target}`);
      if (url.hash) {
        const contents = readFileSync(destination, "utf8");
        assert.ok(contents.includes(`id="${url.hash.slice(1)}"`), `Missing anchor: ${target}`);
      }
    }
    for (const [, id] of html.matchAll(/\b(?:for|aria-describedby)="([^"]+)"/g)) {
      for (const target of id.split(" ")) assert.ok(ids.includes(target), `Missing label target: ${target}`);
    }
  });
}
