# Foundry Field Notes

**Build it. Understand it. Make it reproducible.**

Learn to build reviewable AI applications with **Microsoft Foundry**. These hands-on labs connect a concrete problem to model inference, application checks, human review, and the evidence needed to understand their limits.

For developers comfortable with basic C# and JSON. The current labs use .NET; you do not need an Azure subscription to explore their offline paths. This is an independent educational project, not a Microsoft product or a production-ready application.

**[Explore the interactive field guides](https://ppiova.github.io/foundry-field-notes-labs/)** — Browse the catalog, follow Labs 001 and 002, and explore their browser exercises without installing anything. These are static learning guides, not hosted .NET apps; the exercises make no model calls.

## Samples

| Start here if you want to… | Lab | Without Azure |
| --- | --- | --- |
| Turn a support request into a proposal, check quoted evidence, and keep a person in control | [001 — Support Signal](samples/01-support-signal/README.md) · Microsoft Agent Framework with Foundry | Deterministic simulation; no model or agent framework runs |
| Ask bounded questions, interpret model probabilities, and decide which answers need review | [002 — Bid Review Queue](samples/02-bid-review-queue/README.md) · Microsoft-Decision-1 with an optional generative second opinion | Replay of saved Foundry responses; no new inference |

Follow Lab 001 for the application-validation boundary, then Lab 002 for probability-based decisions. You can also start directly with Lab 002: it does not require running Lab 001.

**Learning or presenting to .NET developers?** Use the [visual field guide portal](https://ppiova.github.io/foundry-field-notes-labs/), including clearly labeled upcoming labs. To preview it locally or publish updates, see the [preview and GitHub Pages instructions](docs/presentation-site.md). Publishing updates requires owner approval.

**Why Microsoft-Decision-1?** Lab 002 explores a different contract from chat: the application offers choices, the model returns choices and probabilities, and the application owns acceptance and review. Follow [one recorded answer from request to review](samples/02-bid-review-queue/docs/decision-model.md), including why a valid response or agreement between two models does not prove correctness.

## Coming soon

The next labs continue the public works bid story from Lab 002, one Foundry Agent Service capability at a time. Lab 001 defines its agent in application code; Labs 003 and 004 add the two agent types that Foundry runs for you: a [prompt agent and a hosted agent](https://learn.microsoft.com/en-us/azure/foundry/agents/overview?wt.mc_id=AI-MVP-5004753).

| Order | Lab | What you will build | Foundry capability | Status on Microsoft Learn |
| --- | --- | --- | --- | --- |
| **Next** | 003 — Bid Clarification Desk | Draft a request for information for each line Lab 002 sends to review; a person approves it, and nothing is sent | [Prompt agents](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/prompt-agents?wt.mc_id=AI-MVP-5004753) | No preview label |
| Planned | 004 — Hosted Bid Reviewer | Run the bid review in Foundry as your own C# agent, with its own identity and endpoint, and its tools behind one MCP endpoint | [Hosted agents](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/hosted-agents?wt.mc_id=AI-MVP-5004753) and [Toolbox](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/toolbox-overview?wt.mc_id=AI-MVP-5004753) | No preview label; toolbox tool search and skills are preview |
| Planned | 005 — Overnight Bid Watch | Review new bid forms on a schedule and remember reviewer corrections | [Routines](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/routines?wt.mc_id=AI-MVP-5004753) and [memory](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/what-is-memory?wt.mc_id=AI-MVP-5004753) | Routines: no preview label; memory: preview |
| Planned | 006 — Measure and Improve | Evaluate the agents on labeled lines, trace each call, and let the optimizer propose better instructions | Evaluation, tracing and [agent optimizer](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/agent-optimizer-overview?wt.mc_id=AI-MVP-5004753) | Agent optimizer: preview |
| Planned | 007 — Voice Bid Desk | Ask about a bid line by voice | [Voice-based prompt agents](https://learn.microsoft.com/en-us/azure/foundry/agents/quickstarts/prompt-voice-agent?wt.mc_id=AI-MVP-5004753) | Preview |
| Planned | 008 — Bid Coordinator Autopilot | A teammate with its own Microsoft 365 identity in a Teams group chat, created from a hosted-agent blueprint | [Autopilots](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/autopilot-overview?wt.mc_id=AI-MVP-5004753) | Preview; requires the Frontier program, a Microsoft 365 Copilot or Agent 365 license, and administrator approval |

Statuses were read on Microsoft Learn on 2026-10-14 and are rechecked before each lab ships. Preview capabilities are labeled as preview in every lab. This order is reviewed monthly; it is a plan, not a release date.

## Choose your path

| Path | What you need | What it demonstrates |
| --- | --- | --- |
| **Explore without Azure** | A checkout, PowerShell 7, and the pinned .NET SDK | The UI, validation, review, export, and clearly labeled simulation or replay |
| **Run with your own Foundry** | The same tools, Azure CLI, your selected subscription, model access, and authorization for inference charges | New model responses through your configured deployment |

Neither path requires access to a maintainer-hosted application. Live inference can run from the local app; Azure App Service hosting is an optional next step, with separate prerequisites and costs.

## Quickstart

Install Git, PowerShell 7, and the SDK pinned in [global.json](global.json) from the [official downloads](https://dotnet.microsoft.com/en-us/download/dotnet/11.0?wt.mc_id=AI-MVP-5004753). The current SDK is **.NET 11 RC1**; Lab 001's Foundry connector and Lab 002's decision model are **preview**. Sample READMEs list the exact versions and evidence.

Install the exact SDK version, `11.0.100-rc.1.26425.128`, not only a newer prerelease or the runtime. SDK roll-forward is disabled because RC2 changes an implicit package version and fails this snapshot's locked restore. This is a repository reproducibility choice; see [.NET SDK selection](https://learn.microsoft.com/en-us/dotnet/core/tools/global-json?wt.mc_id=AI-MVP-5004753), accessed 2026-10-15.

Get a checkout with `git clone https://github.com/ppiova/foundry-field-notes-labs.git`, then `Set-Location .\foundry-field-notes-labs`. If you already have a checkout, use its root. In PowerShell 7:

```powershell
./scripts/Test-Prerequisites.ps1
./Start-Demo.ps1 -Lab 1 -Offline
```

Open http://localhost:5187. Choose **Service outage** and **Analyze request**. Expected result: **Reliability / Priority high**, explicitly labeled simulation. No Azure credentials or spending are needed for this path.

For Lab 002, run `./Start-Demo.ps1 -Lab 2 -Offline`, open http://localhost:5190 and choose **Decide every pay item**. Expect **35 / 35** decided, **24 accepted by rule**, **8 accepted by agreement**, and **3 awaiting review** at threshold 0.90. Inspect the highlighted item 13. These are responses recorded on 2026-10-14, not new model calls; acceptance is the sample's policy, not proof of correctness.

Use **Inspect this decision** to follow the application checks. Edit an answer or reply, observe approval clear, and export the original output separately from your edits. Stop the local server with Ctrl+C; remove exported synthetic JSON when no longer needed.

`-Offline` disables live configuration for the launched process, including inherited Foundry settings and custom recording paths. It does not make package restore work without internet. The helper also recognizes an optional, Git-ignored SDK under `.dotnet/dotnet.exe` on Windows or `.dotnet/dotnet` on Linux/macOS; it is not required when the pinned SDK is on PATH. For SDK discovery, `global.json` searches `.dotnet` first, then the running `dotnet` installation. This lets SDK commands find the local pinned SDK when invoked through a .NET 10 or later host; see [SDK search paths](https://learn.microsoft.com/en-us/dotnet/core/tools/global-json?wt.mc_id=AI-MVP-5004753#paths), accessed 2026-10-16. After adding a local SDK, reload the VS Code window if the solution still reports a missing SDK.

If startup or output differs, use [Lab 001 troubleshooting](samples/01-support-signal/docs/troubleshooting.md) or [Lab 002 troubleshooting](samples/02-bid-review-queue/docs/troubleshooting.md). Do not treat an error as a successful run.

## Run with your own Foundry

Choose [Lab 001's live setup](samples/01-support-signal/README.md#run-with-microsoft-foundry) or [Lab 002's live setup](samples/02-bid-review-queue/README.md#run-with-microsoft-decision-1). Each explains endpoint shape, credentials, model requirements, data sent to Azure, expected results, failures, and cleanup. Select your subscription explicitly and review costs before provisioning or calling a model. A configured endpoint is not proof of working credentials or model access.

Foundry serves inference. Your application defines questions, validates responses, and owns the review policy. App Service can host that application, but is not required for local live inference. For optional hosting, one script creates the [lab platform](docs/shared-azure-platform.md) in your subscription and deploys the labs you select; see [Lab 001 deployment](samples/01-support-signal/docs/azure-deployment.md) and [Lab 002 deployment](samples/02-bid-review-queue/README.md#deploy-to-azure-for-demos).

## Evidence and limits

Both labs have offline contract/API checks and dated live observations. See the [Lab 001 verification record](samples/01-support-signal/docs/verification.md) and [Lab 002 verification record](samples/02-bid-review-queue/docs/verification.md) for the exact environment and results. Historical hosted runs do not verify every later UI build. Hosted runs of both labs on the lab platform, including Lab 002's second opinions, were verified on 2026-10-15; independent clean-environment reproduction remains unverified.

Simulation does not measure AI quality. Replay does not establish current Foundry availability. Synthetic evaluation is not an industry benchmark, and local approval is not a durable audit trail. Preview dependencies and service availability can change; use the versioned references in each sample.

## Layout

```text
.github/                         CI and pull request template
docs/                            Repository standards, roadmap, and static field guide portal
infra/                           Lab platform templates and the deployment script for your own subscription
samples/01-support-signal/
  README.md                      Setup and expected output
  src/SupportSignal/             API and browser UI
  tests/SupportSignal.Checks/    Provider-contract checks
  infra/                         Lab 001's web app and Foundry project on the platform
  docs/                          Architecture, troubleshooting, demo, evidence
samples/02-bid-review-queue/
  README.md                      Setup, live path, costs and expected output
  src/BidReviewQueue/            API, decision client, review policy and Blazor UI
  src/BidReviewQueue.Eval/       Evaluation and recording command
  tests/BidReviewQueue.Checks/   Offline checks, including a stubbed live client
  infra/                         Lab 002's web app on the platform
  docs/                          Architecture, troubleshooting, demo, evidence, sources
scripts/                         Shared validation scripts
FoundryFieldNotes.slnx           Solution entry point
global.json                      Pinned SDK
```

## Validation

Stop the apps before building on Windows. With PowerShell 7 and Node.js 24.15.0 (for the static presentation checks, no npm packages):

```powershell
./scripts/Validate.ps1
```

Runs locked restore, build, offline checks for both labs, the recorded evaluation, HTTP checks against temporary servers, fake-CLI Azure regressions, generated-guide checks, and local Markdown links. No Azure inference. See GitHub Actions for the result on a specific commit; local and live evidence are recorded separately.

## Guides

- Lab 001: [visual field guide](https://ppiova.github.io/foundry-field-notes-labs/labs/001/index.html) · [architecture](samples/01-support-signal/docs/architecture.md) · [troubleshooting](samples/01-support-signal/docs/troubleshooting.md) · [demo](samples/01-support-signal/docs/demo-script.md) · [verification](samples/01-support-signal/docs/verification.md)
- Lab 002: [visual field guide](https://ppiova.github.io/foundry-field-notes-labs/labs/002/index.html) · [overview](samples/02-bid-review-queue/docs/overview.md) · [code walkthrough](samples/02-bid-review-queue/docs/code-walkthrough.md) · [architecture](samples/02-bid-review-queue/docs/architecture.md) · [troubleshooting](samples/02-bid-review-queue/docs/troubleshooting.md) · [demo](samples/02-bid-review-queue/docs/demo-script.md) · [verification](samples/02-bid-review-queue/docs/verification.md) · [sources](samples/02-bid-review-queue/docs/sources.md)

## Contributing and maintaining

Use [Contributing](CONTRIBUTING.md) for change expectations and [Security](SECURITY.md) for data boundaries and reporting limitations. These are educational samples with no production support or response SLA.

Maintainer references: [lab experience guide](docs/lab-experience-guide.md), [quality standard](docs/repository-standards.md), [roadmap](docs/learning-roadmap.md), [lab platform operations](docs/shared-azure-platform.md), [release readiness](docs/release-readiness.md), and [changes](CHANGELOG.md).

**Release scope:** source code, synthetic fixtures, recorded responses, and educational guides. No hosted service or Azure access is included. See [release readiness](docs/release-readiness.md) for the publication record and remaining verification limits.

## License

Original code and documentation are licensed under the [MIT License](LICENSE). Copyright notices identify the Foundry Field Notes contributors.

Third-party dependencies and materials retain their own licenses and required notices. This license does not replace the terms applicable to Azure services, Foundry models, or recorded model responses, and does not grant access to a deployment. See [third-party materials](docs/third-party-materials.md) before redistributing dependencies or recordings.
