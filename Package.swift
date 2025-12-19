// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "TunForge",
    platforms: [
        .iOS(.v13),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "TunForge",
            targets: ["TunForge"]
        ),
        .library(
            name: "TunForgeCore",
            targets: ["TunForgeCore"]
        ),
    ],
    dependencies: [],
    targets: [
        // lwIP C target
        .target(
            name: "Lwip",
            path: "Sources/Lwip",
            exclude: [
                "src/netif/slipif.c",
                "src/apps/lwiperf",
                "src/apps/http",
            ],
            publicHeadersPath: "custom/include",
            cSettings: [
                .headerSearchPath("custom"),
                .headerSearchPath("custom/include"),
                .headerSearchPath("src/include"),
                .define("LWIP_IOS", .when(platforms: [.iOS])),
                .define("LWIP_MACOS", .when(platforms: [.macOS])),
            ]
        ),
        // ObjC core
        .target(
            name: "TunForgeCore",
            dependencies: ["Lwip"],
            path: "Sources/TunForge",
            exclude: ["TunForge.swift"],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("Metrics"),
                .headerSearchPath("../Lwip/src/include"),
                .headerSearchPath("../Lwip/custom"),
                .headerSearchPath("../Lwip/custom/include"),
            ]
        ),
        // Swift surface layer with typealiases and protocol extensions
        .target(
            name: "TunForge",
            dependencies: ["TunForgeCore"],
            path: "Sources/TunForge",
            sources: ["TunForge.swift"]
        ),
        // Tests
        .testTarget(
            name: "TunForgeTests",
            dependencies: ["TunForge"],
            path: "Tests/TunForgeTests"
        ),
    ]
)
