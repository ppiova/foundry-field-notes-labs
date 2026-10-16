# Foundry Field Notes presentation portal

A static, US English website for developers who know C# and JSON. The [portal](site/index.html) has a catalog, a visual guide for each implemented lab, and a clearly labeled planned sequence. It does not host the .NET applications, call Azure, accept uploads, or store approvals.

## Preview without publishing

Open [site/index.html](site/index.html) in a browser. No build, package installation, Azure account, or local web server is required. Source-code and documentation links open external sites only when followed.

| Page | What it teaches | Offline boundary |
| --- | --- | --- |
| [Catalog](site/index.html) | Choose a lab and see the proposed learning sequence | Only Labs 001 and 002 have guides. Labs 003-008 are planned, not runnable. |
| [Lab 001: Support Signal](site/labs/001/index.html) | A support proposal, exact quoted evidence, and human review | Documents deterministic simulation. Its quote exercise checks string membership in the browser; it does not run the simulator, .NET, MAF, or a model. |
| [Lab 002: Bid Review Queue](site/labs/002/index.html) | Bounded choices, threshold policy, and selective escalation | Uses recorded item 13 responses. Its threshold exercise makes no new inference call. |

Both guides include C# excerpts, a 15-minute speaking route, prerequisites for the separate app, and evidence limits. The main explanation remains readable without JavaScript; the exercises stay disabled.

For an HTTP preview, serve only `docs/site` with a local static server of your choice. All local links and assets are relative, including when served under `/foundry-field-notes-labs/`. Do not expose the repository root on a public network. No server or Azure cleanup is needed for a direct file preview.

Expected interactions:

1. From the catalog, open each available lab, follow the next/previous guide link, and return to the catalog. Planned cards have no fictional guide destinations.
2. In Lab 001, the exact quote passes membership only; the invented quote fails. Changing case or inserting whitespace can also fail. All paths still require human judgment.
3. In Lab 002, 0.90 leaves item 13 with a person; 0.70 accepts by rule while retaining the disagreement warning; 0.71 returns to review. Reset restores 0.90 and includes the recorded second opinion.

Approval invalidation, export, input processing, and the full review queue belong to the separate .NET apps, not these web exercises. Use the [Lab 001](../samples/01-support-signal/docs/demo-script.md) and [Lab 002](../samples/02-bid-review-queue/docs/demo-script.md) demo scripts for those portions of a presentation.

## Structure and maintenance

```text
docs/site/
  index.html                 Catalog and planned sequence
  styles.css                 Shared visual style
  navigation.js              Shared chapter highlighting
  labs/001/index.html        Support Signal guide
  labs/001/guide.js           Evidence-membership illustration
  labs/002/index.html        Bid Review Queue guide
  labs/002/guide.js           Recorded threshold illustration
  labs/002/case-data.js       Generated projection of the bundled recordings
```

There is no framework, frontend build, third-party font, analytics, or CDN dependency. Edit the HTML, CSS, and JavaScript directly. Keep source links, preview labels, and access dates accurate. Do not copy private data or operational configuration into this directory: every file in it is publication content.

The shared palette takes visual inspiration from the [Microsoft Foundry product page](https://azure.microsoft.com/en-us/products/ai-foundry?wt.mc_id=AI-MVP-5004753), viewed on 2026-10-15: blue and indigo accents with soft coral highlights. These are our own accessible color choices, not official Microsoft design tokens. Keep Foundry Field Notes branding; do not copy Microsoft logos or imply affiliation. Green, amber, and red remain reserved for result, review, and error states. Gradient headings have solid-color print and forced-colors fallbacks.

Only `labs/002/case-data.js` is generated. It projects selected synthetic choices, probabilities, model names, and capture dates, not raw response metadata or deployment configuration. Regenerate after changing its source recordings. The Lab 001 fixture is checked against `scenarios.outage` in the app; its displayed simulation result and C# snippets are guarded against source drift.

From the repository root, with PowerShell 7 and Node.js **24.15.0** (pinned in CI):

```powershell
.\scripts\Build-BidPresentation.ps1
.\scripts\Build-BidPresentation.ps1 -Check
node --test .\scripts\tests\site.test.cjs .\samples\01-support-signal\tests\presentation.test.cjs .\samples\02-bid-review-queue\tests\presentation.test.cjs
```

No `npm install` is needed. The root validation script includes these checks. Tests cover the published-file allowlist, catalog status, relative links and anchors, source-derived evidence and code excerpts, and interaction/failure paths. They do not replace browser verification or establish live inference.

Before presenting, check desktop and narrow layouts, keyboard focus, both exercises, no-script rendering, and missing recorded evidence. A missing Lab 002 data file must disable that exercise with an error; it must not be shown as an interactive success. Browser guide checks do not validate the separate .NET applications.

To add an implemented lab later, follow the repository's owner-approval process first. Add its guide under `labs/NNN`, link its sample code and evidence, update the catalog and sample README, and expand the publication allowlist and tests. A planned card must not become an available guide before its implementation and supporting evidence exist.

## Publish only after owner approval

The workflow is **manual only**. This local change does not enable Pages, change repository visibility, or establish that publication succeeded.

The intended destination remains the existing `ppiova/foundry-field-notes-labs` repository. Recheck its remote, visibility, approved content, and any existing Pages site before publishing: deploying the portal can replace a previous single-lab site. Treat the output as public material; do not assume Pages inherits a private repository's access restrictions.

After the owner approves the destination and content:

1. Merge the reviewed changes to `main` using the normal repository process.
2. In **Settings > Pages**, select **GitHub Actions** as the publishing source. Do not create another repository or change visibility.
3. Configure the `github-pages` environment with branch restrictions and an owner approval requirement where the account supports it.
4. Run **Publish field guides (manual)** from `main`, explicitly select the publication approval checkbox, and approve the environment deployment if requested.
5. Open the URL from the deployment result. Check the catalog, both guide routes, assets, and exercises. A started workflow is not evidence of a successful deployment.

`.github/workflows/publish-pages.yml` pins action revisions, checks content before upload, and uploads only the eight allowlisted files under `docs/site`. It never uploads the repository, app settings, or full recordings. It does not run on push or pull request. An approved run may incur GitHub plan-dependent usage; it provisions no Azure resources and makes no model calls.

If Pages is not configured, follow the workflow error instead of enabling unrelated services. Local preview remains available. To withdraw a published site, unpublish it from the repository's Pages settings; deleting local files alone does not remove a deployed site.

## Sources

- [GitHub: custom workflows with GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), accessed 2026-10-15. Publishing source, artifacts, permissions, and deployment environment.
- [GitHub: unpublishing a Pages site](https://docs.github.com/en/pages/getting-started-with-github-pages/unpublishing-a-github-pages-site), accessed 2026-10-15.
- [Microsoft Learn: Foundry model provider](https://learn.microsoft.com/en-us/agent-framework/integrations/by-component/model-providers/microsoft-foundry?wt.mc_id=AI-MVP-5004753), accessed 2026-10-15. Code-defined agents versus service-managed agents.
- [Microsoft Learn: Microsoft-Decision-1](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/use-foundry-models-microsoft-decision?wt.mc_id=AI-MVP-5004753), accessed 2026-10-15. Typed decisions and per-option probabilities.
- [Learning roadmap](learning-roadmap.md), [Lab 001 verification](../samples/01-support-signal/docs/verification.md), and [Lab 002 source register](../samples/02-bid-review-queue/docs/sources.md). Planned scope, dated observations, version boundaries, and limitations.

The presentation structure and browser exercises are this project's teaching design, not Microsoft product features or measured learning outcomes.
