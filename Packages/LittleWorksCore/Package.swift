// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LittleWorksCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "LittleWorksCore", targets: ["LittleWorksCore"]),
    ],
    targets: [
        .target(name: "LittleWorksCore"),
        .testTarget(name: "LittleWorksCoreTests", dependencies: ["LittleWorksCore"]),
    ]
)
