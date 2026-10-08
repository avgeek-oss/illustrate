# Illustrate Providers

Swift model definitions and provider adapters, independent of SwiftUI and
SwiftData. Run the offline package tests with:

```sh
swift test --package-path Packages/IllustrateProviders
```

## Shared patterns

`ImageGenerationProtocol` and `VideoGenerationProtocol` define the generation
interface. `ProviderDependencies` supplies the network and model catalogue;
its task-local overrides keep concurrent tests isolated. Adapters must use
the injected `NetworkProvider`, not create their own network sessions.
Use `withProviderDependencies` in synchronous tests too. Calling the global
`configure` method from a test can replace another suite's model catalogue.

Use `performSingleAttemptRequest` for non-idempotent, paid submissions.
Retries belong on safe status reads, not generation creation. Preserve response
status, headers, and raw data through `NetworkResponseEnvelope`.

`ProviderCredentialConfiguration` parses simple and structured secrets.
`ProviderAsyncJobPoller` shares bounded polling and cancellation behavior.
Provider-family base adapters share request and response handling for related
models. Keep endpoint-specific fields in those adapters: a shared family does
not mean every model accepts the same parameters.

## Adding a provider or model

1. Add its stable code under `Core/` and its model definition under `Models/`.
2. Register the model list in `AllModels.createModels()`.
3. Add an adapter under `Protocols/`, reusing its provider family's base when appropriate.
4. Wire its factory in `Illustrate/Services/Adapters/Generate/`, and add provider credentials and artwork to the app.
5. Add offline tests for requests, error responses, costs, and polling. Cover shared behavior in package tests and app wiring in `IllustrateTests/`.

The catalogue is bundled, not fetched from a control plane. Model availability
and pricing can change independently of the app. Preserve pricing provenance
and verify against the provider's documentation when updating either.
