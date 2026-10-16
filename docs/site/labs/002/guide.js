"use strict";

(() => {
  const controls = document.getElementById("policy-controls");
  const slider = document.getElementById("threshold");
  const second = document.getElementById("second-opinion");
  const error = document.getElementById("experiment-error");
  const result = document.getElementById("route-result");
  const title = document.getElementById("route-title");
  const reason = document.getElementById("route-reason");

  function fail(message) {
    controls.disabled = true;
    result.hidden = true;
    error.textContent = message;
    error.hidden = false;
  }

  const data = globalThis.bidReviewCase;
  if (!data || data.number !== "13" || !Array.isArray(data.answers) || data.answers.length !== 2) {
    fail("The recorded case could not be loaded. Reload the page or read the linked source recording. The experiment is unavailable.");
    return;
  }
  const names = new Set();
  for (const answer of data.answers) {
    if (!answer || typeof answer !== "object") {
      fail("The recorded case contains an invalid answer. The experiment is unavailable; check the source recording.");
      return;
    }
    const probabilities = answer.probabilities;
    if (!["system", "work_type"].includes(answer.name) || names.has(answer.name) ||
        !probabilities || typeof probabilities !== "object" || Array.isArray(probabilities) ||
        !Object.hasOwn(probabilities, answer.choice) || !Object.hasOwn(probabilities, answer.secondChoice) ||
        Object.values(probabilities).some(p => !Number.isFinite(p) || p < 0 || p > 1) ||
        Math.abs(Object.values(probabilities).reduce((sum, p) => sum + p, 0) - 1) > 0.02) {
      fail("The recorded case does not match the guide's probability contract. The experiment is unavailable; check the source recording.");
      return;
    }
    names.add(answer.name);
  }

  document.getElementById("recorded-json").textContent = JSON.stringify(data, null, 2);
  controls.disabled = false;

  function update() {
    const threshold = Number(slider.value) / 100;
    if (!Number.isFinite(threshold) || threshold < 0.5 || threshold > 0.99) {
      fail("The threshold must be between 0.50 and 0.99. Reload the page to reset the experiment.");
      return;
    }
    document.getElementById("threshold-value").textContent = threshold.toFixed(2);
    result.querySelector(".eyebrow").textContent = `APPLICATION ROUTE AT ${threshold.toFixed(2)}`;
    const eligible = data.answers.every(a => a.choice !== "unclear" &&
      a.probabilities[a.choice] >= Math.max(...Object.values(a.probabilities)));
    const clearsThreshold = data.answers.every(a => a.probabilities[a.choice] >= threshold);
    const agrees = data.answers.every(a => a.choice === a.secondChoice);
    const route = eligible && clearsThreshold ? "rule" : eligible && second.checked && agrees ? "agreement" : "person";
    result.dataset.route = route;
    if (route === "rule") {
      title.textContent = "Accepted by the threshold rule";
      reason.textContent = "Both selected probabilities clear this threshold and neither answer abstains. The recorded disagreement still exists; lowering the threshold does not make either model more correct.";
    } else if (route === "agreement") {
      title.textContent = "Accepted by model agreement";
      reason.textContent = "All recorded choices agree under this example's policy. Agreement does not prove correctness or produce a new calibrated probability.";
    } else {
      title.textContent = "A person must review";
      reason.textContent = !eligible
        ? "An answer abstains or is not the most probable option. A second opinion cannot settle this line under the sample's policy."
        : second.checked
          ? "The threshold rule cannot accept this line and the recorded models disagree. A person must resolve it; a valid response is not proof of correctness."
          : "The threshold rule cannot accept this line. The recorded second opinion is excluded from this experiment, so the line stays with a person.";
    }
  }

  slider.addEventListener("input", update);
  second.addEventListener("change", update);
  document.getElementById("reset-policy").addEventListener("click", () => {
    slider.value = "90";
    second.checked = true;
    update();
  });
  update();

})();
