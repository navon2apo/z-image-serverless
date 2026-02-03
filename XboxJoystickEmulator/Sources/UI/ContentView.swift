// Xbox Joystick Emulator - Personal Use Only
// Main Content View - SwiftUI interface for the emulator

import SwiftUI

// MARK: - Main Content View

public struct ContentView: View {
    @ObservedObject private var controllerManager = HIDControllerManager.shared
    @ObservedObject private var emulator = XboxEmulator.shared
    @ObservedObject private var mappingManager = MappingManager.shared

    @State private var selectedTab: Tab = .controllers
    @State private var showingProfileEditor = false
    @State private var selectedProfileForEdit: ControllerProfile?

    enum Tab: String, CaseIterable {
        case controllers = "Controllers"
        case mapping = "Mapping"
        case emulator = "Emulator"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .controllers: return "gamecontroller"
            case .mapping: return "arrow.left.arrow.right"
            case .emulator: return "play.circle"
            case .settings: return "gear"
            }
        }
    }

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .navigationTitle("Xbox Emulator")
            .frame(minWidth: 180)
        } detail: {
            Group {
                switch selectedTab {
                case .controllers:
                    ControllersView()
                case .mapping:
                    MappingView()
                case .emulator:
                    EmulatorView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }
}

// MARK: - Controllers View

struct ControllersView: View {
    @ObservedObject private var controllerManager = HIDControllerManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Connected Controllers")
                    .font(.headline)
                Spacer()
                Button(action: {
                    controllerManager.refreshControllers()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    if controllerManager.isScanning {
                        controllerManager.stopScanning()
                    } else {
                        controllerManager.startScanning()
                    }
                }) {
                    Label(
                        controllerManager.isScanning ? "Stop Scanning" : "Start Scanning",
                        systemImage: controllerManager.isScanning ? "stop.fill" : "magnifyingglass"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Controller List
            if controllerManager.connectedControllers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("No Controllers Connected")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Connect a wireless controller or click 'Start Scanning' to detect devices")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(controllerManager.connectedControllers) { controller in
                    ControllerRow(controller: controller)
                }
            }
        }
        .onAppear {
            controllerManager.startScanning()
        }
    }
}

struct ControllerRow: View {
    let controller: ControllerInfo
    @ObservedObject private var emulator = XboxEmulator.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(controller.name)
                        .font(.headline)
                    if controller.isWireless {
                        Image(systemName: "wifi")
                            .foregroundColor(.blue)
                    }
                }

                HStack {
                    Text("ID: \(controller.vendorProductString)")
                    Text("•")
                    Text("\(controller.buttonCount) buttons")
                    Text("•")
                    Text("\(controller.axisCount) axes")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if emulator.activeControllerId == controller.id {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Mapping View

struct MappingView: View {
    @ObservedObject private var mappingManager = MappingManager.shared
    @State private var showingAddProfile = false
    @State private var newProfileName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Controller Profiles")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddProfile = true }) {
                    Label("New Profile", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Profile List
            List {
                ForEach(mappingManager.profiles) { profile in
                    ProfileRow(profile: profile)
                }
            }
        }
        .sheet(isPresented: $showingAddProfile) {
            NewProfileSheet(isPresented: $showingAddProfile)
        }
    }
}

struct ProfileRow: View {
    let profile: ControllerProfile
    @ObservedObject private var mappingManager = MappingManager.shared
    @State private var showingEditor = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    if profile.isDefault {
                        Text("Default")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text("\(profile.buttonMappings.count) buttons • \(profile.axisMappings.count) axes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if mappingManager.activeProfile?.id == profile.id {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Activate") {
                    mappingManager.setActiveProfile(profile)
                }
                .buttonStyle(.bordered)
            }

            Button(action: { showingEditor = true }) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditor) {
            ProfileEditorSheet(profile: profile, isPresented: $showingEditor)
        }
    }
}

struct NewProfileSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var mappingManager = MappingManager.shared
    @State private var name = ""
    @State private var baseProfile: ControllerProfile?

    var body: some View {
        VStack(spacing: 20) {
            Text("New Profile")
                .font(.title2)

            TextField("Profile Name", text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("Based On", selection: $baseProfile) {
                Text("Empty").tag(nil as ControllerProfile?)
                ForEach(mappingManager.profiles) { profile in
                    Text(profile.name).tag(profile as ControllerProfile?)
                }
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    if let base = baseProfile {
                        _ = mappingManager.duplicateProfile(base, newName: name)
                    } else {
                        _ = mappingManager.createEmptyProfile(name: name)
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct ProfileEditorSheet: View {
    let profile: ControllerProfile
    @Binding var isPresented: Bool
    @ObservedObject private var mappingManager = MappingManager.shared
    @State private var editedProfile: ControllerProfile
    @State private var selectedTab = 0

    init(profile: ControllerProfile, isPresented: Binding<Bool>) {
        self.profile = profile
        self._isPresented = isPresented
        self._editedProfile = State(initialValue: profile)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Profile: \(profile.name)")
                    .font(.title2)
                Spacer()
                Button("Done") {
                    mappingManager.updateProfile(editedProfile)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Tab View
            TabView(selection: $selectedTab) {
                ButtonMappingEditor(profile: $editedProfile)
                    .tabItem { Label("Buttons", systemImage: "circle.grid.3x3") }
                    .tag(0)

                AxisMappingEditor(profile: $editedProfile)
                    .tabItem { Label("Axes", systemImage: "arrow.up.and.down.and.arrow.left.and.right") }
                    .tag(1)
            }
        }
        .frame(width: 700, height: 500)
    }
}

struct ButtonMappingEditor: View {
    @Binding var profile: ControllerProfile

    var body: some View {
        List {
            ForEach(Array(profile.buttonMappings.enumerated()), id: \.element.id) { index, mapping in
                HStack {
                    Text("Button \(mapping.sourceButton)")
                        .frame(width: 100, alignment: .leading)

                    Image(systemName: "arrow.right")

                    Picker("", selection: Binding(
                        get: { mapping.targetButton },
                        set: { newValue in
                            profile.buttonMappings[index] = ButtonMapping(
                                sourceButton: mapping.sourceButton,
                                targetButton: newValue,
                                isEnabled: mapping.isEnabled
                            )
                        }
                    )) {
                        ForEach(XboxButton.allCases, id: \.self) { button in
                            Text(button.displayName).tag(button)
                        }
                    }
                    .frame(width: 150)

                    Spacer()

                    Toggle("Enabled", isOn: Binding(
                        get: { mapping.isEnabled },
                        set: { newValue in
                            profile.buttonMappings[index] = ButtonMapping(
                                sourceButton: mapping.sourceButton,
                                targetButton: mapping.targetButton,
                                isEnabled: newValue
                            )
                        }
                    ))
                }
            }
        }
    }
}

struct AxisMappingEditor: View {
    @Binding var profile: ControllerProfile

    var body: some View {
        List {
            ForEach(Array(profile.axisMappings.enumerated()), id: \.element.id) { index, mapping in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Axis \(mapping.sourceAxis)")
                            .frame(width: 80, alignment: .leading)

                        Image(systemName: "arrow.right")

                        Picker("", selection: Binding(
                            get: { mapping.targetAxis },
                            set: { newValue in
                                profile.axisMappings[index] = AxisMapping(
                                    sourceAxis: mapping.sourceAxis,
                                    targetAxis: newValue,
                                    isInverted: mapping.isInverted,
                                    deadzone: mapping.deadzone,
                                    sensitivity: mapping.sensitivity,
                                    isEnabled: mapping.isEnabled
                                )
                            }
                        )) {
                            ForEach(XboxAxis.allCases, id: \.self) { axis in
                                Text(axis.displayName).tag(axis)
                            }
                        }
                        .frame(width: 150)

                        Toggle("Inverted", isOn: Binding(
                            get: { mapping.isInverted },
                            set: { newValue in
                                profile.axisMappings[index] = AxisMapping(
                                    sourceAxis: mapping.sourceAxis,
                                    targetAxis: mapping.targetAxis,
                                    isInverted: newValue,
                                    deadzone: mapping.deadzone,
                                    sensitivity: mapping.sensitivity,
                                    isEnabled: mapping.isEnabled
                                )
                            }
                        ))

                        Toggle("Enabled", isOn: Binding(
                            get: { mapping.isEnabled },
                            set: { newValue in
                                profile.axisMappings[index] = AxisMapping(
                                    sourceAxis: mapping.sourceAxis,
                                    targetAxis: mapping.targetAxis,
                                    isInverted: mapping.isInverted,
                                    deadzone: mapping.deadzone,
                                    sensitivity: mapping.sensitivity,
                                    isEnabled: newValue
                                )
                            }
                        ))
                    }

                    HStack {
                        Text("Deadzone:")
                        Slider(value: Binding(
                            get: { Double(mapping.deadzone) },
                            set: { newValue in
                                profile.axisMappings[index] = AxisMapping(
                                    sourceAxis: mapping.sourceAxis,
                                    targetAxis: mapping.targetAxis,
                                    isInverted: mapping.isInverted,
                                    deadzone: Float(newValue),
                                    sensitivity: mapping.sensitivity,
                                    isEnabled: mapping.isEnabled
                                )
                            }
                        ), in: 0...0.5)
                        Text("\(mapping.deadzone, specifier: "%.2f")")
                            .frame(width: 40)

                        Text("Sensitivity:")
                        Slider(value: Binding(
                            get: { Double(mapping.sensitivity) },
                            set: { newValue in
                                profile.axisMappings[index] = AxisMapping(
                                    sourceAxis: mapping.sourceAxis,
                                    targetAxis: mapping.targetAxis,
                                    isInverted: mapping.isInverted,
                                    deadzone: mapping.deadzone,
                                    sensitivity: Float(newValue),
                                    isEnabled: mapping.isEnabled
                                )
                            }
                        ), in: 0.1...2.0)
                        Text("\(mapping.sensitivity, specifier: "%.2f")")
                            .frame(width: 40)
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Emulator View

struct EmulatorView: View {
    @ObservedObject private var emulator = XboxEmulator.shared
    @ObservedObject private var controllerManager = HIDControllerManager.shared
    @StateObject private var stateObserver = XboxStateObserver()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Xbox Emulator")
                    .font(.headline)

                Spacer()

                Picker("Mode", selection: $emulator.emulationMode) {
                    ForEach(XboxEmulator.EmulationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 200)

                Button(action: {
                    if emulator.isRunning {
                        emulator.stop()
                        stateObserver.stopObserving()
                    } else {
                        emulator.start()
                        stateObserver.startObserving()
                    }
                }) {
                    Label(
                        emulator.isRunning ? "Stop" : "Start",
                        systemImage: emulator.isRunning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(emulator.isRunning ? .red : .green)
            }
            .padding()

            Divider()

            // Controller Visualization
            ControllerVisualization(state: stateObserver.state)
                .padding()

            Divider()

            // Status
            HStack {
                Circle()
                    .fill(emulator.isRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(emulator.isRunning ? "Running" : "Stopped")

                if let controllerId = emulator.activeControllerId {
                    Text("•")
                    Text("Controller: \(controllerId)")
                }

                Spacer()
            }
            .font(.caption)
            .padding()
        }
    }
}

// MARK: - Controller Visualization

struct ControllerVisualization: View {
    let state: XboxControllerState

    var body: some View {
        HStack(spacing: 40) {
            // Left side
            VStack(spacing: 20) {
                // Left Stick
                StickVisualization(
                    xValue: state.axisValue(.leftStickX),
                    yValue: state.axisValue(.leftStickY),
                    isPressed: state.isPressed(.leftStickClick),
                    label: "L"
                )

                // D-Pad
                DPadVisualization(
                    up: state.isPressed(.dpadUp),
                    down: state.isPressed(.dpadDown),
                    left: state.isPressed(.dpadLeft),
                    right: state.isPressed(.dpadRight)
                )

                // Left Bumper/Trigger
                VStack {
                    TriggerVisualization(value: state.axisValue(.leftTrigger), label: "LT")
                    ButtonVisualization(isPressed: state.isPressed(.leftBumper), label: "LB")
                }
            }

            // Center - Face buttons and menu buttons
            VStack(spacing: 20) {
                // Menu buttons
                HStack(spacing: 20) {
                    ButtonVisualization(isPressed: state.isPressed(.back), label: "Back")
                    ButtonVisualization(isPressed: state.isPressed(.guide), label: "Guide", size: 40)
                    ButtonVisualization(isPressed: state.isPressed(.start), label: "Start")
                }

                // Face buttons
                FaceButtonsVisualization(
                    a: state.isPressed(.a),
                    b: state.isPressed(.b),
                    x: state.isPressed(.x),
                    y: state.isPressed(.y)
                )
            }

            // Right side
            VStack(spacing: 20) {
                // Right Stick
                StickVisualization(
                    xValue: state.axisValue(.rightStickX),
                    yValue: state.axisValue(.rightStickY),
                    isPressed: state.isPressed(.rightStickClick),
                    label: "R"
                )

                Spacer()
                    .frame(height: 60)

                // Right Bumper/Trigger
                VStack {
                    TriggerVisualization(value: state.axisValue(.rightTrigger), label: "RT")
                    ButtonVisualization(isPressed: state.isPressed(.rightBumper), label: "RB")
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(16)
    }
}

struct StickVisualization: View {
    let xValue: Float
    let yValue: Float
    let isPressed: Bool
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary, lineWidth: 2)
                .frame(width: 80, height: 80)

            Circle()
                .fill(isPressed ? Color.green : Color.blue)
                .frame(width: 30, height: 30)
                .offset(
                    x: CGFloat(xValue) * 25,
                    y: CGFloat(-yValue) * 25
                )

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .offset(y: 50)
        }
    }
}

struct DPadVisualization: View {
    let up: Bool
    let down: Bool
    let left: Bool
    let right: Bool

    var body: some View {
        VStack(spacing: 2) {
            DPadButton(isPressed: up)
            HStack(spacing: 2) {
                DPadButton(isPressed: left)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 25, height: 25)
                DPadButton(isPressed: right)
            }
            DPadButton(isPressed: down)
        }
    }
}

struct DPadButton: View {
    let isPressed: Bool

    var body: some View {
        Rectangle()
            .fill(isPressed ? Color.green : Color.secondary.opacity(0.5))
            .frame(width: 25, height: 25)
    }
}

struct FaceButtonsVisualization: View {
    let a: Bool
    let b: Bool
    let x: Bool
    let y: Bool

    var body: some View {
        VStack(spacing: 8) {
            FaceButton(isPressed: y, label: "Y", color: .yellow)
            HStack(spacing: 20) {
                FaceButton(isPressed: x, label: "X", color: .blue)
                FaceButton(isPressed: b, label: "B", color: .red)
            }
            FaceButton(isPressed: a, label: "A", color: .green)
        }
    }
}

struct FaceButton: View {
    let isPressed: Bool
    let label: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(isPressed ? color : color.opacity(0.3))
                .frame(width: 35, height: 35)
            Text(label)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

struct ButtonVisualization: View {
    let isPressed: Bool
    let label: String
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isPressed ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: size + 20, height: size)
            Text(label)
                .font(.caption2)
                .foregroundColor(isPressed ? .white : .primary)
        }
    }
}

struct TriggerVisualization: View {
    let value: Float
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(height: geometry.size.height * CGFloat(value))
                }
            }
            .frame(width: 40, height: 50)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("autoStartScanning") private var autoStartScanning = true
    @AppStorage("defaultEmulationMode") private var defaultEmulationMode = "Passthrough"
    @AppStorage("pollingRate") private var pollingRate = 60.0

    var body: some View {
        Form {
            Section("General") {
                Toggle("Auto-start controller scanning", isOn: $autoStartScanning)

                Picker("Default Emulation Mode", selection: $defaultEmulationMode) {
                    ForEach(XboxEmulator.EmulationMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
            }

            Section("Performance") {
                HStack {
                    Text("Polling Rate")
                    Slider(value: $pollingRate, in: 30...144, step: 10)
                    Text("\(Int(pollingRate)) Hz")
                        .frame(width: 60)
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("License")
                    Spacer()
                    Text("Personal Use Only")
                        .foregroundColor(.secondary)
                }
            }

            Section("Permissions") {
                Text("This app requires the following permissions:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Input Monitoring (for controller access)", systemImage: "keyboard")
                    Label("Accessibility (for keyboard emulation mode)", systemImage: "accessibility")
                }
                .font(.caption)

                Button("Open System Preferences") {
                    #if os(macOS)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring") {
                        NSWorkspace.shared.open(url)
                    }
                    #endif
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
