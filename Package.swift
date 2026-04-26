// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PostmanClient",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PostmanClient",
            path: "."
        ),
    ]
)