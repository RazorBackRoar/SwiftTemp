// swift-tools-version: 6.3

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
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "SwiftTempTests",
            dependencies: ["SwiftTemp"],
            path: "Tests/SwiftTempTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
