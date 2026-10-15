# Release readiness

This is the maintainer's publication record, not a prerequisite for following a lab. The owner selected the [MIT License](../LICENSE) for original code and documentation on 2026-10-14 and chose `ppiova/foundry-field-notes-labs` as a new public destination on 2026-10-15. This candidate contains a source snapshot, not the previous repository's Git history, branches, issues, pull requests, logs, or automation artifacts.

**Owner approval: 2026-10-15.** The owner approved publication of the reviewed 106-file candidate (Git tree `944c957a203fcb3b2fba184087025c0efaab7d9d`) at the new destination, with the verification limits below, and authorized recording approval and launch results. The publication process must pass CI before making the new repository public, then enable and verify GitHub's private vulnerability-reporting channel. Repository visibility and the reporting setting must be checked on GitHub; this source document is not a live status check.

## Decisions required before a public release

| Gate | Required evidence or decision | Current status |
| --- | --- | --- |
| Scope and destination | Owner approval of the exact repository contents and public destination | Owner approved the reviewed source-only snapshot for `ppiova/foundry-field-notes-labs` on 2026-10-15; no previous Git history or conversations are included |
| License and notices | Owner-selected license; review rights for code, fixtures, recordings, screenshots, and dependencies; retain required third-party notices | MIT retained; [materials inventory](third-party-materials.md) added; owner confirmed the right to share and authorized publication of the synthetic fixtures, 382 recorded responses, and two application screenshots on 2026-10-15. This is not independent legal clearance |
| Repository exposure | Review everything included in the new snapshot | Tracked-source export only; private tracker and CI links removed; two screenshots visually inspected; text checked for credential patterns, account IDs, email addresses, local user paths, and resource hosts. This is a bounded exposure review, not a comprehensive security audit |
| Independent first success | Follow both offline quickstarts from a clean environment; record prerequisites, timing, failures, and interventions | Source-only copy and both browser quickstarts exercised on Windows on 2026-10-15; a separately provisioned machine and independent reader remain unverified. Owner accepted this disclosed gap for the initial educational release |
| Live and hosted claims | Verify the documented path on the intended build and record limits without exposing identifiers | Dated live and hosted evidence exists for both labs, including Lab 002's second opinions (2026-10-15); recheck on the build proposed for release |
| Reader experience | Check links, sample paths, expected outputs, troubleshooting, cleanup, narrow layouts, and keyboard operation | Both offline first results checked in an 820-pixel-wide browser pane on 2026-10-15; complete narrow-viewport and keyboard-only regressions remain open. Owner accepted these disclosed gaps for the initial educational release |
| Contributions and reporting | Decide contribution scope and establish a private vulnerability-reporting channel; verify it is usable | Owner-maintained; owner approved enabling and verifying GitHub's private reporting form at publication. No response SLA |
| Release commit | Passing CI and review of actionable findings on the exact commit proposed for publication | Candidate offline validation passed on Windows with the exact RC1 SDK. The [Actions history](https://github.com/ppiova/foundry-field-notes-labs/actions) records CI for each new-repository commit; earlier private-repository runs are not used as the release check |

Do not replace pending gates with successful-looking claims. Publication blockers and known sample limitations are different: a chosen license and reviewed public material are required; a clearly disclosed preview limitation is not a production-readiness promise.

## Public-candidate verification - 2026-10-15

Executed on a source-only copy on the existing Windows workstation, not an independently provisioned machine:

- `pwsh -NoProfile -File .\scripts\Validate.ps1`: passed locked restore, build with zero warnings and errors, 11 Lab 001 provider-contract checks, 128 Lab 002 checks, recorded evaluation, 23 Lab 001 HTTP checks, 30 Lab 002 HTTP checks, prerequisite and fake-CLI regressions, Bicep compilation, generated-guide synchronization, and local Markdown links. No live inference or Azure resource changes.
- The first attempt selected the installed RC2 SDK and failed locked restore with `NU1004` for an implicit ASP.NET package. `global.json` now disables roll-forward. A real RC2-only preflight then failed explicitly before app startup. Installed SDK `11.0.100-rc.1.26425.128` locally after comparing its archive's SHA512 with official Microsoft release metadata, then ran the successful suite above. Lockfiles were not regenerated.
- `.\Start-Demo.ps1 -Lab 1 -Offline -Port 58371`: started with Foundry disabled. The browser's Service outage returned Reliability / Priority high, labeled simulation. Approval cleared after editing the draft response.
- `.\Start-Demo.ps1 -Lab 2 -Offline -Port 58372`: started with live decision and second-opinion settings disabled. The browser reproduced 35/35 decided, 24 accepted by rule, 8 by agreement, and 3 awaiting review; item 13 displayed the recorded disagreement. No new model calls.
- Both temporary servers were stopped. The local SDK, build outputs, validation logs, and package cache are not included in the source snapshot.

Credential-pattern and resource-host searches found no credential values or real tenant/subscription identifiers in the selected source. GUID matches were a public role definition and test placeholders. The two screenshots were inspected; the recordings' user, safety-identifier, previous-response, prompt-cache-key, and metadata fields were empty. Opaque response IDs and timestamps remain as historical service metadata. This does not certify the absence of every possible secret or vulnerability.

Core Microsoft Learn pages for the decision API, MAF's code-first Foundry provider, and SDK selection were rechecked on 2026-10-15. Other source-register access dates remain their original dates; they are not represented as a fresh check of every product claim.

## Evidence and operational notes

Keep the reader's path in each sample README and walkthrough. Keep dated observations in [Lab 001 verification](../samples/01-support-signal/docs/verification.md) and [Lab 002 verification](../samples/02-bid-review-queue/docs/verification.md). Keep subscription identifiers, actual resource addresses, credentials, and operational inventories outside the technical repository.

The reference deployment's earlier layout, created by Lab 002's script, reported unexplained property removals in what-if on 2026-10-14, so it is not redeployed in place. The read-only platform check passed 21 checks against it, but did not perform inference or identify the deployed application build. Instead, the owner approved moving to the [lab platform](shared-azure-platform.md#move-from-the-earlier-layout) in a new resource group. Its what-if listed 14 new resources to create and no change to existing ones. On 2026-10-15 (UTC) it was deployed with the owner's confirmation; the read-only check passed 21 of 21, and local live requests reached its model deployments. The owner then deleted the earlier layout. Re-applying the same template left the account features, project association, capacities and model policies that what-if had listed as removals unchanged, so on the new platform those entries were false positives. After the owner signed in, authenticated live runs through both hosted apps succeeded; see [Lab 002 verification](../samples/02-bid-review-queue/docs/verification.md#hosted-verification--2026-10-15-utc).

Historical screenshots and recordings are evidence of their capture dates, not a public hosted service or a guarantee of current model output. Do not remove evidence limitations merely to make the repository appear finished.

## Release procedure

1. Resolve the remaining decisions above and record approval for the exact material and destination. Preserve the owner-selected MIT license; obtain approval before changing licensing or enabling integrations.
2. Reproduce the documented paths and review actual CI results. Use an explicitly selected deployment and authorized consumption for live checks.
3. Verify the license scope, third-party notices, and contribution/reporting policy. Initialize a new Git repository from only the reviewed candidate. Do not push, mirror, or fork the private source repository.
4. Only after exact-material approval, publish the new destination. Leave the original repository private and unchanged. Check links and the clone-to-first-result path as an unauthenticated reader, and verify the private reporting channel.

This procedure does not claim a security audit, license clearance, Microsoft endorsement, or publication readiness.
