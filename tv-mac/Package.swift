// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TVFloat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TVFloat",
            path: "Sources/TVFloat"
        )
    ]
)
