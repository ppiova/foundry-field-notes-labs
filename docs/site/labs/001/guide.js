"use strict";

(() => {
  const request = document.getElementById("support-request").textContent;
  const controls = document.getElementById("evidence-controls");
  const evidence = document.getElementById("evidence-text");
  const result = document.getElementById("evidence-result");
  const title = document.getElementById("evidence-title");
  const reason = document.getElementById("evidence-reason");

  if (!request.trim()) {
    const error = document.getElementById("experiment-error");
    error.textContent = "The synthetic request is missing. The evidence exercise is unavailable; read the linked source fixture.";
    error.hidden = false;
    result.hidden = true;
    return;
  }

  function update() {
    const quote = evidence.value;
    const found = quote.trim().length > 0 && quote.length <= 3000 && request.includes(quote);
    result.dataset.result = found ? "found" : "rejected";
    title.textContent = found ? "Quote found, interpretation not verified" : "Evidence rejected";
    reason.textContent = found
      ? "This excerpt appears exactly in the request. It does not establish the cause, scope, or correctness of the proposed response. Human review is still required."
      : !quote.trim()
        ? "Evidence cannot be empty or whitespace-only. Human review is still required; there is no valid quote to inspect."
        : quote.length > 3000
          ? "Evidence exceeds the application's 3,000-character field limit. No proposal has been approved."
          : "This excerpt does not appear exactly in the request. The check is case-sensitive and preserves whitespace. No proposal has been approved.";
  }

  evidence.addEventListener("input", update);
  document.querySelectorAll("[data-evidence]").forEach(button => {
    button.addEventListener("click", () => {
      evidence.value = button.dataset.evidence;
      update();
    });
  });
  controls.disabled = false;
  update();
})();
