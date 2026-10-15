# Lab experience guide

Use this structure for every Foundry Field Notes lab. It is a teaching and review template, not a requirement to share a UI framework or add a generic application shell. Lab 001 uses HTML and JavaScript; Lab 002 uses Blazor. Keep their implementation simple and their learning experience consistent.

## Write for an independent reader

Assume the reader has no access to a maintainer's Azure environment and has not followed project conversations. Begin with the audience, learning objective, and a choice between offline exploration and their own live deployment. Treat app hosting as a separate path when local live inference works without it.

Keep prerequisites, expected output, failure paths, costs, and cleanup together. Put operational history in dated verification records and maintainer runbooks. Link the [release gates](release-readiness.md) rather than suggesting that a polished page establishes publication or production readiness.

## The five design rules

| Rule | Required experience | Acceptance check |
| --- | --- | --- |
| Make Foundry's role visible | A compact path identifies model inference in Microsoft Foundry separately from application code, hosting, and human review. | A reader can explain what Foundry does and what it does not do in this sample. Simulation and replay never animate or label themselves as live calls. |
| Teach one case before the full workload | Name one synthetic case, ask the reader to predict, and provide a direct path to its actual result. | The case is findable without searching a long table. Uploaded data must not inherit assumptions about the bundled example. |
| Explain before showing JSON | Show input, model output, application checks, and the reason for review in readable form. Keep technical payloads in an expandable inspector. | Explanations are derived from explicit application rules, never invented model rationales. Original output stays separate from edits. |
| Make metrics interpretable | Lead with progress and outcomes relevant to the learning objective. Put latency, cost, and heuristics in a secondary panel. | A score is not presented as accuracy, savings, or expected loss without evidence. Recorded latency and historical estimated cost stay labeled. |
| Start with an explicit mode and action | Put the engine and primary action before large datasets. Offer optional experiments after the first successful result. | Live, replay, and simulation are unmistakable. Switching the selected engine does not relabel earlier results. Errors remain errors; no silent fallback. |

## Page outline

1. **Problem and learning objective:** one sentence, with Microsoft Foundry's concrete role.
2. **Execution boundary:** application input, Foundry inference or explicitly offline substitute, application validation, human review.
3. **Mode and primary action:** prerequisites, data destination, charges, and a clearly identified first case.
4. **Readable result:** original output, application checks, uncertainty, and review actions.
5. **Broader workload and experiments:** the full dataset, threshold changes, alternate inputs, or option-order tests when relevant.
6. **Technical details and evidence:** JSON, versions, source links, cost assumptions, verification limits, and export.

Avoid adding probabilities to a lab that does not return them. Lab 001's teaching result is a proposal with source evidence; Lab 002's is a bounded choice with per-option probabilities. Consistency means the same questions are answered for the learner, not identical dashboards.

## Guide and presentation outline

Each sample README should link a walkthrough and a timed demo script containing:

- Who the lab is for and the one idea they should retain.
- Prerequisites and an explicit engine: live, recorded, or simulation.
- A synthetic input and a prediction checkpoint.
- An expected contract; exact text only for deterministic fixtures or clearly dated recordings.
- A visible failure or uncertainty boundary, including invalid output and unavailable inference.
- An edit that invalidates approval, when the lab has review.
- Evidence limits, costs, and cleanup.

Use [Lab 001's separated cloud/local walkthrough](../samples/01-support-signal/docs/guided-lab.md), [Lab 002's Foundry model explanation](../samples/02-bid-review-queue/docs/decision-model.md), [its recorded presentation script](../samples/02-bid-review-queue/docs/demo-script.md), and [its code walkthrough](../samples/02-bid-review-queue/docs/code-walkthrough.md) as worked examples. A code walkthrough follows one case through the source and shows the exact request and response; validation checks its excerpts against the source and recordings so it cannot silently go stale. Technical claims need official sources under the [repository standard](repository-standards.md); this guide's layout choices are our recommendations, not Microsoft requirements.

## Review before presenting or reusing

Run the repository validation and rehearse the actual page, not just its APIs. Check keyboard access, narrow viewports, long untrusted text, mode labels, invalid input, provider failure without fallback, approval invalidation, and exported originals versus edits. Confirm that changing controls does not issue an undisclosed model request.

Record the actual build and environment, exact commands and results, browser steps, and any unverified live path. A passing replay is not current Foundry availability, and a configuration check is not successful hosted inference. Keep infrastructure migration, new paid services, and larger evaluations separate from last-minute presentation changes.
