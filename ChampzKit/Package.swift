// swift-tools-version: 6.0
// ChampzKit — every module of the app except the thin App target.
// Dependency rules live here and are enforced by the compiler; see the
// Architecture & Engineering Guide, section 3.
import PackageDescription

let package = Package(
    name: "ChampzKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Localization", targets: ["Localization"]),
        .library(name: "Navigation", targets: ["Navigation"]),
        .library(name: "Payments", targets: ["Payments"]),
        .library(name: "AuthFeature", targets: ["AuthFeature"]),
    ],
    targets: [
        // Bottom layer: errors, Loadable, networking, decoding helpers, session, logging.
        .target(name: "Core"),

        // Models and repository protocols. Depends on Core only for AppError/Money helpers.
        .target(name: "Domain", dependencies: ["Core"]),

        // DTOs, endpoint definitions, repository implementations. The only module that decodes API JSON.
        .target(name: "Data", dependencies: ["Core", "Domain"]),

        // Every user-facing string, typed. Resources: Localizable.xcstrings.
        .target(name: "Localization", resources: [.process("Resources")]),

        // Colors, fonts, spacing, icons, reusable components. Resources: bundled fonts.
        .target(name: "DesignSystem", dependencies: ["Core", "Localization"], resources: [.process("Resources")]),

        // Typed routes, router, deep-link parser.
        .target(name: "Navigation", dependencies: ["Domain"]),

        // Checkout engine shared by every paid flow (section 9). Opened through a route, never imported by features.
        .target(name: "Payments", dependencies: ["Core", "Domain", "DesignSystem", "Localization", "Navigation"]),

        // Features: screens + view models. Depend on Domain protocols, never on Data.
        .target(
            name: "AuthFeature",
            dependencies: ["Core", "Domain", "DesignSystem", "Localization", "Navigation"],
            path: "Sources/Features/Auth"
        ),

        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "AuthFeatureTests", dependencies: ["AuthFeature"], path: "Tests/Features/AuthTests"),
        .testTarget(name: "DataTests", dependencies: ["Data"], resources: [.copy("Fixtures")]),
        .testTarget(name: "NavigationTests", dependencies: ["Navigation"]),
    ],
    swiftLanguageModes: [.v6]
)
