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
        .library(name: "JinjaHA", targets: ["JinjaHA"]),
        .library(name: "JinjaHASwiftUI", targets: ["JinjaHASwiftUI"]),
        .executable(name: "MinimalRender", targets: ["MinimalRender"]),
    ],
    dependencies: [
        .package(url: "https://github.com/huggingface/swift-jinja.git", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "JinjaHA",
            dependencies: [
                .product(name: "Jinja", package: "swift-jinja"),
            ]
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
        .testTarget(
            name: "JinjaHATests",
            dependencies: ["JinjaHA"],
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
