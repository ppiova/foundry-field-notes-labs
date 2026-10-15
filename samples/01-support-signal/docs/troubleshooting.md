# Troubleshooting and cleanup

Run commands from the repository root.

| Symptom | Check / next step |
| --- | --- |
| SDK not found | Install the exact prerelease SDK in `global.json`; run `dotnet --info`. The ignored local `.dotnet/` folder is not in a clone. |
| Build reports a locked DLL | Stop the existing demo with Ctrl+C, then rebuild. |
| Port 5187 is in use | Run `./Start-Demo.ps1 -Port 5188` and open that port. Do not terminate unrelated processes. |
| Foundry selector disabled | Set both environment variables documented in the sample README before starting the server, then restart it. |
| Live analysis returns 502 | Check Azure CLI sign-in, project permissions, deployment name, Responses compatibility and returned model format. The sample intentionally avoids exposing provider details in the UI. |
| Sign-in returns AADSTS50011 | Verify that the shared registration contains this web app's exact `https://<app>.azurewebsites.net/.auth/login/aad/callback` URI. Preserve the other labs' callbacks. See Microsoft's [redirect URI mismatch guidance](https://learn.microsoft.com/en-us/troubleshoot/entra/entra-id/app-integration/error-code-aadsts50011-redirect-uri-mismatch?wt.mc_id=AI-MVP-5004753), accessed 2026-10-14. |
| Analysis returns 504 | Provider call exceeded the 60-second deadline or was canceled. Retry after checking service availability. |
| Server busy | Only two analyses can run concurrently. Wait for one to finish. |
| Short input rejected | Supply 15–6,000 characters of synthetic request text. |
| Approval disappears | Editing the proposal invalidates approval; changing input or mode clears the proposal. Review the new content. |
| Data lost on reload | Deliberate in-memory behavior. Export JSON before reloading if you need the sample result. |

For local development, stop the server with Ctrl+C. Starting the application locally creates no Azure resources. The Azure deployment does create a web app, project, role assignment, and shared-registration redirect URI, plus the [lab platform](../../../docs/shared-azure-platform.md) when it is missing: follow the [cloud cleanup procedure](azure-deployment.md#retire-only-lab-001). Existing shared hosting and model charges continue after retiring one lab. Exported JSON remains in your downloads until you remove it. Never export confidential inputs for this demo.
