// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuBarLauncher",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MenuBarLauncher", targets: ["MenuBarLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "MenuBarLauncher",
            path: "Sources/MenuBarLauncher",
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)