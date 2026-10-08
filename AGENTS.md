# Repository guidance

Read the root README, then the README for the area being changed.
This standalone repository contains the SwiftUI app and Swift provider code.
Do not introduce Rust, React Native, a hosted catalogue, or private dependencies.

Use `make build-macos`, `make build-ios`, and `make build-ios-device` for unsigned
Release builds. `make test` runs package unit tests; `make test-app` runs hosted
app unit tests with an isolated identity. Tests must not call live providers,
submit paid requests, open production stores, or access real credentials.

Documentation lives in `/docs`. Run `npm run docs:sync` after changing
`docs/site.json`, and `npm run docs:check` before committing. Generated kit
files must not be edited directly. Public documentation uses GitHub Issues
for reports, with no email or direct-contact links. Do not add contribution
invitations; Avgeek maintains this repository without external pull requests.

Preserve official signing identities. Personal builds use the ignored
`Config/Signing.local.xcconfig`. Never commit signing secrets or generated builds.

## Project Overview

Illustrate is a multi-platform (macOS 15+ / iOS 18+) AI-powered image and video generation application distributed via the Apple App Store. It integrates with multiple AI providers (OpenAI, Stability AI, Google Cloud, Replicate, Fal AI, and Firecrawl) to let users generate images and videos from text prompts, build automated agent workflows on an infinite canvas, and manage generated content through a gallery system.

Data is stored locally using SwiftData with iCloud sync. API keys are securely stored in Apple Keychain.

## Architecture

**Pattern:** MVVM (Model-View-ViewModel) with ObservableObject view models

- **Model Layer** (`Illustrate/Model/`): SwiftData `@Model` entities organized by feature domain
- **View Layer** (`Illustrate/View/`): SwiftUI views organized by feature (17 directories)
- **ViewModel Layer** (`Illustrate/ViewModel/`): `ObservableObject` classes with `@Published` properties
- **Service Layer** (`Illustrate/Services/`): Adapters, caches, and core business logic
- **Utilities** (`Illustrate/Utils/`): Shared helpers (logging, constants, formatting)
- **Provider Package** (`Packages/IllustrateProviders/`): Standalone Swift package containing provider protocols, model definitions, cost models, and request/response types

## SwiftData Rules

- Every `@Model` that has a `project: Project?` relationship **must** have a corresponding `@Relationship(deleteRule: .cascade, inverse: \<Model>.project)` declared on `Project` in `Illustrate/Model/Common/Project.swift`. Missing inverses cause a runtime crash on launch (schema migration failure).
- When adding a new `@Model`, register it in **both**: the `allModels` array in `IllustrateApp.swift` (`createModelContainer()`) **and** the Xcode project file (`Illustrate.xcodeproj/project.pbxproj`) — the build will compile but the app will crash if either is missing.
- New `EnumNavigationItem` cases need entries in **all** navigation helpers: `labelForItem`, `subLabelForItem`, `iconForItem`, `coverImageForItem`, `viewForItem`, and `sectionItems` in `Navigation.swift`. If a cover image asset doesn't exist, return `nil` from `coverImageForItem` — returning a nonexistent asset name causes a runtime crash when the dashboard renders.
