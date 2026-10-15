# Security

These educational samples use synthetic data and are not supported for production use. Local apps have no application authentication and must bind only to localhost. The documented Azure hosting path uses App Service sign-in; it does not make local approvals authenticated, persistent audit records.

## Reporting

Do not post credentials, customer data, or sensitive exploit details in issues or pull requests. The intended reporting channel is GitHub's [private vulnerability report form](https://github.com/ppiova/foundry-field-notes-labs/security/advisories/new). It requires GitHub sign-in. If the form is unavailable, do not publish sensitive details in a public issue.

Include the affected lab and version, reproduction steps using synthetic data, expected and actual behavior, and the potential impact. Omit credentials and customer data. No response SLA is promised. Microsoft is not the security contact for this independent repository.

The maintainer must enable and verify private vulnerability reporting when publishing the repository; see the [publication record](docs/release-readiness.md). The [GitHub configuration documentation](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository), accessed 2026-10-15, describes this feature for public repositories. A link in this file alone does not establish that the feature is enabled.

## Data and model boundaries

JSON and evidence validation do not establish semantic correctness or comprehensive prompt-injection resistance. Lab 001's agent has no external-action tools. Foundry mode sends the input described in each sample's README to your configured Azure deployment. Simulation and replay do not make new inference calls.

Exports contain input and output; treat them as data artifacts rather than proof of authorization. Use synthetic content only, review deployment permissions and costs, and do not commit credentials or environment-specific inventories. Publication review must cover dependencies, permissions, logs, artifacts, and Git history; this document is not evidence that such a review has been completed.
