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
    @Published var isVietnameseMode: Bool = true  // Track Vietnamese/English state
    private var menuBarIconSize: Double = 18.0
    
    init() {
        // Load initial language state from UserDefaults
        let inputMethod = UserDefaults.standard.integer(forKey: "InputMethod")
        isVietnameseMode = (inputMethod == 1)
        
        setupStatusItem()
        setupNotificationObservers()
    }
    
    private func setupStatusItem() {
        // Use square length for icon-based status items (like system icons)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Configure button for icon display
            button.imagePosition = .imageOnly
            button.appearsDisabled = false
            
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
        
        // Create icon image based on language state
        if let image = createMenuBarIcon(size: size, isVietnamese: isVietnameseMode, isEnabled: isEnabled) {
            // Configure for menu bar display
            image.isTemplate = false  // Don't use template mode for text icons
            image.size = NSSize(width: size, height: size)
            
            button.image = image
            button.title = ""  // Clear title when using image
            button.imagePosition = .imageOnly
            
            // Configure button appearance for macOS 15
            if #available(macOS 11.0, *) {
                button.bezelStyle = .texturedRounded
            }
        }

        // Update tooltip
        let languageStatus = isVietnameseMode ? "Tiếng Việt" : "Tiếng Anh"
        button.toolTip = "PHTV - \(currentInputMethod) (\(currentCodeTable))\n\(languageStatus) - \(isEnabled ? "Đang bật" : "Đang tắt")"
    }
    
    private func createMenuBarIcon(size: CGFloat, isVietnamese: Bool, isEnabled: Bool) -> NSImage? {
        // Determine text based on language mode
        let text = isVietnamese ? "Vi" : "En"
        
        // Use modern NSImage rendering for macOS 15 compatibility
        if #available(macOS 10.15, *) {
            return createIconWithRenderer(size: size, text: text, isEnabled: isEnabled)
        } else {
            return createIconWithLockFocus(size: size, text: text, isEnabled: isEnabled)
        }
    }
    
    @available(macOS 10.15, *)
    private func createIconWithRenderer(size: CGFloat, text: String, isEnabled: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        
        image.lockFocus()
        defer { image.unlockFocus() }
        
        // Set up font
        let fontSize = size * 0.65  // Slightly smaller for "Vi"/"En"
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        
        // Use appropriate color that works in menu bar
        let textColor: NSColor
        if isEnabled {
            // Use a color that adapts to light/dark mode
            textColor = NSColor.labelColor
        } else {
            textColor = NSColor.secondaryLabelColor
        }
        
        // Create attributed string
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // Calculate text size and position to center it
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (size - textSize.width) / 2,
            y: (size - textSize.height) / 2 - fontSize * 0.15,  // Slight vertical adjustment
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw text
        attributedString.draw(in: textRect)
        
        return image
    }
    
    private func createIconWithLockFocus(size: CGFloat, text: String, isEnabled: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        
        image.lockFocus()
        defer { image.unlockFocus() }
        
        // Set up font
        let fontSize = size * 0.65
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        
        // Use appropriate color
        let textColor: NSColor = isEnabled ? NSColor.black : NSColor.gray
        
        // Create attributed string
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // Calculate text size and position to center it
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (size - textSize.width) / 2,
            y: (size - textSize.height) / 2 - fontSize * 0.15,
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw text
        attributedString.draw(in: textRect)
        
        return image
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
        
        // Listen for language changes from backend
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LanguageChangedFromBackend"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    // vLanguage: 0 = English, 1 = Vietnamese
                    self.isVietnameseMode = (language.intValue == 1)
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
