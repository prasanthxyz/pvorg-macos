// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pvorg-native",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "pvorg-native", targets: ["PvorgNative"]),
    ],
    targets: [
        .executableTarget(
            name: "PvorgNative",
            path: "Sources/PvorgNative"
        ),
    ]
)
