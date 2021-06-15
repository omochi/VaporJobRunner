// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "VaporJobRunner",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(
            name: "VaporJobRunner",
            targets: [
                "VaporJobRunner"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.45.7"))
    ],
    targets: [
        .target(
            name: "VaporJobRunner",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        .testTarget(
            name: "VaporJobRunnerTests",
            dependencies: ["VaporJobRunner"]
        ),
    ]
)
