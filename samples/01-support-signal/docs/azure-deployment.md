# Deploy Lab 001 to Azure

This optional hosting path puts the UI, API, and MAF execution in App Service; a Foundry project provides the model endpoint. It uses MAF's code-first direct-inference pattern, not a hosted-agent resource. You can instead [run the local app against your Foundry deployment](../README.md#run-with-microsoft-foundry) without App Service.

Lab 001 runs on the [lab platform](../../../docs/shared-azure-platform.md): a Foundry resource with the `gpt-6-luna` chat model deployment, an App Service plan, and sign-in. The same script creates the platform when it does not exist, and reuses it when it does. Lab 002 is not required. No access to the reference deployment is required.

## Prerequisites and deployment

Select your intended subscription explicitly. You need permission to create resource groups, resources and role assignments (for example Owner, or Contributor with User Access Administrator), permission to create or update a Microsoft Entra app registration, availability and remaining quota for the chat model (`gpt-6-luna`, `DataZoneStandard`) in the region, Azure CLI, PowerShell 7, and the pinned .NET SDK. Microsoft-Decision-1 is deployed only with Lab 002, so Lab 001 alone needs no quota for it. Review [cost and quota](../../../docs/shared-azure-platform.md#cost) first.

From the repository root:

```powershell
./infra/Deploy-Labs.ps1 -Subscription '<selected-subscription>' -Labs 01 -WhatIfOnly
./infra/Deploy-Labs.ps1 -Subscription '<selected-subscription>' -Labs 01
```

The script publishes a self-contained Linux build using the lock file before provisioning. For Lab 001 it creates the project `proj-lab01-support-signal`, the web app `app-ffn-lab01-support-signal-<suffix>` and its inference role, adds the app's redirect URI to the sign-in registration while keeping existing ones, and uploads the application. It creates the shared resources only if they are missing, and keeps an existing plan's tier and each existing model deployment's type and capacity unless you pass new values. Run serially with other platform changes. The script restores your Azure CLI subscription when it finishes.

Azure sets `FOUNDRY_CREDENTIAL=managed-identity` and `SUPPORT_SIGNAL_LIVE_ONLY=true`. `WEBSITE_SITE_NAME` also forces live-only execution. The app refuses startup without Foundry configuration in this mode. Simulation requests are rejected by the API, not merely hidden in the UI. A missing or invalid live response remains an error.

## Verification

Start with the read-only check that the script prints, for example `./scripts/Test-AzureLabs.ps1 -Subscription '<selected-subscription>' -Labs 01 -ChatCapacity <n>`. Then:

1. An anonymous request to the deployed app and API must require sign-in.
2. Sign in with an allowed account. The header must say **Azure App Service**, and the engine must be **Microsoft Foundry · MAF**. Simulation must be unavailable.
3. Analyze a synthetic request. Confirm the returned mode is `foundry`, evidence is a literal substring, and the proposal needs review. Exact prose may vary.
4. Edit, approve, and export. Confirm original output and human edits remain separate. Approval still sends nothing and remains browser-local.
5. Record the result and date in verification. A successful deployment, a redirect, or a configured endpoint is not evidence of successful model inference. Test a disallowed account separately when available.

Hosting both labs exceeded F1's quota on 2026-10-14; pass `-AppServiceSku B1` for that case and see [cost](../../../docs/shared-azure-platform.md#cost). Inference is billed per token on the shared chat deployment. Do not report model-token cost as the total platform cost.

## Retire only Lab 001

Use the Azure portal with the selected subscription. Run these steps serially with other shared-platform changes. Record the exact Lab 001 web app name, its system-assigned identity object ID, Foundry account/project names, and authentication application client ID before deleting anything. These values are visible in the web app's **Identity**, **Configuration**, and **Authentication** pages. Keep this environment-specific inventory outside the repository.

1. Open the Lab 001 web app and select **Stop**. Do not stop the shared App Service plan or Lab 002. If the app is already stopped, continue.
2. Open the shared Foundry account's **Access control (IAM) → Role assignments**. Locate the **Foundry User** assignment (role definition `53ca6127-db72-4b80-b1b0-d745d6d5456d`) whose principal object ID exactly matches the Lab 001 system-assigned identity. Remove only that assignment at the account scope. If it is absent, continue; never remove the Lab 002 or shared sign-in identity assignments.
3. In **Microsoft Entra ID → App registrations → All applications**, select the application by the recorded client ID, not its display name. Under **Authentication → Web redirect URIs**, remove only `https://<lab-001-web-app>.azurewebsites.net/.auth/login/aad/callback` and save. Keep every other URI and the federated credential. If that exact URI is already absent, continue.
4. Delete only the recorded Lab 001 web app. In the shared Foundry account, delete only its Lab 001 project (default `proj-lab01-support-signal`). Verify its `lab=01` tag and confirm no other lab uses it first. An already absent resource needs no action.
5. Verify Lab 002 still opens and signs in, the shared model deployments remain, and the shared App Service plan remains at its selected tier. Confirm the removed identity assignment and exact redirect URI are absent.

This procedure is repeatable because absent items are skipped and shared items are retained. If the web app was deleted before its identity and application IDs were recorded, recover those values from deployment records; do not guess identities or remove assignments by display name. Never delete the shared resource group, model, plan, sign-in identity, or app registration as single-lab cleanup. Shared-plan charges continue while the plan exists. This procedure is documented for operator execution and has not been exercised against the active labs.

## Official sources

Accessed 2026-10-14:

- [MAF Foundry model provider](https://learn.microsoft.com/en-us/agent-framework/integrations/by-component/model-providers/microsoft-foundry?wt.mc_id=AI-MVP-5004753): code-first direct inference and explicit credentials.
- [Foundry project resource schema](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/2025-06-01/accounts/projects?wt.mc_id=AI-MVP-5004753): project resource used by Bicep.
- [App Service Entra authentication](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad?wt.mc_id=AI-MVP-5004753): sign-in, identity allowlists, and managed-identity federated credentials.
