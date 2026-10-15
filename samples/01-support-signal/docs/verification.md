# Verification — 2026-10-13

These dated observations predate the initial public snapshot. Historical commit IDs identify the builds used for those observations; those commits and their private review conversations are not part of this repository. They are maintainer-reported evidence, not independently reproduced public CI. Current snapshot checks are recorded in [release readiness](../../../docs/release-readiness.md).

## Current status — 2026-10-15

Hosted sign-in, one successful Foundry/MAF outage request, review invalidation, and export were verified on 2026-10-14 on the earlier layout. On 2026-10-15 (UTC) the labs moved to the [lab platform](../../../docs/shared-azure-platform.md); its read-only check passed and a local live request reached the new project and model deployment. See [lab platform deployment](#lab-platform-deployment--2026-10-15-utc). A hosted request on the new platform succeeded after the owner signed in; see [hosted verification](#hosted-verification--2026-10-15-utc). Disallowed-user access and independent clean-environment reproduction remain unverified. The presentation guide separates the cloud walkthrough from a deterministic local simulation exercise.

Presentation preparation on Windows, 2026-10-14: `scripts/Validate.ps1` passed locked restore, a zero-warning/error build, 11 Lab 001 contract checks, cloud-mode rejection of simulation, 20 HTTP checks, guide synchronization, and local Markdown links, together with Lab 002's checks. The pinned SDK was installed into this worktree after verifying its SHA512 against official release metadata. `Start-Demo.ps1 -Lab 1 -Offline` served simulation with live configuration disabled despite inherited endpoint, model, credential, and live-only settings. The separated browser guide was served and visually inspected. No new inference or Azure deployment occurred; this prepared workstation is not an independent clean-machine reproduction.

This file is chronological. Earlier unverified items describe their dated checkpoints; the final hosted verification section records the later Azure result.

## Shared lab experience — 2026-10-14

- Applied the repository's five-rule experience guide: visible execution responsibilities, mode before input, Service outage as the first case, readable checks before original JSON, and secondary timing.
- `scripts/Validate.ps1` passed with 11 provider-contract checks and 22 Lab 001 HTTP checks, together with the other lab and script checks. No model was called.
- Desktop browser, `Start-Demo.ps1 -Lab 1 -Offline -Port 55187`: Reliability/High, explicit simulation provenance, readable inspector, original response JSON, approval invalidation after a reply edit, and export preserving originals separately from edits. Editing the input hid the old result; a short input showed the explicit validation error.
- A static HTML snapshot at a 389-pixel viewport had no horizontal document overflow. This is not a new interactive mobile-device verification. Keyboard-only end-to-end operation was not reverified.
- This UI build has not been deployed or exercised against Foundry. Historical hosted evidence below does not validate the changed UI. The two labs share teaching rules, not a UI framework.

Environment: Windows x64, isolated .NET SDK 11.0.100-rc.1.26425.128. SDK archive SHA512 matched Microsoft's release metadata. Dependencies restored from NuGet; lockfiles retained.

## Completed

- ASP.NET Core app build succeeded with zero compilation warnings/errors on the initial build.
- Locked package restore succeeded.
- 20 HTTP smoke checks passed: static UI, CSP, four synthetic scenarios, evidence membership, human-review flag, invalid inputs, unavailable Foundry and an adversarial simulation fixture.
- Nine provider-contract checks passed: valid JSON accepted; invented evidence, unknown categories/priorities, empty/oversized fields, malformed/null/missing output rejected.
- Browser walkthrough passed: analyze outage, inspect proposal, approve, edit reply (approval invalidated), approve again, export JSON, switch scenario (proposal invalidated), reload (state cleared), reject short input.
- Downloaded JSON inspected: original proposal preserved, human edits separate, approval and timestamp present.
- Desktop layout visually inspected. Mobile viewport 390 × 844 inspected; a mode-selector overflow was found and fixed. After the fix, document width was 375 px within the 390 px viewport.

A running Windows process initially locked the assembly during the contract-test build. Stopping the demo released the lock; tests passed and the server was restarted. Stop the app before rebuilding on Windows.

## Not verified

- Live Foundry inference, model availability, regional access and Azure authorization: no owner-selected endpoint/deployment supplied.
- Real model quality, adversarial robustness, costs, token usage or model latency. Rule-based simulation results do not establish any of these.
- Production hosting, authentication, persistence, multi-user behavior or durable approvals.
- Clean-machine first-success timing. The run instructions were exercised on the prepared workstation, not an independent fresh machine.

## Repeat

With the app stopped:

```powershell
./.dotnet/dotnet.exe run --project samples/01-support-signal/tests/SupportSignal.Checks
./Start-Demo.ps1
```

Use `dotnet` instead of `./.dotnet/dotnet.exe` when the pinned SDK is on your PATH.

In another PowerShell 7 terminal:

```powershell
./scripts/Test-Demo.ps1
```


## Repository restructuring verification

On 2026-10-13, the sample was moved under samples/01-support-signal. The new scripts/Validate.ps1 entry point passed locked solution restore, a zero-warning/error build, all 29 checks and local Markdown links. Its temporary server was stopped automatically. The CI definition has not been executed on GitHub; Linux execution remains unverified.
# Guided walkthrough verification — 2026-10-14

- Added the service-outage [guided lab](guided-lab.md) and browser copy, generated with `scripts/Build-SupportGuide.ps1`. Validation checks that the browser copy matches its Markdown source.
- Verified in the browser: Reliability/High, exact fixture evidence, local approval, editing clears approval, reapproval, and downloaded JSON retaining the original proposal separately from human edits. The controlled test-portal variation returned Reliability/Medium.
- Captured the simulation screenshot used in the guide. The browser guide and embedded screenshot loaded successfully. Official documentation links include the owner's tracking parameter and source access dates.
- Lab 001 built; its 9 offline contract checks and 20 HTTP checks passed. Full local solution validation encountered a locked Lab 002 executable from a running app; that app was not stopped for this documentation change. Hosted CI is reported in the pull request.
- No live Azure inference was performed. These observations demonstrate simulation and application behavior only. The code-edit exercise's expected result follows from the documented Boolean rule; it is not a recorded live-model result.
# Shared Azure rollout — 2026-10-14

- Built the Linux self-contained package with locked restore and zero build warnings/errors. Bicep compilation and Azure what-if succeeded. What-if created only a Lab 001 project, web app, authentication configuration, and inference role; shared resources remained references.
- Azure infrastructure and package deployment succeeded. The app uses the existing generative deployment, shared hosting plan, shared sign-in registration/identity, and existing user allowlist. The deployment preserved existing redirect URIs and did not change model capacity.
- Both apps subsequently reported `QuotaExceeded` / `usageState: Exceeded` on the shared F1 tier. The Lab 001 browser returned platform 503 and then a stopped-app 403. These are platform quota failures, not evidence of successful Entra sign-in or application authorization.
- The owner authorized B1 and the shared plan was upgraded on 2026-10-14. A concurrent Lab 002 deployment reverted it to F1; B1 was reapplied and the Lab 002 deployment script was changed to preserve the existing tier by default. Both sites then reported Running / Normal; Lab 001 Always On was enabled. Hosted managed-identity inference, allowed-user sign-in, disallowed-user access, and the authenticated cloud UI walkthrough remain to be verified.
- Hosted Linux CI passed the full validation suite on commit `f0439d9`, including 11 Lab 001 contract checks and the new cloud-mode HTTP check that selects Foundry and rejects simulation without calling a model. Local Windows Application Control blocked the isolated checkout's test executable; its policy was not changed.
- B1 package deployment subsequently completed successfully, and both apps reported `Running` / `Normal`. An anonymous Lab 001 API request returned HTTP 302 to sign-in.
- The owner then observed `AADSTS50011`. Inspection confirmed that the shared registration contained only Lab 002's callback after its concurrent deployment. Lab 001's exact callback was restored, preserving Lab 002's, and both were read back from Microsoft Graph. Lab 002's deployment script now preserves existing callbacks. Successful owner sign-in and hosted inference remain pending; redirect registration alone does not verify either.

## Hosted walkthrough completed — 2026-10-14

- The owner confirmed successful sign-in after callback repair; the authenticated browser displayed Azure App Service and Microsoft Foundry · MAF, with Local simulation disabled.
- The first synthetic outage request timed out during a shared-plan update/restart recorded by Azure. The next request succeeded: `mode=foundry`, deployment `bid-review-escalation`, Reliability / High, 11,011 ms application processing time. The exact evidence was `unavailable to all users since 9:15 AM`. The configured cloud credential was the web app's system-assigned managed identity.
- Approved the real result, edited the response, observed approval invalidation, approved again, and exported JSON. Inspected the downloaded JSON: original proposal and human edits were separate; `requiresHumanReview=true`, `reviewed=true`, review and export timestamps were present. No operational action or message was sent.
- Captured the actual [reviewed Azure result](../src/SupportSignal/wwwroot/guide-assets/cloud-outage-reviewed.png) and documented it separately from the simulation in the guided lab.
- Both hosted Linux CI runs passed on `768f177`; local shared-tier/account regression, guide synchronization, Markdown links, and whitespace checks also passed. Copilot returned two documentation findings; cleanup and verification-status documentation were corrected.
- Still unverified: a separate disallowed-user test, independent clean-machine reproduction, production persistence, model-quality evaluation, and cost/token measurements. One successful inference does not establish these. The documented cleanup procedure was not run against active resources.

## Cloud-first documentation and Linux validation — 2026-10-14

- The hosted run's deployment, `bid-review-escalation`, is gpt-6-luna version 2026-09-22 (`DataZoneStandard`, capacity 100) according to the record made when Lab 002 created it. Lab 001 shares it with Lab 002's second opinion, including its rate limit. The guided lab now names the model.
- The demo script and architecture now present the hosted app first: simulation is disabled in Azure, and the app uses its managed identity. Local simulation remains the rehearsal and fallback path.
- Local validation on Linux with the pinned SDK 11.0.100-rc.1.26425.128: `Validate.ps1` passed with zero build warnings, 11 contract checks, 20 Lab 001 HTTP checks, guide synchronization and local Markdown links, together with the Lab 002 checks.
- Browser, headless Chromium, local simulation: Service outage returned Reliability / Priority high with the exact fixture as evidence; approval cleared after editing the reply; the export kept the original proposal separate from the human edits, with review and export timestamps; the test-portal variation returned Priority medium; short input showed the inline error; the guide page loaded both screenshots; no horizontal overflow at 390 pixels; no console errors. No Azure requests were made.

## Read-only Azure platform verification — 2026-10-14

- Executed `scripts/Test-AzureLabs.ps1` from commit `5650002` with the owner-confirmed subscription and shared resource group, `-DecisionCapacity 300 -EscalationCapacity 100`. All 21 checks passed against Azure, not the offline CLI stand-in.
- Both apps were running on the shared B1 plan. Lab 001's settings required managed identity and disabled simulation; its endpoint matched the Foundry account returned by Azure CLI, and its identity held Foundry User on that account. The shared `bid-review-escalation` deployment reported gpt-6-luna version `2026-09-22`, `DataZoneStandard`, capacity 100, and `Succeeded`.
- Both sign-in callbacks were registered. Each app required sign-in on every path with one allowed user. Anonymous requests returned HTTP 302 directly to `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/authorize`; the checker accepted this redirect format.
- No authenticated walkthrough, inference, deployment, or cleanup was performed in this round. The [Lab 002 preview](../../02-bid-review-queue/docs/verification.md#read-only-azure-preview-and-platform-verification--2026-10-14) reported unexplained shared-account property removals, so redeployment was held. These checks establish configuration and anonymous reachability, not deployed application version or successful inference.

## Lab platform deployment — 2026-10-15 (UTC)

Lab 001 now deploys with the shared [lab platform](../../../docs/shared-azure-platform.md) script instead of extending Lab 002's resources. The full record of the preview, deployment and its one fix is in [Lab 002's verification](../../02-bid-review-queue/docs/verification.md#lab-platform-deployment--2026-10-15-utc).

- **Deployed:** the project `proj-lab01-support-signal` on the new Foundry resource, and the web app on the shared B1 plan with `FOUNDRY_MODEL` set to the shared `gpt-6-luna` deployment (gpt-6-luna 2026-09-22, `DataZoneStandard`, capacity 100). The application code was the same as `main` at `c2d7931`.
- **Platform check: 21 of 21 passed.** Lab 001's settings require managed identity and disable simulation, its project endpoint names the new Foundry resource, its identity holds Foundry User there, its callback is registered, and an anonymous request redirects to Microsoft Entra sign-in.
- **Live inference against the new project, from a local app.** Lab 001 ran locally with `AzureCliCredential`, the new project endpoint and `gpt-6-luna`. The Service outage fixture returned `mode: foundry`, Reliability / High, and the evidence `unavailable to all users since 9:15 AM`, which passed the exact-substring check, in 7.7 seconds.
- **Not verified:** an authenticated request through the hosted app and its managed identity on the new platform. It needs the owner's sign-in.

## Hosted verification — 2026-10-15 (UTC)

The owner signed in to the hosted Lab 001 app on the lab platform with the allowed account in a browser and accepted the consent prompt of the new sign-in registration. The application code was the same as the pre-publication build `c2d7931`; the platform was the one deployed on 2026-10-15 and recorded above.

- **Status endpoint:** hosting Azure App Service, Foundry configured, simulation disabled, default engine Microsoft Foundry · MAF.
- **Service outage, live:** Reliability / Priority high, with the evidence `unavailable to all users since 9:15 AM`, which passed the exact-substring check. The run took 13,085 ms on `gpt-6-luna` through the app's managed identity and the project `proj-lab01-support-signal`. The proposal awaited human review, and no message was sent.
