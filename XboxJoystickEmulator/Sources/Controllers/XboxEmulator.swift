// Xbox Joystick Emulator - Personal Use Only
// Virtual Xbox Controller Emulator - Translates input to Xbox controller format

import Foundation
import XboxJoystickCore
import Mapping

#if canImport(GameController)
import GameController
#endif

// MARK: - Xbox Emulator

/// Main emulator that translates generic controller input to Xbox controller output
public class XboxEmulator: ObservableObject {
    public static let shared = XboxEmulator()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentState: XboxControllerState = XboxControllerState()
    @Published public private(set) var activeControllerId: String?
    @Published public var emulationMode: EmulationMode = .passthrough

    private let controllerManager = HIDControllerManager.shared
    private let mappingManager = MappingManager.shared
    private var mappingProvider: ProfileMappingProvider?
    private var virtualControllerOutput: VirtualControllerOutput?

    private let updateQueue = DispatchQueue(label: "com.xbox-emulator.update-queue")
    private var updateTimer: Timer?

    public enum EmulationMode: String, CaseIterable {
        case passthrough = "Passthrough"    // Direct mapping
        case keyboard = "Keyboard"          // Output as keyboard events
        case virtual = "Virtual Controller" // Create virtual controller device
    }

    private init() {
        setupCallbacks()
    }

    // MARK: - Public API

    /// Start the emulator
    public func start(controllerId: String? = nil) {
        guard !isRunning else { return }

        // Determine which controller to use
        if let id = controllerId {
            activeControllerId = id
        } else if let firstController = controllerManager.connectedControllers.first {
            activeControllerId = firstController.id
        }

        guard activeControllerId != nil else {
            print("No controller connected")
            return
        }

        // Load mapping provider
        mappingProvider = mappingManager.getActiveMappingProvider()

        // Start controller scanning if not already
        controllerManager.startScanning()

        // Set up output based on mode
        setupOutput()

        isRunning = true
        print("Xbox Emulator started")
    }

    /// Stop the emulator
    public func stop() {
        guard isRunning else { return }

        updateTimer?.invalidate()
        updateTimer = nil

        virtualControllerOutput?.disconnect()
        virtualControllerOutput = nil

        isRunning = false
        activeControllerId = nil

        // Reset state
        currentState = XboxControllerState()

        print("Xbox Emulator stopped")
    }

    /// Switch to a different controller
    public func switchController(to controllerId: String) {
        activeControllerId = controllerId
    }

    /// Update the emulation mode
    public func setEmulationMode(_ mode: EmulationMode) {
        let wasRunning = isRunning

        if wasRunning {
            stop()
        }

        emulationMode = mode

        if wasRunning {
            start(controllerId: activeControllerId)
        }
    }

    /// Manually update state (for testing)
    public func setButton(_ button: XboxButton, pressed: Bool) {
        currentState.setButton(button, pressed: pressed)
        outputState()
    }

    /// Manually update axis (for testing)
    public func setAxis(_ axis: XboxAxis, value: Float) {
        currentState.setAxis(axis, value: value)
        outputState()
    }

    // MARK: - Private Setup

    private func setupCallbacks() {
        controllerManager.setButtonChangeCallback { [weak self] controllerId, button, pressed in
            self?.handleButtonChange(controllerId: controllerId, button: button, pressed: pressed)
        }

        controllerManager.setAxisChangeCallback { [weak self] controllerId, axis, value in
            self?.handleAxisChange(controllerId: controllerId, axis: axis, value: value)
        }
    }

    private func setupOutput() {
        switch emulationMode {
        case .passthrough:
            // Direct state updates, no special output setup needed
            break

        case .keyboard:
            virtualControllerOutput = KeyboardOutput()

        case .virtual:
            virtualControllerOutput = VirtualGamepadOutput()
        }

        virtualControllerOutput?.connect()
    }

    // MARK: - Input Handling

    private func handleButtonChange(controllerId: String, button: Int, pressed: Bool) {
        guard isRunning, controllerId == activeControllerId else { return }

        // Map generic button to Xbox button
        if let xboxButton = mappingProvider?.mapButton(genericIndex: button) {
            updateQueue.async { [weak self] in
                self?.currentState.setButton(xboxButton, pressed: pressed)
                DispatchQueue.main.async {
                    self?.outputState()
                }
            }
        }
    }

    private func handleAxisChange(controllerId: String, axis: Int, value: Float) {
        guard isRunning, controllerId == activeControllerId else { return }

        // Map generic axis to Xbox axis with transformations
        if let xboxAxis = mappingProvider?.mapAxis(genericIndex: axis) {
            let transformedValue = mappingProvider?.transformAxisValue(genericIndex: axis, value: value) ?? value

            updateQueue.async { [weak self] in
                self?.currentState.setAxis(xboxAxis, value: transformedValue)
                DispatchQueue.main.async {
                    self?.outputState()
                }
            }
        }
    }

    // MARK: - Output

    private func outputState() {
        virtualControllerOutput?.sendState(currentState)
    }
}

// MARK: - Virtual Controller Output Protocol

protocol VirtualControllerOutput {
    func connect() -> Bool
    func disconnect()
    func sendState(_ state: XboxControllerState)
}

// MARK: - Keyboard Output

/// Outputs Xbox controller state as keyboard events
class KeyboardOutput: VirtualControllerOutput {
    private var keyMappings: [XboxButton: UInt16] = [:]
    private var pressedKeys: Set<UInt16> = []

    init() {
        setupDefaultKeyMappings()
    }

    private func setupDefaultKeyMappings() {
        // Default keyboard mappings (using macOS virtual key codes)
        keyMappings = [
            .a: 0x00,           // A key
            .b: 0x0B,           // B key
            .x: 0x07,           // X key
            .y: 0x10,           // Y key
            .leftBumper: 0x0C,  // Q key
            .rightBumper: 0x0E, // E key
            .start: 0x24,       // Return key
            .back: 0x35,        // Escape key
            .dpadUp: 0x7E,      // Up arrow
            .dpadDown: 0x7D,    // Down arrow
            .dpadLeft: 0x7B,    // Left arrow
            .dpadRight: 0x7C,   // Right arrow
            .leftStickClick: 0x38,  // Shift
            .rightStickClick: 0x3B, // Control
        ]
    }

    func connect() -> Bool {
        return true
    }

    func disconnect() {
        // Release all pressed keys
        for keyCode in pressedKeys {
            postKeyEvent(keyCode: keyCode, keyDown: false)
        }
        pressedKeys.removeAll()
    }

    func sendState(_ state: XboxControllerState) {
        // Handle button presses
        for (button, keyCode) in keyMappings {
            let isPressed = state.isPressed(button)
            let wasPressed = pressedKeys.contains(keyCode)

            if isPressed && !wasPressed {
                postKeyEvent(keyCode: keyCode, keyDown: true)
                pressedKeys.insert(keyCode)
            } else if !isPressed && wasPressed {
                postKeyEvent(keyCode: keyCode, keyDown: false)
                pressedKeys.remove(keyCode)
            }
        }

        // Handle analog sticks as WASD (for left stick) and arrow keys (for right stick)
        handleAnalogAsKeys(state: state)
    }

    private func handleAnalogAsKeys(state: XboxControllerState) {
        let threshold: Float = 0.5

        // Left stick -> WASD
        let leftX = state.axisValue(.leftStickX)
        let leftY = state.axisValue(.leftStickY)

        updateKeyFromAxis(value: leftX, positive: 0x02 /* D */, negative: 0x00 /* A */, threshold: threshold)
        updateKeyFromAxis(value: leftY, positive: 0x0D /* W */, negative: 0x01 /* S */, threshold: threshold)

        // Right stick -> Arrow keys
        let rightX = state.axisValue(.rightStickX)
        let rightY = state.axisValue(.rightStickY)

        updateKeyFromAxis(value: rightX, positive: 0x7C, negative: 0x7B, threshold: threshold)
        updateKeyFromAxis(value: rightY, positive: 0x7E, negative: 0x7D, threshold: threshold)
    }

    private func updateKeyFromAxis(value: Float, positive: UInt16, negative: UInt16, threshold: Float) {
        let positivePressed = value > threshold
        let negativePressed = value < -threshold

        let posWasPressed = pressedKeys.contains(positive)
        let negWasPressed = pressedKeys.contains(negative)

        if positivePressed && !posWasPressed {
            postKeyEvent(keyCode: positive, keyDown: true)
            pressedKeys.insert(positive)
        } else if !positivePressed && posWasPressed {
            postKeyEvent(keyCode: positive, keyDown: false)
            pressedKeys.remove(positive)
        }

        if negativePressed && !negWasPressed {
            postKeyEvent(keyCode: negative, keyDown: true)
            pressedKeys.insert(negative)
        } else if !negativePressed && negWasPressed {
            postKeyEvent(keyCode: negative, keyDown: false)
            pressedKeys.remove(negative)
        }
    }

    private func postKeyEvent(keyCode: UInt16, keyDown: Bool) {
        #if os(macOS)
        // Note: This requires Accessibility permissions on macOS
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
        event?.post(tap: .cghidEventTap)
        #endif
    }
}

// MARK: - Virtual Gamepad Output

/// Creates a virtual gamepad device (placeholder - requires driver)
class VirtualGamepadOutput: VirtualControllerOutput {
    private var isConnected = false

    func connect() -> Bool {
        // Note: Creating a true virtual gamepad on macOS requires a kernel extension
        // or using a tool like foohid/karabiner
        // This is a placeholder that logs state changes
        print("Virtual Gamepad connected (simulation mode)")
        isConnected = true
        return true
    }

    func disconnect() {
        print("Virtual Gamepad disconnected")
        isConnected = false
    }

    func sendState(_ state: XboxControllerState) {
        guard isConnected else { return }

        // In a real implementation, this would send the state to a virtual driver
        // For now, we just update the shared state
        // Applications can poll XboxEmulator.shared.currentState
    }
}

// MARK: - State Observer

/// Observer class for monitoring Xbox emulator state changes
public class XboxStateObserver: ObservableObject {
    @Published public var state: XboxControllerState = XboxControllerState()

    private var timer: Timer?

    public init() {}

    public func startObserving(interval: TimeInterval = 1.0/60.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.state = XboxEmulator.shared.currentState
        }
    }

    public func stopObserving() {
        timer?.invalidate()
        timer = nil
    }
}
