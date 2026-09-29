// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Vieja",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ViejaCore", path: "Sources/ViejaCore"),
        .executableTarget(name: "Vieja", dependencies: ["ViejaCore"], path: "Sources/Vieja"),
        .testTarget(name: "ViejaCoreTests", dependencies: ["ViejaCore"], path: "Tests/ViejaCoreTests"),
    ]
)
