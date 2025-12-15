//
//  StatusBarController.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

@MainActor
class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    @Published var currentInputMethod: String = "VN"
    @Published var currentCodeTable: String = "Unicode"
    @Published var isEnabled: Bool = true
    private var menuBarIconSize: Double = 18.0
    
    init() {
        setupStatusItem()
        setupNotificationObservers()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateStatusButton()
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        setupMenu()
    }
    
    @objc private func statusBarButtonClicked(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            statusItem?.menu = createMenu()
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // Left click - show settings
            showSettings()
        }
    }
    
    private func setupMenu() {
        // Menu will be created dynamically on right-click
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Status section
        let statusItem = NSMenuItem(title: isEnabled ? "Đang bật" : "Đang tắt", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Input Method section
        let inputMethodMenu = NSMenu()
        let inputMethods = [
            ("Telex", 0),
            ("VNI", 1),
            ("Simple Telex 1", 2),
            ("Simple Telex 2", 3)
        ]
        
        for (name, tag) in inputMethods {
            let item = NSMenuItem(title: name, action: #selector(selectInputMethod(_:)), keyEquivalent: "")
            item.tag = tag
            item.target = self
            item.state = (tag == 0) ? .on : .off
            inputMethodMenu.addItem(item)
        }
        
        let inputMethodItem = NSMenuItem(title: "Kiểu gõ", action: nil, keyEquivalent: "")
        inputMethodItem.submenu = inputMethodMenu
        menu.addItem(inputMethodItem)
        
        // Code Table section
        let codeTableMenu = NSMenu()
        let codeTables = [
            ("Unicode", 0),
            ("TCVN3", 1),
            ("VNI Windows", 2),
            ("Unicode Composite", 3),
            ("Vietnamese Locale (CP1258)", 4)
        ]
        
        for (name, tag) in codeTables {
            let item = NSMenuItem(title: name, action: #selector(selectCodeTable(_:)), keyEquivalent: "")
            item.tag = tag
            item.target = self
            item.state = (tag == 0) ? .on : .off
            codeTableMenu.addItem(item)
        }
        
        let codeTableItem = NSMenuItem(title: "Bảng mã", action: nil, keyEquivalent: "")
        codeTableItem.submenu = codeTableMenu
        menu.addItem(codeTableItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick actions
        menu.addItem(NSMenuItem(title: "Tạm tắt (\(getHotkeyString()))", action: #selector(toggleEnabled), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Công cụ chuyển mã", action: #selector(showConvertTool), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        menu.addItem(NSMenuItem(title: "Cài đặt...", action: #selector(showSettingsMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Về PHTV...", action: #selector(showAbout), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        menu.addItem(NSMenuItem(title: "Thoát PHTV", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    @objc private func selectInputMethod(_ sender: NSMenuItem) {
        // Update input method
        let methods = ["Telex", "VNI", "Simple Telex 1", "Simple Telex 2"]
        currentInputMethod = methods[sender.tag]
        updateStatusButton()
        
        // Notify backend (will bridge to Objective-C)
        NotificationCenter.default.post(name: NSNotification.Name("InputMethodChanged"), object: sender.tag)
    }
    
    @objc private func selectCodeTable(_ sender: NSMenuItem) {
        // Update code table
        let tables = ["Unicode", "TCVN3", "VNI Windows", "Unicode Composite", "CP1258"]
        currentCodeTable = tables[sender.tag]
        
        // Notify backend
        NotificationCenter.default.post(name: NSNotification.Name("CodeTableChanged"), object: sender.tag)
    }
    
    @objc private func toggleEnabled() {
        isEnabled.toggle()
        updateStatusButton()
        
        // Notify backend
        NotificationCenter.default.post(name: NSNotification.Name("ToggleEnabled"), object: isEnabled)
    }
    
    @objc private func showConvertTool() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowConvertTool"), object: nil)
    }
    
    @objc private func showSettingsMenu() {
        showSettings()
    }
    
    @objc private func showAbout() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowAbout"), object: nil)
    }
    
    private func showSettings() {
        // Open settings window
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
    
    func updateStatusButton() {
        guard let button = statusItem?.button else { return }

        let size = CGFloat(menuBarIconSize)
        if let image = makeMenuBarIcon(size: size, slashed: !isEnabled) {
            image.isTemplate = true
            image.size = NSSize(width: size, height: size)
            button.image = image
            button.title = ""
            button.imagePosition = .imageOnly
        }

        // Update tooltip
        button.toolTip = "PHTV - \(currentInputMethod) (\(currentCodeTable))\n\(isEnabled ? "Đang bật" : "Đang tắt")"
    }

    private func makeMenuBarIcon(size: CGFloat, slashed: Bool) -> NSImage? {
        let baseIcon: NSImage? = {
            if let img = NSImage(named: "menubar_icon") {
                return img
            }
            return NSApplication.shared.applicationIconImage
        }()
        guard let baseIcon else { return nil }
        let targetSize = NSSize(width: size, height: size)
        let img = NSImage(size: targetSize)
        img.lockFocus()
        defer { img.unlockFocus() }

        // Draw app icon scaled to fit
        let rect = NSRect(origin: .zero, size: targetSize)
        let fraction: CGFloat = slashed ? 0.35 : 1.0
        baseIcon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: fraction, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])

        return img
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MenuBarIconSizeChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let size = notification.object as? NSNumber {
                Task { @MainActor in
                    self.menuBarIconSize = size.doubleValue
                    self.updateStatusButton()
                }
            }
        }
    }
    
    private func getHotkeyString() -> String {
        // Get hotkey from AppState
        let appState = AppState.shared
        var parts: [String] = []
        if appState.switchKeyCommand { parts.append("⌘") }
        if appState.switchKeyOption { parts.append("⌥") }
        if appState.switchKeyControl { parts.append("⌃") }
        if appState.switchKeyShift { parts.append("⇧") }
        parts.append("Z")
        return parts.joined()
    }
}

// MARK: - SwiftUI Integration
struct StatusBarView: View {
    @StateObject private var controller = StatusBarController()
    
    var body: some View {
        EmptyView()
            .onAppear {
                // Status bar is managed by the controller
            }
    }
}
