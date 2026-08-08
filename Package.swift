// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GotifyMac",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "GotifyMac",
            path: "Sources/GotifyMac"
        ),
        .testTarget(
            name: "GotifyMacTests",
            dependencies: ["GotifyMac"],
            path: "Tests/GotifyMacTests"
        )
    ]
)
