CONFIGURATION ?= Release
BUILD_DIR ?= $(CURDIR)/build
XCODE_FLAGS ?= CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
XCODE = xcodebuild -quiet -project Illustrate.xcodeproj -scheme Illustrate -derivedDataPath '$(BUILD_DIR)/Apple' -clonedSourcePackagesDirPath '$(BUILD_DIR)/SourcePackages'

.PHONY: build build-macos build-ios build-ios-device test test-providers test-app format format-check docs-dev docs-check

build: build-macos build-ios

build-macos:
	$(XCODE) -configuration $(CONFIGURATION) -destination 'generic/platform=macOS' $(XCODE_FLAGS) build

build-ios:
	$(XCODE) -configuration $(CONFIGURATION) -destination 'generic/platform=iOS Simulator' $(XCODE_FLAGS) build

build-ios-device:
	$(XCODE) -configuration $(CONFIGURATION) -destination 'generic/platform=iOS' $(XCODE_FLAGS) build

test-providers:
	swift test --package-path Packages/IllustrateProviders

test: test-providers
	swift test --package-path Packages/apple-foundations
	swift test --package-path Packages/apple-design-system
	swift test --package-path Packages/apple-test-support

test-app:
	$(XCODE) -configuration Debug -destination 'platform=macOS' -parallel-testing-enabled NO $(XCODE_FLAGS) ILLUSTRATE_BUNDLE_IDENTIFIER=so.illustrate.tests test

format:
	swiftformat Illustrate IllustrateTests Packages --config .swiftformat

format-check:
	swiftformat Illustrate IllustrateTests Packages --lint --config .swiftformat

docs-dev:
	npm run docs:dev

docs-check:
	npm run docs:check
