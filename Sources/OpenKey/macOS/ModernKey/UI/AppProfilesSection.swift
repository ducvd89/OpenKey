//
//  AppProfilesSection.swift
//  Per-application language rules and smart-switch options.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppProfilesSection: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var runningApps: [(id: String, name: String)] = []
    @State private var message: String?

    var body: some View {
        VStack(spacing: 16) {
            GlassCard(title: "Chuyển chế độ thông minh", systemImage: "sparkles") {
                SettingToggle(title: "Tự ghi nhớ chế độ gõ theo ứng dụng",
                              caption: "Mỗi ứng dụng giữ chế độ gõ bạn dùng lần cuối.",
                              isOn: store.flag("UseSmartSwitchKey") { vUseSmartSwitchKey = $0 })
                SettingToggle(title: "Tự ghi nhớ bảng mã theo ứng dụng",
                              isOn: store.flag("vRememberCode") { vRememberCode = $0 })
                SettingToggle(title: "Tắt tiếng Việt khi bộ gõ hệ thống khác tiếng Anh",
                              isOn: store.flag("vOtherLanguage") { vOtherLanguage = $0 })
                SettingToggle(title: "Tạm tắt OpenKey bằng phím ⌘",
                              caption: "Bấm Command để tạm ngừng cho tới khi bắt đầu từ mới.",
                              isOn: store.flag("vTempOffOpenKey") { vTempOffOpenKey = $0 })
            }

            GlassCard(title: "Quy tắc cố định", systemImage: "square.stack.3d.up") {
                Text("Luôn dùng một chế độ gõ khi mở các ứng dụng dưới đây. Quy tắc được ưu tiên hơn ghi nhớ tự động.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if store.profiles.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "app.dashed").font(.largeTitle).foregroundStyle(.tertiary)
                            Text("Chưa có quy tắc nào").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.profiles) { profile in
                            ProfileRow(profile: profile)
                        }
                    }
                }

                HStack {
                    Menu {
                        Button("Duyệt ứng dụng…", systemImage: "folder", action: browse)
                        if !runningApps.isEmpty {
                            Divider()
                            Section("Ứng dụng đang chạy") {
                                ForEach(runningApps, id: \.id) { app in
                                    Button(app.name) { add(app.id, app.name) }
                                }
                            }
                        }
                    } label: {
                        Label("Thêm ứng dụng", systemImage: "plus")
                    }
                    .fixedSize()
                    .glassButtonStyle(prominent: true)

                    if let message {
                        Text(message).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .onAppear(perform: refreshRunningApps)
        .onChange(of: store.profiles) { _ in refreshRunningApps() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            refreshRunningApps()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            refreshRunningApps()
        }
    }

    private func refreshRunningApps() {
        runningApps = store.runningAppsWithoutProfile()
    }

    private func add(_ identifier: String?, _ name: String?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            message = store.addProfile(identifier: identifier, name: name)
                ? nil : "Hãy chọn một ứng dụng macOS khác."
        }
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.prompt = "Thêm"
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url, let bundle = Bundle(url: url) else { return }
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            add(bundle.bundleIdentifier, name)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }
}

private struct ProfileRow: View {
    @EnvironmentObject private var store: SettingsStore
    let profile: AppProfile

    private var icon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.id) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 28, height: 28)
            } else {
                Image(systemName: "macwindow").font(.title3).frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name).lineLimit(1)
                Text(profile.id).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Picker("Chế độ gõ của \(profile.name)", selection: Binding(
                get: { profile.vietnamese },
                set: { store.setProfile(profile.id, vietnamese: $0) }
            )) {
                Text("Tiếng Việt").tag(true)
                Text("English").tag(false)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    store.removeProfile(profile.id)
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Xoá quy tắc")
            .accessibilityLabel("Xoá quy tắc của \(profile.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14)
    }
}
