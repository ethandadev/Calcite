// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CalciteCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "CalciteCore", targets: ["CalciteCore"]),
    ],
    targets: [
        .target(name: "CalciteCore"),
        .testTarget(name: "CalciteCoreTests", dependencies: ["CalciteCore"]),
    ]
)
