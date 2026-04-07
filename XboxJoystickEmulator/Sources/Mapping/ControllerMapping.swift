// Xbox Joystick Emulator - Personal Use Only
// Controller Mapping - Maps generic controller inputs to Xbox controller layout

import Foundation
import XboxJoystickCore

// MARK: - Button Mapping

/// Maps a generic button index to an Xbox button
public struct ButtonMapping: Codable, Identifiable, Hashable {
    public let id: UUID
    public var sourceButton: Int
    public var targetButton: XboxButton
    public var isEnabled: Bool

    public init(sourceButton: Int, targetButton: XboxButton, isEnabled: Bool = true) {
        self.id = UUID()
        self.sourceButton = sourceButton
        self.targetButton = targetButton
        self.isEnabled = isEnabled
    }
}

// MARK: - Axis Mapping

/// Maps a generic axis to an Xbox axis with additional configuration
public struct AxisMapping: Codable, Identifiable, Hashable {
    public let id: UUID
    public var sourceAxis: Int
    public var targetAxis: XboxAxis
    public var isInverted: Bool
    public var deadzone: Float
    public var sensitivity: Float
    public var isEnabled: Bool

    public init(
        sourceAxis: Int,
        targetAxis: XboxAxis,
        isInverted: Bool = false,
        deadzone: Float = 0.1,
        sensitivity: Float = 1.0,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.sourceAxis = sourceAxis
        self.targetAxis = targetAxis
        self.isInverted = isInverted
        self.deadzone = deadzone
        self.sensitivity = sensitivity
        self.isEnabled = isEnabled
    }

    /// Apply deadzone and sensitivity to a value
    public func applyTransform(_ value: Float) -> Float {
        var result = value

        // Apply inversion
        if isInverted {
            result = -result
        }

        // Apply deadzone
        if abs(result) < deadzone {
            return 0.0
        }

        // Rescale after deadzone
        let sign: Float = result >= 0 ? 1 : -1
        result = sign * ((abs(result) - deadzone) / (1.0 - deadzone))

        // Apply sensitivity
        result *= sensitivity

        // Clamp to valid range
        return result.clamped(to: targetAxis.range)
    }
}

// MARK: - Controller Profile

/// A complete mapping profile for a controller
public struct ControllerProfile: Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var controllerVendorProduct: String  // "VendorID:ProductID" for matching
    public var buttonMappings: [ButtonMapping]
    public var axisMappings: [AxisMapping]
    public var isDefault: Bool
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        name: String,
        controllerVendorProduct: String = "",
        buttonMappings: [ButtonMapping] = [],
        axisMappings: [AxisMapping] = [],
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.controllerVendorProduct = controllerVendorProduct
        self.buttonMappings = buttonMappings
        self.axisMappings = axisMappings
        self.isDefault = isDefault
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Create a default Xbox-compatible mapping
    public static func createDefaultXboxMapping() -> ControllerProfile {
        var profile = ControllerProfile(
            name: "Default Xbox Mapping",
            isDefault: true
        )

        // Standard button mappings (assuming common layout)
        profile.buttonMappings = [
            ButtonMapping(sourceButton: 0, targetButton: .a),
            ButtonMapping(sourceButton: 1, targetButton: .b),
            ButtonMapping(sourceButton: 2, targetButton: .x),
            ButtonMapping(sourceButton: 3, targetButton: .y),
            ButtonMapping(sourceButton: 4, targetButton: .leftBumper),
            ButtonMapping(sourceButton: 5, targetButton: .rightBumper),
            ButtonMapping(sourceButton: 6, targetButton: .leftTrigger),
            ButtonMapping(sourceButton: 7, targetButton: .rightTrigger),
            ButtonMapping(sourceButton: 8, targetButton: .leftStickClick),
            ButtonMapping(sourceButton: 9, targetButton: .rightStickClick),
            ButtonMapping(sourceButton: 10, targetButton: .start),
            ButtonMapping(sourceButton: 11, targetButton: .back),
            ButtonMapping(sourceButton: 12, targetButton: .dpadUp),
            ButtonMapping(sourceButton: 13, targetButton: .dpadDown),
            ButtonMapping(sourceButton: 14, targetButton: .dpadLeft),
            ButtonMapping(sourceButton: 15, targetButton: .dpadRight),
            ButtonMapping(sourceButton: 16, targetButton: .guide),
        ]

        // Standard axis mappings
        profile.axisMappings = [
            AxisMapping(sourceAxis: 0, targetAxis: .leftStickX),
            AxisMapping(sourceAxis: 1, targetAxis: .leftStickY),
            AxisMapping(sourceAxis: 2, targetAxis: .rightStickX),
            AxisMapping(sourceAxis: 3, targetAxis: .rightStickY),
            AxisMapping(sourceAxis: 4, targetAxis: .leftTrigger),
            AxisMapping(sourceAxis: 5, targetAxis: .rightTrigger),
        ]

        return profile
    }

    /// Create a PlayStation-style controller mapping
    public static func createPlayStationMapping() -> ControllerProfile {
        var profile = ControllerProfile(
            name: "PlayStation Controller",
            isDefault: false
        )

        // PS to Xbox button mapping
        // Cross -> A, Circle -> B, Square -> X, Triangle -> Y
        profile.buttonMappings = [
            ButtonMapping(sourceButton: 0, targetButton: .a),      // Cross
            ButtonMapping(sourceButton: 1, targetButton: .b),      // Circle
            ButtonMapping(sourceButton: 2, targetButton: .x),      // Square
            ButtonMapping(sourceButton: 3, targetButton: .y),      // Triangle
            ButtonMapping(sourceButton: 4, targetButton: .leftBumper),   // L1
            ButtonMapping(sourceButton: 5, targetButton: .rightBumper),  // R1
            ButtonMapping(sourceButton: 6, targetButton: .leftTrigger),  // L2 (digital)
            ButtonMapping(sourceButton: 7, targetButton: .rightTrigger), // R2 (digital)
            ButtonMapping(sourceButton: 8, targetButton: .back),         // Share/Select
            ButtonMapping(sourceButton: 9, targetButton: .start),        // Options/Start
            ButtonMapping(sourceButton: 10, targetButton: .leftStickClick),  // L3
            ButtonMapping(sourceButton: 11, targetButton: .rightStickClick), // R3
            ButtonMapping(sourceButton: 12, targetButton: .guide),       // PS Button
            ButtonMapping(sourceButton: 13, targetButton: .dpadUp),
            ButtonMapping(sourceButton: 14, targetButton: .dpadDown),
            ButtonMapping(sourceButton: 15, targetButton: .dpadLeft),
            ButtonMapping(sourceButton: 16, targetButton: .dpadRight),
        ]

        profile.axisMappings = [
            AxisMapping(sourceAxis: 0, targetAxis: .leftStickX),
            AxisMapping(sourceAxis: 1, targetAxis: .leftStickY, isInverted: true),  // PS Y-axis often inverted
            AxisMapping(sourceAxis: 2, targetAxis: .rightStickX),
            AxisMapping(sourceAxis: 3, targetAxis: .rightStickY, isInverted: true),
            AxisMapping(sourceAxis: 4, targetAxis: .leftTrigger),
            AxisMapping(sourceAxis: 5, targetAxis: .rightTrigger),
        ]

        return profile
    }

    /// Create a Nintendo Switch Pro controller mapping
    public static func createSwitchProMapping() -> ControllerProfile {
        var profile = ControllerProfile(
            name: "Nintendo Switch Pro Controller",
            isDefault: false
        )

        // Switch Pro to Xbox mapping
        // B -> A, A -> B, Y -> X, X -> Y (Nintendo layout swap)
        profile.buttonMappings = [
            ButtonMapping(sourceButton: 0, targetButton: .b),  // B (Nintendo) -> B (Xbox)
            ButtonMapping(sourceButton: 1, targetButton: .a),  // A (Nintendo) -> A (Xbox)
            ButtonMapping(sourceButton: 2, targetButton: .y),  // Y (Nintendo) -> Y (Xbox)
            ButtonMapping(sourceButton: 3, targetButton: .x),  // X (Nintendo) -> X (Xbox)
            ButtonMapping(sourceButton: 4, targetButton: .leftBumper),
            ButtonMapping(sourceButton: 5, targetButton: .rightBumper),
            ButtonMapping(sourceButton: 6, targetButton: .leftTrigger),
            ButtonMapping(sourceButton: 7, targetButton: .rightTrigger),
            ButtonMapping(sourceButton: 8, targetButton: .back),    // Minus
            ButtonMapping(sourceButton: 9, targetButton: .start),   // Plus
            ButtonMapping(sourceButton: 10, targetButton: .leftStickClick),
            ButtonMapping(sourceButton: 11, targetButton: .rightStickClick),
            ButtonMapping(sourceButton: 12, targetButton: .guide),  // Home
            ButtonMapping(sourceButton: 13, targetButton: .dpadUp),
            ButtonMapping(sourceButton: 14, targetButton: .dpadDown),
            ButtonMapping(sourceButton: 15, targetButton: .dpadLeft),
            ButtonMapping(sourceButton: 16, targetButton: .dpadRight),
        ]

        profile.axisMappings = [
            AxisMapping(sourceAxis: 0, targetAxis: .leftStickX),
            AxisMapping(sourceAxis: 1, targetAxis: .leftStickY),
            AxisMapping(sourceAxis: 2, targetAxis: .rightStickX),
            AxisMapping(sourceAxis: 3, targetAxis: .rightStickY),
            AxisMapping(sourceAxis: 4, targetAxis: .leftTrigger),
            AxisMapping(sourceAxis: 5, targetAxis: .rightTrigger),
        ]

        return profile
    }

    public mutating func updateModifiedDate() {
        modifiedAt = Date()
    }
}

// MARK: - Mapping Provider Implementation

/// Provides mapping lookup for a given profile
public class ProfileMappingProvider: MappingProvider {
    private let profile: ControllerProfile
    private var buttonLookup: [Int: XboxButton] = [:]
    private var axisLookup: [Int: AxisMapping] = [:]

    public init(profile: ControllerProfile) {
        self.profile = profile
        buildLookupTables()
    }

    private func buildLookupTables() {
        for mapping in profile.buttonMappings where mapping.isEnabled {
            buttonLookup[mapping.sourceButton] = mapping.targetButton
        }

        for mapping in profile.axisMappings where mapping.isEnabled {
            axisLookup[mapping.sourceAxis] = mapping
        }
    }

    public func mapButton(genericIndex: Int) -> XboxButton? {
        return buttonLookup[genericIndex]
    }

    public func mapAxis(genericIndex: Int) -> XboxAxis? {
        return axisLookup[genericIndex]?.targetAxis
    }

    public func getAxisInversion(genericIndex: Int) -> Bool {
        return axisLookup[genericIndex]?.isInverted ?? false
    }

    public func getAxisDeadzone(genericIndex: Int) -> Float {
        return axisLookup[genericIndex]?.deadzone ?? 0.1
    }

    public func getAxisSensitivity(genericIndex: Int) -> Float {
        return axisLookup[genericIndex]?.sensitivity ?? 1.0
    }

    /// Transform an axis value using the mapping configuration
    public func transformAxisValue(genericIndex: Int, value: Float) -> Float {
        guard let mapping = axisLookup[genericIndex] else {
            return value
        }
        return mapping.applyTransform(value)
    }
}
