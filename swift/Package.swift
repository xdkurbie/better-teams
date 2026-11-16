// swift-tools-version: 6.2
import Foundation
import PackageDescription

// Absolute -L for the prebuilt Rust staticlib (built by scripts/build-rust.sh).
// Derived from this manifest's location so no env var is needed.
let rustLibDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // swift/
    .deletingLastPathComponent() // repo root
    .appendingPathComponent("rust/ostmac-core/target/release")
    .standardizedFileURL.path

// Frameworks that do not exist on macOS 12.0. Availability checks make
// the references weak; these flags keep a strong autolink from winning.
// SwiftPM passes linkerSettings to the Swift driver, which only forwards
// ld-only options placed after -Xlinker.
let weakSystemFrameworks: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "FoundationModels"]),
    .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "Translation"]),
    .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "ScreenCaptureKit"]),
]

let rustLink: [LinkerSetting] = [
    .unsafeFlags(["-L\(rustLibDir)", "-lostmac_core"]),
    .linkedFramework("Security"),
    .linkedFramework("CoreFoundation"),
    .linkedFramework("SystemConfiguration"),
] + weakSystemFrameworks

// UI-SPEC §4: every target stays in Swift 5 language mode (no strict-
// concurrency churn in the core).
let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "OstMac",
    // Keep in sync with MACOSX_DEPLOYMENT_TARGET in scripts/build-rust.sh.
    // macOS 12 is the floor (Monterey, including Intel). Newer APIs are
    // runtime-gated; see Shared/MacOS12Compat.swift.
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "OstMac", targets: ["OstMac"]),
        .executable(name: "ostmac-mcp", targets: ["ostmac-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "2.0.12"),
    ],
    targets: [
        .target(name: "COstMac", publicHeadersPath: "include"),
        // All non-view logic, incl. the former OstMacChatList files and
        // the AppState composition root (UI-SPEC §11.1).
        .target(name: "OstMacCore", dependencies: ["COstMac"], swiftSettings: v5),
        .target(name: "OstMacMCP", dependencies: ["OstMacCore"], swiftSettings: v5),
        // Every view, controller, and window (UI-SPEC §11.2). Skeleton
        // until P1.
        .target(
            name: "BetterTeamsUI",
            dependencies: [
                "OstMacCore",
                "COstMac",
                .product(name: "Perception", package: "swift-perception"),
            ],
            swiftSettings: v5
        ),
        .executableTarget(
            name: "OstMac",
            dependencies: ["BetterTeamsUI", "OstMacCore", "COstMac"],
            swiftSettings: v5,
            linkerSettings: rustLink
        ),
        .executableTarget(
            name: "ostmac-mcp",
            dependencies: ["OstMacMCP", "OstMacCore", "COstMac"],
            swiftSettings: v5,
            linkerSettings: rustLink
        ),
        .testTarget(
            name: "OstMacCoreTests",
            dependencies: ["OstMacCore", "COstMac"],
            swiftSettings: v5,
            linkerSettings: rustLink
        ),
        .testTarget(
            name: "OstMacMCPTests",
            dependencies: ["OstMacMCP", "OstMacCore", "COstMac"],
            swiftSettings: v5,
            linkerSettings: rustLink
        ),
        // Pure-logic UI tests only (UI-SPEC §11.1).
        .testTarget(
            name: "BetterTeamsUITests",
            dependencies: ["BetterTeamsUI", "OstMacCore", "COstMac"],
            swiftSettings: v5,
            linkerSettings: rustLink
        ),
    ]
)
