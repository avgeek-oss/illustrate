// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AvgeekAppleTestSupport",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "AvgeekTestSupport", targets: ["AvgeekTestSupport"]),
    ],
    dependencies: [
        .package(path: "../apple-foundations"),
    ],
    targets: [
        .target(
            name: "AvgeekTestSupport",
            dependencies: [
                .product(name: "AvgeekNetworking", package: "apple-foundations"),
            ]
        ),
        .testTarget(
            name: "AvgeekTestSupportTests",
            dependencies: [
                "AvgeekTestSupport",
                .product(name: "AvgeekNetworking", package: "apple-foundations"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
