// Xbox Joystick Emulator - Personal Use Only
// HID Controller Manager - Detects and manages connected game controllers

import Foundation
import IOKit
import IOKit.hid
import XboxJoystickCore

#if canImport(GameController)
import GameController
#endif

// MARK: - HID Controller Manager

/// Manages detection and input from HID game controllers
public class HIDControllerManager: ObservableObject {
    public static let shared = HIDControllerManager()

    @Published public private(set) var connectedControllers: [ControllerInfo] = []
    @Published public private(set) var isScanning: Bool = false

    private var hidManager: IOHIDManager?
    private var controllerStates: [String: GenericControllerState] = [:]
    private var eventPublisher = ControllerEventPublisher()
    private let queue = DispatchQueue(label: "com.xbox-emulator.hid-manager")

    // Callback closures for HID events
    private var onButtonChange: ((String, Int, Bool) -> Void)?
    private var onAxisChange: ((String, Int, Float) -> Void)?

    private init() {}

    // MARK: - Public API

    /// Start scanning for controllers
    public func startScanning() {
        queue.async { [weak self] in
            self?.setupHIDManager()
            self?.setupGameControllerNotifications()
        }

        DispatchQueue.main.async {
            self.isScanning = true
        }
    }

    /// Stop scanning for controllers
    public func stopScanning() {
        queue.async { [weak self] in
            self?.teardownHIDManager()
        }

        DispatchQueue.main.async {
            self.isScanning = false
        }
    }

    /// Add event delegate
    public func addDelegate(_ delegate: ControllerEventDelegate) {
        eventPublisher.addDelegate(delegate)
    }

    /// Set callback for button changes
    public func setButtonChangeCallback(_ callback: @escaping (String, Int, Bool) -> Void) {
        onButtonChange = callback
    }

    /// Set callback for axis changes
    public func setAxisChangeCallback(_ callback: @escaping (String, Int, Float) -> Void) {
        onAxisChange = callback
    }

    /// Get current state for a controller
    public func getControllerState(id: String) -> GenericControllerState? {
        return controllerStates[id]
    }

    /// Manually refresh controller list
    public func refreshControllers() {
        #if canImport(GameController)
        scanGameControllers()
        #endif
        scanHIDDevices()
    }

    // MARK: - HID Setup

    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        guard let manager = hidManager else {
            print("Failed to create HID Manager")
            return
        }

        // Set up matching dictionaries for game controllers
        let matchingDictionaries = createMatchingDictionaries()

        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDictionaries as CFArray)

        // Set up callbacks
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let manager = Unmanaged<HIDControllerManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleDeviceConnected(device)
        }, context)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let manager = Unmanaged<HIDControllerManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleDeviceDisconnected(device)
        }, context)

        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            guard let context = context else { return }
            let manager = Unmanaged<HIDControllerManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleInputValue(value)
        }, context)

        // Schedule with run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // Open the manager
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("Failed to open HID Manager: \(openResult)")
        }
    }

    private func teardownHIDManager() {
        guard let manager = hidManager else { return }

        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = nil
    }

    private func createMatchingDictionaries() -> [NSDictionary] {
        // Game pad
        let gamePadDict: NSDictionary = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_GamePad
        ]

        // Joystick
        let joystickDict: NSDictionary = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Joystick
        ]

        // Multi-axis controller
        let multiAxisDict: NSDictionary = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_MultiAxisController
        ]

        return [gamePadDict, joystickDict, multiAxisDict]
    }

    // MARK: - GameController Framework

    #if canImport(GameController)
    private func setupGameControllerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gameControllerConnected),
            name: .GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gameControllerDisconnected),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Scan for existing controllers
        scanGameControllers()
    }

    @objc private func gameControllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        registerGameController(controller)
    }

    @objc private func gameControllerDisconnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        unregisterGameController(controller)
    }

    private func scanGameControllers() {
        GCController.startWirelessControllerDiscovery { }

        for controller in GCController.controllers() {
            registerGameController(controller)
        }
    }

    private func registerGameController(_ controller: GCController) {
        let info = createControllerInfo(from: controller)

        DispatchQueue.main.async {
            if !self.connectedControllers.contains(where: { $0.id == info.id }) {
                self.connectedControllers.append(info)
                self.controllerStates[info.id] = GenericControllerState()
                self.eventPublisher.publish(.connected(info))
            }
        }

        // Set up input handlers
        setupGameControllerHandlers(controller, info: info)
    }

    private func unregisterGameController(_ controller: GCController) {
        let controllerId = controller.vendorName ?? "Unknown-\(ObjectIdentifier(controller).hashValue)"

        DispatchQueue.main.async {
            if let index = self.connectedControllers.firstIndex(where: { $0.id == controllerId }) {
                let info = self.connectedControllers[index]
                self.connectedControllers.remove(at: index)
                self.controllerStates.removeValue(forKey: controllerId)
                self.eventPublisher.publish(.disconnected(info))
            }
        }
    }

    private func createControllerInfo(from controller: GCController) -> ControllerInfo {
        let id = controller.vendorName ?? "Unknown-\(ObjectIdentifier(controller).hashValue)"

        var buttonCount = 0
        var axisCount = 0

        if let gamepad = controller.extendedGamepad {
            buttonCount = 17 // Standard extended gamepad buttons
            axisCount = 6   // 2 sticks (4 axes) + 2 triggers
            _ = gamepad // Silence unused warning
        } else if let gamepad = controller.microGamepad {
            buttonCount = 4
            axisCount = 2
            _ = gamepad
        }

        return ControllerInfo(
            id: id,
            name: controller.vendorName ?? "Unknown Controller",
            vendorID: 0,
            productID: 0,
            isWireless: !controller.isAttachedToDevice,
            buttonCount: buttonCount,
            axisCount: axisCount
        )
    }

    private func setupGameControllerHandlers(_ controller: GCController, info: ControllerInfo) {
        guard let gamepad = controller.extendedGamepad else { return }

        // Button handlers
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 0, pressed: pressed)
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 1, pressed: pressed)
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 2, pressed: pressed)
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 3, pressed: pressed)
        }
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 4, pressed: pressed)
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 5, pressed: pressed)
        }
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 6, pressed: pressed)
        }
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 7, pressed: pressed)
        }

        // D-Pad
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 12, pressed: pressed)
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 13, pressed: pressed)
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 14, pressed: pressed)
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 15, pressed: pressed)
        }

        // Thumbstick clicks
        if let leftThumbstickButton = gamepad.leftThumbstickButton {
            leftThumbstickButton.pressedChangedHandler = { [weak self] _, _, pressed in
                self?.handleButtonInput(controllerId: info.id, buttonIndex: 8, pressed: pressed)
            }
        }
        if let rightThumbstickButton = gamepad.rightThumbstickButton {
            rightThumbstickButton.pressedChangedHandler = { [weak self] _, _, pressed in
                self?.handleButtonInput(controllerId: info.id, buttonIndex: 9, pressed: pressed)
            }
        }

        // Menu buttons
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 10, pressed: pressed)
        }
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonInput(controllerId: info.id, buttonIndex: 11, pressed: pressed)
        }

        // Axis handlers
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleAxisInput(controllerId: info.id, axisIndex: 0, value: xValue)
            self?.handleAxisInput(controllerId: info.id, axisIndex: 1, value: yValue)
        }
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleAxisInput(controllerId: info.id, axisIndex: 2, value: xValue)
            self?.handleAxisInput(controllerId: info.id, axisIndex: 3, value: yValue)
        }
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.handleAxisInput(controllerId: info.id, axisIndex: 4, value: value)
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.handleAxisInput(controllerId: info.id, axisIndex: 5, value: value)
        }
    }
    #else
    private func setupGameControllerNotifications() {
        // GameController framework not available
    }
    #endif

    // MARK: - HID Device Handling

    private func scanHIDDevices() {
        // HID devices are automatically detected through the callback system
    }

    private func handleDeviceConnected(_ device: IOHIDDevice) {
        let info = createControllerInfo(from: device)

        DispatchQueue.main.async {
            if !self.connectedControllers.contains(where: { $0.id == info.id }) {
                self.connectedControllers.append(info)
                self.controllerStates[info.id] = GenericControllerState()
                self.eventPublisher.publish(.connected(info))
            }
        }
    }

    private func handleDeviceDisconnected(_ device: IOHIDDevice) {
        let deviceId = getDeviceId(device)

        DispatchQueue.main.async {
            if let index = self.connectedControllers.firstIndex(where: { $0.id == deviceId }) {
                let info = self.connectedControllers[index]
                self.connectedControllers.remove(at: index)
                self.controllerStates.removeValue(forKey: deviceId)
                self.eventPublisher.publish(.disconnected(info))
            }
        }
    }

    private func handleInputValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let deviceId = getDeviceId(device)

        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)

        // Determine if this is a button or axis
        if usagePage == kHIDPage_Button {
            let buttonIndex = Int(usage) - 1
            let pressed = intValue != 0
            handleButtonInput(controllerId: deviceId, buttonIndex: buttonIndex, pressed: pressed)
        } else if usagePage == kHIDPage_GenericDesktop {
            let axisIndex = mapUsageToAxisIndex(usage)
            if axisIndex >= 0 {
                let normalizedValue = normalizeAxisValue(element: element, rawValue: intValue)
                handleAxisInput(controllerId: deviceId, axisIndex: axisIndex, value: normalizedValue)
            }
        }
    }

    private func createControllerInfo(from device: IOHIDDevice) -> ControllerInfo {
        let deviceId = getDeviceId(device)
        let name = getDeviceProperty(device, key: kIOHIDProductKey) as? String ?? "Unknown Controller"
        let vendorID = getDeviceProperty(device, key: kIOHIDVendorIDKey) as? Int ?? 0
        let productID = getDeviceProperty(device, key: kIOHIDProductIDKey) as? Int ?? 0
        let transport = getDeviceProperty(device, key: kIOHIDTransportKey) as? String ?? ""

        let isWireless = transport.lowercased().contains("bluetooth") ||
                        transport.lowercased().contains("wireless")

        // Count buttons and axes
        var buttonCount = 0
        var axisCount = 0

        if let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] {
            for element in elements {
                let usagePage = IOHIDElementGetUsagePage(element)
                if usagePage == kHIDPage_Button {
                    buttonCount += 1
                } else if usagePage == kHIDPage_GenericDesktop {
                    let usage = IOHIDElementGetUsage(element)
                    if usage >= kHIDUsage_GD_X && usage <= kHIDUsage_GD_Rz {
                        axisCount += 1
                    }
                }
            }
        }

        return ControllerInfo(
            id: deviceId,
            name: name,
            vendorID: vendorID,
            productID: productID,
            isWireless: isWireless,
            buttonCount: buttonCount,
            axisCount: axisCount
        )
    }

    private func getDeviceId(_ device: IOHIDDevice) -> String {
        let vendorID = getDeviceProperty(device, key: kIOHIDVendorIDKey) as? Int ?? 0
        let productID = getDeviceProperty(device, key: kIOHIDProductIDKey) as? Int ?? 0
        let locationID = getDeviceProperty(device, key: kIOHIDLocationIDKey) as? Int ?? 0
        return "\(vendorID):\(productID):\(locationID)"
    }

    private func getDeviceProperty(_ device: IOHIDDevice, key: String) -> Any? {
        return IOHIDDeviceGetProperty(device, key as CFString)
    }

    private func mapUsageToAxisIndex(_ usage: UInt32) -> Int {
        switch usage {
        case UInt32(kHIDUsage_GD_X): return 0
        case UInt32(kHIDUsage_GD_Y): return 1
        case UInt32(kHIDUsage_GD_Z): return 2
        case UInt32(kHIDUsage_GD_Rx): return 3
        case UInt32(kHIDUsage_GD_Ry): return 4
        case UInt32(kHIDUsage_GD_Rz): return 5
        default: return -1
        }
    }

    private func normalizeAxisValue(element: IOHIDElement, rawValue: Int) -> Float {
        let min = IOHIDElementGetLogicalMin(element)
        let max = IOHIDElementGetLogicalMax(element)

        if max == min {
            return 0.0
        }

        // Normalize to -1.0 to 1.0
        let normalized = Float(rawValue - min) / Float(max - min)
        return (normalized * 2.0) - 1.0
    }

    // MARK: - Input Processing

    private func handleButtonInput(controllerId: String, buttonIndex: Int, pressed: Bool) {
        controllerStates[controllerId]?.buttons[buttonIndex] = pressed
        controllerStates[controllerId]?.timestamp = Date()

        eventPublisher.publish(.buttonChanged(controllerId: controllerId, button: buttonIndex, pressed: pressed))
        onButtonChange?(controllerId, buttonIndex, pressed)
    }

    private func handleAxisInput(controllerId: String, axisIndex: Int, value: Float) {
        controllerStates[controllerId]?.axes[axisIndex] = value
        controllerStates[controllerId]?.timestamp = Date()

        eventPublisher.publish(.axisChanged(controllerId: controllerId, axis: axisIndex, value: value))
        onAxisChange?(controllerId, axisIndex, value)
    }
}
