// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Unhitch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Unhitch",
            path: "Sources/Unhitch",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
