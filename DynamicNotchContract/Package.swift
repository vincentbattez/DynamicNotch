// swift-tools-version: 6.0
import PackageDescription

// Pure-Foundation wire contracts shared by the app and the `dynamicnotch` CLI: the
// notification payload, the command payload, the core severity level, inbox/commands-path
// derivation and the atomic drop mechanism. Zero dependencies — no SwiftUI/AppKit — so both
// the GUI app and a command-line binary can link it without dragging in a UI stack.
let package = Package(
    name: "DynamicNotchContract",
    products: [
        .library(name: "DynamicNotchContract", targets: ["DynamicNotchContract"]),
    ],
    targets: [
        .target(name: "DynamicNotchContract"),
        .testTarget(
            name: "DynamicNotchContractTests",
            dependencies: ["DynamicNotchContract"]
        ),
    ]
)
