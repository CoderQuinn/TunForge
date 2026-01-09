// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TunForge",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        // Swift surface
        .library(
            name: "TunForge",
            targets: ["TunForge"]
        ),
        // ObjC core (can be used standalone)
        .library(
            name: "TunForgeCore",
            targets: ["TunForgeCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CoderQuinn/ForgeLogKit.git", from: "0.2.0"),
    ],
    targets: [
        // =========================================================
        // Layer 1: lwIP engine (pure C)
        // =========================================================
        .target(
            name: "Lwip",
            dependencies: [
                .product(name: "ForgeLogKitC", package: "ForgeLogKit"),
            ],
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

        // =========================================================
        // Layer 2: ObjC semantic core
        // =========================================================
        .target(
            name: "TunForgeCore",
            dependencies: [
                "Lwip",
                .product(name: "ForgeLogKitOC", package: "ForgeLogKit"),
            ],
            path: "Sources/TunForgeCore",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../Lwip/src/include"),
                .headerSearchPath("../Lwip/custom"),
            ]
        ),

        // =========================================================
        // Layer 3: Swift mapping / Flow layer
        // =========================================================
        .target(
            name: "TunForge",
            dependencies: [
                "TunForgeCore",
            ],
            path: "Sources/TunForge"
        ),

        // =========================================================
        // Tests
        // =========================================================
        .testTarget(
            name: "TunForgeTests",
            dependencies: ["TunForge"],
            path: "Tests/TunForgeTests"
        ),
    ]
)
