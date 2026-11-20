//
//  ControlPanel.swift
//  The SwiftUI control panel window, exposed to Objective-C as OKControlPanel.
//

import AppKit
import SwiftUI

enum PanelSection: String, CaseIterable, Identifiable, Hashable {
    case input, spelling, macro, apps, system, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .input: return "Bộ gõ"
        case .spelling: return "Chính tả & gõ nhanh"
        case .macro: return "Gõ tắt"
        case .apps: return "Theo ứng dụng"
        case .system: return "Hệ thống"
        case .about: return "Thông tin"
        }
    }

    var systemImage: String {
        switch self {
        case .input: return "keyboard"
        case .spelling: return "textformat"
        case .macro: return "text.badge.plus"
        case .apps: return "square.stack.3d.up"
        case .system: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

final class PanelNavigation: ObservableObject {
    private static let key = "ControlPanelSection"

    @Published var section: PanelSection? {
        didSet { UserDefaults.standard.set(section?.rawValue, forKey: Self.key) }
    }

    init() {
        section = UserDefaults.standard.string(forKey: Self.key).flatMap(PanelSection.init) ?? .input
    }
}

@objc(OKControlPanel)
final class ControlPanel: NSObject, NSWindowDelegate {
    @objc static let shared = ControlPanel()

    let store = SettingsStore()
    let navigation = PanelNavigation()
    private var window: NSWindow?

    @objc func show() {
        present(section: nil)
    }

    @objc func showAppProfiles() {
        present(section: .apps)
    }

    @objc func showAbout() {
        present(section: .about)
    }

    @objc func reload() {
        store.reload()
    }

    @objc func updatePermission(ready: Bool, hasAccessibility: Bool) {
        if store.permissionReady != ready { store.permissionReady = ready }
        if store.hasAccessibility != hasAccessibility { store.hasAccessibility = hasAccessibility }
    }

    private func present(section: PanelSection?) {
        if let section { navigation.section = section }
        let window = self.window ?? makeWindow()
        self.window = window
        store.reload()
        appDelegate.refreshInputPermission()
        if !window.isVisible { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let root = ControlPanelView()
            .environmentObject(store)
            .environmentObject(navigation)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.title = "OpenKey"
        window.subtitle = "Bộ gõ Tiếng Việt"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 820, height: 600))
        window.contentMinSize = NSSize(width: 700, height: 500)
        window.setFrameAutosaveName("OpenKeyControlPanel")
        window.delegate = self
        return window
    }
}

// MARK: - Root view

struct ControlPanelView: View {
    @EnvironmentObject private var store: SettingsStore
    @EnvironmentObject private var navigation: PanelNavigation

    var body: some View {
        NavigationSplitView {
            List(PanelSection.allCases, selection: $navigation.section) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
            .safeAreaInset(edge: .bottom) {
                LanguageBadge()
                    .padding(12)
            }
        } detail: {
            ZStack {
                PanelBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !store.permissionReady {
                            PermissionBanner()
                        }
                        detail(for: navigation.section ?? .input)
                    }
                    .padding(24)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle((navigation.section ?? .input).title)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    @ViewBuilder
    private func detail(for section: PanelSection) -> some View {
        switch section {
        case .input: InputSection()
        case .spelling: SpellingSection()
        case .macro: MacroSection()
        case .apps: AppProfilesSection()
        case .system: SystemSection()
        case .about: AboutSection()
        }
    }
}

/// Soft color field behind the content so the glass has something to refract.
struct PanelBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let strength = colorScheme == .dark ? 0.28 : 0.18
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Circle()
                .fill(Color.red.opacity(strength))
                .frame(width: 420)
                .blur(radius: 120)
                .offset(x: -220, y: -200)
            Circle()
                .fill(Color.yellow.opacity(strength * 0.9))
                .frame(width: 360)
                .blur(radius: 120)
                .offset(x: 240, y: 40)
            Circle()
                .fill(Color.blue.opacity(strength * 0.8))
                .frame(width: 380)
                .blur(radius: 130)
                .offset(x: -60, y: 300)
        }
        .ignoresSafeArea()
    }
}

/// Compact current-language indicator for the sidebar.
struct LanguageBadge: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        let vietnamese = store.isVietnamese.wrappedValue
        Button {
            store.isVietnamese.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                Text(vietnamese ? "V" : "E")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(vietnamese ? Color.red : Color.blue))
                VStack(alignment: .leading, spacing: 0) {
                    Text(vietnamese ? "Tiếng Việt" : "English").font(.callout.weight(.semibold))
                    Text("Bấm để đổi").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: 16, interactive: true)
        .help("Đổi chế độ gõ")
    }
}

struct PermissionBanner: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.hasAccessibility ? "Chưa bật được bộ gõ" : "OpenKey cần quyền Trợ năng")
                    .font(.headline)
                Text(store.hasAccessibility
                     ? "Hãy thử lại."
                     : "Cấp quyền trong Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Trợ năng.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(store.hasAccessibility ? "Thử lại" : "Cấp quyền") {
                appDelegate.requestInputPermission()
            }
            .glassButtonStyle(prominent: true)
        }
        .padding(16)
        .glassSurface(cornerRadius: 22, tint: .orange.opacity(0.25))
    }
}
