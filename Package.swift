// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TATSU",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TATSUCore", targets: ["TATSUCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .target(name: "TATSUCore", path: "Sources/TATSUCore"),
        .testTarget(
            name: "TATSUCoreTests",
            dependencies: [
                "TATSUCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/TATSUCoreTests"
        ),
    ]
)
