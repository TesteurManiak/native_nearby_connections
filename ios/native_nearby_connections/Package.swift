// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "native_nearby_connections",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "native-nearby-connections", targets: ["native_nearby_connections"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // No usable release tag: the SDK's own dependencies are branch-based, so pin a commit.
        .package(
            url: "https://github.com/google/nearby.git",
            revision: "5a1508439d9a9b522945b427ee8d4892b9b8e073"
        ),
    ],
    targets: [
        .target(
            name: "native_nearby_connections_objc_gen",
            dependencies: [],
            publicHeadersPath: "."
        ),
        .target(
            name: "native_nearby_connections",
            dependencies: [
                "native_nearby_connections_objc_gen",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "NearbyConnections", package: "nearby"),
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it uses any required
                // reason APIs, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ]
        )
    ]
)
