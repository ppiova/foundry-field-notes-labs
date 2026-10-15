# Verification — 2026-10-13

These dated observations predate the initial public snapshot. Historical commit IDs identify the builds used for those observations; those commits and their private review conversations are not part of this repository. They are maintainer-reported evidence, not independently reproduced public CI. Current snapshot checks are recorded in [release readiness](../../../docs/release-readiness.md).

## Current status — 2026-10-15

The presentation path explicitly replays bundled Foundry responses, not new inference. Local live evaluations of Microsoft-Decision-1 and gpt-6-luna, recorded-run UI behavior, and read-only Azure configuration checks are documented below. On 2026-10-15 (UTC) the labs moved to the [lab platform](../../../docs/shared-azure-platform.md) in a new resource group: the platform check passed 21 of 21, and a local live request reached both new model deployments. See [lab platform deployment](#lab-platform-deployment--2026-10-15-utc). A hosted live run through the app's managed identity, with second opinions, succeeded the same day; see [hosted verification](#hosted-verification--2026-10-15-utc). Independent clean-environment reproduction remains unverified. The hosting plan is paid B1; replay itself incurs no inference charges.

Presentation preparation on Windows, 2026-10-14:

- `scripts/Validate.ps1` passed locked restore, a zero-warning/error build, 104 Lab 002 checks, 27 HTTP checks, recorded evaluation, prerequisite/startup regression checks, fake-CLI Azure checks, and local Markdown links, together with Lab 001's checks. No model was called.
- `Start-Demo.ps1 -Lab 2 -Offline` started successfully with inherited live endpoints and nonexistent custom recording paths: both live engines were disabled, and bundled recordings were loaded. The pinned .NET SDK was installed into this worktree with its official SHA512 verified; this is not independent clean-machine reproduction.
- Browser rehearsal reproduced 35/35 decisions, 32 accepted (24 by rule, 8 by agreement), and $116,500 in review. Item 13 showed `force_main` at approximately 0.7078 and the recorded second model's `sanitary_gravity` answer. Raising the threshold to 0.98 offered 13 missing second opinions; restoring 0.90 preserved the results. Approval cleared after editing item 13, while original probabilities remained visible. The generated JSON export contained 35 lines, `mode: replay`, the original model result, second opinion, and separate reviewer fields. The export was inspected in-browser without saving a download.
- The presentation script allocates 300 seconds, including a 30-second buffer; spoken delivery has not been timed. No hosted inference, infrastructure changes, or expanded model-quality evaluation occurred in this round.

The entries below are chronological evidence, not a claim that every historical engine or limitation is still current.

## Shared lab experience — 2026-10-14

- Applied the repository's five-rule experience guide: explicit Foundry/application boundaries, mode and primary action before the collapsed dataset, highlighted item 13, readable inspection before JSON, and four primary outcome counts. Operational metrics and optional experiments are expandable.
- `scripts/Validate.ps1` passed with 104 Lab 002 checks and 30 HTTP checks, a zero-warning/error build, recorded evaluation, and synchronized browser guides. The new `/model-guide.html` serves the decision-model explanation locally; its companion-document/source links require repository access.
- Desktop browser, `Start-Demo.ps1 -Lab 2 -Offline -Port 55190`: 35/35, 24 accepted by rule, 8 by agreement, 3 awaiting review. Item 13 appeared once and showed the original force-main probability and recorded disagreement. At 0.98, the explicit request prompt covered 13 missing second opinions. Restoring 0.90, approving, then editing item 13 cleared its approval; export retained `mode: replay`, 35 lines, original `force_main`, and separate reviewer `sanitary_gravity`.
- Uploaded a synthetic one-item form numbered 13: bundled-case guidance disappeared. Markup-like input rendered as text, not an image. Running the unrecorded input produced the explicit missing-recording failure, with 0/1 decided and no invented response.
- Full interactive narrow-viewport and keyboard-only regression remain unverified in this round. A static snapshot did not reproduce Fluent's runtime styling and was not accepted as mobile evidence.
- No new inference, Azure deployment, model-quality evaluation, or policy change. The changed UI is not evidence of hosted second-opinion success.

Environment: Windows x64, isolated .NET SDK 11.0.100-rc.1.26425.128, Azure.Identity 1.21.0 and Microsoft.FluentUI.AspNetCore.Components 5.0.0 (with Icons 5.0.0) restored from NuGet with lockfiles.

## Completed

- The solution builds with zero warnings and errors.
- 53 offline checks passed: option builder and spans, alignment of all 99 labels with the questions the app builds, request shape, 14 response-contract cases, review policy, simulation against the contract, settings, the live client against a local HTTP stub (bearer token, Content-Length, one retry after HTTP 429, no retry after 401, token caching, incomplete response rejected), the shared decision service (503 for unconfigured sources, 400 for invalid input), replay, and scoring helpers.
- 20 HTTP checks passed against a temporary local server started from build output: prerendered Blazor page, CSP with same-origin scripts, Fluent UI assets served, status, demo form, simulation decisions and review fields, reversed option order, six invalid inputs, unconfigured Microsoft-Decision-1 rejected with HTTP 503 and no fallback, replay without a recording rejected.
- The evaluation command ran in simulation mode on the labeled set (99 items, 198 requests) and on the demo form, and labeled both reports as simulation.
- Browser walkthrough of the Fluent UI page in simulation: 35 of 35 decided; 9 accepted automatically at 0.90 with $2,134,490 in review and $813,054 at risk; the slider at 0.60 gave 32 accepted and $150,520 in review without new requests; approving a line moved it to approved; changing an answer through the dropdown removed the approval and marked the answer as edited; the reversed run reported 0 of 104 answers changed; export produced 35 lines with model output, review and threshold. Checked in dark and light themes, and at 375 px wide with no horizontal overflow. No Content Security Policy violations were logged.

These numbers come from keyword rules written alongside the labels. They demonstrate the workflow, not model quality.

## Live verification — 2026-10-14

Owner-selected subscription (not recorded here), new resource group and Foundry resource (`AIServices`, S0, custom subdomain) in East US 2. Deployment `bid-review-decision`: Microsoft-Decision-1 version 1, `DataZoneStandard`, capacity 50, which the deployment reports as 50 requests per minute. The model catalog API reported the model as Preview and offered only `DataZoneStandard` in that region. The signed-in user already held Foundry User at subscription scope, so no new role assignment was needed. Authentication: Microsoft Entra ID through Azure CLI; no keys.

- **Raw request.** HTTP 200 from both the `cognitiveservices.azure.com` and `services.ai.azure.com` hosts. Each choice answer contained `choice`, `confidence`, `probabilities` and `type`; the body contained `model: microsoft-decision-1` and `usage.input_tokens` / `usage.output_tokens`. Span keys with quotes (`6"`, `8"`) were accepted.
- **Labeled evaluation** (99 items, 198 requests, `--concurrency 2 --max-rpm 45`, 0 failures):

  | Question | Accuracy | Mean Brier |
  | --- | ---: | ---: |
  | system | 98 of 99 | 0.027 |
  | work_type | 98 of 99 | 0.020 |
  | diameter | 53 of 53 | 0.014 |
  | material | 29 of 30 | 0.025 |
  | depth_band | 10 of 10 | 0.008 |

  Automatic acceptance with no wrong line accepted: 82 of 99 at 0.80, 68 at 0.90, 58 at 0.95, 17 at 0.99; review caught 3 of 3 wrong lines at every threshold. The three differences from the labels: L021 material `VCP` answered `none` (0.59), L024 bypass pumping answered `force_main` instead of `sanitary_gravity` (0.71; arguably a debatable label), L090 milling answered `connect_adjust` instead of `restoration` (0.42). Answers at 0.80 or above were all correct (272 answers). Reversed option order changed 0 of 291 answers. Round trip p50 226 ms, p95 435 ms; 41,435 input tokens for one pass.
- **Demo form, recorded for replay** (35 items, 70 requests, 0 failures): at 0.90, 24 accepted and 11 in review ($778,200 in review, $139,259 at risk); 0 of 104 answers changed with reversed options; p50 233 ms; 14,692 input tokens.
- **Browser, live engine.** 35 of 35 decided in 3.5 s with four requests in parallel; 24 accepted at 0.90; median 224 ms; 14,692 input tokens, shown as $0.000617. The queue started with Lift Station No. 2 Rehabilitation ($385,000, work type 0.86), the septic tank abandonment (system 0.64) and bypass pumping (system 0.67). Dollars at risk were $146,366, against $139,259 in the recorded run: probabilities vary slightly between calls.
- **Browser, recorded engine.** Reproduced the recorded run exactly without network calls and labeled it as recorded.
- The evaluation runs above were paced under 50 requests per minute. At the owner's request the capacity was then raised to 300 (the deployment reported a `request` limit of 300 per 60 seconds). The demo form was decided twice back to back, 70 requests four at a time with no pacing, with 0 failures; 24 lines were accepted at 0.90 again.

## Azure hosting — 2026-10-14

`infra/Deploy-Azure.ps1` ran against the owner-selected subscription in East US 2, reusing the existing Foundry resource and deployment (capacity 300), with an F1 Linux plan. The Bicep deployment succeeded, the self-contained build deployed, and the site started in about 80 seconds.

- Unauthenticated requests: a browser request to `/` returned HTTP 302 to the tenant's v2.0 authorize endpoint with `response_type=code id_token`; requests without a browser user agent to `/`, `/api/status` and `/api/bid-form` returned HTTP 401. Plain HTTP redirected to HTTPS.
- The applied `authsettingsV2` showed `requireAuthentication: true`, a v2.0 tenant issuer, exactly one allowed principal, and `OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID` as the client credential setting, so no client secret exists.
- Pending: the owner's interactive sign-in, the 403 for another account, and a live decision from the hosted app through its managed identity.

## Not verified

- Results on real bid documents, other domains, or repeated runs with confidence intervals.
- `GlobalStandard` deployments, other regions, and API keys (deliberately not used).
- Clean-machine first success, and production hosting, authentication or persistence.

## Hosted CI

On 2026-10-14 the pre-publication GitHub Actions workflow passed on `ubuntu-latest` for build `c24a4d7`: locked restore, build, offline checks, simulation evaluation and HTTP checks for both labs on Linux. That run is not part of this repository's Actions history. CI makes no Azure calls.

## Cleanup

The resource group created for this run can be deleted with `az group delete --name <resource-group>`; that removes the Foundry resource and the deployment.
## Educational walkthrough and review fixes — 2026-10-14

- Full local validation passed: zero build warnings/errors, 9 Lab 001 contract checks, 66 Lab 002 offline checks, 20 HTTP checks per lab, simulation evaluation, local Markdown links, and two mocked cross-tenant deployment checks. No live requests or deployment were made for this update.
- Browser simulation completed 35/35 items with 9 automatically accepted at 0.90. Editing accepted line 20 to Unclear reduced automatic acceptance to 8 and displayed the explicit-review reason. The inspector displayed input state, questions, and original answers. No browser console errors were observed.
- Renamed the heuristic from “dollars at risk” to “review priority score,” including the JSON field `priorityScore`. Historical measurements below used the previous label; they are not measurements of expected loss. Original model probabilities do not score reviewer edits.
- A fresh source copy outside the checkout restored locked dependencies and built successfully using the pinned SDK. Windows Application Control blocked the newly built test executable in the temporary directory. The full clean-copy run therefore did not complete; no security policy was changed. This is not evidence of independent clean-machine reproduction.
- The [overview](overview.md) explains the user problem, the three responsibilities, the threshold experiment, human correction, and the three engines in plain English. Hosted sign-in/inference checks listed below remain separate and have not been repeated for these changes.

## Copilot review fixes — 2026-10-14

Addressed 13 comments from a pre-publication automated code review. A running copy of the app locked the normal build output, so this round was built into a separate output folder: zero warnings in Debug and Release, 66 offline checks, 20 HTTP checks against a temporary server, both deployment-account tests, and a syntax check of `Deploy-Azure.ps1`. No live requests or deployments were made for these fixes.

- Deployment: app registrations are reused only by explicit client ID or from the auth settings of this resource group's own Lab 002 app, never by display name; a stale federated identity credential is updated to trust the current sign-in identity; publishing uses a locked restore.
- Evaluation: unknown options are rejected (`--mdoe foundry` exits with an error instead of running the simulation); token and cost totals include the reversed-order pass; `--record` refuses to append to an existing file, and replay summaries describe the responses actually served.
- UI and documentation: sign-out stays visible on small screens; data-flow statements say that live mode sends item number, description and unit to Foundry instead of "sends nothing"; the run summary names model calls per engine; the documented check count and changelog wording are current.

## Recorded engine replaces the simulation — 2026-10-14

At the owner's request, the keyword-rule simulation was removed: its placeholder scores looked like model probabilities in a lab about a model. The recorded engine now ships with the app and is selected when no Azure settings are present.

- Bundled recordings: the live runs from 2026-10-14 on the demo form (70 responses) and the labeled set (198 responses), unchanged, embedded in the assembly. They contain synthetic descriptions and model output only.
- 67 offline checks passed, including that both recordings cover every item in both option orders and still pass the response contract with the current questions, and that a missing item returns HTTP 404 instead of an invented answer. 21 HTTP checks passed against a temporary server, including HTTP 400 for the removed `simulation` mode. Debug and Release builds had zero warnings. Builds used a separate output folder because a running copy of the app locked the normal one.
- The evaluation command's default replay reproduced the live labeled results exactly (98 of 99 for system and work type, 68 of 99 accepted at 0.90 with none wrong, 0 of 291 answers changed by option order) and the demo results (24 of 35 accepted at 0.90, $778,200 in review).
- Browser check: with no Azure settings the recorded run was selected; 35 of 35 decided; 24 lines appeared under "Accepted automatically, no review needed" without approval buttons; 11 lines needed review.

## Second opinion with gpt-6-luna — 2026-10-14

At the owner's request, lines below the threshold now go to a second model. The owner-selected subscription and Foundry resource gained a second deployment, `bid-review-escalation`: gpt-6-luna version 2026-09-22, `DataZoneStandard`, capacity 100 (100,000 tokens and 100 requests per minute). Requests used Microsoft Entra ID through Azure CLI; no keys.

- **Raw requests.** `POST <resource>/openai/v1/responses` returned HTTP 200 on the `services.ai.azure.com` host with a token for `https://ai.azure.com/.default`. Strict structured outputs rejected `enum` values containing a double quote, so such options are sent as aliases. `reasoning.effort: minimal` was rejected; `low` and `none` were accepted.
- **Demo form, recorded for replay** (Microsoft-Decision-1 replayed from the bundled run, 30 live gpt-6-luna requests at eight in parallel, 0 failures): gpt-6-luna chose the same options as Microsoft-Decision-1 for 28 of 30 lines. It disagreed on #13 bypass pumping (sanitary gravity, against force main at 0.71) and #19 tapping sleeve (size `6"`, against `none` at 0.56). At 0.90, 24 lines were accepted by the rule and 8 by agreement, and 3 lines worth $116,500 stayed with a person (#13, #19 and #35, which is Unclear), against 11 lines and $778,200 without the second opinion. The same 3 lines stayed with a person at every threshold from 0.80 to 0.99. gpt-6-luna latency: p50 9.5 s, p95 52 s, including retries; 17,901 input and 1,274 output tokens, $0.0027 at list price.
- **Labeled set, recorded for replay** (Microsoft-Decision-1 replayed from the bundled run, 84 lines that could need a second opinion at some threshold in either option order). The bundled file combines two live runs made five minutes apart with the same build, deployment and request: 82 responses from a run at four in parallel, whose other 2 requests returned HTTP 408 on both attempts, and those 2 lines from a run at eight in parallel, which itself lost 3 other lines to timeouts. gpt-6-luna chose the same options for 80 of 84 lines. Where Microsoft-Decision-1 differed from the labels, gpt-6-luna matched the label all three times: L021 material `VCP` (against `none` at 0.59), L024 system `sanitary_gravity` (against `force_main` at 0.71) and L090 work type `restoration` (against `connect_adjust` at 0.42). It also answered L086 `Dewatering` with `unclear`, where Microsoft-Decision-1 matched the label. In the other run, gpt-6-luna answered L090 `remove_abandon` and L087 `unclear`, so answers vary between runs.

  | Threshold | Accepted by rule | Accepted by agreement | Without review | Wrong among accepted | Sent to people | Wrong lines caught |
  | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
  | 0.80 | 82 | 11 | 93 of 99 | 0 | 6 | 3 of 3 |
  | 0.90 | 68 | 25 | 93 of 99 | 0 | 6 | 3 of 3 |
  | 0.95 | 58 | 35 | 93 of 99 | 0 | 6 | 3 of 3 |
  | 0.99 | 17 | 76 | 93 of 99 | 0 | 6 | 3 of 3 |

  No line was accepted by agreement with an answer that differs from its label. gpt-6-luna latency: p50 7.1 s, p95 40 s, max 60 s, including retries; 49,934 input and 3,787 output tokens, $0.0076 at list price. Synthetic labels written for this lab, one recorded run per line, no confidence intervals: this shows the mechanism, not a general error rate.
- **Earlier demo runs the same day**, discarded because each had a failed request: one at reasoning effort `low` (p50 8.9 s, one HTTP 408 before the retry existed), one at `low` (p50 8.0 s, one request over 60 seconds; it also answered #33 `unclear`), and one at `none` (p50 7.0 s, 0 failures; it answered #33 `unclear`). The client now abandons a first attempt after 20 seconds and retries once after HTTP 408, 429 or 5xx.
- **Local validation.** A running copy of the app locked the normal build output, so this round was built into a separate folder: zero warnings in Debug and Release; 101 offline checks, including the second-opinion schema and aliases, response contract, policy, retries against a local stub, and coverage of every eligible line by both bundled second-opinion recordings; 27 HTTP checks against a temporary server; the evaluation command with `--escalation replay` on both datasets; both deployment-account tests; a Bicep build; a syntax check of `Deploy-Azure.ps1`; and local Markdown links. `Validate.ps1` itself runs in CI.
- **Stateless requests.** The stored responses showed `store: true`, the service default, and Learn states that response data is retained for 30 days by default. The bundled recordings were made that way; they contain synthetic descriptions only. The client now sends `store: false`. A live pass over the demo form with the final build returned `store: false` on all 30 responses with 0 failures. gpt-6-luna agreed on 29 of 30 lines in that pass (it chose `none` for #19 this time), leaving 2 lines and $102,000 with a person at 0.90; latency p50 3.0 s, p95 34 s, max 78 s. The bundled recording, not this pass, is what the recorded engine shows.
- **Browser, recorded engine.** With the second opinion on: 35 of 35 decided, 32 · 91% accepted without review (24 by rule · 8 by agreement), $116,500 in review, gpt-6-luna median 9.0 s for 10 lines, estimated cost $0.001479 for both models. #13 showed both answers and an approval button; #15 (septic tank, 0.63) showed "Accepted by agreement"; #35 was not sent to the second model. Raising the threshold to 0.98 showed "13 lines are below the new threshold without a second opinion" and made no model call; asking filled them from the recording, giving 11 by rule and 21 by agreement with the same $116,500 in review. No horizontal overflow at a 448-pixel-wide pane.

## Shared-platform merge and safer redeployment — 2026-10-14

No live requests or Azure changes were made for this round.

- **Merge.** `main`, which now hosts Lab 001 on the shared Azure platform, was merged into this change. The root catalog keeps both labs' rows, and `Deploy-Azure.ps1` keeps the second-model parameters together with the tier-preserving `-AppServiceSku`.
- **Second Copilot review.** The automatic second-opinion phase uses the threshold set when the run started, or a lower one chosen since; a threshold raised during the run only offers the explicit Ask button. Second-opinion answers with fields the application did not ask for are rejected, with a new offline check. Contract errors name the response that failed: the decision or the second opinion. Microsoft links in `sources.md` carry the tracking parameter.
- **Third Copilot review.** A card compared the two models only when the comparison decided the route, so after a reviewer edit, or at a threshold low enough for the rule, a recorded disagreement read as "chose the same option". The card now compares the answers directly. Exports keep every second opinion obtained in the run even when the switch hides them. The catalog no longer implies that the second opinion runs in Azure. In the browser, #13 still showed "The models disagree" after its System answer was edited, and an export with the switch off kept all 10 second opinions, including #13's.
- **Fourth Copilot review.** Showing or hiding second opinions now clears approvals on lines that have one: in the browser, #13 approved while they were hidden returned to "Awaiting review" with the disagreement when they were shown again. `-SkipSecondModel` no longer reads or validates the gpt-6-luna deployment, so an unsupported type there cannot block a redeployment that leaves it out (checked against the Azure CLI stand-in). The evaluation command's timeout message names the 60-second retry.
- **Fifth Copilot review.** Cards accepted by the rule did not receive the second opinion, so lowering the threshold after a run hid the evidence already obtained. Every card now receives the line's second opinion, error and in-progress state while the switch is on; a failed second opinion on a rule-accepted line says the rule accepts it without one. In the browser, after a recorded run at 0.90, lowering the threshold to 0.50 kept all 10 second opinions on screen, and #13, now accepted by the rule, still read "The models disagree. At this threshold the rule accepts the line without the second opinion." Without the change, the same steps left none on screen.
- **Sixth Copilot review.** The cost and cleanup section now warns that Lab 001 calls `bid-review-escalation`, so on the shared platform the deployment and resource group stay, and links the shared cleanup guidance. The evaluation command refuses `--record-escalation` with `--no-order-check`, because without the reversed pass a recording could miss lines that need review only when the page reverses the options; the check runs before any configuration or request, and locally it exited with code 2 and created no file. The second-opinion switch now shows whether second opinions apply to the selected engine. In the browser, with Microsoft-Decision-1 configured to an unreachable test endpoint and no second model, the switch read off and disabled, on for the recorded engine, and off again for Microsoft-Decision-1, with no request leaving the machine; before the change it read on while disabled.
- **Redeployment could lower shared capacity.** This record shows `bid-review-decision` raised to capacity 300 and `bid-review-escalation` created at capacity 100, while the script defaulted both to 50. A redeployment without capacity arguments would have lowered both rate limits, including the deployment Lab 001 calls. The script now keeps each existing deployment's type and capacity unless they are passed, and reuses the resource group's Lab 002 Foundry resource when `-FoundryAccountName` is omitted. Checked offline against a stand-in for the Azure CLI: a redeployment sent capacities 300 and 100 and tier B1 to Bicep; an explicit `-DecisionCapacity 120` was honored; an empty resource group used 50, 50 and F1; `-SkipSecondModel` left the gpt-6-luna deployment out of the template. Not yet run against Azure.
- **Local validation** on Linux with the pinned SDK 11.0.100-rc.1.26425.128: `Validate.ps1` passed with zero build warnings, 11 Lab 001 contract checks, 104 Lab 002 offline checks, 20 and 27 HTTP checks, the recorded-run evaluation, the deployment tests and local Markdown links.
- **Browser**, headless Chromium, recorded engine with second opinions: 35 of 35 decided, 32 · 91% accepted without review (24 by rule · 8 by agreement), $116,500 in review. Raising the threshold to 0.98 made no model call and offered "Ask gpt-6-luna about 13 lines"; asking gave 11 by rule · 21 by agreement with the same $116,500. No console errors and no horizontal overflow at 448 pixels. Moving the slider during a live run was not exercised: the recorded engine answers immediately.

## Read-only Azure preview and platform verification — 2026-10-14

Executed from commit `5650002` on Windows with the owner-confirmed subscription and shared resource group. Arguments below omit environment-specific identifiers.

```powershell
.\samples\02-bid-review-queue\infra\Deploy-Azure.ps1 -Subscription '<selected-subscription>' -ResourceGroup '<shared-resource-group>' -WhatIfOnly
.\scripts\Test-AzureLabs.ps1 -Subscription '<selected-subscription>' -ResourceGroup '<shared-resource-group>' -DecisionCapacity 300 -EscalationCapacity 100
```

- **Preview: exit 0, not approval to deploy.** It printed `Preserving hosting tier: B1.` and existing `DataZoneStandard` capacities 300 for `bid-review-decision` and 100 for `bid-review-escalation`. Bicep CLI was `0.42.1`; the Foundry template API version was `2025-06-01`. What-if reported 5 resources to modify, 4 unchanged, and 2 ignored. The plan was unchanged; no `sku.capacity` change was reported. Lab 001's project and web app appeared as `Ignore`, not planned modifications.
- **Deployment held.** The shared Foundry account showed property removals for `armFeatures`, `associatedProjects` (including `support-signal`), and `defaultProject`. Model deployments showed removals for `currentCapacity`, `raiPolicyName`, and `versionUpgradeOption`. The preview also showed an unresolved role-assignment identity reference and Lab 002 site configuration changes, including Always On. [Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if?wt.mc_id=AI-MVP-5004753), accessed 2026-10-14, documents reference-expression differences and possible false-positive deletions; that does not establish that these specific shared-account removals are harmless. Their deployment effect remains unverified.
- **Platform check: exit 0, all 21 checks passed against Azure.** Both apps ran on B1; model versions, deployment types and capacities matched; managed identities held Foundry User; both callbacks and sign-in restrictions passed. Lab 002 already had second-model settings. Both endpoint hosts matched the Foundry account returned by Azure CLI. Both anonymous requests returned HTTP 302 directly to the tenant's Microsoft Entra `/oauth2/v2.0/authorize` endpoint, accepted by the checker.
- No Azure resources were changed and no inference was requested. Configuration does not prove which application build is deployed or that hosted second opinions work. Deployment and authenticated synthetic runs remain pending. The workstation also lacked the pinned .NET SDK when checked with `dotnet --version`; no package build was attempted.

## Lab platform deployment — 2026-10-15 (UTC)

Both labs moved from the earlier layout, which Lab 002's script had created with Lab 002 names, to the [lab platform](../../../docs/shared-azure-platform.md) in a new resource group. The deployment ran on Windows with an owner-confirmed subscription; the application code was the same as the pre-publication build `c2d7931`. Arguments omit environment-specific identifiers.

```powershell
./infra/Deploy-Labs.ps1 -Subscription '<selected-subscription>' -AppServiceSku B1 -DecisionCapacity 200 -ChatCapacity 100 -WhatIfOnly
./infra/Deploy-Labs.ps1 -Subscription '<selected-subscription>' -AppServiceSku B1 -DecisionCapacity 200 -ChatCapacity 100
./scripts/Test-AzureLabs.ps1 -Subscription '<selected-subscription>' -DecisionCapacity 200 -ChatCapacity 100
```

- **Preview: exit 0, before anything existed.** Azure what-if at subscription scope listed 14 resources to create in the new resource group and no change to existing resources. The web apps' identities and settings appeared masked because they depend on resources created in the same deployment, so the compiled template's app settings were inspected instead. Both web app names and the Foundry subdomain were reported available.
- **Quota.** Both layouts temporarily consumed the selected subscription's model quota. The new `decision-1` deployment used capacity 200 and `gpt-6-luna` used capacity 100. These are the observed deployment capacities, not a recommendation or a statement of quota available to another subscription.
- **Deployment: exit 0 after one fix.** The first run created the platform, the app registration, both redirect URIs and the federated identity credential, and uploaded Lab 001. Azure CLI 2.85.0 then kept reporting "Starting the site" for more than six minutes after the container log showed the site running, because the site's deployment-status list stayed empty. The run was stopped before Lab 002's upload; the CLI subscription was restored and the temporary build folder removed by hand. The script now uploads with `--track-status false`. The rerun reused the resource group, Foundry resource, both model deployments, plan and registration, uploaded both labs, and restored the CLI subscription.
- **Platform check: 21 of 21 passed** on the second attempt; the first ran while Lab 002's authentication container was still starting and got no response from it. Both apps run on one B1 plan. `decision-1` (Microsoft-Decision-1 1, capacity 200) and `gpt-6-luna` (gpt-6-luna 2026-09-22, capacity 100) succeeded, both app identities hold Foundry User, both callbacks are registered, and anonymous requests redirect to Microsoft Entra sign-in.
- **Live inference against the new deployments, from a local app.** Lab 002 ran locally with `AzureCliCredential` and live settings for the new resource, and decided item 13 with second opinions on. Microsoft-Decision-1 chose `force_main` at 0.7078 and `support_work` at 0.9954 (355 input tokens, 897 ms), matching the 2026-10-14 recording to four decimal places. gpt-6-luna chose `sanitary_gravity` and `support_work` (517 input and 24 output tokens, 2.0 seconds), so the line went to a person. Estimated cost at list prices: about USD 0.00009.
- **Not verified:** an authenticated request through the hosted app and its managed identity. It needs the owner's sign-in, which may include consent for the new registration.
- **Earlier layout.** The owner deleted the earlier resource group. Its app registration listed only the earlier apps' callbacks and was deleted with the owner's approval.
- **What-if removals that a redeployment did not apply.** The rerun applied the same template over the new platform, and the deployment succeeded. A later what-if against that platform, after the deployment review fixes, again listed removals of the Foundry account's `armFeatures`, `associatedProjects` and `defaultProject`, and of each deployment's `currentCapacity`, `raiPolicyName` and `versionUpgradeOption`. It also showed the role assignments' principal IDs as unresolved reference expressions. Read back after the rerun, all of these were unchanged: five ARM features, the Lab 001 project as associated and default project, capacities 200 and 100, `Microsoft.DefaultV2`, and `OnceNewDefaultVersionAvailable`. On this platform, then, those what-if entries were false positives. The earlier layout's held what-if showed the same properties; this observation does not prove that every such entry is harmless elsewhere.

## Hosted verification — 2026-10-15 (UTC)

The owner signed in to the hosted Lab 002 app on the lab platform with the allowed account in a browser, after accepting the consent prompt of the new sign-in registration on the first app. The application code was the same as the pre-publication build `c2d7931`; the platform was the one deployed on 2026-10-15 and recorded above.

- **Live run of the demo form** with Microsoft-Decision-1 (`decision-1`) and gpt-6-luna second opinions at threshold 0.90: 35 of 35 decided, 25 accepted by rule, 6 by agreement, 4 awaiting review (89% accepted), and $123,320 in review. No call failed, and no second opinion failed or timed out.
- **Measurements shown by the page:** median decision latency 1,078 ms; gpt-6-luna 7.0 seconds across 9 lines; estimated cost USD 0.001494 at list prices (Microsoft-Decision-1 14,692 input tokens; gpt-6-luna 5,135 input and 568 output tokens).
- **Item 13:** `force_main` at 0.70, with general at 0.16 and sanitary gravity at 0.14, and `support_work` at 0.99. gpt-6-luna chose sanitary gravity, so the line went to a person, as in the recording.
- **Live answers vary.** This run differs from the 2026-10-14 recording (24 by rule, 8 by agreement, 3 in review; item 13's force main at 0.7078). A local live request three hours earlier had matched the recording to four decimal places. The demo script therefore presents the recorded run and treats a hosted live run as an optional variant.
- **Found and fixed:** in live mode, the operational details footnote said that latency and cost "describe the earlier model runs, not this replay". The footnote now depends on the engine; this fix was not yet deployed during the run.
