// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalaryClockCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SalaryClockCore", targets: ["SalaryClockCore"])
    ],
    targets: [
        .target(name: "SalaryClockCore"),
        .testTarget(name: "SalaryClockCoreTests", dependencies: ["SalaryClockCore"]),
    ]
)
