# Microsoft Foundry: from model probabilities to a reviewable decision

**The takeaway:** Microsoft Foundry serves a model that answers bounded questions. Microsoft-Decision-1 supplies choices and probabilities; our application decides when those answers are good enough to accept, when to ask another model, and when a person must review them.

Read this after the [five-minute demo](demo-script.md). No Azure calls are needed to follow the recorded example. This guide explains the documented API behavior, not an unpublished model architecture or training procedure.

## 1. Where Foundry fits

| Step | Responsibility |
| --- | --- |
| Build the input and allowed options | Application |
| Return a choice and probabilities | Microsoft-Decision-1 deployment in Foundry |
| Validate the response and apply a threshold | Application |
| Answer eligible uncertain questions again | Optional generative model deployment in Foundry |
| Compare answers and determine the review route | Application |
| Review, correct, and approve where required | Person, through the application |

These are calls the application orchestrates, not an automatic Foundry workflow. Both models are deployed in the selected Foundry resource. The hosted app authenticates using its managed identity; local live development uses Azure CLI authentication. App Service hosts the UI and backend, not the model. The recording bypasses inference and replays saved answers through the same validation and policy.

For this lab, Foundry's contribution is concrete: model deployment and inference access through authenticated APIs. We do not claim to demonstrate every Foundry capability. See [the official decision-model guide](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/use-foundry-models-microsoft-decision?wt.mc_id=AI-MVP-5004753) and [Foundry role-based access control](https://learn.microsoft.com/en-us/azure/foundry/concepts/rbac-foundry?wt.mc_id=AI-MVP-5004753).

## 2. A decision API, not a chat response

Microsoft Learn documents three question types:

| Type | What you ask | What you receive |
| --- | --- | --- |
| `noul` | Does a condition hold? | A probability from 0 to 1. |
| `choice` | Which offered option fits? | A selected option and a probability for each option. |
| `score` | Where does this input fall on an ordered scale? | A score and probabilities for the levels; the score is the probability-weighted average of their indexes. |

This sample uses **only `choice`**. It does not ask the model to invent categories, write an explanation, extract arbitrary JSON, or carry out an action. The API does not return a written rationale. A generative model remains the appropriate choice when the task needs prose, summaries, or explanations.

Multiple questions can share one `state`. Here, each pay item gets system and work-type questions, plus size, material, or depth questions when the code finds candidate spans. These are separate answers, not independent events whose probabilities we can automatically multiply.

## 3. The application defines the decision

Consider item 13, `Sanitary Sewer Bypass Pumping, Complete`. This is an abbreviated request: it shows the actual system question and options from the application; the full request also includes the work-type question.

```json
{
  "model": "bid-review-decision",
  "state": {
    "pay_item": "13",
    "description": "Sanitary Sewer Bypass Pumping, Complete",
    "unit": "LS"
  },
  "questions": {
    "system": {
      "type": "choice",
      "instructions": "Which utility system does this bid pay item belong to?",
      "criteria": {
        "sanitary_gravity": "Gravity sanitary sewer: sewer pipe, manholes, service laterals, cleanouts",
        "force_main": "Sanitary force main, lift station, or pump station",
        "water": "Potable water: water mains, valves, hydrants, services, meters",
        "storm": "Storm drainage: storm pipe, inlets, culverts, end sections",
        "general": "Not tied to one utility system: mobilization, traffic control, bonds, survey, restoration, allowances",
        "unclear": "The description does not identify the system"
      }
    }
  }
}
```

The request goes to the Foundry resource's `/providers/microsoft/v1/systemone` endpoint. `model` names the deployment, not necessarily the catalog model. `state` contains the input; `instructions` defines the question; `criteria` defines the allowed answers. Prices and quantities are not in this state.

The question design is part of the system's quality. Ambiguous options can still produce confident scores. An `unclear` option allows abstention; it does not guarantee that the model will use it correctly.

For numeric spans, code offers only text it found in the description. If a line mentions both a `6"` lateral and an `8"` main, both are candidates. Preventing invented sizes does not prevent selecting the wrong real size.

## 4. Read an actual recorded answer

The bundled [demo recording](../src/BidReviewQueue/Data/recordings/demo-run.jsonl), captured on 2026-10-14, contains this system answer for item 13. The table rounds the recorded probabilities to four decimal places:

| Option | Probability |
| --- | ---: |
| `force_main` | 0.7078 |
| `general` | 0.1394 |
| `sanitary_gravity` | 0.1394 |
| `unclear` | 0.0089 |
| `storm` | 0.0037 |
| `water` | 0.0008 |

The recorded `choice` is `force_main`. The response also has a separate `confidence` field, approximately 0.6494. **This application's threshold uses `probabilities[choice]`, approximately 0.7078, not that separate field.** The UI rounds it to 0.71. We do not assume undocumented equivalence between the two fields.

The parser checks that every question has an answer, the choice is offered, every offered option has a finite probability between 0 and 1, no unoffered option is scored, and probabilities sum to 1 within a 0.02 tolerance. The tolerance and acceptance policy are application decisions, not service guarantees.

**Checkpoint:** Does a valid answer establish that bypass pumping belongs to force main? No. It establishes that the response meets the contract.

## 5. The application, not the model, sets the review policy

At the lab's default threshold of 0.90:

1. A line can be accepted by rule only when every selected answer meets the threshold, no answer is `unclear`, and each selected option has the highest probability for its question.
2. If the line is below the threshold, the optional second model in Foundry answers the same bounded questions. In this recording, gpt-6-luna chooses `sanitary_gravity` for item 13, so the models disagree and the line stays with a person.
3. Agreement can accept an eligible line under this sample's policy, but does not create a new calibrated probability. Two models can share the same error. `unclear` answers and reviewer edits still require a person; a failed second opinion is not accepted by agreement.

The weakest selected probability is a conservative input to our rule, **not a calculated probability that the whole line is correct**. Similarly, the review priority score uses the line amount and that weakest probability to order attention; it is not an estimate of financial loss.

The threshold slider reevaluates saved answers without calling Foundry. Raising it can expose lines that have no second opinion yet; the UI requires an explicit request to obtain those opinions. An approval is local browser state, not a durable or authenticated audit record.

## 6. What does 0.90 really mean?

A model probability is useful for decisions only to the extent that it behaves reliably on the intended workload. Calibration is a property measured over groups of predictions: among comparable predictions near 0.90, are roughly nine out of ten correct? One answer with a 0.90 score cannot establish that.

Before using a threshold operationally, evaluate representative labeled examples, including ambiguous and out-of-distribution inputs. Measure incorrect automatic acceptances separately from review volume. Check calibration, wording and option-order sensitivity, failures, latency, and cost. Select a threshold based on the consequences of errors, not because 90% sounds reassuring. Microsoft Learn explicitly recommends workload-specific evaluation and meaningful human review for consequential decisions about people.

The bundled evaluation has 99 synthetic labeled items, not a held-out industry benchmark. The recorded second-opinion run increased acceptance from 68 to 93 lines at 0.90 without an accepted error against those labels. That is an observation, not proof of general reliability or measured human time savings. See [the full evidence and failed requests](verification.md).

## 7. Follow it in code or on screen

| Boundary | Location |
| --- | --- |
| Input state and offered options | [PayItems.cs](../src/BidReviewQueue/PayItems.cs): `BidItem.ToState`, `PayItemQuestions.For` |
| Foundry request and response contract | [Decisions.cs](../src/BidReviewQueue/Decisions.cs): `DecisionWire.BuildRequest`, `ParseResponse` |
| Engine choice, failures, and deadlines | [DecisionService.cs](../src/BidReviewQueue/DecisionService.cs) |
| Second-model request | [Escalation.cs](../src/BidReviewQueue/Escalation.cs) |

The [code walkthrough](code-walkthrough.md) follows item 13 through these files, with the exact request and response JSON.

Start with `./Start-Demo.ps1 -Lab 2 -Offline`, run the demo form, and open **Inspect this decision** in the highlighted item 13 case. The inspector explains the input, original choices, checks, and route. Expand **HTTP request and response** for the JSON exchanged with Foundry, and **Technical details** for the application's validated view. Compare its question, options, probabilities, and second opinion with this guide. Say **recorded responses from Foundry**, not **Foundry is running now**.

## Sources and lifecycle

The [Microsoft Learn decision-model guide](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/use-foundry-models-microsoft-decision?wt.mc_id=AI-MVP-5004753) was accessed on 2026-10-14 (page date 2026-10-07). It documents the question types, request path, lack of written rationales, calibration limits, wording sensitivity, and evaluation guidance. The [RBAC guide](https://learn.microsoft.com/en-us/azure/foundry/concepts/rbac-foundry?wt.mc_id=AI-MVP-5004753) is recorded in the sample's [source register](sources.md).

This sample targets Microsoft-Decision-1 model version `1`, the Microsoft provider's `v1/systemone` API, and .NET 11 RC1. The catalog reported the decision model as **Preview** in the verified region on 2026-10-14; the source register records differing documentation signals rather than asserting general availability. Exact response values above are measured observations. Thresholds, ranking, and acceptance by agreement are our design recommendations, not built-in Foundry behavior.
