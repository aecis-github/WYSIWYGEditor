// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WYSIWYGEditor",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WYSIWYGEditor",
            targets: ["WYSIWYGEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yonat/MultiSelectSegmentedControl", from: "2.3.8"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WYSIWYGEditor",
            dependencies: [
                .product(name: "MultiSelectSegmentedControl", package: "MultiSelectSegmentedControl"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ]
        ),
        .testTarget(
            name: "WYSIWYGEditorTests",
            dependencies: ["WYSIWYGEditor"]),
    ]
)
