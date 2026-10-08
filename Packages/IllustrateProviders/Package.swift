// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IllustrateProviders",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "IllustrateProviders",
            targets: ["IllustrateProviders"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.14.0"),
    ],
    targets: [
        .target(
            name: "IllustrateProviders",
            dependencies: [
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ]
        ),
        .testTarget(
            name: "IllustrateProvidersTests",
            dependencies: ["IllustrateProviders"]
        ),
    ]
)
