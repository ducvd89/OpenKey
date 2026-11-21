//
//  SettingsStore.swift
//  Bridges the engine's global settings and NSUserDefaults to SwiftUI.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import SwiftUI

struct AppProfile: Identifiable, Equatable {
    let id: String
    var name: String
    var vietnamese: Bool
}

final class SettingsStore: ObservableObject {
    @Published var permissionReady = true
    @Published var hasAccessibility = true
    @Published private(set) var profiles: [AppProfile] = []
    @Published var isCheckingUpdate = false

    private let defaults = UserDefaults.standard

    init() {
        loadProfiles()
    }

    func reload() {
        objectWillChange.send()
        loadProfiles()
    }

    // MARK: - Generic bindings

    /// A 0/1 integer preference that may also drive an engine global.
    func flag(_ key: String, apply: ((Int32) -> Void)? = nil, after: ((Bool) -> Void)? = nil) -> Binding<Bool> {
        Binding(
            get: { [defaults] in defaults.integer(forKey: key) != 0 },
            set: { [weak self] newValue in
                guard let self else { return }
                self.objectWillChange.send()
                self.defaults.set(newValue ? 1 : 0, forKey: key)
                apply?(newValue ? 1 : 0)
                after?(newValue)
            }
        )
    }

    // MARK: - Input

    var isVietnamese: Binding<Bool> {
        Binding(
            get: { vLanguage == 1 },
            set: { newValue in
                if newValue != (vLanguage == 1) {
                    appDelegate.onInputMethodSelected()
                }
            }
        )
    }

    static let inputTypes = ["Telex", "VNI", "Simple Telex 1", "Simple Telex 2"]

    var inputType: Binding<Int> {
        Binding(
            get: { [defaults] in defaults.integer(forKey: "InputType") },
            set: { appDelegate.onInputTypeSelectedIndex(Int32($0)) }
        )
    }

    let codeTables: [String] = (OpenKeyManager.getTableCodes() as? [String]) ?? []

    var codeTable: Binding<Int> {
        Binding(
            get: { [defaults] in defaults.integer(forKey: "CodeTable") },
            set: { appDelegate.onCodeTableChanged(Int32($0)) }
        )
    }

    // MARK: - Switch key (packed into vSwitchKeyStatus)

    private func setSwitchStatus(_ status: UInt32) {
        objectWillChange.send()
        vSwitchKeyStatus = Int32(bitPattern: status)
        defaults.set(Int(vSwitchKeyStatus), forKey: "SwitchKeyStatus")
    }

    private var switchStatus: UInt32 { UInt32(bitPattern: vSwitchKeyStatus) }

    func switchBit(_ mask: UInt32) -> Binding<Bool> {
        Binding(
            get: { [unowned self] in self.switchStatus & mask != 0 },
            set: { [unowned self] on in
                self.setSwitchStatus(on ? self.switchStatus | mask : self.switchStatus & ~mask)
            }
        )
    }

    static let controlMask: UInt32 = 0x100
    static let optionMask: UInt32 = 0x200
    static let commandMask: UInt32 = 0x400
    static let shiftMask: UInt32 = 0x800
    static let beepMask: UInt32 = 0x8000
    static let noKey: UInt32 = 0xFE

    /// Stores the switch key the same way the original key field did:
    /// key code in the low byte, typed character in the high byte.
    func setSwitchKey(keyCode: UInt32, character: UInt32) {
        var status = switchStatus
        status = (status & 0xFFFF_FF00) | (keyCode & 0xFF)
        status = (status & 0x00FF_FFFF) | ((character & 0xFF) << 24)
        setSwitchStatus(status)
    }

    var switchKeyDisplay: String {
        let character = (switchStatus >> 24) & 0xFF
        if character == UInt32(kVK_Space) { return "Space" }
        if character == Self.noKey || character == 0 { return "—" }
        return String(UnicodeScalar(UInt8(character))).uppercased()
    }

    var switchLanguageWithFn: Binding<Bool> {
        Binding(
            get: { [defaults] in defaults.bool(forKey: "SwitchLanguageWithFn") },
            set: { [unowned self] on in
                self.objectWillChange.send()
                self.defaults.set(on, forKey: "SwitchLanguageWithFn")
                vSwitchLanguageWithFn = on ? 1 : 0
            }
        )
    }

    var showLanguageSwitchHUD: Binding<Bool> {
        Binding(
            get: { [defaults] in defaults.bool(forKey: "ShowLanguageSwitchHUD") },
            set: { [unowned self] on in
                self.objectWillChange.send()
                self.defaults.set(on, forKey: "ShowLanguageSwitchHUD")
            }
        )
    }

    // MARK: - System

    var checkUpdateOnStartup: Binding<Bool> {
        Binding(
            get: { [defaults] in defaults.integer(forKey: "DontCheckUpdate") == 0 },
            set: { [unowned self] on in
                self.objectWillChange.send()
                self.defaults.set(on ? 0 : 1, forKey: "DontCheckUpdate")
            }
        )
    }

    func resetToDefaults() {
        appDelegate.loadDefaultConfig()
        defaults.set(0, forKey: "ShowUIOnStartup")
        defaults.set(1, forKey: "RunOnStartup")
        appDelegate.setRunOnStartup(true)
        reload()
    }

    func checkForUpdate(window: NSWindow?) {
        isCheckingUpdate = true
        OpenKeyManager.checkNewVersion(window) { [weak self] in
            self?.isCheckingUpdate = false
        }
    }

    // MARK: - App profiles

    private func loadProfiles() {
        let stored = defaults.dictionary(forKey: OpenKeyAppProfilesKey) ?? [:]
        profiles = stored.compactMap { identifier, value in
            guard let entry = value as? [String: Any] else { return nil }
            return AppProfile(id: identifier,
                              name: entry["name"] as? String ?? identifier,
                              vietnamese: (entry["language"] as? NSNumber)?.boolValue ?? false)
        }
        .sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }

    private func saveProfiles() {
        var stored: [String: Any] = [:]
        for profile in profiles {
            stored[profile.id] = ["name": profile.name, "language": NSNumber(value: profile.vietnamese)]
        }
        defaults.set(stored, forKey: OpenKeyAppProfilesKey)
        appDelegate.refreshActiveApp()
    }

    /// Returns false when the identifier can't be used (empty or OpenKey itself).
    @discardableResult
    func addProfile(identifier: String?, name: String?) -> Bool {
        guard let identifier, !identifier.isEmpty,
              identifier != Bundle.main.bundleIdentifier else { return false }
        if !profiles.contains(where: { $0.id == identifier }) {
            profiles.append(AppProfile(id: identifier, name: name ?? identifier,
                                       vietnamese: defaults.bool(forKey: "InputMethod")))
            saveProfiles()
            loadProfiles()
        }
        return true
    }

    func setProfile(_ identifier: String, vietnamese: Bool) {
        guard let index = profiles.firstIndex(where: { $0.id == identifier }) else { return }
        profiles[index].vietnamese = vietnamese
        saveProfiles()
    }

    func removeProfile(_ identifier: String) {
        profiles.removeAll { $0.id == identifier }
        saveProfiles()
    }

    /// Include Windows apps with a normal window even if Wine hasn't marked them as regular apps.
    func runningAppsWithoutProfile() -> [(id: String, name: String)] {
        var found: [String: String] = [:]
        let rules = Set(profiles.map(\.id))
        let windows = CGWindowListCopyWindowInfo(.excludeDesktopElements, kCGNullWindowID)
            as? [[String: Any]] ?? []
        let windowOwners = Set(windows.compactMap { info -> pid_t? in
            guard info[kCGWindowLayer as String] as? Int == 0 else { return nil }
            return info[kCGWindowOwnerPID as String] as? pid_t
        })
        let applications = NSWorkspace.shared.runningApplications
        let knownPIDs = Set(applications.map(\.processIdentifier))
        let windowApps = windowOwners.subtracting(knownPIDs).compactMap { NSRunningApplication(processIdentifier: $0) }
        for app in applications + windowApps {
            let isRegular = app.activationPolicy == .regular
            guard isRegular || windowOwners.contains(app.processIdentifier) else { continue }
            var name: NSString?
            guard let identifier = OpenKeyManager.profileIdentifier(for: app, displayName: &name),
                  !identifier.isEmpty,
                  identifier != Bundle.main.bundleIdentifier,
                  !rules.contains(identifier),
                  isRegular || identifier.hasPrefix("windows-exe:") else { continue }
            found[identifier] = (name as String?) ?? identifier
        }
        return found.map { (id: $0.key, name: $0.value) }
            .sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
    }
}
