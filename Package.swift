// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AntiIdle",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AntiIdle",
            path: "Sources/AntiIdle"
        )
    ]
)
