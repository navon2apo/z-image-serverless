// swift-tools-version:5.9
// Xbox Joystick Emulator - Personal Use Only
// Remaps wireless joystick controllers to Xbox controller configuration

import PackageDescription

let package = Package(
    name: "XboxJoystickEmulator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "XboxJoystickEmulator",
            targets: ["XboxJoystickEmulatorApp"]
        ),
        .library(
            name: "XboxJoystickCore",
            targets: ["XboxJoystickCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "XboxJoystickCore",
            dependencies: [],
            path: "Sources/Core"
        ),
        .target(
            name: "Mapping",
            dependencies: ["XboxJoystickCore"],
            path: "Sources/Mapping"
        ),
        .target(
            name: "Controllers",
            dependencies: ["XboxJoystickCore", "Mapping"],
            path: "Sources/Controllers"
        ),
        .target(
            name: "UI",
            dependencies: ["XboxJoystickCore", "Controllers", "Mapping"],
            path: "Sources/UI"
        ),
        .executableTarget(
            name: "XboxJoystickEmulatorApp",
            dependencies: ["XboxJoystickCore", "Controllers", "Mapping", "UI"],
            path: "Sources/App"
        )
    ]
)
