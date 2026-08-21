// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SwiftTemp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SwiftTemp",
            targets: ["SwiftTemp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SwiftTemp",
            path: "Sources/SwiftTemp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftTempTests",
            dependencies: ["SwiftTemp"],
            path: "Tests/SwiftTempTests"
        )
    ]
)
