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

// Aemi, pinned to one revision. HubRules builds on AemiKernel, which wine-objects compiles as Embedded Swift with
// AemiKernels and their C (CAemiKernels, CAemiCPU) into libwinekit.a; QualityKit builds on AemiFileSystem; the gates use
// Aemi's scripts (check-manifest-settings.sh, check-tags.sh, analyzers.lock, lib/c-targets.sh) and canonical
// configuration. Aemi's LintBuild plugin (swift-format lint --strict as a prebuild step) only runs behind WINEKIT_DEV, so Wine's build
// doesn't lint.
let isDev = Context.environment["WINEKIT_DEV"] != nil
let devPlugins: [Target.PluginUsage] = isDev ? [.plugin(name: "LintBuild", package: "aemi")] : []

let aemi: Package.Dependency = .package(
    url: "https://github.com/Aemi-Studio/aemi.git",
    revision: "fbd6b3088abed46e25428832ebcbd6ab053dca77"
)

let package = Package(
    name: "WineKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "HubRules", targets: ["HubRules"]),
        .plugin(name: "Quality", targets: ["Quality"])
    ],
    dependencies: [aemi],
    targets: [
        .target(
            name: "HubRules",
            dependencies: [.product(name: "AemiKernel", package: "aemi")],
            swiftSettings: librarySettings,
            plugins: devPlugins
        ),
        .testTarget(name: "HubRulesTests", dependencies: ["HubRules"], swiftSettings: strictSettings),

        // The quality gates: QualityKit decides, winekit-quality runs it, the Quality plugin hands it the package.
        .target(
            name: "QualityKit",
            dependencies: [.product(name: "AemiFileSystem", package: "aemi")],
            swiftSettings: strictSettings,
            plugins: devPlugins
        ),
        .executableTarget(name: "winekit-quality", dependencies: ["QualityKit"], swiftSettings: strictSettings),
        .plugin(
            name: "Quality",
            capability: .command(
                intent: .custom(
                    verb: "quality",
                    description:
                        "Run WineKit's quality gates (see QualityKit's Gate), or write libwinekit.a and winekit.h "
                        + "for Wine's build: quality wine-objects <dir>"
                ),
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
        .testTarget(name: "QualityKitTests", dependencies: ["QualityKit"], swiftSettings: strictSettings)
    ]
)
