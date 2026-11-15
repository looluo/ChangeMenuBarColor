// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ChangeMenuBarColor",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "ChangeMenuBarColor", targets: ["ChangeMenuBarColor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.2.2"),
        .package(url: "https://github.com/JohnSundell/Files", from: "4.3.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ChangeMenuBarColor",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Rainbow", package: "Rainbow"),
                .product(name: "Files", package: "Files")
            ]),
    ]
)
