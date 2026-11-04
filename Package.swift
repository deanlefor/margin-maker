// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarginMaker",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MarginMaker", targets: ["MarginMaker"]),
        .library(name: "MarginMakerCore", targets: ["MarginMakerCore"])
    ],
    targets: [
        .target(name: "MarginMakerCore"),
        .executableTarget(name: "MarginMaker", dependencies: ["MarginMakerCore"]),
        .testTarget(name: "MarginMakerCoreTests", dependencies: ["MarginMakerCore"])
    ]
)
