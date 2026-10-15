# Third-party materials

## Original project material

The root [MIT License](../LICENSE) covers original Foundry Field Notes code and documentation. It does not relicense dependencies, Microsoft documentation, Azure services, or model output.

## Dependencies

This source repository does not vendor NuGet packages, SDKs, or published application binaries. The project files and `packages.lock.json` files identify the dependencies restored from NuGet, including prerelease packages. Do not remove their license files, notices, or accurate package metadata from redistributed packages or published applications.

The direct package references are:

| Package | Pinned version | Package and licensing information |
| --- | --- | --- |
| Microsoft.Agents.AI.Foundry | 1.24.0-preview.261006.1 | [NuGet](https://www.nuget.org/packages/Microsoft.Agents.AI.Foundry/1.24.0-preview.261006.1) |
| Azure.Identity | 1.21.0 | [NuGet](https://www.nuget.org/packages/Azure.Identity/1.21.0) |
| Microsoft.FluentUI.AspNetCore.Components | 5.0.0 | [NuGet](https://www.nuget.org/packages/Microsoft.FluentUI.AspNetCore.Components/5.0.0) |
| Microsoft.FluentUI.AspNetCore.Components.Icons | 5.0.0 | [NuGet](https://www.nuget.org/packages/Microsoft.FluentUI.AspNetCore.Components.Icons/5.0.0) |

The restored locked packages' NuGet license declarations were inspected on 2026-10-15. They declare MIT, except Google.Protobuf 3.30.2 (BSD-3-Clause) and System.Security.Cryptography.ProtectedData 4.5.0, which uses a legacy corefx license URL rather than an SPDX declaration. Package declarations are not a review of every bundled notice. This table is not a complete notice inventory for a binary distribution; inspect the locked packages and their included notices before redistributing a binary build.

## Fixtures, recordings, and screenshots

The sample inputs and labels are synthetic teaching fixtures, not customer documents. Lab 002 includes 268 Microsoft-Decision-1 responses and 114 gpt-6-luna responses recorded on 2026-10-14. The two Lab 001 screenshots show this project's application with synthetic requests; one is simulation and one is a dated live response. No model weights are included.

Recordings contain model output and service response metadata, including opaque response IDs and timestamps. They are retained as historical evidence, not generated anew by replay. They must not be represented as a current successful model run, a general benchmark, or proof of stateless processing. The bundled second-opinion responses report `store: true`; see the [source register](../samples/02-bid-review-queue/docs/sources.md).

The applicable Azure agreement, model terms, and third-party rights are separate from this repository's MIT license. The [Microsoft Product Terms](https://www.microsoft.com/licensing/terms/product/ForOnlineServices/all?wt.mc_id=AI-MVP-5004753) and [Foundry data-processing documentation](https://learn.microsoft.com/en-us/azure/foundry/responsible-ai/openai/data-privacy?wt.mc_id=AI-MVP-5004753) were consulted on 2026-10-15. They do not establish which agreement applies to a particular subscriber or provide an independent legal clearance for these materials. Maintainer approval of redistribution is recorded separately in [release readiness](release-readiness.md).

Microsoft references are linked, not republished wholesale. Foundry Field Notes is independent and does not imply Microsoft sponsorship or endorsement.
