// Xbox Joystick Emulator - Personal Use Only
// Mapping Manager - Manages controller profiles and mappings

import Foundation
import XboxJoystickCore

// MARK: - Mapping Manager

/// Manages controller mapping profiles
public class MappingManager: ObservableObject {
    public static let shared = MappingManager()

    @Published public private(set) var profiles: [ControllerProfile] = []
    @Published public var activeProfile: ControllerProfile?

    private let storageKey = "xbox_emulator_profiles"
    private let activeProfileKey = "xbox_emulator_active_profile"
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard

    private var configDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("XboxJoystickEmulator")
    }

    private var profilesFile: URL {
        return configDirectory.appendingPathComponent("profiles.json")
    }

    private init() {
        ensureConfigDirectory()
        loadProfiles()
    }

    // MARK: - File Management

    private func ensureConfigDirectory() {
        if !fileManager.fileExists(atPath: configDirectory.path) {
            try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Profile Management

    /// Load profiles from disk
    public func loadProfiles() {
        if fileManager.fileExists(atPath: profilesFile.path),
           let data = try? Data(contentsOf: profilesFile),
           let loadedProfiles = try? JSONDecoder().decode([ControllerProfile].self, from: data) {
            profiles = loadedProfiles
        } else {
            // Create default profiles
            profiles = [
                ControllerProfile.createDefaultXboxMapping(),
                ControllerProfile.createPlayStationMapping(),
                ControllerProfile.createSwitchProMapping()
            ]
            saveProfiles()
        }

        // Load active profile
        if let activeId = userDefaults.string(forKey: activeProfileKey),
           let uuid = UUID(uuidString: activeId),
           let profile = profiles.first(where: { $0.id == uuid }) {
            activeProfile = profile
        } else if let defaultProfile = profiles.first(where: { $0.isDefault }) {
            activeProfile = defaultProfile
        } else {
            activeProfile = profiles.first
        }
    }

    /// Save profiles to disk
    public func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: profilesFile)
        } catch {
            print("Failed to save profiles: \(error)")
        }

        // Save active profile ID
        if let activeProfile = activeProfile {
            userDefaults.set(activeProfile.id.uuidString, forKey: activeProfileKey)
        }
    }

    /// Add a new profile
    public func addProfile(_ profile: ControllerProfile) {
        profiles.append(profile)
        saveProfiles()
    }

    /// Update an existing profile
    public func updateProfile(_ profile: ControllerProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            var updatedProfile = profile
            updatedProfile.updateModifiedDate()
            profiles[index] = updatedProfile

            if activeProfile?.id == profile.id {
                activeProfile = updatedProfile
            }

            saveProfiles()
        }
    }

    /// Delete a profile
    public func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }

        if activeProfile?.id == id {
            activeProfile = profiles.first(where: { $0.isDefault }) ?? profiles.first
        }

        saveProfiles()
    }

    /// Set the active profile
    public func setActiveProfile(_ profile: ControllerProfile) {
        activeProfile = profile
        userDefaults.set(profile.id.uuidString, forKey: activeProfileKey)
    }

    /// Duplicate a profile
    public func duplicateProfile(_ profile: ControllerProfile, newName: String) -> ControllerProfile {
        var newProfile = ControllerProfile(
            name: newName,
            controllerVendorProduct: profile.controllerVendorProduct,
            buttonMappings: profile.buttonMappings.map { mapping in
                ButtonMapping(
                    sourceButton: mapping.sourceButton,
                    targetButton: mapping.targetButton,
                    isEnabled: mapping.isEnabled
                )
            },
            axisMappings: profile.axisMappings.map { mapping in
                AxisMapping(
                    sourceAxis: mapping.sourceAxis,
                    targetAxis: mapping.targetAxis,
                    isInverted: mapping.isInverted,
                    deadzone: mapping.deadzone,
                    sensitivity: mapping.sensitivity,
                    isEnabled: mapping.isEnabled
                )
            },
            isDefault: false
        )

        addProfile(newProfile)
        return newProfile
    }

    /// Create a new empty profile
    public func createEmptyProfile(name: String) -> ControllerProfile {
        let profile = ControllerProfile(name: name)
        addProfile(profile)
        return profile
    }

    /// Find a profile matching a controller
    public func findMatchingProfile(for controller: ControllerInfo) -> ControllerProfile? {
        return profiles.first { $0.controllerVendorProduct == controller.vendorProductString }
    }

    /// Get mapping provider for the active profile
    public func getActiveMappingProvider() -> ProfileMappingProvider? {
        guard let profile = activeProfile else { return nil }
        return ProfileMappingProvider(profile: profile)
    }

    /// Export profile to file
    public func exportProfile(_ profile: ControllerProfile, to url: URL) throws {
        let data = try JSONEncoder().encode(profile)
        try data.write(to: url)
    }

    /// Import profile from file
    public func importProfile(from url: URL) throws -> ControllerProfile {
        let data = try Data(contentsOf: url)
        var profile = try JSONDecoder().decode(ControllerProfile.self, from: data)

        // Generate new ID to avoid conflicts
        let newProfile = ControllerProfile(
            name: profile.name + " (Imported)",
            controllerVendorProduct: profile.controllerVendorProduct,
            buttonMappings: profile.buttonMappings,
            axisMappings: profile.axisMappings,
            isDefault: false
        )

        addProfile(newProfile)
        return newProfile
    }

    // MARK: - Button Mapping Helpers

    /// Add a button mapping to a profile
    public func addButtonMapping(to profileId: UUID, sourceButton: Int, targetButton: XboxButton) {
        guard var profile = profiles.first(where: { $0.id == profileId }) else { return }

        // Remove existing mapping for this source button
        profile.buttonMappings.removeAll { $0.sourceButton == sourceButton }

        // Add new mapping
        let mapping = ButtonMapping(sourceButton: sourceButton, targetButton: targetButton)
        profile.buttonMappings.append(mapping)

        updateProfile(profile)
    }

    /// Remove a button mapping from a profile
    public func removeButtonMapping(from profileId: UUID, sourceButton: Int) {
        guard var profile = profiles.first(where: { $0.id == profileId }) else { return }

        profile.buttonMappings.removeAll { $0.sourceButton == sourceButton }
        updateProfile(profile)
    }

    // MARK: - Axis Mapping Helpers

    /// Add an axis mapping to a profile
    public func addAxisMapping(
        to profileId: UUID,
        sourceAxis: Int,
        targetAxis: XboxAxis,
        isInverted: Bool = false,
        deadzone: Float = 0.1,
        sensitivity: Float = 1.0
    ) {
        guard var profile = profiles.first(where: { $0.id == profileId }) else { return }

        // Remove existing mapping for this source axis
        profile.axisMappings.removeAll { $0.sourceAxis == sourceAxis }

        // Add new mapping
        let mapping = AxisMapping(
            sourceAxis: sourceAxis,
            targetAxis: targetAxis,
            isInverted: isInverted,
            deadzone: deadzone,
            sensitivity: sensitivity
        )
        profile.axisMappings.append(mapping)

        updateProfile(profile)
    }

    /// Update axis configuration
    public func updateAxisMapping(
        in profileId: UUID,
        sourceAxis: Int,
        isInverted: Bool? = nil,
        deadzone: Float? = nil,
        sensitivity: Float? = nil
    ) {
        guard var profile = profiles.first(where: { $0.id == profileId }) else { return }

        if let index = profile.axisMappings.firstIndex(where: { $0.sourceAxis == sourceAxis }) {
            var mapping = profile.axisMappings[index]

            if let isInverted = isInverted {
                mapping = AxisMapping(
                    sourceAxis: mapping.sourceAxis,
                    targetAxis: mapping.targetAxis,
                    isInverted: isInverted,
                    deadzone: mapping.deadzone,
                    sensitivity: mapping.sensitivity,
                    isEnabled: mapping.isEnabled
                )
            }
            if let deadzone = deadzone {
                mapping = AxisMapping(
                    sourceAxis: mapping.sourceAxis,
                    targetAxis: mapping.targetAxis,
                    isInverted: mapping.isInverted,
                    deadzone: deadzone,
                    sensitivity: mapping.sensitivity,
                    isEnabled: mapping.isEnabled
                )
            }
            if let sensitivity = sensitivity {
                mapping = AxisMapping(
                    sourceAxis: mapping.sourceAxis,
                    targetAxis: mapping.targetAxis,
                    isInverted: mapping.isInverted,
                    deadzone: mapping.deadzone,
                    sensitivity: sensitivity,
                    isEnabled: mapping.isEnabled
                )
            }

            profile.axisMappings[index] = mapping
            updateProfile(profile)
        }
    }

    /// Remove an axis mapping from a profile
    public func removeAxisMapping(from profileId: UUID, sourceAxis: Int) {
        guard var profile = profiles.first(where: { $0.id == profileId }) else { return }

        profile.axisMappings.removeAll { $0.sourceAxis == sourceAxis }
        updateProfile(profile)
    }
}
