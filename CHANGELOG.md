# Changelog

## Initial snapshot - 2026-10-15

- Lab 001, Support Signal: synthetic support triage, exact evidence validation, editable proposals, approval invalidation, and export. Deterministic simulation is separate from live Foundry inference through Microsoft Agent Framework.
- Lab 002, Bid Review Queue: Microsoft-Decision-1 over REST, bounded choices and probabilities, a review policy shared by the UI, API, and evaluation command, and optional gpt-6-luna second opinions.
- Bundled responses recorded on 2026-10-14 support no-Azure replay and synthetic evaluation. Replay is not a new model run or a general model-quality benchmark.
- Reader-facing quickstarts, generated browser guides, code walkthroughs, troubleshooting, cost and cleanup guidance, and dated verification records.
- Optional Azure hosting through `infra/Deploy-Labs.ps1`, with an explicitly selected subscription, preview, managed identity, and Microsoft Entra sign-in.
- Locked dependencies, offline contract and HTTP checks, fake-CLI deployment regressions, and GitHub Actions validation.
- MIT licensing for original code and documentation, with separate third-party and model-response terms.

See [release readiness](docs/release-readiness.md) for this snapshot's publication status and remaining verification limits. Historical live observations are preserved in each lab's verification record; no live inference was performed as part of preparing the public copy.
