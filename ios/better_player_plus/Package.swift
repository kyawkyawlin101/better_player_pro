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
    ],
    targets: [
        .target(
            name: "GCDWebServer"
        ),
        .target(
            name: "PINCache"
        ),
        .target(
            name: "HLSCachingReverseProxyServer",
            dependencies: [
                .target(name: "GCDWebServer"),
                .target(name: "PINCache"),
            ]
        ),
        .target(
            name: "better_player_plus",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .target(name: "GCDWebServer"),
                .target(name: "PINCache"),
                .target(name: "HLSCachingReverseProxyServer"),
            ],
            exclude: [
                "BetterPlayerPlugin.h",
                "BetterPlayerPlugin.m",
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
