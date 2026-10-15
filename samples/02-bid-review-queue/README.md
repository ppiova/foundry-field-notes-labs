# Lab 002 — Bid Review Queue

Build it. Understand it. Make it reproducible.

An estimator has a unit-price bid form with dozens of pay items and two days to bid. Before pricing, every line has to be mapped: which utility system, what work, which pipe size, material and depth band. Reviewing every line takes time; a wrong mapping on an expensive line costs money.

This lab maps each pay item with **Microsoft-Decision-1**, a Foundry model that returns a probability for every option you offer instead of generated text, and turns those probabilities into a review queue ordered by review priority score. When Microsoft-Decision-1 is unsure, **gpt-6-luna** answers the same closed questions as a second opinion: if both models choose the same options, the line is accepted by agreement; if not, a person decides with both answers on screen. It is an educational sample with a synthetic bid form. It does not price or submit bids or send messages; in live mode it sends each pay item's number, description and unit to your Foundry deployments.

All commands run from the repository root.

## What you will learn

For developers familiar with C# and JSON who want to understand bounded model decisions. You do not need to complete Lab 001 first.

1. Call Microsoft-Decision-1 from C# with Microsoft Entra ID, using the documented request: a `state` plus typed questions.
2. Let the application build every option. Fixed taxonomies cover system and work type; sizes, materials and depth bands are spans copied from the description. Reject an answer outside those options; choosing the wrong offered value is still possible.
3. Validate the response contract: an offered option and a probability for every offered option. A failed call is an error, never a silent substitute.
4. Turn probabilities into a business rule: a threshold, an abstention option, and a queue ranked by line amount × (1 − weakest probability).
5. Ask a second model only where the first is unsure: gpt-6-luna through the Azure OpenAI v1 Responses API, held to the same options by strict structured outputs, with agreement as the acceptance rule.
6. Measure on labeled data: accuracy, Brier score, reliability, option-order robustness, how often two agreeing models are wrong together, latency and cost.

## Choose your path

| Path | Start here | Required access |
| --- | --- | --- |
| Explore without Azure | [Recorded first success](#first-success-the-recorded-run-no-azure) | Local tools; bundled responses, no new inference |
| Run new inference from your local app | [Run with Microsoft-Decision-1](#run-with-microsoft-decision-1) | Your subscription, model access, and authorized inference charges |
| Host your own app (optional) | [Deploy to Azure](#deploy-to-azure-for-demos) | Deployment permissions and a separate hosting budget |

No maintainer-hosted application or shared subscription is required. Read [how Microsoft-Decision-1 works in Foundry](docs/decision-model.md) alongside the highlighted case: the model supplies choices and probabilities; the application decides what is accepted or reviewed. For teaching others, use the [five-minute recorded demo](docs/demo-script.md); to present or read the code, follow item 13 through the [code walkthrough](docs/code-walkthrough.md).

**Evidence limits:** the bundled recordings and local live evaluations are dated 2026-10-14. A hosted live run with second opinions was verified on 2026-10-15; independent clean-environment reproduction remains unverified. See [verification](docs/verification.md) for measured results, not a production-readiness claim. Operators updating an existing shared platform must also review [deployment cautions](../../docs/release-readiness.md#evidence-and-operational-notes).

## First success: the recorded run, no Azure

Prerequisites: PowerShell 7 and the SDK pinned in [global.json](../../global.json) (.NET 11 RC1) from the [official download page](https://dotnet.microsoft.com/en-us/download/dotnet/11.0?wt.mc_id=AI-MVP-5004753). Startup reports a missing or incompatible SDK before launching.

```powershell
./Start-Demo.ps1 -Lab 2 -Offline
```

Open http://localhost:5190. `-Offline` disables live settings for this process and selects the bundled recordings, regardless of terminal configuration. **Recorded Microsoft-Decision-1 run** is selected, and the top panel confirms that recorded second opinions are on. Choose **Decide every pay item**, then follow **inspect item 13**. Expected primary counts: **35 / 35** decided, **24 accepted by rule**, **8 accepted by agreement**, and **3 awaiting review**. Acceptance is this demo's policy, not proof of correctness.

Open **Inspect this decision** in the highlighted case for the input, original probabilities, checks, and review route; expand **HTTP request and response** for the JSON exchanged with Foundry. The **Foundry model walkthrough** is served at `/model-guide.html`. Item 13 appears once; queue totals include it. Expand **Operational details** to see **$116,500** in review. The recorded-run notice distinguishes these saved answers from new inference.

Under **Policy and optional experiments**, turn the second opinion off to see the rule alone: 24 accepted and $778,200 in review. With it on, raise the threshold to 0.98: a yellow bar offers second opinions for 13 newly uncertain lines, but the slider itself never calls a model. Edit an answer and approval clears; reload clears everything. **Full bid form** expands the dataset and JSON upload. Uploaded forms do not inherit the bundled item 13 guidance. Stop with Ctrl+C.

The UI is a Blazor Server page built with [Fluent UI Blazor](https://github.com/microsoft/fluentui-blazor), so it follows Fluent 2 styling and your system's light or dark theme. The review policy runs in C# only; the same code serves the page, the HTTP API and the evaluation command.

The recorded run shows real Microsoft-Decision-1 responses from a live run of the demo form on 2026-10-14, in both option orders, and real gpt-6-luna second opinions recorded the same day for every line that could need one at some threshold, all embedded in the app. It makes no requests and costs nothing, and every response passes the same contract as a live one. It cannot decide items that were not recorded, such as your own bid form; use the live engine for those.

Run the evaluation command the same way:

```powershell
dotnet run --project samples/02-bid-review-queue/src/BidReviewQueue.Eval -- --escalation replay
```

It replays the recorded responses of both models for 99 labeled synthetic pay items and writes a report under `artifacts/bid-review-queue/`, reproducing the measurements in [verification](docs/verification.md) without Azure. Leave out `--escalation replay` to evaluate Microsoft-Decision-1 alone, or add `--dataset demo` to evaluate the demo bid form by dollars. Commands use the pinned SDK on PATH; if installed only under `.dotnet`, use that executable instead.

## Run with Microsoft-Decision-1

You need an Azure subscription you have chosen for this test, a Microsoft Foundry resource (kind `AIServices`) with a custom subdomain, and permission to create model deployments; the Microsoft Learn article names **Cognitive Services Contributor** for deploying. For inference with Microsoft Entra ID, the **Foundry User** role (formerly Azure AI User) covers the data actions.

These commands use the deployment path verified on 2026-10-14 in East US 2. Select and confirm your subscription before creating anything. Replace the placeholders with your own values. If you already host the [lab platform](../../docs/shared-azure-platform.md), reuse its deployments rather than creating another set.

```powershell
$subscription = 'YOUR-SUBSCRIPTION'
az login
if ($LASTEXITCODE -ne 0) { throw 'Azure sign-in failed.' }
az account set --subscription $subscription
if ($LASTEXITCODE -ne 0) { throw 'Subscription selection failed; do not create resources.' }
az account show --subscription $subscription --query '{name:name,id:id,tenantId:tenantId}' -o table
az cognitiveservices model list --subscription $subscription --location eastus2 --query "[?model.name=='Microsoft-Decision-1'].{kind:kind, skus:model.skus[].name, lifecycle:model.lifecycleStatus}"
```

Stop if sign-in, subscription selection, or the model availability check fails; do not continue under the CLI's previous default. The [Azure subscription guide](https://learn.microsoft.com/en-us/cli/azure/manage-azure-subscriptions-azure-cli?wt.mc_id=AI-MVP-5004753), accessed 2026-10-14, documents explicit subscription selection.

In the verified subscription and region the catalog offered only `DataZoneStandard`, which keeps inference processing in the US data zone, although the Learn region table also lists `GlobalStandard` there. Deployment capacity for this model is a **requests-per-minute** limit (the deployment reports a `request` rate limit renewed every 60 seconds), not a token limit: capacity 50 allows 50 requests per minute. One run of the demo form is 35 requests.

After reviewing [costs and cleanup](#cost-and-cleanup), create resources only if you do not already have suitable ones in your selected subscription:

```powershell
az group create --subscription $subscription --name YOUR-RESOURCE-GROUP --location eastus2
az cognitiveservices account create --subscription $subscription --name YOUR-RESOURCE --resource-group YOUR-RESOURCE-GROUP --location eastus2 --kind AIServices --sku S0 --custom-domain YOUR-RESOURCE
az cognitiveservices account deployment create --subscription $subscription --name YOUR-RESOURCE --resource-group YOUR-RESOURCE-GROUP --deployment-name decision-1 --model-name "Microsoft-Decision-1" --model-format Microsoft --model-version "1" --sku-name DataZoneStandard --sku-capacity 50
```

For the second opinion, deploy gpt-6-luna on the same resource. Its capacity is in units of 1,000 tokens per minute, and a second opinion uses about 600 tokens:

```powershell
az cognitiveservices account deployment create --subscription $subscription --name YOUR-RESOURCE --resource-group YOUR-RESOURCE-GROUP --deployment-name gpt-6-luna --model-name gpt-6-luna --model-format OpenAI --model-version "2026-09-22" --sku-name DataZoneStandard --sku-capacity 50
```

Using the same signed-in terminal and selected subscription, start the live demo without `-Offline`:

```powershell
$env:FOUNDRY_RESOURCE_ENDPOINT = 'https://YOUR-RESOURCE.services.ai.azure.com'
$env:FOUNDRY_DECISION_DEPLOYMENT = 'decision-1'
$env:FOUNDRY_ESCALATION_DEPLOYMENT = 'gpt-6-luna'
$env:FOUNDRY_ESCALATION_MODEL = 'gpt-6-luna'
./Start-Demo.ps1 -Lab 2
```

With these settings the live engine is selected by default. `FOUNDRY_ESCALATION_MODEL` is only the label shown on the page and used for the cost estimate; leave out `FOUNDRY_ESCALATION_DEPLOYMENT` to run without a second model. Use the **resource** endpoint from the deployment details page, not a project endpoint (`/api/projects/...`); the app rejects project endpoints with that message. Select **Microsoft-Decision-1 · decision-1**. The app calls `<resource endpoint>/providers/microsoft/v1/systemone` with a token from `AzureCliCredential`. No API key is read or stored. Your identity needs data-plane access to the deployment; HTTP 403 means a role assignment is missing.

Each line sends its pay item number, description and unit. Quantities and prices stay in the app. The run makes one request per pay item (35 for the demo form, four at a time), plus one more per line if you run the order check. With capacity 50, wait a minute before the order-check run. With the second opinion on, lines below the threshold then go to gpt-6-luna, eight at a time, through `POST <resource endpoint>/openai/v1/responses` with a token for `https://ai.azure.com/.default`. At 0.90 that is 10 lines of the demo form. Expect the decisions in a few seconds and the second opinions in about a minute: on 2026-10-14 the median gpt-6-luna answer took 9.5 seconds and a few took close to a minute. A line whose second opinion fails or times out stays with a person.

Live evaluation, with optional recordings for offline replay (each run records to a new file). `--max-rpm` keeps the run under the deployment's limit instead of relying on retries:

```powershell
dotnet run --project samples/02-bid-review-queue/src/BidReviewQueue.Eval -- --mode foundry --concurrency 2 --max-rpm 45
dotnet run --project samples/02-bid-review-queue/src/BidReviewQueue.Eval -- --mode foundry --dataset demo --concurrency 2 --max-rpm 45 --record artifacts/bid-review-queue/demo-run.jsonl
dotnet run --project samples/02-bid-review-queue/src/BidReviewQueue.Eval -- --dataset demo --escalation foundry --concurrency 4 --record-escalation artifacts/bid-review-queue/escalation-demo-run.jsonl
$env:BID_REVIEW_REPLAY_FILE = (Resolve-Path artifacts/bid-review-queue/demo-run.jsonl).Path
$env:BID_REVIEW_ESCALATION_REPLAY_FILE = (Resolve-Path artifacts/bid-review-queue/escalation-demo-run.jsonl).Path
./Start-Demo.ps1 -Lab 2
```

The third command replays the bundled Microsoft-Decision-1 run and asks gpt-6-luna live about every line that could need a second opinion at some threshold, in either option order; it therefore refuses `--no-order-check`. **Recorded Microsoft-Decision-1 run** then replays the saved responses through the same validation. Its latency is the latency measured when recorded. The recordings contain the synthetic descriptions and model output only.

### Cost and cleanup

Microsoft's announcement lists $0.042 per million input tokens with free output tokens for Microsoft-Decision-1 (2026-10-09). For gpt-6-luna, the Azure blog announcement and the Azure Retail Prices API list $0.11 per million input tokens and $0.55 per million output tokens for US Data Zone Standard (read 2026-10-14). Second opinions for the whole demo form cost $0.0027 when recorded, and a demo run at 0.90 about $0.0015 for both models together. The evaluation report and the page print measured tokens and an estimate; check current [Foundry pricing](https://azure.microsoft.com/pricing/details/ai-foundry/?wt.mc_id=AI-MVP-5004753) for your deployment types before relying on it. Standard deployments are billed per token; capacity is a rate limit. If you created a resource group only for this lab and no other lab uses it, delete it when you finish; that removes the resource and both deployments:

```powershell
az group delete --subscription $subscription --name YOUR-RESOURCE-GROUP
```

To keep the resource, delete only the deployments with `az cognitiveservices account deployment delete --subscription $subscription --name YOUR-RESOURCE --resource-group YOUR-RESOURCE-GROUP --deployment-name decision-1`, and the same command with `--deployment-name gpt-6-luna` when no other lab calls it. On the lab platform, Lab 001 also calls `gpt-6-luna`: keep it and the resource group while any lab uses them, and follow [platform cleanup](../../docs/shared-azure-platform.md#retire-a-lab-or-delete-the-platform). The app itself creates no Azure resources. Exported JSON and recordings stay on your machine until you delete them.

## Deploy to Azure for demos

The app can run on Azure App Service so you can open it from any browser during a demo. **Only the account that runs the deployment script can open it.** Anyone else who wants a hosted copy deploys it in their own subscription and tenant with the same script; nothing in this repository points to a shared deployment.

Lab 002 runs on the [lab platform](../../docs/shared-azure-platform.md), which the same script creates when it does not exist. Preview first, then deploy:

```powershell
az login
./infra/Deploy-Labs.ps1 -Subscription "YOUR-SUBSCRIPTION" -Labs 02 -WhatIfOnly
./infra/Deploy-Labs.ps1 -Subscription "YOUR-SUBSCRIPTION" -Labs 02
```

The subscription is a required argument on purpose; the script never assumes your Azure CLI default. `-DecisionCapacity` sets the Microsoft-Decision-1 requests-per-minute limit, `-ChatCapacity` sets gpt-6-luna's limit in thousands of tokens per minute, and `-AppServiceSku B1` switches to a paid plan. New resources start on F1 and capacity 50; a redeployment keeps the existing plan's tier and each existing model deployment's type and capacity unless you pass these parameters, and prints what it keeps. Capacity uses your subscription's model quota; see [quota](../../docs/shared-azure-platform.md#preview-and-deploy). `-WhatIfOnly` runs the same reads and shows Azure what-if without changing anything, also before the resource group exists. Omit `-Labs` to host both labs. The script prints each app's URL and the read-only check command for the labs it deployed.

What the script creates for Lab 002 ([infra/main.bicep](infra/main.bicep) and the platform templates):

| Resource | Purpose | Cost driver |
| --- | --- | --- |
| Foundry resource (`AIServices`, S0, API keys disabled) and the `decision-1` deployment (Microsoft-Decision-1, `DataZoneStandard`) | The decision model | Input tokens |
| `gpt-6-luna` deployment: gpt-6-luna 2026-09-22, `DataZoneStandard` | The second opinion for uncertain lines; Lab 001 shares it | Input and output tokens, only for lines below the threshold |
| App Service plan `asp-ffn-labs` (Linux, F1 by default) and web app `app-ffn-lab02-bid-review-<suffix>` | Hosts the Blazor app | F1: $0 per hour. B1: $0.017 per hour. Azure Retail Prices API, Linux, East US 2, 2026-10-14 |
| User-assigned managed identity | The app's sign-in credential, through a federated identity credential, instead of a client secret | None |
| Two Foundry User role assignments | The app's system-assigned identity calls both models; you can run the evaluation locally | None |
| Single-tenant Microsoft Entra app registration | App Service sign-in | None |

The shared rows already exist when another lab is hosted; the script then reuses them.

How access is limited, following the Microsoft Learn article on App Service authentication with Microsoft Entra:

- Every request, including `/api`, requires sign-in. The issuer is your tenant's v2.0 endpoint, and `WEBSITE_AUTH_AAD_ALLOWED_TENANTS` limits tokens to that tenant.
- The built-in authorization policy (`allowedPrincipals.identities`) admits only the object ID of the user who ran the script. Other users in the tenant get HTTP 403.
- No client secret exists. App Service presents a federated credential from a user-assigned managed identity that is used for nothing else.
- The app calls both models with its system-assigned managed identity (`FOUNDRY_CREDENTIAL=managed-identity`).

The script publishes a self-contained linux-x64 build on the .NET 10 Linux image, so the app does not depend on the platform's .NET 11 runtime, which App Service lists as a preview. F1 has daily compute quotas and no Always On, so the app sleeps when idle and the first request takes a few seconds; open it before a demo. For a demo day you can redeploy with `-AppServiceSku B1` and back to F1 afterward; before moving back, turn off Always On on each app, or the script stops and says which apps still have it. The plan is shared, so a tier change applies to every lab on it; hosting both labs needs B1 (see [platform cost](../../docs/shared-azure-platform.md#cost)). See [App Service limits](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits?wt.mc_id=AI-MVP-5004753#azure-app-service-limits).

### Live status

**Live path verified on 2026-10-14** against a `DataZoneStandard` deployment in East US 2, from the UI, the evaluation command and a raw request. Responses carried the fields this sample expects (`answers.<question>.probabilities`, `usage.input_tokens`).

On the 99 synthetic labeled items, one run gave 99% accuracy for system and work type, 100% for size and depth band, and 96.7% for material. At a 0.90 threshold, 68 of 99 lines were accepted automatically with no wrong line among them, and review caught all 3 lines whose answers differed from the labels; each of those answers had a probability of 0.71 or less. Reversing every option list changed 0 of 291 answers. Median round trip was 226 ms from the test machine, and the pass used 41,435 input tokens (about $0.0017 at list price). These are measurements on synthetic data written for this lab, not a general benchmark; details are in [verification](docs/verification.md).

**Second opinion verified on 2026-10-14** with a gpt-6-luna `DataZoneStandard` deployment on the same resource. gpt-6-luna chose the same options as Microsoft-Decision-1 for 80 of the 84 labeled lines that could need a second opinion. At 0.90, the rule accepted 68 lines and agreement 25 more, so 93 of 99 needed no review, with no wrong line among them; the 6 lines left for people included all 3 that differed from the labels, and on each of those gpt-6-luna had chosen the labeled answer. On the demo form, agreement cut the amount in review at 0.90 from $778,200 to $116,500. Second opinions were slow: median 7 to 10 seconds and some close to a minute, and 0 to 4% of the requests in a run failed with HTTP 408 or a timeout even after a retry; those lines stay with a person. Answers also varied between runs, so treat agreement as a measured rule on your own labels, not a guarantee.

## Stack and lifecycle

Verified against official documentation and package metadata on 2026-10-13:

| Component | Version | Status in this sample |
| --- | --- | --- |
| .NET SDK | 11.0.100-rc.1.26425.128 | Release candidate |
| Azure.Identity | 1.21.0 | Stable package |
| Microsoft.FluentUI.AspNetCore.Components (+ Icons) | 5.0.0 | Stable release (2026-09-25) that lists a net11.0 target. Open source under MIT and maintained in Microsoft's repository, but not an official part of ASP.NET Core; support is best effort through GitHub. |
| Microsoft-Decision-1 | Model version 1, Decision API | **Preview.** The Azure model catalog API (`az cognitiveservices model list`, East US 2) reported `lifecycleStatus: Preview` on 2026-10-14, although the Learn model table (updated 2026-10-08) shows no preview marker. |
| gpt-6-luna | Model version 2026-09-22, Azure OpenAI v1 Responses API | Generally available per the Azure blog announcement of 2026-09-22. The Learn reasoning-models article lists Responses API, structured outputs and reasoning effort support for this version. Called over REST; no OpenAI SDK package. |
| UI | Blazor Server (interactive) | No Node build; one small JavaScript module saves the export file |

There is no Microsoft Agent Framework in this lab on purpose: each pay item is one bounded, single-turn decision with no tools and no conversation. [Lab 001](../01-support-signal/README.md) uses an agent for a task that generates text.

## Architecture and boundaries

Blazor page (or `/api/decide`) → `DecisionService` → question builder → Microsoft-Decision-1 or the recorded run → response contract → review policy → second opinion for uncertain lines → human review on the page.

- The application writes every option; the models only select. Decision responses that choose an option not offered, skip an option's probability, or do not sum to 1 are rejected. Second opinions use a strict JSON schema whose `enum` lists only the offered options, and are rejected if incomplete, refused or outside those options.
- A line is accepted automatically only when every answer clears the threshold, no answer is `unclear`, and each selected option is the most probable one. Moving the threshold reruns this C# policy on the decisions already received, without new requests.
- Below the threshold, a line with no `unclear` answer can be accepted by agreement only when gpt-6-luna chooses the same option for every question. Disagreement, a failed or slow second opinion, or a reviewer's edit leaves it with a person. Agreement is this sample's rule, measured on synthetic labels; it is not a documented guarantee.
- Descriptions are untrusted data. The model has no tools and returns numbers, not instructions; Razor encodes all text.
- The Content Security Policy allows same-origin scripts only. It allows inline styles because Fluent UI components set style attributes.
- API requests are capped at 16 KiB, uploaded bid forms at 256 KB and 150 items, and descriptions at 500 characters. Decision calls time out after 30 seconds and retry once after HTTP 429. Second-opinion calls retry once after a 20-second first attempt, HTTP 408, 429 or 5xx, and stop at 45 seconds.
- Approval and edits live in the page's server-side session only and are lost on reload. There is no authentication, persistence or production hosting. Bind to localhost and use synthetic or non-confidential data.
- The Learn article says not to use the model as the sole decision-maker for consequential decisions about people, such as credit, employment, housing, healthcare or legal matters. This lab decides about documents and keeps a person in the loop.

More detail: [plain-English overview](docs/overview.md) · [code walkthrough](docs/code-walkthrough.md) · [architecture](docs/architecture.md) · [demo script](docs/demo-script.md) · [troubleshooting](docs/troubleshooting.md) · [verification](docs/verification.md) · [sources](docs/sources.md).

## Verification

```powershell
./scripts/Validate.ps1
```

Runs the deployment-account tests and the 128 offline checks (bid form uploads, option builder, label alignment, request shape, response contract, review policy and reviewer edits, the second-opinion schema, contract and policy, the bundled recordings of both models, settings and credentials, both live clients against a local stub, the requests kept for the inspector, the shared decision service, replay, scoring, and every excerpt in the code walkthrough), the evaluation command with second opinions on the bundled recordings, and the HTTP checks for both labs. No live Azure calls.

The browser model guide is generated from `docs/decision-model.md`. After editing that source, run `./scripts/Build-BidReviewGuide.ps1` from the repository root. Validation checks that the served copy stays synchronized.

Original code and documentation use the [MIT License](../../LICENSE); see the root [license scope](../../README.md#license) for third-party and service terms. This independent educational sample implies no Microsoft affiliation or production support. [Publication review](../../docs/release-readiness.md) remains separate.
