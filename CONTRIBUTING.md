# Contributing

Changes should make a lab easier to understand, reproduce, or evaluate. Documentation corrections, focused bug fixes, and meaningful behavioral checks are more useful than additional frameworks without a teaching purpose.

The project is owner-maintained. Before substantial implementation, discuss the developer problem and proposed scope with the maintainer. Contributions to original code and documentation use the project's [MIT License](LICENSE). Only submit work you have the right to contribute, and retain applicable third-party notices. Use [Security](SECURITY.md) for private vulnerability reporting and [release readiness](docs/release-readiness.md) for verification limits.

## Before proposing a change

Read the [quality standard](docs/repository-standards.md) and affected sample guide. For UI or walkthrough changes, apply the five teaching rules in the [lab experience guide](docs/lab-experience-guide.md), without introducing a shared framework solely for visual consistency. Keep changes focused on a developer problem. Update expected output and setup instructions when behavior changes.

Use US English and synthetic fixtures. For a reproducible bug report, include the sample, commit, operating system, pinned SDK version, engine mode, steps, expected behavior, and actual result. Remove endpoints, identifiers, credentials, and customer content from logs and screenshots. Use the [security reporting guidance](SECURITY.md) rather than public issues for vulnerability details.

## Verification and review

Run `pwsh ./scripts/Validate.ps1` with the pinned SDK. Check UI changes in a browser, including narrow layouts and keyboard access. Record commands and actual results in the PR template; state what was not exercised. Record live validation separately from simulation and replay. Live checks require your explicitly selected deployment and authorized consumption; no live call is required for the offline suite.

When changing a browser guide, edit its Markdown source and regenerate it with `./scripts/Build-SupportGuide.ps1` or `./scripts/Build-BidReviewGuide.ps1`. Do not edit the generated HTML independently. Cite official Microsoft sources and access dates for product claims, and preserve accurate preview labels.

## New labs and project boundaries

New examples belong under numbered `samples/` directories with `src/`, `tests/`, and sample documentation. Update the root catalog. Start from the [lab experience guide](docs/lab-experience-guide.md); add a second language or service only when it teaches a meaningful difference. Explain costs and cleanup before adding infrastructure.

Maintain Foundry Field Notes branding and required third-party notices. No Microsoft CLA or Microsoft support policy applies to this independent project. Release approval, repository visibility, license selection, and new integrations are maintainer decisions, not side effects of a contribution.
