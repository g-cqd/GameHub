// swift-tools-version: 6.4
import PackageDescription

// WineKit: parts of Wine rewritten in Swift, one boundary at a time (GameHub ADR-0020).
//
// Library code is kept compatible with Embedded Swift (no Foundation, no existentials, byte-level text), so the same source
// links into Wine's Unix side with no Swift runtime; `Scripts/quality.sh embedded` checks that.

// The g-cqd family's canonical settings (Aemi-Studio/aemi scripts/check-manifest-settings.sh checks them): Swift 6 mode,
// warnings as errors, and the upcoming features that tighten existentials and imports.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility")
]

// The rules engine reads executables a game ships, so every unsafe construct in it must be marked `unsafe`.
let librarySettings: [SwiftSetting] = strictSettings + [.strictMemorySafety()]

// Dev-only tooling behind WINEKIT_DEV, so a consumer never resolves it: Aemi's shared LintBuild plugin (swift-format lint
// --strict as a prebuild step), its scripts (check-manifest-settings.sh, check-tags.sh, analyzers.lock) and its canonical
// configuration, pinned to one revision.
let isDev = Context.environment["WINEKIT_DEV"] != nil
let devPlugins: [Target.PluginUsage] = isDev ? [.plugin(name: "LintBuild", package: "aemi")] : []

let aemi: Package.Dependency = .package(
    url: "https://github.com/Aemi-Studio/aemi.git",
    revision: "c06c050dd13fa737fac9d173113c727d3212c5b8"
)

let package = Package(
    name: "WineKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "HubRules", targets: ["HubRules"]),
        .plugin(name: "Quality", targets: ["Quality"]),
        .plugin(name: "WineObjects", targets: ["WineObjects"])
    ],
    dependencies: isDev ? [aemi] : [],
    targets: [
        .target(name: "HubRules", swiftSettings: librarySettings, plugins: devPlugins),
        .testTarget(name: "HubRulesTests", dependencies: ["HubRules"], swiftSettings: strictSettings),

        // The quality gates: QualityKit decides, winekit-quality runs it, the Quality plugin hands it the package.
        .target(name: "QualityKit", swiftSettings: strictSettings, plugins: devPlugins),
        .executableTarget(name: "winekit-quality", dependencies: ["QualityKit"], swiftSettings: strictSettings),
        .plugin(
            name: "Quality",
            capability: .command(
                intent: .custom(verb: "quality", description: "Run WineKit's quality gates (see QualityKit's Gate)"),
                permissions: [
                    .allowNetworkConnections(
                        scope: .all(ports: [443]),
                        reason: "Download the pinned analyzers and swift-mutation-testing"
                    ),
                    .writeToPackageDirectory(reason: "Build and test in .build/quality, write the mutation reports")
                ]
            ),
            dependencies: ["winekit-quality"]
        ),
        .plugin(
            name: "WineObjects",
            capability: .command(
                intent: .custom(
                    verb: "wine-objects",
                    description: "Write libwinekit.a and winekit.h for Wine's build (make WINEKIT_DIR=<dir>)"
                ),
                permissions: [.writeToPackageDirectory(reason: "Build the Embedded Swift objects")]
            ),
            dependencies: ["winekit-quality"]
        ),
        .testTarget(name: "QualityKitTests", dependencies: ["QualityKit"], swiftSettings: strictSettings)
    ]
)
