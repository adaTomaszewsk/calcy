// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Calcy",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Calcy", targets: ["Calcy"]),
        .library(name: "CalcEngine", targets: ["CalcEngine"]),
        .library(name: "Updater", targets: ["Updater"]),
    ],
    targets: [
        .target(name: "CalcEngine"),
        .target(name: "Updater"),
        .executableTarget(name: "Calcy", dependencies: ["CalcEngine", "Updater"]),
        .testTarget(name: "CalcEngineTests", dependencies: ["CalcEngine"]),
        .testTarget(name: "UpdaterTests", dependencies: ["Updater"]),
    ]
)
