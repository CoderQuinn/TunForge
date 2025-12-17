// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "TunForge",
    platforms: [
        .iOS(.v12),
        .macOS(.v13),
    ],
    products: [
        // Swift library
        .library(
            name: "TunForge",
            targets: ["TunForge"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.9.0"),
    ],
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
        // ObjC wrapper target
        .target(
            name: "Tun2Socks",
            dependencies: ["Lwip"],
            path: "Sources/Tun2socks",
            publicHeadersPath: ".", // ObjC headers
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("Metrics"),
                .headerSearchPath("../Lwip/src/include"),
                .headerSearchPath("../Lwip/custom"),
                .headerSearchPath("../Lwip/custom/include"),
            ]
        ),
        // Swift high-level module
        .target(
            name: "TunForge",
            dependencies: [
                "Tun2Socks",
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ],
            path: "Sources/TunForge"
        ),
    ]
)
