# Offline app tests

Run `make test-app` from the repository root. Xcode hosts these unit tests in
a minimal SwiftUI test host, not the production application. The test build
uses `so.illustrate.tests`, keeping preferences and Keychain access separate
from the official app. Shared SwiftData fixtures are in memory with CloudKit off.

Provider tests use synthetic keys and injected network transports. Do not add
live integration tests, real credentials, or paid API calls. `make test` runs
the standalone provider and shared-package unit tests.

When adding a model, cover request serialization, malformed/error responses,
cost calculations, and any polling or cancellation behavior. Changes to shared
adapters need regression tests for the other models that use them.
