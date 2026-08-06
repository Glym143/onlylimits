// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OnlyLimits",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OnlyLimits",
            path: "Sources/OnlyLimits"
        )
    ]
)
