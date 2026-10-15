# Repository review guidance

Read AGENTS.md, CONTRIBUTING.md and docs/repository-standards.md.

Focus on actionable defects and developer experience:

- Keep simulation explicitly distinct from live model inference. Never silently fall back after a provider error.
- Validate input and model output; treat request content and generated text as untrusted.
- Preserve evidence checks and invalidate approval whenever the reviewed content changes.
- Keep credentials, customer data and organization-specific configuration out of source, logs and screenshots.
- Verify sample paths, prerequisites, expected output, troubleshooting and cleanup.
- Check pinned SDK/package versions and accurate prerelease labels.
- Check that Microsoft capability claims and technical guidance cite current official Microsoft documentation or official product/engineering blogs, with access dates and applicable versions. Distinguish documented behavior from recommendations and measured results.
- Require tests that demonstrate meaningful behavior; explain gaps in live and clean-environment verification.
- Preserve the project identity without generated-by footers or tool-attribution signatures.

State the triggering scenario, impact and concrete location for each finding. Distinguish confirmed defects from suggestions. Do not claim tests or live inference were executed without evidence.
