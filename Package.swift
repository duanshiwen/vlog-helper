// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VlogPack",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "VlogPackCore",
            targets: ["VlogPackCore"]
        ),
        .executable(
            name: "VlogPack",
            targets: ["VlogPackApp"]
        ),
    ],
    dependencies: [],
    targets: [
        // Core library — models, services, adapters (testable)
        .target(
            name: "VlogPackCore",
            path: "Sources/VlogPackCore",
            resources: [
                .process("Resources")
            ]
        ),
        // SwiftUI app shell — excludes Resources (Info.plist/entitlements handled by build script)
        .executableTarget(
            name: "VlogPackApp",
            dependencies: ["VlogPackCore"],
            path: "Sources/VlogPackApp",
            exclude: ["Resources"]
        ),
        // Core tests
        .testTarget(
            name: "VlogPackCoreTests",
            dependencies: ["VlogPackCore"],
            path: "Tests/VlogPackCoreTests"
        ),
    ]
)
