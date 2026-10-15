// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IsLandToken",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "IsLandToken", targets: ["IsLandToken"])],
    // Pinned Vortex revision for the visual effects implementation.
    dependencies: [.package(path: "Vendor/Vortex")],
    targets: [
        .target(name: "IslandCore"),
        .executableTarget(name: "IsLandToken", dependencies: ["IslandCore", .product(name: "Vortex", package: "Vortex")], resources: [.process("Resources")]),
        .testTarget(name: "IslandCoreTests", dependencies: ["IslandCore"])
    ],
    swiftLanguageModes: [.v5]
)
