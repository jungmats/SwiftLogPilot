// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LogPilot",
    platforms: [
         .macOS(.v10_15), // Set the minimum deployment target to macOS 10.15
         .iOS(.v13)
     ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LogPilot",
            targets: ["LogPilot"]),
    ],
    dependencies: [
            // Add the zip-foundation dependency
            .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
        ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LogPilot",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                ]
            ),
        .testTarget(
            name: "LogPilotTests",
            dependencies: [
                "LogPilot",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                ]
        ),
    ]
)
