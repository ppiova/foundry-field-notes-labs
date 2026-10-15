# Architecture

## Flow

```text
Blazor page Home.razor (Fluent UI)          POST /api/decide (scripts, HTTP checks)
  │  one decision per pay item, 4 at a time       │
  └──────────────────────┬────────────────────────┘
                         ▼
DecisionService                               input validation, source selection, error messages
  ├─ PayItemQuestions.For(description)        options written by the application
  ├─ IDecisionProvider
  │    ├─ FoundryDecisionProvider             POST <resource>/providers/microsoft/v1/systemone
  │    └─ ReplayProvider                      recorded live responses: bundled run or BID_REVIEW_REPLAY_FILE
  ├─ DecisionWire.ParseResponse               response contract, shared by live and replay
  └─ ISecondOpinionProvider                   only for lines below the threshold, up to 8 at a time
       ├─ FoundrySecondOpinionProvider        POST <resource>/openai/v1/responses, strict JSON schema
       └─ SecondOpinionReplay                 recorded gpt-6-luna responses: bundled or BID_REVIEW_ESCALATION_REPLAY_FILE
ReviewPolicy.Evaluate                         threshold, abstention, review priority score
EscalationPolicy.Settle                       rule, agreement of two models, or a person
```

The page runs in Blazor Server interactive mode: the browser holds a SignalR connection, and the decisions, second opinions, edits and approvals stay in that server-side session. `BidReviewQueue.Eval` reuses the same question builder, providers, contracts and policies against the labeled set or the demo form.

The UI uses Fluent UI Blazor components (data grid, select, slider, switch, cards, message bars, progress bars and accordions) and Fluent design tokens for color, type and spacing in `wwwroot/app.css`. Each card is a `LineCard` component; the threshold slider uses whole percentages so the policy reruns in C# as it moves.

## Questions

Every pay item gets two taxonomy questions, `system` and `work_type`, each with an `unclear` abstention option. Up to three span questions are added when regular expressions find candidates in the description:

| Question | Spans found by | Example options |
| --- | --- | --- |
| `diameter` | inch sizes: `8"`, `15-inch` | `6"`, `8"`, `none` |
| `material` | pipe materials and classes | `PVC SDR-26`, `none` |
| `depth_band` | feet ranges and open bands | `0'-6'`, `Over 12'`, `none` |

The patterns over-find on purpose: `Asphalt Pavement Restoration, 1.5" Type SP-9.5 Overlay` offers `1.5"` and `none`, and the right answer is `none`. A span question is skipped when nothing matches, so the model is never asked to choose from an empty list. All questions for a line go in one request, as the Learn article recommends for questions about the same state.

## Contract

The request follows the Microsoft Learn article: `model` (the deployment name), `state` (pay item number, description and unit) and `questions` with `type: choice`, `instructions` and `criteria`.

A response is accepted only if, for every question asked, `answers.<name>.type` is `choice`, `choice` is an offered key, and `probabilities` holds a number from 0 to 1 for every offered key and nothing else, summing to 1 ± 0.02. `usage.input_tokens` is read when present.

The Learn article's examples do not show the probability and usage fields. Live responses on 2026-10-14 confirmed them: each choice answer carried `choice`, `confidence`, `probabilities` (an object keyed by option) and `type`, and the body carried `model: microsoft-decision-1` and `usage` with `input_tokens` and `output_tokens`. This sample ranks by the selected option's probability and does not use the service's `confidence` value. Span keys that contain quotes, such as `6"`, were accepted as option keys.

## Review policy

A line is accepted automatically when every answer's selected probability is at or above the threshold, no answer is `unclear`, and each selected option is the most probable one. Otherwise the line goes to the queue with its reasons. The queue is sorted by review priority score: the line amount × (1 − the weakest selected probability). A reviewer can change any answer, which requires approval again.

Review priority score is a heuristic, not expected loss or a joint probability that the whole line is wrong. Per-answer calibration alone does not validate this ranking. Evaluate queue usefulness and classification quality on representative labeled data; the evaluation command reports reliability and Brier scores as partial evidence. JSON exports now use `priorityScore` instead of `dollarsAtRisk`.

Reviewer edits force the line back into review in the grid, queue, and export. Original probabilities remain attached to original model answers. Changing an approved answer clears approval; changing the threshold does not rescore the model.

## Second opinion

Lines the rule cannot accept are not all equally doubtful. When the second opinion is on, a line below the threshold whose answers are all the most probable options and none is `unclear` is sent to a second model with the same questions and options. If the second model chooses the same option for every question, the line is **accepted by agreement**. Any difference, a failed request, a missing answer, or a reviewer's edit leaves the line with a person, and the card shows both answers. Lines the rule accepts never reach the second model, and an `unclear` answer always goes to a person.

The second model is gpt-6-luna, a chat model on the same Foundry resource, called through the Azure OpenAI v1 Responses API (`POST <resource>/openai/v1/responses`) with the token scope `https://ai.azure.com/.default` and the same credential as Microsoft-Decision-1. The request uses structured outputs in `text.format` with `strict: true`: one required string property per question whose `enum` lists exactly the offered options, `additionalProperties: false`, and `reasoning.effort: low`. It sends `store: false`, because the app never reads a response back and the service otherwise retains response data for 30 days. The pay item reaches the model as data with an instruction to ignore instructions inside it. The response is accepted only if `status` is `completed`, there is no refusal, and the `output_text` JSON names an offered option for every question; `usage.input_tokens` and `usage.output_tokens` are read for the cost estimate.

Two details came from live testing, not from documentation:

- Strict mode rejected enum values containing a double quote, such as `8"`. Options whose key is not a plain lowercase identifier travel under aliases (`option_1`, `option_2`, …) that the prompt describes and the parser maps back. Taxonomy keys such as `sanitary_gravity` stay as they are.
- Latency had a long tail. The client abandons a first attempt after 20 seconds and sends it once more; a retry also follows HTTP 408, 429 or a 5xx response. The reported latency includes every attempt, and the service stops waiting at 45 seconds.

The second model returns a choice, not probabilities, so agreement is a yes-or-no signal. The display probabilities and review priority score remain Microsoft-Decision-1's. Two models agreeing can still be wrong together; the evaluation command reports how often that happened on the labeled set.

The threshold slider never calls a model. Second opinions are requested for lines below the threshold when the run starts. If you raise the threshold later, the newly uncertain lines stay with a person until you choose **Ask gpt-6-luna about N lines**.

## Why a decision model, and no agent framework

Each line needs a few bounded choices about one short text, with no tools, memory or conversation. A decision model returns those choices as numbers in one call. An agent framework would add orchestration this task does not need. Use a generative model when you need to create or explain content; the Learn article suggests routing or gating with Microsoft-Decision-1 first and sending approved requests to a generative model. The second opinion follows that order: Microsoft-Decision-1 answers every line in about a quarter of a second, and the slower, general model sees only the lines it was unsure about.

## Hosting

The deployment script selects and verifies the requested CLI subscription and tenant before any Microsoft Graph command, then restores the previous subscription in `finally`. Run deployment serially; do not change the shared CLI account concurrently. Offline checks exercise selection across two mocked tenants and reject a mismatched context.

Locally the app uses `AzureCliCredential`. In Azure, the lab's `infra/main.bicep` sets `FOUNDRY_CREDENTIAL=managed-identity`, and the app uses its system-assigned identity, which holds Foundry User on the Foundry resource; the same role covers both deployments. The [lab platform](../../../docs/shared-azure-platform.md) owns the Foundry resource, with API keys disabled, and creates the `gpt-6-luna` deployment after the `decision-1` deployment; the lab template points `FOUNDRY_DECISION_DEPLOYMENT`, `FOUNDRY_ESCALATION_DEPLOYMENT` and `FOUNDRY_ESCALATION_MODEL` at them.

App Service authentication sits in front of the app: every request needs a Microsoft Entra sign-in from the deploying tenant, and the built-in authorization policy admits only the deploying user's object ID. The sign-in client credential is a federated identity credential backed by a separate user-assigned identity, so no secret is stored anywhere. The header shows the signed-in account from the `X-MS-CLIENT-PRINCIPAL-NAME` header, for display only; the platform enforces access. Session affinity and WebSockets are enabled for Blazor Server.

## Data handling

- Live requests send pay item number, description and unit, to Microsoft-Decision-1 for every line and to the second model for lines below the threshold. Quantities and prices never leave the app.
- `AzureCliCredential` provides Microsoft Entra tokens scoped to `https://cognitiveservices.azure.com/.default` for Microsoft-Decision-1 and `https://ai.azure.com/.default` for the Responses API, each cached until five minutes before expiry. No keys are read or stored.
- Logs record status codes and validation reasons, not request text.
- Page state lives in the server-side Blazor session only and ends when the page reloads. Uploaded bid forms are read in memory, limited to 256 KB. Exports and recordings are local files.
- The Content Security Policy keeps scripts same-origin. Styles allow `'unsafe-inline'` because Fluent UI components render style attributes; Razor still encodes all text, so descriptions cannot inject markup.
