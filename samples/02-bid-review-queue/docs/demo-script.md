# Microsoft Foundry decisions in five minutes

**Audience:** developers who know what a model API is but have not used a decision model.

**One takeaway:** Foundry provides model inference; Microsoft-Decision-1 returns bounded choices and probabilities; our application turns those answers into a review policy.

This is a **recorded demonstration**, not a new inference run. The answers were captured from Foundry on 2026-10-14. The five-minute script totals 300 seconds, including a 30-second buffer; rehearse to confirm your delivery fits. For technical questions, keep [the model walkthrough](decision-model.md) open.

## Before presenting

From the repository root, in PowerShell 7:

```powershell
./scripts/Test-Prerequisites.ps1
./Start-Demo.ps1 -Lab 2 -Offline
```

Open http://localhost:5190. Rehearse before the event so package restore and compilation do not happen on stage. `-Offline` disables live model configuration and custom recording files for this process; it does not mean package restore works without internet.

Start from a fresh page with threshold 0.90, default option order, no edits, **Recorded Microsoft-Decision-1 run** selected, and second opinions on. Run once and confirm **35 / 35**, **24 accepted by rule**, **8 accepted by agreement**, and **3 awaiting review**. Expand **Operational details** for **$116,500 in review** and inspect the highlighted item 13 disagreement. Locate the slider inside **Policy and optional experiments**. Reload before presenting. Stop if results differ; do not narrate expected numbers as observed results.

A hosted live run with second opinions was verified on 2026-10-15, but live answers vary between runs: that run gave 25 accepted by rule, 6 by agreement and 4 in review instead of the recording's 24, 8 and 3. Present the recorded run for the numbers in this script, and show a hosted live run only as an optional variant. Do not redeploy the platform during the session. A prerecorded run is not proof of current Foundry availability.

## On stage

| Time | Show | Say |
| --- | --- | --- |
| 0:00-0:30 | The responsibility strip, recorded engine label, and named item 13 case | "Microsoft Foundry lets us use different models for different tasks. Here, a decision model helps us decide which bid lines need a person. These are recorded Foundry responses; no model is being called now." |
| 0:30-1:10 | Run **Decide every pay item**, then open **Inspect this decision** on item 13 | "Our code defines the input, the question, and every allowed answer. Microsoft-Decision-1 returns a choice and probabilities, not a written explanation. The model does not set our approval policy." |
| 1:10-2:00 | Item 13's system probabilities and 0.71 result | "It selected force main at about 0.71. The application's default threshold is 0.90, so this needs more review. A probability is not a guarantee: calibration must be measured on our data. The score here is the selected option's probability, not the separate confidence field." |
| 2:00-2:45 | Item 13's recorded second opinion and an accepted-by-agreement line such as item 15 | "We can use a second model in Foundry for uncertain lines. On item 13 it disagrees, so a person decides. Agreement accepts some other lines under our rule, but two models can be wrong together." |
| 2:45-3:20 | Expand **Policy and optional experiments**; move the threshold to 0.98, show the request button, then return to 0.90 | "The application is changing policy over answers it already has. Moving this slider makes no model call. New second opinions require an explicit request. Review effort and error risk must be evaluated together." |
| 3:20-4:00 | Approve item 13, edit an answer, observe approval cleared, and export JSON | "Review is part of the design. A changed answer invalidates approval. The export keeps the model result and our edits separate. This sample's approval is local, not a production audit trail." |
| 4:00-4:30 | The architecture in the model walkthrough | "Foundry serves the models. App Service can host our app. Our code owns validation and review. The reusable pattern is bounded questions, measured probabilities, and an explicit decision boundary." |
| 4:30-5:00 | Buffer or one question | "The next step is evaluating your own representative data, not copying our 0.90 threshold." |

## Optional depth, outside the five minutes

- Show the code and the HTTP exchange behind item 13 with the [code walkthrough](code-walkthrough.md), about 10 minutes.
- Show item 35: `unclear` always requires a person.
- Explain `noul`, `choice`, and `score` with the [official Microsoft guide](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/use-foundry-models-microsoft-decision?wt.mc_id=AI-MVP-5004753), accessed 2026-10-14. Only `choice` is used here.
- Reverse option order and compare results. An unchanged recorded comparison does not establish robustness on other inputs.
- Open the evaluation report: 99 synthetic labeled items, not a general benchmark. Explain automatic-acceptance errors, review volume, latency, and cost together.

## Live variant and recovery

A live variant needs an owner-selected deployment, authorized spending, and a successful rehearsal with the exact build and hosting environment. Use the README's live setup without `-Offline`; do not promise the recorded answers or a five-minute run. Hosted sign-in requires a permitted user. Inference charges and hosting charges are separate.

If a live call fails, show the error and say it failed. Switch explicitly to the recorded local demo; never describe replay as a successful retry. For SDK or startup errors, follow [troubleshooting](troubleshooting.md). Do not change shared infrastructure to rescue a stage demo.

Use synthetic data only. Do not display tokens, subscription details, or private resource addresses. Stop the local server with Ctrl+C and remove exported synthetic JSON when no longer needed. No Azure cleanup is needed for this recorded path.
