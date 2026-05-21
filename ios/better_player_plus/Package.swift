// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "better_player_plus",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "better-player-plus", targets: ["better_player_plus"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Cache (hyperoslo) — SPM supported
        .package(url: "https://github.com/hyperoslo/Cache.git", from: "6.0.0"),
        // TODO: GCDWebServer has no official SPM support.
        // Option A: Use a community fork, e.g.:
        //   .package(url: "https://github.com/<fork>/GCDWebServer.git", from: "..."),
        // Option B: Vendor the source files directly into Sources/better_player_plus.
        //
        // TODO: HLSCachingReverseProxyServer has no SPM package.
        // It depends on GCDWebServer — resolve GCDWebServer first,
        // then either find an SPM fork or vendor the source.
        //
        // TODO: PINCache — verify SPM availability:
        //   .package(url: "https://github.com/pinterest/PINCache.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "better_player_plus",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "Cache", package: "Cache"),
                // Add GCDWebServer, HLSCachingReverseProxyServer, PINCache here
                // once their SPM packages are resolved above.
            ],
            resources: [
                // Uncomment if PrivacyInfo.xcprivacy is added:
                // .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
