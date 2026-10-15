# Lab platform in Azure

An optional operator runbook for hosting the labs in your selected subscription. It is not a prerequisite for the [offline quickstarts or local live paths](../README.md#choose-your-path), and it does not provide access to a maintainer-hosted service.

One script, [infra/Deploy-Labs.ps1](../infra/Deploy-Labs.ps1), creates a resource group with a shared platform and the labs you select. Hosting a lab never requires deploying another lab first.

## What it creates

```text
Browser → Microsoft Entra sign-in → Azure App Service (UI + API + MAF)
                                                ↓ managed identity
                                Microsoft Foundry resource → model deployments
```

Foundry provides the inference endpoint and, for Lab 001, a project. App Service hosts each lab's browser UI and .NET application. Lab 001's MAF agent runs inside its application; it is not a Foundry hosted-agent resource. See the [official integration patterns](https://learn.microsoft.com/en-us/agent-framework/integrations/by-component/model-providers/microsoft-foundry?wt.mc_id=AI-MVP-5004753), accessed 2026-10-14.

| Resource | Default name | Used by | Purpose |
| --- | --- | --- | --- |
| Resource group | `rg-foundry-field-notes-labs` | Every lab | Holds everything below |
| Foundry resource (`AIServices`, S0, API keys disabled) | `aif-ffn-labs-<suffix>` | Every lab | Inference endpoint; its custom subdomain uses the same name |
| Model deployment | `decision-1` | Lab 002 | Microsoft-Decision-1 version 1; deployed only when Lab 002 is selected |
| Model deployment | `gpt-6-luna` | Lab 001, Lab 002 | gpt-6-luna version 2026-09-22: Lab 001's agent and Lab 002's second opinions |
| App Service plan (Linux) | `asp-ffn-labs` | Every lab | Hosts the lab apps |
| User-assigned managed identity | `id-ffn-labs-signin` | Every lab | App Service sign-in credential through a federated identity credential; nothing else |
| Microsoft Entra app registration | Foundry Field Notes Labs sign-in | Every lab | Sign-in, with one redirect URI per lab app |
| Foundry project | `proj-lab01-support-signal` | Lab 001 | The project endpoint MAF calls |
| Web app | `app-ffn-lab01-support-signal-<suffix>` | Lab 001 | UI, API and MAF agent |
| Web app | `app-ffn-lab02-bid-review-<suffix>` | Lab 002 | Blazor UI and API |
| Foundry User role assignments | — | Each web app, the deploying user | Inference with Microsoft Entra ID; the user's grant enables local live runs |

The templates are [infra/main.bicep](../infra/main.bicep) (resource group and lab selection), [infra/platform.bicep](../infra/platform.bicep) (shared resources), and each lab's `infra/main.bicep`. Lab 002 has no Foundry project because it calls the resource endpoint.

**Naming.** Names follow the Cloud Adoption Framework [resource abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations?wt.mc_id=AI-MVP-5004753) (`rg`, `aif`, `proj`, `asp`, `app`, `id`) and the component order in [Define your naming convention](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming?wt.mc_id=AI-MVP-5004753), both accessed 2026-10-14. Foundry subdomains and web app names must be unique across Azure, so `<suffix>` is six characters derived from the subscription and resource group name: the same inputs always produce the same names. Model deployments are named after their model, not a lab, because several labs call them. Every resource carries `project=foundry-field-notes`, plus `scope=shared` or `lab=01`/`lab=02`. These are our conventions, not Microsoft requirements.

## Preview and deploy

Run these from the repository root after `az login`, serially with any other platform change. Pass the subscription you selected; the script never assumes your Azure CLI default.

```powershell
./infra/Deploy-Labs.ps1 -Subscription '<selected-subscription>' -AppServiceSku B1 -WhatIfOnly
./infra/Deploy-Labs.ps1 -Subscription '<selected-subscription>' -AppServiceSku B1
```

- `-WhatIfOnly` runs the same reads and Azure what-if at subscription scope, then stops. It changes nothing and also works before the resource group exists. Without an app registration it previews a placeholder client ID and says that a deployment would create the registration. Review every listed change and stop on anything unexplained. Values that depend on resources created in the same deployment, such as the web apps' identities and settings, can appear masked; Microsoft Learn describes what-if's limits in [Bicep deployment what-if](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if?wt.mc_id=AI-MVP-5004753), accessed 2026-10-14. On an existing platform we observed what-if listing removals of the Foundry account's `armFeatures`, `associatedProjects` and `defaultProject` and of each deployment's `currentCapacity`, `raiPolicyName` and `versionUpgradeOption`, which a redeployment of the same template did not apply ([evidence](../samples/02-bid-review-queue/docs/verification.md#lab-platform-deployment--2026-10-15-utc)). Treat any other change as real until explained.
- `-Labs 01` or `-Labs 02` hosts one lab; both are the default. Leaving a lab out does not delete it. Microsoft-Decision-1 is deployed only with Lab 002, so Lab 001 alone needs quota for the chat model only.
- `-AppServiceSku` chooses F1 (free, daily CPU quota) or B1 (billed hourly). A new plan defaults to F1; a redeployment keeps the existing tier unless you pass a new one. Two labs exceeded F1's quota on 2026-10-14, so host both on B1. F1 does not offer Always On, which the templates enable on B1, so before moving a B1 plan back to F1, turn off Always On on each app; the script checks and stops before changing anything.
- `-DecisionCapacity` (requests per minute) and `-ChatCapacity` (thousands of tokens per minute) default to 50 for new deployments. A redeployment keeps each existing deployment's type and capacity unless you pass new values. The script prints what it keeps.
- `-ResourceGroup` and `-Location` default to `rg-foundry-field-notes-labs` and `eastus2`; an existing group keeps its region. `-AuthClientId` reuses a specific app registration.

A deployment first publishes each selected lab with a locked restore, so a failed build creates nothing. It then creates or reuses the app registration, deploys the template, adds each app's redirect URI without removing existing ones, trusts the sign-in identity through the platform's own federated identity credential, named `platform-<resource group>-<hash of the subscription and resource group>`, and uploads each build. Platforms that share a registration therefore keep each other's trust. Each app can take a minute or two to start after its upload; then run the [check](#verify) command that the script prints for the labs it deployed. Only the account that runs the script can open the apps it deploys: its object ID replaces their allowlist on every deployment. No client secret or API key is created.

**Quota.** Model deployments use your subscription's per-region quota for each model and deployment type, even while idle. Check it before choosing capacities:

```powershell
az cognitiveservices usage list --location eastus2 --subscription '<selected-subscription>' -o table
```

## Cost

The plan bills while it exists, whether or not anyone opens the apps: F1 is free; the Azure Retail Prices API listed Linux B1 in East US 2 at USD 0.017 per hour (about USD 12.41 for 730 hours) on 2026-10-14. This is a dated list-price observation, not a spending cap. Model deployments are billed per token; capacity is a rate limit, not a charge. The managed identity, app registration and role assignments have no charge. See [App Service plans](https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans?wt.mc_id=AI-MVP-5004753) and [Foundry pricing](https://azure.microsoft.com/en-us/pricing/details/ai-foundry/?wt.mc_id=AI-MVP-5004753). Credits are not a spending limit.

## Verify

1. Check the configuration: `./scripts/Test-AzureLabs.ps1 -Subscription '<selected-subscription>' -DecisionCapacity <n> -ChatCapacity <n>`, with the capacities the preview printed. It is read-only. With one lab hosted, pass `-Labs 01` or `-Labs 02`; the deployment script prints the exact command. It checks that both web apps run on one plan, their app settings as the apps validate them, sign-in on every path with an allowlist, each app identity's Foundry User role on the Foundry resource its endpoint names, the model, version, type and capacity of every deployment the labs call, both sign-in callbacks, and that an anonymous request is redirected to sign-in rather than refused or served. Without the capacity arguments, capacities are printed but not compared. `-ResourceGroup` checks another group.
2. Sign in to each app with the deploying account and run one synthetic request: Lab 001's Service outage with Microsoft Foundry · MAF, and Lab 002's demo form with Microsoft-Decision-1 and the second opinion. Only this step calls the models; it is billed per token. A passing configuration check is not evidence of successful inference.

Neither the preview nor the configuration check changes anything in Azure. Both select the subscription in the Azure CLI for the run and restore the previous selection afterwards. `Validate.ps1` runs both against a fake Azure CLI, so their read-only behavior and failure messages are tested offline.

## Retire a lab or delete the platform

To retire one lab, follow its guide: [Lab 001](../samples/01-support-signal/docs/azure-deployment.md#retire-only-lab-001). The same steps apply to Lab 002's web app, without a project. Keep the shared resources while any lab uses them.

To delete everything, delete the resource group, then the app registration by its recorded client ID; the registration lives in Microsoft Entra ID, not in the group. Microsoft Graph commands such as `az ad app delete` use the Azure CLI's active tenant, so select the platform's subscription first and restore your previous selection afterwards:

```powershell
$previous = az account show --query id -o tsv
az account set --subscription '<selected-subscription>'
az group delete --name rg-foundry-field-notes-labs --subscription '<selected-subscription>'
if ($LASTEXITCODE -eq 0) { az ad app delete --id '<sign-in-client-id>' }
az account set --subscription $previous
```

Record the client ID first; it is on each web app's **Authentication** page. Do not select a registration by display name. If the group deletion fails, the registration is kept; fix the cause and run the commands again. If another platform uses the same registration, do not delete it: remove only this platform's redirect URIs and its `platform-…` federated credential under **Certificates & secrets**.

## Move from the earlier layout

Earlier versions created the platform with Lab 002's deployment script, in a resource group and with resources named after Lab 002, and deployed Lab 001 into it. Most Azure resource names cannot change after creation, so moving to this layout means deploying it beside the old one:

1. Check quota. Both layouts' model deployments use the same quota while they coexist; choose capacities that fit, and raise them after the old deployments are gone.
2. Preview, then deploy the new platform with this script. It does not read or change the old resource group.
3. Verify with `Test-AzureLabs.ps1` and one synthetic request per app.
4. Only then delete the old resource group. Delete the old app registration by recorded client ID only if no remaining platform uses it: compare it with the client ID on each new web app's **Authentication** page. If you reused it with `-AuthClientId`, keep it and remove only the old apps' redirect URIs and the old platform's federated credential. Both plans bill until the old one is deleted.

Keep environment-specific names, identifiers and inventories outside the repository.
