# Lab 001 — Support Signal

Foundry Field Notes · Build it. Understand it. Make it reproducible.

A US English support-triage workbench: enter a synthetic request, inspect a classification and an exact evidence excerpt, edit the next step and reply, approve locally, and export JSON. No messages are sent and no operational actions are executed.

All commands below run from the repository root, not this sample directory.

### What you will learn

For developers familiar with basic C# and JSON; no agent-framework experience is required.

1. Use a code-defined Microsoft Agent Framework (MAF) agent with Foundry inference for a bounded support-triage task.
2. Validate output structure and quoted evidence without confusing those checks with semantic correctness.
3. Keep human edits separate from the original proposal and invalidate approval when reviewed content changes.
4. Distinguish deterministic simulation from a live model call, including failure and cost boundaries.

### Choose your path

| Path | Start here | Required access |
| --- | --- | --- |
| Explore without Azure | [First success](#first-success) and the local exercise in the guide | Local tools only; deterministic simulation |
| Run new inference from your local app | [Run with Microsoft Foundry](#run-with-microsoft-foundry) | Your Foundry project, compatible deployment, and authorized spending |
| Host the app in Azure (optional) | [Deploy Lab 001 to Azure](docs/azure-deployment.md) | Your subscription, deployment permissions, model quota, and hosting budget |

You do not need access to a maintainer-hosted app. Hosting uses the repository's [lab platform](../../docs/shared-azure-platform.md), which one script creates in your subscription; Lab 002 is not required. Local live inference does not require deploying App Service.

### Guided learning path

Start with the [step-by-step service-outage lab](docs/guided-lab.md). Its live walkthrough and separate simulation exercise have distinct instructions and evidence. The UI's **Open the guided lab** link opens the same walkthrough at `/guide.html`.

The Markdown guide is the source of truth. After editing it, run `./scripts/Build-SupportGuide.ps1` to refresh the browser copy; `-Check` verifies they match. Simulation evidence is separate from the recorded Azure run verified on 2026-10-14.

### First success

Explore the application workflow without Azure first. The deterministic result below is not evidence of a model run; switch explicitly to the live path when you want to exercise Foundry.

Prerequisites: PowerShell 7 and the SDK pinned in `global.json` (.NET 11 RC1) from the [official .NET download page](https://dotnet.microsoft.com/en-us/download/dotnet/11.0?wt.mc_id=AI-MVP-5004753). Run `./scripts/Test-Prerequisites.ps1` to check SDK resolution before starting. The helper recognizes the SDK on PATH or an optional repository-local copy under `.dotnet`, ignored by Git.

```powershell
./Start-Demo.ps1 -Lab 1 -Offline
```

Open http://localhost:5187. Select **Service outage**, click **Analyze request**, and expect **Reliability / Priority high** in simulation mode. Edit the reply, approve it, and export JSON. Editing either output clears approval. Editing the input or mode clears the proposal. Reloading clears all browser state. Stop with Ctrl+C.

Simulation is a deterministic keyword-based teaching fixture, not AI inference, MAF execution, or a quality benchmark. It is intentionally limited and can misclassify negation or mixed-language requests.

### Run with Microsoft Foundry

Use your existing Foundry project and a model deployment compatible with Responses. Follow the [official Foundry provider prerequisites](https://learn.microsoft.com/en-us/agent-framework/integrations/by-component/model-providers/microsoft-foundry?wt.mc_id=AI-MVP-5004753), accessed 2026-10-14, if you do not have them. You also need Azure CLI and permission to invoke the deployment. Model availability and permissions must be checked in your subscription.

This implementation uses MAF's code-first `AIProjectClient.AsAIAgent` integration, not a hosted agent resource. The local commands below provision no resources; the separate Azure deployment script does.

```powershell
az login
if ($LASTEXITCODE -ne 0) { throw 'Azure sign-in failed.' }
az account set --subscription 'YOUR-SUBSCRIPTION'
if ($LASTEXITCODE -ne 0) { throw 'Subscription selection failed; do not start the live app.' }
az account show --subscription 'YOUR-SUBSCRIPTION' --query '{name:name,id:id,tenantId:tenantId}' -o table
$env:FOUNDRY_PROJECT_ENDPOINT = 'https://YOUR-RESOURCE.services.ai.azure.com/api/projects/YOUR-PROJECT'
$env:FOUNDRY_MODEL = 'YOUR-DEPLOYMENT-NAME'
./Start-Demo.ps1
```

Confirm that the selected subscription and tenant are the intended ones; stop if selection fails. Omit `-Offline` for this live path. The signed-in identity needs permission to invoke that project's model. Select **Microsoft Foundry · MAF** in the UI. A configured endpoint is not proof of valid credentials or model access. Live requests transmit the synthetic input to Azure and incur the deployment's normal charges. No API keys are needed or stored. The server uses `AzureCliCredential` explicitly for local development. A live error stays an error; it never silently falls back to simulation.

Cloud execution status and observed results are recorded in [verification](docs/verification.md). Configuration alone is not proof of successful inference.

After a successful live request, inspect the category, priority, and exact evidence excerpt; approve, edit, and confirm approval clears. Export must identify `mode: foundry` and retain the original proposal separately from your edits. Do not expect the exact prose from the simulation fixture. See [troubleshooting](docs/troubleshooting.md) for authentication, model access, and timeout failures.

Stop the local app with Ctrl+C and remove exported synthetic JSON when finished. These local commands create no resources to delete, but your existing Azure services may continue to incur charges. If you separately provisioned hosting, follow the deployment guide's scoped cleanup rather than deleting shared resources.

### Stack and lifecycle

Verified against official docs and package/release metadata on 2026-10-13:

| Component | Pinned version | Status in this sample |
| --- | --- | --- |
| .NET SDK | 11.0.100-rc.1.26425.128 | Release candidate / prerelease |
| Microsoft.Agents.AI.Foundry | 1.24.0-preview.261006.1 | Preview connector |
| Azure.Identity | 1.21.0 | Stable package |
| UI | HTML, CSS, browser JavaScript | Served by ASP.NET Core; no Node build |

`packages.lock.json` pins transitive dependencies. These are the latest versions returned by the consulted feeds at preparation time, not a promise that the repository always tracks latest. Preview APIs may change. No blanket GA claim is made for Foundry models or features; verify availability for your region and deployment.

### Architecture and boundaries

Browser → ASP.NET Core `/api/analyze` → simulation rules **or** MAF → Foundry Responses → application validation → human review in browser.

- The app validates input length, category, priority, required fields and exact evidence membership. This catches malformed results, not semantic errors or all prompt injection.
- Request content is untrusted data. The agent has no tools or side-effect permissions. A single model-backed agent is enough for this bounded example; multi-agent orchestration is not needed.
- Live calls have a 60-second cancellation deadline and a two-request concurrency limit. Requests are capped at 16 KiB and 6,000 text characters.
- Approval is an in-memory UI decision, not a durable audit trail or identity-verified approval. Export retains original model output and separate human edits.
- Azure hosting uses App Service authentication and the shared platform's Entra user allowlist. Local development has no application authentication and must bind only to localhost. Durable approvals, persistence, and production operations remain outside the sample. Exported files contain the request and generated text.
- The page renders model text as text, never HTML. No external UI assets or analytics are loaded.

### Verification

```powershell
dotnet restore samples/01-support-signal/src/SupportSignal --locked-mode
dotnet build samples/01-support-signal/src/SupportSignal --no-restore
dotnet run --project samples/01-support-signal/tests/SupportSignal.Checks
# With the demo running:
./scripts/Test-Demo.ps1
```

These commands use the pinned SDK on PATH. If you installed it only under `.dotnet`, use that executable instead. `./scripts/Validate.ps1` resolves either installation and runs these checks, and those of Lab 002, against temporary servers.

See [verification](docs/verification.md) and [demo script](docs/demo-script.md).

### Official references

- [Foundry provider and code-first agent pattern](https://learn.microsoft.com/en-us/agent-framework/integrations/by-component/model-providers/microsoft-foundry?wt.mc_id=AI-MVP-5004753)
- [Microsoft Agent Framework](https://github.com/microsoft/agent-framework)
- [.NET 11 downloads](https://dotnet.microsoft.com/en-us/download/dotnet/11.0?wt.mc_id=AI-MVP-5004753)
- [.NET 11 release metadata](https://builds.dotnet.microsoft.com/dotnet/release-metadata/11.0/releases.json)
- [MAF Foundry package](https://www.nuget.org/packages/Microsoft.Agents.AI.Foundry/1.24.0-preview.261006.1)

Original code and documentation use the [MIT License](../../LICENSE); see the root [license scope](../../README.md#license) for third-party and service terms. This independent educational sample implies no Microsoft affiliation or production support. [Publication review](../../docs/release-readiness.md) remains separate.
