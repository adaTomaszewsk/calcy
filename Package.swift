// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Calcy",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Calcy", targets: ["Calcy"]),
        .library(name: "CalcEngine", targets: ["CalcEngine"]),
    ],
    targets: [
        .target(name: "CalcEngine"),
        .executableTarget(name: "Calcy", dependencies: ["CalcEngine"]),
        .testTarget(name: "CalcEngineTests", dependencies: ["CalcEngine"]),
    ]
)
