# Xbox Joystick Emulator for macOS

**Personal Use Only - Not for Commercial Purposes**

A native macOS application that remaps wireless joystick/gamepad controllers to Xbox controller configuration. Perfect for using third-party controllers with games that only support Xbox controller input.

## Features

- **Universal Controller Support**: Automatically detects USB and Bluetooth game controllers
- **Xbox Button Mapping**: Remap any controller's buttons to standard Xbox layout
- **Analog Stick Configuration**: Adjust deadzone, sensitivity, and axis inversion
- **Multiple Profiles**: Create and save different mapping profiles for different controllers
- **Preset Mappings**: Built-in profiles for PlayStation and Nintendo Switch controllers
- **Real-time Visualization**: See your controller input in real-time with visual feedback
- **Multiple Emulation Modes**:
  - Passthrough: Direct state mapping for applications that read controller state
  - Keyboard: Translate controller input to keyboard events
  - Virtual Controller: Create a virtual Xbox controller device (requires additional driver)

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building)
- Swift 5.9+

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone <repository-url>
cd XboxJoystickEmulator
```

2. Build using Swift Package Manager:
```bash
swift build -c release
```

3. Run the application:
```bash
swift run XboxJoystickEmulator
```

### Building with Xcode

1. Open the package in Xcode:
```bash
open Package.swift
```

2. Select the `XboxJoystickEmulator` scheme and build (⌘B)

3. Run the application (⌘R)

## Usage

### Connecting Controllers

1. Launch the application
2. Navigate to the **Controllers** tab
3. Connect your wireless controller via Bluetooth or USB
4. Click **Start Scanning** if your controller isn't automatically detected
5. Your controller should appear in the list

### Setting Up Mappings

1. Navigate to the **Mapping** tab
2. Select an existing profile or create a new one
3. Click the **Edit** button (pencil icon) to modify mappings

#### Button Mapping
- Select the source button from your controller
- Choose the target Xbox button
- Enable/disable individual mappings as needed

#### Axis Mapping
- Map analog sticks and triggers to Xbox equivalents
- Adjust **Deadzone** to eliminate stick drift (0.1 recommended)
- Adjust **Sensitivity** to make sticks more or less responsive
- Toggle **Inverted** if your Y-axis is reversed

### Using the Emulator

1. Navigate to the **Emulator** tab
2. Select your preferred **Emulation Mode**:
   - **Passthrough**: For applications that poll controller state directly
   - **Keyboard**: Translates controller input to keyboard keys
   - **Virtual Controller**: Creates a virtual Xbox device (requires driver)
3. Click **Start** to begin emulation
4. The controller visualization shows your input in real-time

### Built-in Profiles

The application includes preset profiles for common controllers:

- **Default Xbox Mapping**: Standard 1:1 mapping for Xbox-compatible controllers
- **PlayStation Controller**: Maps DualShock/DualSense buttons to Xbox equivalents
- **Nintendo Switch Pro Controller**: Maps Switch buttons with Nintendo button swap (A↔B, X↔Y)

## Emulation Modes

### Passthrough Mode
The simplest mode - reads controller input and translates it to Xbox controller state. Applications that directly poll `XboxEmulator.shared.currentState` can use this data.

### Keyboard Mode
Translates controller input to keyboard events. Useful for games that don't support controllers.

Default keyboard mappings:
| Xbox Button | Keyboard Key |
|-------------|-------------|
| A | A |
| B | B |
| X | X |
| Y | Y |
| LB | Q |
| RB | E |
| Start | Return |
| Back | Escape |
| D-Pad | Arrow Keys |
| Left Stick | WASD |
| Right Stick | Arrow Keys |

### Virtual Controller Mode
Creates a virtual Xbox controller device. Requires a virtual HID driver such as:
- [foohid](https://github.com/unbit/foohid) (legacy)
- [Karabiner DriverKit](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice)

## Permissions

The application requires certain macOS permissions:

### Input Monitoring
Required to read game controller input.
- Go to **System Preferences** → **Security & Privacy** → **Privacy** → **Input Monitoring**
- Add the Xbox Joystick Emulator application

### Accessibility (for Keyboard Mode)
Required to send keyboard events.
- Go to **System Preferences** → **Security & Privacy** → **Privacy** → **Accessibility**
- Add the Xbox Joystick Emulator application

## Project Structure

```
XboxJoystickEmulator/
├── Package.swift              # Swift Package configuration
├── README.md                  # This file
├── Sources/
│   ├── Core/
│   │   ├── XboxControllerTypes.swift    # Xbox button/axis definitions
│   │   └── ControllerProtocols.swift    # Protocols and event handling
│   ├── Controllers/
│   │   ├── HIDControllerManager.swift   # HID device detection
│   │   └── XboxEmulator.swift           # Main emulation logic
│   ├── Mapping/
│   │   ├── ControllerMapping.swift      # Button/axis mapping types
│   │   └── MappingManager.swift         # Profile management
│   ├── UI/
│   │   └── ContentView.swift            # SwiftUI interface
│   └── App/
│       └── XboxJoystickEmulatorApp.swift # App entry point
└── Resources/
```

## API Usage (for Developers)

If you want to integrate the emulator into your own project:

```swift
import XboxJoystickCore

// Start the controller manager
let manager = HIDControllerManager.shared
manager.startScanning()

// Set up the emulator
let emulator = XboxEmulator.shared
emulator.start()

// Read the current Xbox controller state
let state = emulator.currentState
let isAPressed = state.isPressed(.a)
let leftStickX = state.axisValue(.leftStickX)

// Create custom mappings
let profile = ControllerProfile(name: "My Custom Profile")
// ... add button and axis mappings
MappingManager.shared.addProfile(profile)
MappingManager.shared.setActiveProfile(profile)
```

## Troubleshooting

### Controller Not Detected
1. Ensure the controller is in pairing mode
2. Check Bluetooth connection in System Preferences
3. Try clicking "Refresh" in the Controllers tab
4. Grant Input Monitoring permission

### Keyboard Emulation Not Working
1. Grant Accessibility permission
2. Restart the application after granting permission
3. Check that the emulator is in "Keyboard" mode

### High Latency
1. Increase the polling rate in Settings
2. Use USB connection instead of Bluetooth
3. Close other applications using the controller

## License

This software is provided for **PERSONAL USE ONLY**. It is not intended for commercial purposes. By using this software, you agree to use it solely for personal, non-commercial gaming and development purposes.

## Disclaimer

This project is not affiliated with, endorsed by, or connected to Microsoft Corporation or Xbox. "Xbox" is a registered trademark of Microsoft Corporation.

## Contributing

This is a personal project. Feel free to fork and modify for your own use.

## Acknowledgments

- Apple's [GameController Framework](https://developer.apple.com/documentation/gamecontroller)
- IOKit HID Manager documentation
- The macOS gaming community
