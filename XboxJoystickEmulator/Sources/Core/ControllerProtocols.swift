// Xbox Joystick Emulator - Personal Use Only
// Protocols for controller handling and event delegation

import Foundation

// MARK: - Controller Events

/// Events that can occur with a controller
public enum ControllerEvent {
    case connected(ControllerInfo)
    case disconnected(ControllerInfo)
    case buttonChanged(controllerId: String, button: Int, pressed: Bool)
    case axisChanged(controllerId: String, axis: Int, value: Float)
    case stateUpdated(controllerId: String, state: GenericControllerState)
}

// MARK: - Controller Delegate Protocol

/// Protocol for receiving controller events
public protocol ControllerEventDelegate: AnyObject {
    func controllerDidConnect(_ info: ControllerInfo)
    func controllerDidDisconnect(_ info: ControllerInfo)
    func controllerButtonChanged(controllerId: String, button: Int, pressed: Bool)
    func controllerAxisChanged(controllerId: String, axis: Int, value: Float)
}

// MARK: - Default Implementations

public extension ControllerEventDelegate {
    func controllerDidConnect(_ info: ControllerInfo) {}
    func controllerDidDisconnect(_ info: ControllerInfo) {}
    func controllerButtonChanged(controllerId: String, button: Int, pressed: Bool) {}
    func controllerAxisChanged(controllerId: String, axis: Int, value: Float) {}
}

// MARK: - Input Provider Protocol

/// Protocol for objects that can provide controller input
public protocol ControllerInputProvider {
    var isConnected: Bool { get }
    var controllerInfo: ControllerInfo? { get }

    func startListening()
    func stopListening()
    func getCurrentState() -> GenericControllerState
}

// MARK: - Emulator Output Protocol

/// Protocol for outputting emulated Xbox controller input
public protocol XboxEmulatorOutput {
    func sendState(_ state: XboxControllerState)
    func sendButton(_ button: XboxButton, pressed: Bool)
    func sendAxis(_ axis: XboxAxis, value: Float)
    func connect() -> Bool
    func disconnect()
}

// MARK: - Mapping Provider Protocol

/// Protocol for objects that provide button/axis mappings
public protocol MappingProvider {
    func mapButton(genericIndex: Int) -> XboxButton?
    func mapAxis(genericIndex: Int) -> XboxAxis?
    func getAxisInversion(genericIndex: Int) -> Bool
    func getAxisDeadzone(genericIndex: Int) -> Float
    func getAxisSensitivity(genericIndex: Int) -> Float
}

// MARK: - Configuration Storage

/// Protocol for storing and retrieving configurations
public protocol ConfigurationStorage {
    func save<T: Encodable>(_ value: T, forKey key: String) throws
    func load<T: Decodable>(forKey key: String) throws -> T?
    func delete(forKey key: String) throws
    func listKeys() -> [String]
}

// MARK: - Event Publisher

/// Simple event publisher for controller events
public class ControllerEventPublisher {
    private var delegates: [ObjectIdentifier: WeakDelegate] = [:]

    public init() {}

    public func addDelegate(_ delegate: ControllerEventDelegate) {
        let id = ObjectIdentifier(delegate as AnyObject)
        delegates[id] = WeakDelegate(delegate)
    }

    public func removeDelegate(_ delegate: ControllerEventDelegate) {
        let id = ObjectIdentifier(delegate as AnyObject)
        delegates.removeValue(forKey: id)
    }

    public func publish(_ event: ControllerEvent) {
        // Clean up nil references
        delegates = delegates.filter { $0.value.delegate != nil }

        for (_, weakDelegate) in delegates {
            guard let delegate = weakDelegate.delegate else { continue }

            switch event {
            case .connected(let info):
                delegate.controllerDidConnect(info)
            case .disconnected(let info):
                delegate.controllerDidDisconnect(info)
            case .buttonChanged(let controllerId, let button, let pressed):
                delegate.controllerButtonChanged(controllerId: controllerId, button: button, pressed: pressed)
            case .axisChanged(let controllerId, let axis, let value):
                delegate.controllerAxisChanged(controllerId: controllerId, axis: axis, value: value)
            case .stateUpdated:
                break // Handle separately if needed
            }
        }
    }

    private class WeakDelegate {
        weak var delegate: ControllerEventDelegate?
        init(_ delegate: ControllerEventDelegate) {
            self.delegate = delegate
        }
    }
}
