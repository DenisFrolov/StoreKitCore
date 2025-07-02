// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StoreKitCore",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "StoreKitCore",
            targets: ["StoreKitCore"]),
    ],
    targets: [
        .target(
            name: "StoreKitCore"),
        .testTarget(
            name: "StoreKitCoreTests",
            dependencies: ["StoreKitCore"]
        ),
    ]
)
