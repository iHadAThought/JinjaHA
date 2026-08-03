// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JinjaHA",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "JinjaCore", targets: ["JinjaCore"]),
        .library(name: "JinjaHA", targets: ["JinjaHA"]),
        .library(name: "JinjaHASwiftUI", targets: ["JinjaHASwiftUI"]),
        .executable(name: "MinimalRender", targets: ["MinimalRender"]),
        .executable(name: "CompareDemo", targets: ["CompareDemo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "JinjaCore",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            exclude: ["LICENSE.upstream"]
        ),
        .target(
            name: "JinjaHA",
            dependencies: ["JinjaCore"]
        ),
        .target(
            name: "JinjaHASwiftUI",
            dependencies: ["JinjaHA"]
        ),
        .executableTarget(
            name: "MinimalRender",
            dependencies: ["JinjaHA"],
            path: "Examples/MinimalRender"
        ),
        .executableTarget(
            name: "CompareDemo",
            dependencies: ["JinjaHA", "JinjaHASwiftUI"],
            path: "Examples/CompareDemo",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]
        ),
        .testTarget(
            name: "JinjaCoreTests",
            dependencies: ["JinjaCore"]
        ),
        .testTarget(
            name: "JinjaHATests",
            dependencies: ["JinjaHA", "JinjaCore"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "JinjaHASwiftUITests",
            dependencies: ["JinjaHASwiftUI", "JinjaHA"]
        ),
    ]
)
