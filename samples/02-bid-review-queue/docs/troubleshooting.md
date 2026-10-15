# Troubleshooting and cleanup

Run commands from the repository root. Messages below are the exact text the app shows.

| Message or symptom | Cause and next step |
| --- | --- |
| Startup reports `.NET SDK is missing` or `No usable SDK for global.json` | Install the SDK version in `global.json`, not just the runtime, then run `./scripts/Test-Prerequisites.ps1` from the repository root. The local startup and deployment checks stop before launching an app or contacting Azure for deployment. What-if does not need the SDK. |
| Only RC2 is installed, or restore reports `NU1004` for `Microsoft.AspNetCore.App.Internal.Assets` | Install the exact RC1 SDK `11.0.100-rc.1.26425.128`. Keep `rollForward: disable` in `global.json` and the committed lockfiles. RC2 changes an implicit package version; do not disable locked mode to bypass the mismatch. |
| The presentation unexpectedly selects the live engine or a custom recording | Stop the app and use `./Start-Demo.ps1 -Lab 2 -Offline`. It disables live model settings and custom recording paths only for the launched process. The normal command intentionally retains your settings. |
| `Microsoft-Decision-1 is not configured. Set FOUNDRY_RESOURCE_ENDPOINT and FOUNDRY_DECISION_DEPLOYMENT, sign in with az login, and restart.` | Set both variables in the same terminal before `./Start-Demo.ps1 -Lab 2`. The option stays disabled until then. |
| `FOUNDRY_RESOURCE_ENDPOINT is a project endpoint. Use the resource endpoint from the deployment details page, without /api/projects/.` | Copy the resource endpoint, for example `https://YOUR-RESOURCE.services.ai.azure.com`. |
| `FOUNDRY_RESOURCE_ENDPOINT must be an https URL.` | Include `https://`. |
| `Set FOUNDRY_DECISION_DEPLOYMENT to your deployment name (letters, digits, '.', '_' or '-').` | Use the deployment name, not the model name `Microsoft-Decision-1`. |
| `Authentication failed (HTTP 401). Run az login again.` | Token missing or expired. Sign in with the account that has access to the resource. |
| `Access denied (HTTP 403). Verify your role assignment for this deployment.` | Your identity lacks data-plane access to the resource. |
| `Endpoint or deployment not found (HTTP 404). Use the resource endpoint from the deployment details page and check the deployment name.` | Wrong host or path, or, for the second model, a deployment name that does not exist on the resource. |
| `The deployment name or a question definition is not supported (HTTP 422).` | Check the deployment name. If it is right, record the request shape and report it; the sample's questions follow the Learn article. |
| `The deployment rate limit was exceeded (HTTP 429). Wait and retry, or request more quota.` | The client already retried once. For this model, capacity counts requests per minute: capacity 50 allows 50. Wait a minute between demo runs, run the evaluation with `--max-rpm` below the capacity, or raise the capacity within your quota. |
| `The decision did not match its response contract: ...` | Microsoft-Decision-1 answered but not in the expected shape, for example without per-option probabilities. Nothing was guessed. Note the reason and update [verification](verification.md). |
| `The second opinion did not match its response contract: ...` | The second model answered but not with exactly one offered option per question, for example with an extra or missing field. The line stays with a person. Note the reason and update [verification](verification.md). |
| `Could not reach Foundry or get a token. Run az login and check FOUNDRY_RESOURCE_ENDPOINT.` | Network, DNS, or Azure CLI sign-in problem. |
| `The decision took longer than 30 seconds. Please try again.` | Request timed out. |
| `This pay item is not in the recorded run. Decide it with Microsoft-Decision-1, or record it with the evaluation command first.` | The recording covers the demo form only, matched by description, unit and option order. Use the live engine for other items. |
| The second-opinion switch is disabled: `The second opinion is off for this engine. Set FOUNDRY_ESCALATION_DEPLOYMENT to a chat model deployment on the same Foundry resource, then restart.` | Live second opinions need `FOUNDRY_ESCALATION_DEPLOYMENT` as well as the Microsoft-Decision-1 settings. The recorded engine always has recorded second opinions. |
| `FOUNDRY_ESCALATION_DEPLOYMENT must contain only letters, digits, '.', '_' or '-'.` | Use the deployment name, not a URL. |
| `The second model rejected the request shape (HTTP 400). Check the question definitions. The line stays with a person.` | The deployment's model does not accept the request, for example a model without structured outputs or the `low` reasoning effort. Use gpt-6-luna or check the model's supported features. |
| `The second opinion took longer than 45 seconds. Please try again.` | gpt-6-luna answered most requests in under 10 seconds on 2026-10-14, but some took close to a minute. The client abandons a first attempt after 20 seconds and tries once more. The line is not accepted without an answer. |
| `This pay item has no recorded second opinion.` | The recorded second opinions cover the demo lines that could need one at some threshold. Use the live engine for other items. |
| A yellow bar: `N lines are below the new threshold without a second opinion` | You raised the threshold after the run. The slider never calls a model; choose **Ask gpt-6-luna about N lines** to ask, or leave them with a person. |
| `Deploy-Labs.ps1`: `Deployment decision-1 uses Standard, which this template does not support. Stop before changing it.` (or `gpt-6-luna`) | An existing model deployment has a type the template does not manage, and the script stopped before deploying the template. Review the deployment in the Foundry portal. Pass `-DecisionSku` or `-ChatSku` only if you intend to change a deployment that other labs may use. |
| `Deploy-Labs.ps1`: `This resource group has more than one shared Foundry resource. Stop before changing either.` | Keep one platform per resource group. Use `-ResourceGroup` to deploy another platform elsewhere. The script stopped before deploying the template. |
| `Deploy-Labs.ps1`: `Multiple shared plans found. Specify -AppServiceSku explicitly.` or `The existing plan tier is not supported by this template. Stop before changing it.` | The script found more than one shared plan, or a tier other than F1 or B1, and stopped before deploying the template. Changing the shared plan affects every lab on it. |
| `Deploy-Labs.ps1`: `The lab apps in this resource group use different app registrations (...). Pass -AuthClientId.` | Choose the registration the platform should keep with `-AuthClientId`. The script stopped before deploying the template. |
| `Deploy-Labs.ps1`: `Moving the plan from B1 to F1 fails while these apps keep Always On: ...` | F1 does not offer Always On. Turn it off on each listed app with `az webapp config set --ids <app-id> --always-on false`, then run the script again. Nothing was changed. |
| `Deploy-Labs.ps1`: `Federated credential '...' already trusts this platform's sign-in identity, but for audiences ...` | A credential outside the script's naming trusts the platform's identity for another audience, so sign-in cannot use it. Correct its audience to `api://AzureADTokenExchange` or delete it in the app registration's **Certificates & secrets**, then run the script again. |
| `Deploy-Labs.ps1`: the deployment fails with a quota error for `decision-1` or `gpt-6-luna` | The capacity exceeds your remaining quota for that model and deployment type in the region. Check `az cognitiveservices usage list --location <region> --subscription <subscription>` and pass a smaller `-DecisionCapacity` or `-ChatCapacity`. |
| Hosted app: HTTP 403 after signing in | The account is not the one that ran `Deploy-Labs.ps1`, or is in another tenant. Only that user's object ID is allowed. |
| Hosted app: a redirect URI mismatch during sign-in | The app's host name changed. Run `Deploy-Labs.ps1` again; it updates the app registration. |
| Hosted app: sign-in fails after the consent page | The federated identity credential is missing or points to another identity. Run `Deploy-Labs.ps1` again; it recreates the trust with the sign-in identity. |
| Hosted app: the first page takes several seconds | The F1 plan let the app sleep. Open it a few minutes before a demo, or redeploy with `-AppServiceSku B1` for the day. The plan is shared, so the tier applies to every lab on it; hosting both labs needs B1. |
| Hosted app: decisions fail with HTTP 403 right after deployment | New role assignments can take a few minutes to apply. Retry shortly. |
| Port 5190 is in use | `./Start-Demo.ps1 -Lab 2 -Port 5191`. Do not stop unrelated processes. |
| Build reports a locked DLL | Stop the running demo with Ctrl+C, then rebuild. |
| The page shows text but buttons do nothing | The interactive connection did not start. Reload the page; check that nothing blocks WebSockets to localhost. |
| A reconnection message covers the page | The server stopped or restarted. Start it again and reload; decisions from the old session are gone. |
| `The file is larger than 256 KB.` / `The file needs 1 to 150 pay items.` | Split the bid form or trim the descriptions. |

Cleanup: stop the server with Ctrl+C. Delete the Azure deployments if you created them for this lab (commands in the [README](../README.md#cost-and-cleanup)). Remove exported JSON, reports and recordings under `artifacts/` when you no longer need them.
