// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalaryClockCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SalaryClockCore", targets: ["SalaryClockCore"])
    ],
    targets: [
        .target(name: "SalaryClockCore"),
        .testTarget(
            name: "SalaryClockCoreTests", dependencies: ["SalaryClockCore"],
            // 공휴일 자료 검증 테스트가 #filePath로 직접 읽는다. 리소스로 복사하지 않는다.
            exclude: ["Fixtures"]
        ),
    ]
)
