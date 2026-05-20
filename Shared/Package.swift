// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HealthSyncShared",
    platforms: [
        .iOS(.v19),
        .tvOS(.v19)
    ],
    products: [
        .library(name: "HealthSyncShared", targets: ["HealthSyncShared"])
    ],
    targets: [
        .target(name: "HealthSyncShared", path: "Sources/HealthSyncShared")
    ]
)
