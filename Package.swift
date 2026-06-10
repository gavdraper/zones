// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Zones",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "ZonesCore"
        ),
        .executableTarget(
            name: "ZonesApp",
            dependencies: [
                "ZonesCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(
            name: "ZonesCoreTests",
            dependencies: ["ZonesCore"]
        )
    ]
)
