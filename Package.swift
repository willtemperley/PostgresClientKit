// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "PostgresClientKit",
    platforms: [
        .macOS(.v10_14), .iOS(.v12), .tvOS(.v12)
    ],
    products: [
        .library(
            name: "PostgresClientKit",
            targets: ["PostgresClientKit"]),
    ],
    targets: [
        .target(
            name: "PostgresClientKit"
        ),
        .testTarget(
            name: "PostgresClientKitTests",
            dependencies: ["PostgresClientKit"]),
    ]
)
