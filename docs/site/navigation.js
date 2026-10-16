"use strict";

(() => {
  const links = [...document.querySelectorAll('.chapter-nav a[href^="#"]')];
  const sections = [...document.querySelectorAll("main > section")];
  const header = document.querySelector(".site-header");
  if (!links.length || !sections.length) return;
  let scheduled = false;

  function update() {
    scheduled = false;
    const anchorOffset = Number.parseFloat(getComputedStyle(document.documentElement).scrollPaddingTop);
    // Fragment scrolling can leave a fractional CSS pixel above the requested offset.
    const boundary = Math.max(header?.getBoundingClientRect().bottom ?? 0, Number.isFinite(anchorOffset) ? anchorOffset : 0) + 1;
    let current = sections[0];
    for (const section of sections) {
      if (section.getBoundingClientRect().top <= boundary) current = section;
    }
    for (const link of links) {
      if (link.hash === `#${current.id}`) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    }
  }

  function schedule() {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(update);
  }

  globalThis.addEventListener("scroll", schedule, { passive: true });
  globalThis.addEventListener("resize", schedule);
  update();
})();
