# Repository quality standard

Decision date: 2026-10-13. Owner direction: follow relevant Microsoft sample conventions and aim for professional Developer Relations quality.

## Reference patterns

Inspected on 2026-10-13:

- [Microsoft Agent Framework .NET samples](https://github.com/microsoft/agent-framework/tree/main/dotnet/samples): numbered learning paths, sample catalog and shared build/editor conventions.
- [Azure AI Travel Agents](https://github.com/Azure-Samples/azure-ai-travel-agents): architecture, local setup, cost guidance and contribution/security documentation.

There is no single Microsoft repository layout. Adopt useful patterns, not corporate branding, Microsoft's CLA or its security-reporting addresses. Add infrastructure only when a sample requires it.

## Evidence and official sources

Owner requirement recorded on 2026-10-13: every lab and technical recommendation must be grounded in official Microsoft documentation or official Microsoft product/engineering blogs.

- Prefer current Microsoft Learn reference documentation for behavior, prerequisites, limits and GA/preview status. Use official Microsoft blogs for context and announcements, checking later documentation for changes.
- Supplement with Microsoft-owned repositories and samples; do not infer supported behavior solely from an example.
- Record direct source URLs, access dates and relevant API/SDK versions alongside capability claims.
- Owner requirement recorded on 2026-10-14: include relevant Microsoft documentation links in guides with `wt.mc_id=AI-MVP-5004753`. Append it with `?` or, when the URL already has a query, `&`; preserve existing parameters and put it before any fragment. Do not duplicate it or add it to unrelated third-party links.
- Distinguish documented capabilities, our architectural recommendations and results we actually measured.
- Treat third-party articles as inspiration only. A post on a community platform is not automatically an official Microsoft statement.
- If official sources disagree or do not establish a claim, document the uncertainty and verify before relying on it.

## Azure service selection

Foundry is not the boundary of the architecture. Additional Azure services are welcome when they solve a documented requirement. For each service, explain its role, the simpler alternative, authentication, expected cost drivers and cleanup. Select the intended subscription explicitly; an existing sign-in or available credits do not establish a deployment budget. Provisioning and live execution must follow the owner's authorized scope.

## Every sample must

Use the [lab experience guide](lab-experience-guide.md) for the common page, walkthrough, and presentation structure. Its five rules keep Foundry's role visible, introduce one case first, explain before JSON, contextualize metrics, and make mode selection explicit.

1. State the audience, problem, learning objectives and expected output.
2. Include prerequisites, exact setup commands, configuration, troubleshooting and cleanup.
3. Explain architecture, simpler alternatives and why each framework is present.
4. Pin dependencies, date product sources and distinguish stable from preview APIs.
5. Separate simulation, live integration and verification evidence. Fixture results are not model-quality evidence.
6. Include meaningful behavior/contract checks and an error path.
7. Use its own `src/`, `tests/` and `docs/`; update the root catalog.
8. Make generated content untrusted, errors accessible and approval boundaries visible.
9. Use US English for all UI, fixtures, prompts, messages, identifiers, and documentation.

## Publication readiness

Use [release readiness](release-readiness.md) for the publication gates and outstanding decisions. They include clean-environment reproduction, accurate live evidence, review of all material becoming public, third-party rights and notices under the owner-selected MIT licensing scope, private reporting, and owner approval of the exact destination.

Write reader-facing guides for someone without access to a maintainer's deployment or prior conversations. Separate offline exploration, inference through the reader's own Foundry deployment, and optional hosting. Keep operational history in verification records and operator runbooks, not in the first-success instructions. Reader-oriented wording is not permission to publish.

## Presentation and review

Present the project under Foundry Field Notes. Do not add assistant branding, generation signatures, tool-attribution footers or assistant co-author trailers to authored content or commits. Preserve required third-party notices and accurate dependency metadata.

The owner welcomes GitHub Copilot reviews. Use them when available for focused pull requests in the verified destination. Review findings critically and run applicable checks; automated review does not replace validation. Do not claim a review occurred unless an actual review was returned.

## Resource naming

Owner decision recorded on 2026-10-14: Azure resources use the Cloud Adoption Framework [resource abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations?wt.mc_id=AI-MVP-5004753) and the component order in [Define your naming convention](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming?wt.mc_id=AI-MVP-5004753), both accessed 2026-10-14. A name is the type abbreviation, the workload (`ffn`, spelled out as `foundry-field-notes` in the resource group), `labs` or the lab, the purpose, and a derived suffix where the name must be unique across Azure: for example `aif-ffn-labs-<suffix>` or `app-ffn-lab01-support-signal-<suffix>`. Shared resources belong to the [lab platform](shared-azure-platform.md), never to one lab; name model deployments after their model. Tag every resource `project=foundry-field-notes` and `scope=shared` or `lab=<number>`.

Documentation uses these generic patterns and placeholders. Never commit a real subscription, endpoint or suffix. Obtain the actual project endpoint from Azure and verify the deployment in the selected subscription before configuring the live path.
