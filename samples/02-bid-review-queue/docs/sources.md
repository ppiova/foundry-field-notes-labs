# Sources

Accessed on 2026-10-13, except the second-model sources, accessed on 2026-10-14.

The Microsoft-Decision-1 deployment and usage guide was rechecked on 2026-10-14 for the [model walkthrough](decision-model.md): typed questions, deployment-name request field, per-option probabilities, lack of rationales, wording sensitivity, and workload-specific evaluation. The walkthrough separates this documented behavior from the application's policy and the bundled recording's exact values.

## Official Microsoft sources

| Source | What this lab relies on |
| --- | --- |
| [Deploy and use Microsoft-Decision-1 in Microsoft Foundry](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/use-foundry-models-microsoft-decision?wt.mc_id=AI-MVP-5004753) (ms.date 2026-10-07) | Question types (`noul`, `choice`, `score`), request shape (`model`, `state`, `questions`, `instructions`, `criteria`), the `/providers/microsoft/v1/systemone` path, Entra scope `https://cognitiveservices.azure.com/.default`, deployment types and CLI commands, HTTP error meanings, best practices (thresholds from error costs, an abstention option, option-order testing), and limits on consequential decisions about people. |
| [Foundry Models sold by Azure](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure?wt.mc_id=AI-MVP-5004753) (updated 2026-10-08) | Model capabilities: calibrated probability per option, inputs up to 32K tokens, text only, no rationales. Listed without a preview marker. |
| [Introducing Microsoft-Decision-1](https://commandline.microsoft.com/microsoft-decision-1-model-foundry/?wt.mc_id=AI-MVP-5004753) (Microsoft Command Line, 2026-10-09) | Availability in Foundry, the list price of $0.042 per million input tokens with free output tokens, and Microsoft's own benchmark claims, which this lab does not reproduce. |
| [Microsoft Foundry pricing](https://azure.microsoft.com/pricing/details/ai-foundry/?wt.mc_id=AI-MVP-5004753) | Where to check current prices. |
| [Configure Microsoft Entra authentication — Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad?wt.mc_id=AI-MVP-5004753) (ms.date 2026-04-27) | The v2.0 issuer format, the redirect URI `/.auth/login/aad/callback`, `allowedPrincipals.identities` and `WEBSITE_AUTH_AAD_ALLOWED_TENANTS`, HTTP 403 for failed checks, the recommendation against the implicit flow, and using a managed identity with a federated identity credential (`OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID`) instead of a client secret. |
| [Role-based access control for Microsoft Foundry](https://learn.microsoft.com/en-us/azure/foundry/concepts/rbac-foundry?wt.mc_id=AI-MVP-5004753) | Foundry User (formerly Azure AI User) for inference; role definition `53ca6127-db72-4b80-b1b0-d745d6d5456d` read from Azure on 2026-10-14. |
| [Azure Retail Prices API](https://prices.azure.com/api/retail/prices) and the App Service web app stacks API | App Service Linux prices in East US 2 (F1 $0, B1 $0.017 per hour), gpt-6-luna Data Zone Standard prices in East US 2 ($0.11 input, $0.55 output per million tokens), and .NET 11 listed as a preview Linux stack, all read on 2026-10-14. |
| [Use the Azure OpenAI Responses API](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/responses?wt.mc_id=AI-MVP-5004753) (ms.date 2026-08-18) | The v1 path `/openai/v1/responses` without an `api-version`, the Microsoft Entra scope `https://ai.azure.com/.default`, structured outputs defined in `text.format`, `content_filters` as a Foundry extension of the response, response data retained for 30 days by default, and stateless requests with `store: false`. Its examples use the `openai.azure.com` host. |
| [Structured outputs](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/structured-outputs?wt.mc_id=AI-MVP-5004753) (ms.date 2026-08-24) | The Responses API request shape (`text.format` with `type: json_schema`, `name`, `schema`, `strict: true`), `enum` as a supported type, every field required, `additionalProperties: false`, up to 100 object properties and five nesting levels, and checking `status` and refusals before reading the output. |
| [Azure OpenAI reasoning models](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/reasoning?wt.mc_id=AI-MVP-5004753) (ms.date 2026-09-21, updated 2026-09-29) | gpt-6-luna version 2026-09-22 supports the Responses API, structured outputs and reasoning effort including `none`, and needs no access request. Supported effort values vary by model; the page suggests `none` for latency-critical work such as classification. |
| [GPT-6 Astra, Sol and Luna for production agents in Microsoft Foundry](https://azure.microsoft.com/en-us/blog/gpt-6-astra-sol-and-luna-for-production-agents-in-microsoft-foundry/?wt.mc_id=AI-MVP-5004753) (Azure blog, 2026-09-22) | gpt-6-luna as the smaller, faster model for high-volume work such as extraction and routing, generally available with Standard deployments in Global and US/EU Data Zones, and US Data Zone Standard list prices of $0.11 per million input tokens and $0.55 per million output tokens (short context). |
| [Fluent UI Blazor repository](https://github.com/microsoft/fluentui-blazor) and [NuGet package 5.0.0](https://www.nuget.org/packages/Microsoft.FluentUI.AspNetCore.Components/5.0.0) | Setup (`AddFluentUIComponents`, the bundled stylesheet, `FluentProviders`, interactive render mode), the net11.0 target, the MIT license, and the statement that the library is open source and not an official part of ASP.NET Core. Component parameters were read from the package's XML documentation. |

## Observed on a live deployment, 2026-10-14

Measured in one subscription in East US 2. These are observations, not documented guarantees.

- The model catalog API reported `lifecycleStatus: Preview` and offered only `DataZoneStandard` for Microsoft-Decision-1 in East US 2, although the Learn region table lists `GlobalStandard` there too.
- The deployment's rate limit was expressed as requests (`key: request`, renewed every 60 seconds), equal to the capacity.
- Responses included `choice`, `confidence`, `probabilities` and `type` per answer, plus `model` and `usage.input_tokens` / `usage.output_tokens`. Both the `cognitiveservices.azure.com` and `services.ai.azure.com` hosts of the resource answered the decision path.
- A gpt-6-luna deployment (version 2026-09-22, `DataZoneStandard`) on the same resource answered `/openai/v1/responses` on the `services.ai.azure.com` host with a token for `https://ai.azure.com/.default`. Responses carried `status: completed`, the deployment name in `model`, a `message` output item whose `output_text` held the JSON (preceded by a `reasoning` item in 11 of 30 demo responses), and `usage` with `input_tokens`, `output_tokens` and `output_tokens_details.reasoning_tokens` (at most 69 reasoning tokens with `low` effort).
- Strict structured outputs rejected an `enum` value containing a double quote (`8"`) with an error that a quote is not allowed in string literals in strict mode. The structured outputs article does not list this limit. This sample therefore sends such options under aliases.
- `reasoning.effort: minimal` was rejected for gpt-6-luna; `low` and `none` were accepted. On the demo form, `none` was not meaningfully faster than `low` (median 7.0 s against 8.0 to 9.5 s in three `low` runs the same day, with similar tails) and answered one line `unclear`, which one of the `low` runs also did.
- gpt-6-luna latency had a long tail: across the demo recording, median 9.5 s, 95th percentile 52 s, eight requests at a time.
- All 114 bundled gpt-6-luna responses report `"store": true`. The current request builder sends `"store": false`, but the recordings keep responses only, so the value those calls sent cannot be confirmed from them. Treat retention for the recorded calls as unverified, and compare the request and response of a new live call in the inspector before relying on stateless behavior.

## Recommendations of this sample, not documented behavior

Deployment account context: [Manage Azure subscriptions with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/manage-azure-subscriptions-azure-cli?wt.mc_id=AI-MVP-5004753), accessed 2026-10-14. `az account set` selects the subscription and changes the active tenant when necessary. The script verifies both before Graph operations.

- Building span options with regular expressions so the model cannot retype numbers.
- Ranking the review queue by review priority score.
- The automatic acceptance rule and its default threshold of 0.90.
- Requiring `answers.<name>.probabilities` for every offered option, and rejecting a response without them.
- Asking a second model only below the threshold and accepting a line only when both models choose the same option for every question. The Learn article on Microsoft-Decision-1 describes gating with the decision model before a generative model; agreement between two models as an acceptance rule is this sample's design and is measured, not documented.
- `reasoning.effort: low`, a 20-second first-attempt timeout with one retry, and a 45-second limit for a second opinion.

## Community context, not evidence

These posts appeared in the days after the launch. They informed what to test, not what this lab claims.

- [ElBruno.AI.Decisions](https://github.com/elbruno/ElBruno.AI.Decisions), a community .NET SDK for decision models, and its [announcement](https://elbruno.com/2026/10/09/less-chat-more-decisions-introducing-elbruno-ai-decisions-for-net/).
- [Microsoft-Decision-1 vs Jev, tested from C#](https://jocheojeda.com/2026/10/12/microsoft-decision-1-vs-jev/), which reports response fields, a required Content-Length, a `retry-after-ms` header on HTTP 429, and that `microsoft` is reserved in deployment names. This sample sends Content-Length and honors `retry-after-ms` or `Retry-After`; the other observations are unverified.
