// Xbox Joystick Emulator - Personal Use Only
// Main Application Entry Point

import SwiftUI
import XboxJoystickCore
import Controllers
import Mapping
import UI

@main
struct XboxJoystickEmulatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Xbox Joystick Emulator") {
                    showAboutWindow()
                }
            }

            CommandMenu("Emulator") {
                Button("Start Emulation") {
                    XboxEmulator.shared.start()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(XboxEmulator.shared.isRunning)

                Button("Stop Emulation") {
                    XboxEmulator.shared.stop()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!XboxEmulator.shared.isRunning)

                Divider()

                Button("Refresh Controllers") {
                    HIDControllerManager.shared.refreshControllers()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandMenu("Profiles") {
                Button("New Profile...") {
                    // Will be handled by UI
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Import Profile...") {
                    importProfile()
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Export Profile...") {
                    exportProfile()
                }
                .keyboardShortcut("e", modifiers: [.command])
            }
        }

        Settings {
            SettingsWindowView()
        }
    }

    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "Xbox Joystick Emulator"
        alert.informativeText = """
        Version 1.0.0

        A personal-use utility to remap wireless game controllers to Xbox controller configuration.

        This software is for PERSONAL USE ONLY and is not intended for commercial purposes.

        © 2024 - Personal Project
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                _ = try MappingManager.shared.importProfile(from: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    private func exportProfile() {
        guard let profile = MappingManager.shared.activeProfile else {
            let alert = NSAlert()
            alert.messageText = "No Profile Selected"
            alert.informativeText = "Please select a profile to export."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(profile.name).json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try MappingManager.shared.exportProfile(profile, to: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start controller scanning on launch
        if UserDefaults.standard.bool(forKey: "autoStartScanning") {
            HIDControllerManager.shared.startScanning()
        }

        // Request accessibility permissions if needed
        checkAccessibilityPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop emulator and clean up
        XboxEmulator.shared.stop()
        HIDControllerManager.shared.stopScanning()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func checkAccessibilityPermissions() {
        #if os(macOS)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            print("Accessibility permissions not granted. Keyboard emulation mode will not work.")
        }
        #endif
    }
}

// MARK: - Settings Window

struct SettingsWindowView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ControllerSettingsView()
                .tabItem {
                    Label("Controllers", systemImage: "gamecontroller")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

struct GeneralSettingsView: View {
    @AppStorage("autoStartScanning") private var autoStartScanning = true
    @AppStorage("startMinimized") private var startMinimized = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true

    var body: some View {
        Form {
            Toggle("Auto-start controller scanning on launch", isOn: $autoStartScanning)
            Toggle("Start minimized", isOn: $startMinimized)
            Toggle("Show in menu bar", isOn: $showInMenuBar)
        }
        .padding()
    }
}

struct ControllerSettingsView: View {
    @AppStorage("defaultDeadzone") private var defaultDeadzone = 0.1
    @AppStorage("defaultSensitivity") private var defaultSensitivity = 1.0
    @AppStorage("pollingRate") private var pollingRate = 60.0

    var body: some View {
        Form {
            Section("Default Axis Settings") {
                HStack {
                    Text("Deadzone")
                    Slider(value: $defaultDeadzone, in: 0...0.5, step: 0.05)
                    Text("\(defaultDeadzone, specifier: "%.2f")")
                        .frame(width: 40)
                }

                HStack {
                    Text("Sensitivity")
                    Slider(value: $defaultSensitivity, in: 0.1...2.0, step: 0.1)
                    Text("\(defaultSensitivity, specifier: "%.1f")")
                        .frame(width: 40)
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
        }
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("debugMode") private var debugMode = false
    @AppStorage("logInputEvents") private var logInputEvents = false

    var body: some View {
        Form {
            Section("Debugging") {
                Toggle("Enable debug mode", isOn: $debugMode)
                Toggle("Log input events", isOn: $logInputEvents)
            }

            Section("Data") {
                Button("Reset All Settings") {
                    resetSettings()
                }
                .buttonStyle(.bordered)

                Button("Clear All Profiles") {
                    clearProfiles()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
    }

    private func resetSettings() {
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
    }

    private func clearProfiles() {
        // Would need to implement profile clearing in MappingManager
    }
}

// MARK: - Import Types

import IOKit
import IOKit.hid
