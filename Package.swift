// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Zones",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "ZonesCore"
        ),
        .executableTarget(
            name: "ZonesApp",
            dependencies: ["ZonesCore"]
        ),
        .testTarget(
            name: "ZonesCoreTests",
            dependencies: ["ZonesCore"]
        )
    ]
)
