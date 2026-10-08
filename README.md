<p align="center"><img src="docs/assets/logo.png" width="96" height="96" alt="Illustrate" /></p>

# Illustrate

A native SwiftUI workspace for AI image and video creation on iPhone, iPad,
and Mac. Use your own provider accounts, organize work into projects, and
keep prompts and generated media together.

The app includes image and video generation, chat threads, bulk workflows,
storyboards, Flow Canvas, agent workflows, and product photoshoots. Its Swift
catalogue contains 27 providers. Availability and charges depend on your
provider account; catalogue entries do not guarantee live model access.

## Build your own copy

Use a Mac with Xcode 26 or newer and the iOS platform installed.
The app runs on iOS 18.6 or later and macOS 15.6 or later.

```sh
git clone https://github.com/avgeek-oss/illustrate.git
cd illustrate
make build-macos
make build-ios
```

These commands build unsigned Release binaries. Public Swift dependencies
are downloaded automatically. No Rust, React Native, server, or private
package registry is required.

To run a signed copy, copy `Config/Signing.local.xcconfig.example` to
`Config/Signing.local.xcconfig`. Set your team, unique bundle identifier, and
iCloud container. Configure that container, CloudKit, push notifications,
and Keychain Sharing in your Apple Developer account. Open
`Illustrate.xcodeproj` and run the **Illustrate** scheme. The local file is
ignored by Git. Official app identifiers remain unchanged.

See the [build guide](docs/docs/build-from-source.mdx).

## Tests

```sh
make test             # Offline provider and shared-package unit tests
make test-app         # Hosted app unit tests with a separate app identity
make format-check     # Requires SwiftFormat
```

Tests use injected transports, synthetic credentials, and in-memory stores.
They do not submit paid generations or validate real provider accounts.
See the [test guide](IllustrateTests/README.md) and
[provider package](Packages/IllustrateProviders/README.md).

## Documentation

The Mintlify homepage and guides live in [docs/](docs/README.md).
Node.js 24 or newer is needed only for documentation tooling.

```sh
npm ci
npm run docs:dev      # http://localhost:4188
npm run docs:check
```

## Maintenance and license

Illustrate is maintained by Avgeek. We publish the source so you can inspect,
clone, build, and modify your own copy under the [Apache-2.0 license](LICENSE).
We do not accept external contributions or pull requests. Report bugs and
share feedback through [GitHub Issues](https://github.com/avgeek-oss/illustrate/issues).

Copyright 2026 Avgeek, Inc. Illustrate and its bundled Avgeek Apple packages
are licensed under Apache-2.0. Provider names, trademarks, and artwork belong
to their respective owners; inclusion does not imply endorsement or grant
rights to those marks. Third-party Swift dependencies retain their own licenses,
included in their source distributions.

Documentation uses [Avgeek OSS Docs](https://github.com/avgeek-oss/oss-docs),
copyright 2026 Avgeek, Inc., under Apache-2.0. Its homepage layout and header
behavior are derived from [Towbar](https://github.com/avgeek-oss/towbar),
also licensed under Apache-2.0.
