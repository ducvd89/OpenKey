//
//  LanguageHUD.swift
//  Floating Liquid Glass indicator shown when the input language switches.
//

import AppKit
import SwiftUI

final class LanguageHUDModel: ObservableObject {
    @Published var vietnamese = true
    @Published var whileHeld = false
}

struct LanguageHUDView: View {
    @ObservedObject var model: LanguageHUDModel
    @Namespace private var namespace

    var body: some View {
        GlassGroup(spacing: 8) {
            Group {
                if model.whileHeld {
                    option(vietnamese: model.vietnamese, selected: true)
                } else {
                    HStack(spacing: 6) {
                        option(vietnamese: false, selected: !model.vietnamese)
                        option(vietnamese: true, selected: model.vietnamese)
                    }
                    .padding(6)
                    .glassCapsule()
                }
            }
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
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(minWidth: 132)
        .glassCapsule(tint: selected ? (vietnamese ? .red : .blue) : nil)
        .glassID(vietnamese, in: namespace)
    }
}

@objc(OKLanguageHUD)
final class LanguageHUD: NSObject {
    private let model = LanguageHUDModel()
    private lazy var hosting = NSHostingView(rootView: LanguageHUDView(model: model))
    private lazy var panel: NSPanel = makePanel()
    private var hideTimer: Timer?

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
        let wasVisible = panel.isVisible
        if wasVisible {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                model.vietnamese = vietnamese
                model.whileHeld = whileHeld
            }
        } else {
            model.vietnamese = vietnamese
            model.whileHeld = whileHeld
        }
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

        hideTimer?.invalidate()
        hideTimer = nil
        if !whileHeld {
            let timer = Timer(timeInterval: 0.95, repeats: false) { [weak self] _ in self?.dismiss() }
            RunLoop.main.add(timer, forMode: .common)
            hideTimer = timer
        }
    }

    @objc func dismiss() {
        hideTimer?.invalidate()
        hideTimer = nil
        panel.orderOut(nil)
    }
}
