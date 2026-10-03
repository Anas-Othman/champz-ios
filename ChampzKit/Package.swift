// swift-tools-version: 6.0
// ChampzKit — everything except the thin App target, in one module.
// Folders (Core, Models, Repositories, DesignSystem, Localization, Navigation, Features)
// are organisation, not compiler boundaries; SwiftLint keeps features out of Repositories internals.
import PackageDescription

let package = Package(
    name: "ChampzKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ChampzKit", targets: ["ChampzKit"]),
    ],
    targets: [
        .target(
            name: "ChampzKit",
            path: "Sources",
            resources: [
                .process("DesignSystem/Resources"),
                .process("Localization/Resources"),
            ]
        ),
        .testTarget(
            name: "ChampzKitTests",
            dependencies: ["ChampzKit"],
            path: "Tests/ChampzKitTests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
