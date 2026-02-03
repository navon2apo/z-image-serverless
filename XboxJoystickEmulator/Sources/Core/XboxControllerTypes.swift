// Xbox Joystick Emulator - Personal Use Only
// Core types representing Xbox controller layout and inputs

import Foundation

// MARK: - Xbox Controller Button Layout

/// Standard Xbox controller buttons
public enum XboxButton: String, CaseIterable, Codable, Hashable {
    case a = "A"
    case b = "B"
    case x = "X"
    case y = "Y"
    case leftBumper = "LB"
    case rightBumper = "RB"
    case leftTrigger = "LT"
    case rightTrigger = "RT"
    case leftStickClick = "LS"
    case rightStickClick = "RS"
    case start = "Start"
    case back = "Back"  // Also known as "View" on newer controllers
    case guide = "Guide"  // Xbox button
    case dpadUp = "DPad Up"
    case dpadDown = "DPad Down"
    case dpadLeft = "DPad Left"
    case dpadRight = "DPad Right"

    public var displayName: String {
        return rawValue
    }

    public var keyCode: Int {
        switch self {
        case .a: return 0x00
        case .b: return 0x01
        case .x: return 0x02
        case .y: return 0x03
        case .leftBumper: return 0x04
        case .rightBumper: return 0x05
        case .leftTrigger: return 0x06
        case .rightTrigger: return 0x07
        case .leftStickClick: return 0x08
        case .rightStickClick: return 0x09
        case .start: return 0x0A
        case .back: return 0x0B
        case .guide: return 0x0C
        case .dpadUp: return 0x0D
        case .dpadDown: return 0x0E
        case .dpadLeft: return 0x0F
        case .dpadRight: return 0x10
        }
    }
}

/// Xbox controller analog axes
public enum XboxAxis: String, CaseIterable, Codable, Hashable {
    case leftStickX = "Left Stick X"
    case leftStickY = "Left Stick Y"
    case rightStickX = "Right Stick X"
    case rightStickY = "Right Stick Y"
    case leftTrigger = "Left Trigger"
    case rightTrigger = "Right Trigger"

    public var displayName: String {
        return rawValue
    }

    /// Value range for this axis (-1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers)
    public var range: ClosedRange<Float> {
        switch self {
        case .leftTrigger, .rightTrigger:
            return 0.0...1.0
        default:
            return -1.0...1.0
        }
    }
}

// MARK: - Controller State

/// Complete state of an Xbox-style controller
public struct XboxControllerState: Codable, Equatable {
    public var buttons: [XboxButton: Bool]
    public var axes: [XboxAxis: Float]

    public init() {
        buttons = Dictionary(uniqueKeysWithValues: XboxButton.allCases.map { ($0, false) })
        axes = Dictionary(uniqueKeysWithValues: XboxAxis.allCases.map { ($0, 0.0) })
    }

    public mutating func setButton(_ button: XboxButton, pressed: Bool) {
        buttons[button] = pressed
    }

    public mutating func setAxis(_ axis: XboxAxis, value: Float) {
        axes[axis] = value.clamped(to: axis.range)
    }

    public func isPressed(_ button: XboxButton) -> Bool {
        return buttons[button] ?? false
    }

    public func axisValue(_ axis: XboxAxis) -> Float {
        return axes[axis] ?? 0.0
    }
}

// MARK: - Generic Controller Input

/// Represents a generic button input from any controller
public struct GenericButtonInput: Codable, Hashable {
    public let index: Int
    public let name: String

    public init(index: Int, name: String = "") {
        self.index = index
        self.name = name.isEmpty ? "Button \(index)" : name
    }
}

/// Represents a generic axis input from any controller
public struct GenericAxisInput: Codable, Hashable {
    public let index: Int
    public let name: String
    public let isInverted: Bool

    public init(index: Int, name: String = "", isInverted: Bool = false) {
        self.index = index
        self.name = name.isEmpty ? "Axis \(index)" : name
        self.isInverted = isInverted
    }
}

/// State of a generic/unknown controller
public struct GenericControllerState {
    public var buttons: [Int: Bool]
    public var axes: [Int: Float]
    public var timestamp: Date

    public init() {
        buttons = [:]
        axes = [:]
        timestamp = Date()
    }
}

// MARK: - Controller Info

/// Information about a connected controller
public struct ControllerInfo: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let vendorID: Int
    public let productID: Int
    public let isWireless: Bool
    public let buttonCount: Int
    public let axisCount: Int

    public init(
        id: String,
        name: String,
        vendorID: Int,
        productID: Int,
        isWireless: Bool,
        buttonCount: Int,
        axisCount: Int
    ) {
        self.id = id
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
        self.isWireless = isWireless
        self.buttonCount = buttonCount
        self.axisCount = axisCount
    }

    public var vendorProductString: String {
        return String(format: "%04X:%04X", vendorID, productID)
    }
}

// MARK: - Utility Extensions

extension Float {
    public func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Double {
    public func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
