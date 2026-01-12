// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SDL-Swift-Playground",
    platforms: [
        .macOS(.v13),
        .iOS(.v14)
    ],
    products: [
        .executable(name: "SDL-Swift-Playground", targets: ["SDL-Swift-Playground"])
    ],
    targets: [
        // SDL3 XCFramework (静的ライブラリ)
        .binaryTarget(
            name: "SDL3",
            path: "Dependencies/SDL3.xcframework"
        ),

        // Cバインディングターゲット
        .target(
            name: "CSDL3",
            dependencies: ["SDL3"],
            path: "Sources/CSDL3",
            publicHeadersPath: "include",
            linkerSettings: [
                // macOS用システムフレームワーク
                .linkedFramework("CoreVideo", .when(platforms: [.macOS])),
                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("IOKit", .when(platforms: [.macOS])),
                .linkedFramework("ForceFeedback", .when(platforms: [.macOS])),
                .linkedFramework("Carbon", .when(platforms: [.macOS])),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreHaptics"),
                .linkedFramework("GameController"),
                .linkedFramework("CoreServices", .when(platforms: [.macOS])),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("UniformTypeIdentifiers"),
                // iOS用フレームワーク
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS])),
                .linkedFramework("CoreMotion", .when(platforms: [.iOS])),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreBluetooth", .when(platforms: [.iOS])),
                .linkedFramework("CoreVideo", .when(platforms: [.iOS])),
                // 共通
                .linkedFramework("Foundation"),
            ]
        ),

        // メイン実行ターゲット
        .executableTarget(
            name: "SDL-Swift-Playground",
            dependencies: ["CSDL3"]
        ),
    ]
)
