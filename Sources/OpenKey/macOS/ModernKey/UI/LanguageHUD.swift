//
//  LanguageHUD.swift
//  Floating Liquid Glass indicator shown when the input language switches.
//

import AppKit
import SwiftUI

final class LanguageHUDModel: ObservableObject {
    @Published var vietnamese = true
}

struct LanguageHUDView: View {
    @ObservedObject var model: LanguageHUDModel
    private let optionWidth: CGFloat = 132
    private let optionHeight: CGFloat = 44
    private let optionSpacing: CGFloat = 6

    var body: some View {
        GlassGroup(spacing: 8) {
            HStack(spacing: optionSpacing) {
                option(vietnamese: false, selected: !model.vietnamese)
                option(vietnamese: true, selected: model.vietnamese)
            }
            .background(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 0.14, green: 0.36, blue: 0.76).gradient)
                    .frame(width: optionWidth, height: optionHeight)
                    .offset(x: model.vietnamese ? optionWidth + optionSpacing : 0)
                    .accessibilityHidden(true)
            }
            .padding(6)
            .glassCapsule()
        }
        .padding(16)
        .fixedSize()
    }

    private func option(vietnamese: Bool, selected: Bool) -> some View {
        HStack(spacing: 8) {
            Text(vietnamese ? "V" : "E")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .frame(width: 22, height: 22)
                .background(Circle().fill(selected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)))
            Text(vietnamese ? "Tiếng Việt" : "English")
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(width: optionWidth, height: optionHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vietnamese ? "Tiếng Việt" : "English")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

@objc(OKLanguageHUD)
final class LanguageHUD: NSObject {
    private let model = LanguageHUDModel()
    private lazy var hosting = NSHostingView(rootView: LanguageHUDView(model: model))
    private lazy var panel: NSPanel = makePanel()
    private var hideTimer: Timer?
    private var showingPreview = false

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = hosting
        return panel
    }

    @objc(showVietnamese:whileHeld:)
    func show(vietnamese: Bool, whileHeld: Bool) {
        updateSelection(vietnamese: vietnamese)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let frame = NSRect(x: visible.midX - size.width / 2,
                           y: visible.minY + visible.height * 0.25,
                           width: size.width, height: size.height)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        showingPreview = whileHeld
        hideTimer?.invalidate()
        hideTimer = nil
        if !whileHeld {
            scheduleDismissal(after: 0.95)
        }
    }

    @objc(finishPreviewWithVietnamese:)
    func finishPreview(vietnamese: Bool) {
        guard showingPreview, panel.isVisible else { return }
        showingPreview = false
        updateSelection(vietnamese: vietnamese)
        scheduleDismissal(after: 0.65)
    }

    private func updateSelection(vietnamese: Bool) {
        if panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.83)) {
                model.vietnamese = vietnamese
            }
        } else {
            model.vietnamese = vietnamese
        }
    }

    private func scheduleDismissal(after delay: TimeInterval) {
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in self?.dismiss() }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }

    @objc func dismiss() {
        showingPreview = false
        hideTimer?.invalidate()
        hideTimer = nil
        panel.orderOut(nil)
    }
}
