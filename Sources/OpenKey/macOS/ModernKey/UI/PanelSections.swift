//
//  PanelSections.swift
//  Content of each control panel section.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - Input

struct InputSection: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        VStack(spacing: 16) {
            GlassCard(title: "Chế độ gõ", systemImage: "globe") {
                GlassSegmented(options: [true, false], selection: store.isVietnamese) { vietnamese in
                    vietnamese ? ("Tiếng Việt", "character.textbox") : ("English", "abc")
                }
            }

            GlassCard(title: "Kiểu gõ & bảng mã", systemImage: "keyboard") {
                Picker("Kiểu gõ", selection: store.inputType) {
                    ForEach(SettingsStore.inputTypes.indices, id: \.self) { index in
                        Text(SettingsStore.inputTypes[index]).tag(index)
                    }
                }
                Picker("Bảng mã", selection: store.codeTable) {
                    ForEach(store.codeTables.indices, id: \.self) { index in
                        Text(store.codeTables[index]).tag(index)
                    }
                }
            }

            GlassCard(title: "Phím chuyển chế độ", systemImage: "command") {
                HStack(spacing: 8) {
                    GlassGroup(spacing: 6) {
                        HStack(spacing: 6) {
                            ModifierChip(symbol: "⌃", help: "Phím Control", isOn: store.switchBit(SettingsStore.controlMask))
                            ModifierChip(symbol: "⌥", help: "Phím Option", isOn: store.switchBit(SettingsStore.optionMask))
                            ModifierChip(symbol: "⌘", help: "Phím Command", isOn: store.switchBit(SettingsStore.commandMask))
                            ModifierChip(symbol: "⇧", help: "Phím Shift", isOn: store.switchBit(SettingsStore.shiftMask))
                        }
                    }
                    Text("+").foregroundStyle(.secondary)
                    KeyRecorder()
                    Spacer()
                }
                SettingToggle(title: "Kêu beep khi chuyển",
                              caption: "Không áp dụng cho chuyển chế độ thông minh.",
                              isOn: store.switchBit(SettingsStore.beepMask))
                Divider()
                SettingToggle(title: "Đổi bằng phím 🌐/Fn",
                              caption: "Nhấn rồi thả riêng phím 🌐/Fn để đổi Tiếng Việt và Tiếng Anh. Nên đặt phím 🌐 của macOS thành “Không làm gì”.",
                              isOn: store.switchLanguageWithFn)
                SettingToggle(title: "Hiện bảng báo ngôn ngữ",
                              caption: "Hiện ngôn ngữ hiện tại khi giữ 🌐/Fn, hoặc sau khi chuyển bằng phím tắt.",
                              isOn: store.showLanguageSwitchHUD)
            }
        }
    }
}

struct ModifierChip: View {
    let symbol: String
    let help: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { isOn.toggle() }
        } label: {
            Text(symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .frame(width: 40, height: 34)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassCapsule(tint: isOn ? .accentColor : nil, interactive: true)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Click, then press a key to set the switch key. Delete clears it; Esc cancels.
struct KeyRecorder: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Nhấn một phím…" : store.switchKeyDisplay)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(recording ? Color.white : Color.primary)
                .frame(minWidth: 90, minHeight: 34)
                .padding(.horizontal, 6)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassCapsule(tint: recording ? .accentColor : nil, interactive: true)
        .help("Bấm rồi nhấn phím muốn dùng. Delete để bỏ phím, Esc để huỷ.")
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                break
            case kVK_Space:
                store.setSwitchKey(keyCode: UInt32(kVK_Space), character: UInt32(kVK_Space))
            case kVK_Delete, kVK_ForwardDelete:
                store.setSwitchKey(keyCode: SettingsStore.noKey, character: SettingsStore.noKey)
            default:
                let character = event.charactersIgnoringModifiers?.utf8.first ?? 0
                store.setSwitchKey(keyCode: UInt32(event.keyCode), character: UInt32(character))
            }
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}

// MARK: - Spelling

struct SpellingSection: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        let spelling = store.flag("Spelling") { vCheckSpelling = $0 } after: { _ in OnSpellCheckingChanged() }
        VStack(spacing: 16) {
            GlassCard(title: "Đặt dấu", systemImage: "textformat") {
                SettingToggle(title: "Cho phép bỏ dấu tự do", isOn: store.flag("FreeMark") { vFreeMark = $0 })
                SettingToggle(title: "Đặt dấu oà, uý (thay vì òa, úy)",
                              isOn: store.flag("ModernOrthography") { vUseModernOrthography = $0 })
            }

            GlassCard(title: "Chính tả", systemImage: "checkmark.seal") {
                SettingToggle(title: "Kiểm tra chính tả",
                              caption: "Hạn chế gõ sai từ tiếng Việt.",
                              isOn: spelling)
                Group {
                    SettingToggle(title: "Tự khôi phục phím với từ sai",
                                  caption: "Từ không hợp lệ sẽ được trả lại đúng các phím đã gõ.",
                                  isOn: store.flag("RestoreIfInvalidWord") { vRestoreIfWrongSpelling = $0 })
                    SettingToggle(title: "Cho phép “z w j f” làm phụ âm",
                                  isOn: store.flag("vAllowConsonantZFWJ") { vAllowConsonantZFWJ = $0 })
                    SettingToggle(title: "Tạm tắt chính tả bằng phím ⌃",
                                  caption: "Dùng khi gõ các từ như Đắk Lắk, Krông…",
                                  isOn: store.flag("vTempOffSpelling") { vTempOffSpelling = $0 })
                }
                .padding(.leading, 16)
                .disabled(!spelling.wrappedValue)
            }

            GlassCard(title: "Gõ nhanh", systemImage: "hare") {
                SettingToggle(title: "Gõ nhanh Telex",
                              caption: "cc=ch, gg=gi, kk=kh, nn=ng, qq=qu, pp=ph, tt=th",
                              isOn: store.flag("QuickTelex") { vQuickTelex = $0 })
                SettingToggle(title: "Gõ tắt phụ âm đầu",
                              caption: "f→ph, j→gi, w→qu. Ví dụ: fải→phải",
                              isOn: store.flag("vQuickStartConsonant") { vQuickStartConsonant = $0 })
                SettingToggle(title: "Gõ tắt phụ âm cuối",
                              caption: "g→ng, h→nh, k→ch. Ví dụ: trươg→trương",
                              isOn: store.flag("vQuickEndConsonant") { vQuickEndConsonant = $0 })
                SettingToggle(title: "Viết hoa chữ cái đầu câu",
                              caption: "Sau dấu chấm câu và khi xuống dòng.",
                              isOn: store.flag("UpperCaseFirstChar") { vUpperCaseFirstChar = $0 })
            }
        }
    }
}

// MARK: - Macro

struct MacroSection: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        VStack(spacing: 16) {
            GlassCard(title: "Gõ tắt", systemImage: "text.badge.plus") {
                SettingToggle(title: "Cho phép gõ tắt", isOn: store.flag("UseMacro") { vUseMacro = $0 })
                SettingToggle(title: "Gõ tắt cả khi đang gõ tiếng Anh",
                              isOn: store.flag("UseMacroInEnglishMode") { vUseMacroInEnglishMode = $0 })
                SettingToggle(title: "Tự động viết hoa theo phím tắt",
                              isOn: store.flag("vAutoCapsMacro") { vAutoCapsMacro = $0 })
                HStack {
                    Button("Bảng gõ tắt…", systemImage: "list.bullet.rectangle") {
                        appDelegate.onMacroSelected()
                    }
                    .glassButtonStyle(prominent: true)
                }
            }

            GlassCard(title: "Chuyển mã", systemImage: "arrow.left.arrow.right") {
                Text("Chuyển văn bản trong clipboard giữa các bảng mã, đổi chữ hoa/thường hoặc bỏ dấu.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Công cụ chuyển mã…", systemImage: "wand.and.stars") {
                        appDelegate.onConvertTool()
                    }
                    .glassButtonStyle()
                    Button("Chuyển mã nhanh", systemImage: "bolt") {
                        appDelegate.onQuickConvert()
                    }
                    .glassButtonStyle()
                }
            }
        }
    }
}

// MARK: - System

struct SystemSection: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var confirmReset = false

    var body: some View {
        let fixRecommend = store.flag("FixRecommendBrowser") { vFixRecommendBrowser = $0 }
        VStack(spacing: 16) {
            GlassCard(title: "Khởi động", systemImage: "power") {
                SettingToggle(title: "Khởi động cùng macOS",
                              isOn: store.flag("RunOnStartup") { appDelegate.setRunOnStartup($0 != 0) })
                SettingToggle(title: "Mở bảng này khi khởi động", isOn: store.flag("ShowUIOnStartup"))
                SettingToggle(title: "Kiểm tra bản mới lúc khởi động", isOn: store.checkUpdateOnStartup)
            }

            GlassCard(title: "Giao diện", systemImage: "menubar.rectangle") {
                SettingToggle(title: "Biểu tượng đơn sắc trên thanh menu",
                              isOn: store.flag("GrayIcon") { appDelegate.setGrayIcon($0 != 0) })
                SettingToggle(title: "Hiện biểu tượng trên Dock",
                              isOn: store.flag("vShowIconOnDock") {
                                  vShowIconOnDock = $0
                                  appDelegate.showIcon(onDock: $0 != 0)
                              })
            }

            GlassCard(title: "Tương thích", systemImage: "wrench.and.screwdriver") {
                SettingToggle(title: "Sửa lỗi gợi ý (trình duyệt, Excel…)",
                              caption: "Tránh lặp chữ ở thanh địa chỉ và ô có gợi ý.",
                              isOn: fixRecommend)
                SettingToggle(title: "Sửa lỗi trên Chromium (beta)",
                              isOn: store.flag("vFixChromiumBrowser") { vFixChromiumBrowser = $0 })
                    .padding(.leading, 16)
                    .disabled(!fixRecommend.wrappedValue)
                SettingToggle(title: "Gửi từng phím",
                              caption: "Mặc định nên tắt. Bật nếu một ứng dụng bị lỗi khi gõ.",
                              isOn: store.flag("SendKeyStepByStep") { vSendKeyStepByStep = $0 })
                SettingToggle(title: "Tương thích Telex trên layout khác",
                              caption: "Dvorak, Colemak…",
                              isOn: store.flag("vPerformLayoutCompat") { vPerformLayoutCompat = $0 })
            }

            HStack {
                Button("Khôi phục mặc định", systemImage: "arrow.counterclockwise") {
                    confirmReset = true
                }
                .glassButtonStyle()
                Spacer()
                Button("Thoát OpenKey", systemImage: "xmark.circle", role: .destructive) {
                    NSApp.terminate(nil)
                }
                .glassButtonStyle()
            }
        }
        .confirmationDialog("Khôi phục cấu hình mặc định?", isPresented: $confirmReset) {
            Button("Khôi phục", role: .destructive) { store.resetToDefaults() }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Mọi tuỳ chọn sẽ trở về giá trị ban đầu.")
        }
    }
}

// MARK: - About

struct AboutSection: View {
    @EnvironmentObject private var store: SettingsStore

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "Phiên bản \(short) (build \(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Text("OpenKey").font(.largeTitle.weight(.bold))
                Text("Bộ gõ Tiếng Việt mã nguồn mở").foregroundStyle(.secondary)
                Text("\(version) · \(OpenKeyManager.getBuildDate() ?? "")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button {
                    store.checkForUpdate(window: NSApp.keyWindow)
                } label: {
                    if store.isCheckingUpdate {
                        Label("Đang kiểm tra…", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("Kiểm tra bản mới", systemImage: "arrow.down.circle")
                    }
                }
                .glassButtonStyle(prominent: true)
                .disabled(store.isCheckingUpdate)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .glassSurface(cornerRadius: 28)

            GlassCard(title: "Liên kết", systemImage: "link") {
                HStack {
                    link("Bản phát hành", "shippingbox", "https://github.com/ducvd89/OpenKey/releases")
                    link("Mã nguồn", "chevron.left.forwardslash.chevron.right", "https://github.com/ducvd89/OpenKey")
                    link("Bản gốc", "arrow.triangle.branch", "https://github.com/tuyenvm/OpenKey")
                }
                Text("Bản tuỳ biến của ducvd89, dựa trên OpenKey của Mai Vũ Tuyên. Phát hành theo giấy phép GPL.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func link(_ title: String, _ systemImage: String, _ url: String) -> some View {
        Button(title, systemImage: systemImage) {
            if let url = URL(string: url) { NSWorkspace.shared.open(url) }
        }
        .glassButtonStyle()
    }
}
