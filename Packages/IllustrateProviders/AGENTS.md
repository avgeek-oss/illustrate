# Provider package guidance

Read README.md before changing provider code. This package must remain pure
Swift with no dependency on SwiftUI, SwiftData, Rust, or a hosted catalogue.

Use stable provider and model codes. Existing UUIDs derive from those codes,
so renaming a code changes persisted identity.

New providers register in Core/EnumProviderCode.swift, Models/, and AllModels.
New models also need an EnumProviderModelCode case, an adapter under Protocols/,
and factory wiring in the app's Services/Adapters/Generate directory.
The app owns credential forms and artwork.

Use the shared credential parser, async poller, response envelope, and
provider-family base classes where their contracts match. Inject networking
through NetworkProvider. Paid create requests must not retry automatically.
A provider family does not imply identical fields across all of its models.

Update offline tests for request fields, errors, polling, cancellation, and
pricing calculations. Never use live credentials or paid requests in tests.
Run swift test --package-path Packages/IllustrateProviders from the repo root,
then the app unit tests if model factory wiring changed.

Model descriptions are one sentence of 6-9 words describing the creative job.
Keep pricing, quotas, dates, and release claims in metadata and documentation,
not model descriptions. Verify provider API and pricing changes against their
official documentation and retain source and verification dates.
