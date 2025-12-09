// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TunForge",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TunForge",
            targets: ["TunForge"]
        ),
        .executable(name: "TunForgeDemo", targets: ["TunForgeDemo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.9.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TunForge",
            dependencies: [
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ],
            path: "Sources/TunForge"
        ),
        .testTarget(
            name: "TunForgeTests",
            dependencies: ["TunForge"]
        ),
        .executableTarget(
            name: "TunForgeDemo",
            dependencies: [
                "TunForge",
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ],
            path: "Sources/TunForgeDemo"
        ),
    ]
)
