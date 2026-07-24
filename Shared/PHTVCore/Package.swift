// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "PHTVCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PHTVCore", type: .dynamic, targets: ["PHTVCore"]),
        .library(name: "PHTVCoreContracts", targets: ["PHTVCoreContracts"]),
        .executable(name: "PHTVCoreABISmoke", targets: ["PHTVCoreABISmoke"]),
    ],
    targets: [
        .target(
            name: "PHTVCoreContracts",
            publicHeadersPath: "include"
        ),
        .target(
            name: "PHTVCore",
            dependencies: ["PHTVCoreContracts"]
        ),
        .executableTarget(
            name: "PHTVCoreABISmoke",
            dependencies: ["PHTVCore", "PHTVCoreContracts"]
        ),
        .testTarget(
            name: "PHTVCoreTests",
            dependencies: ["PHTVCore", "PHTVCoreContracts"]
        ),
    ]
)
