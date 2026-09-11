// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IsLandToken",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "IsLandToken", targets: ["IsLandToken"])],
    // CodexBar's exact Vortex revision: ef5392088d4aeb255c4eee83157dbdafcd31bf07.
    dependencies: [.package(path: "Vendor/Vortex")],
    targets: [
        .target(name: "IslandCore"),
        .executableTarget(name: "IsLandToken", dependencies: ["IslandCore", .product(name: "Vortex", package: "Vortex")], resources: [.process("Resources")]),
        .testTarget(name: "IslandCoreTests", dependencies: ["IslandCore"])
    ],
    swiftLanguageModes: [.v5]
)
