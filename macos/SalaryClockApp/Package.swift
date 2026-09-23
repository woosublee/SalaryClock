// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalaryClockApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../SalaryClockCore"),
        // 자동 업데이트. 버전을 정확히 못 박는다 — 프레임워크를 번들에 직접
        // 복사해 서명하므로(scripts/bundle-app.sh) 올라간 버전이 조용히
        // 바뀌면 서명과 임베드가 어긋난다.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2"),
    ],
    targets: [
        // main.swift를 제외한 전부. 실행 파일의 최상위 main.swift 코드를
        // 테스트 번들에 링크하면 main 심볼이 충돌하므로 라이브러리로 분리한다.
        .target(
            name: "SalaryClockAppLib",
            dependencies: [
                .product(name: "SalaryClockCore", package: "SalaryClockCore"),
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        // main.swift만 담는다. 빌드 산출물 이름은 scripts/bundle-app.sh가
        // 그대로 복사하므로 SalaryClockApp을 유지한다.
        .executableTarget(
            name: "SalaryClockApp",
            dependencies: ["SalaryClockAppLib"]
        ),
        .testTarget(
            name: "SalaryClockAppTests",
            dependencies: ["SalaryClockAppLib"]
        ),
    ]
)
