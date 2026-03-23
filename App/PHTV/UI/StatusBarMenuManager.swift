//
//  StatusBarMenuManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  Replaces SwiftUI MenuBarExtra to fix submenu hover behavior.
//  SwiftUI's Menu{} inside MenuBarExtra(.menu) does not expand on hover;
//  NSStatusItem + NSMenu gives native submenu behavior.
//

import AppKit
import Combine

@MainActor
final class StatusBarMenuManager: NSObject, NSMenuDelegate {
    static let shared = StatusBarMenuManager()

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let iconCache = NSCache<NSString, NSImage>()

    private var appState: AppState { AppState.shared }

    private override init() {
        super.init()
        iconCache.countLimit = 32
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        // Keep the icon in sync only with fields that actually affect its appearance.
        appState.$isEnabled
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        appState.uiState.$useVietnameseMenubarIcon
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        appState.uiState.$menuBarIconSize
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let name = resolvedIconName()
        let size = resolvedIconSize()
        button.image = renderedIcon(named: name, size: size)
    }

    private func resolvedIconName() -> String {
        if !appState.isEnabled { return "menubar_english" }
        return appState.useVietnameseMenubarIcon ? "menubar_vietnamese" : "menubar_icon"
    }

    private func resolvedIconSize() -> CGFloat {
        let minSize: CGFloat = 12
        let maxSize = max(minSize, NSStatusBar.system.thickness - 4)
        let requested = CGFloat(appState.menuBarIconSize)
        return min(max(requested, minSize), maxSize)
    }

    private func renderedIcon(named name: String, size: CGFloat) -> NSImage? {
        let key = "\(name)-\(Int((size * 10).rounded()))" as NSString
        if let cached = iconCache.object(forKey: key) { return cached }
        guard let base = NSImage(named: name)?.copy() as? NSImage else { return nil }
        base.isTemplate = true
        let target = NSSize(width: size, height: size)
        let result = NSImage(size: target)
        result.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: target),
                  from: .zero, operation: .sourceOver, fraction: 1,
                  respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        result.unlockFocus()
        result.isTemplate = true
        iconCache.setObject(result, forKey: key)
        return result
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        populate(menu)
    }

    // MARK: - Menu Structure

    private func populate(_ menu: NSMenu) {
        addLanguagePicker(to: menu)
        menu.addItem(.separator())

        menu.addItem(submenu("Bộ gõ", image: "keyboard.fill", build: buildBoGoMenu))
        menu.addItem(submenu("Tính năng", image: "star.fill", build: buildTinhNangMenu))
        menu.addItem(submenu("Tương thích", image: "wrench.and.screwdriver.fill", build: buildTuongThichMenu))
        menu.addItem(submenu("Hệ thống", image: "gearshape.fill", build: buildHeThongMenu))

        menu.addItem(.separator())

        menu.addItem(submenu("Công cụ", image: "hammer.fill", build: buildCongCuMenu))

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Mở Cài đặt...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        settingsItem.image = sfImage("slider.horizontal.3")
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        menu.addItem(actionItem("Về PHTV v\(version)", image: "info.circle", sel: #selector(openAbout)))
        menu.addItem(actionItem("Kiểm tra cập nhật", image: "arrow.down.circle", sel: #selector(checkUpdates)))

        let quitItem = NSMenuItem(title: "Thoát PHTV", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        quitItem.image = sfImage("power")
        menu.addItem(quitItem)
    }

    private func addLanguagePicker(to menu: NSMenu) {
        let hotkey = HotkeyFormatter.switchHotkeyString(
            control: appState.switchKeyControl,
            option: appState.switchKeyOption,
            shift: appState.switchKeyShift,
            command: appState.switchKeyCommand,
            fn: appState.switchKeyFn,
            keyCode: appState.switchKeyCode,
            keyName: appState.switchKeyName
        )
        let header = NSMenuItem(title: "Chế độ gõ (\(hotkey))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(radioItem("Tiếng Việt", image: "v.circle", on: appState.isEnabled, sel: #selector(setVietnamese)))
        menu.addItem(radioItem("Tiếng Anh", image: "e.circle", on: !appState.isEnabled, sel: #selector(setEnglish)))
    }

    // MARK: - Submenu Builders

    private func buildBoGoMenu() -> NSMenu {
        let m = NSMenu()

        sectionHeader("Phương pháp gõ", in: m)
        for method in InputMethod.allCases {
            m.addItem(closureRadio(method.displayName, on: appState.inputMethod == method) {
                AppState.shared.inputMethod = method
            })
        }

        m.addItem(.separator())

        sectionHeader("Bảng mã", in: m)
        for table in CodeTable.allCases {
            m.addItem(closureRadio(table.displayName, on: appState.codeTable == table) {
                AppState.shared.codeTable = table
            })
        }

        m.addItem(.separator())

        sectionHeader("Tùy chọn nhập", in: m)
        m.addItem(closureToggle("Gõ nhanh (Quick Telex)", image: "hare", on: appState.quickTelex) {
            AppState.shared.quickTelex.toggle()
        })
        m.addItem(closureToggle("Viết hoa đầu câu", image: "textformat.size.larger", on: appState.upperCaseFirstChar) {
            AppState.shared.upperCaseFirstChar.toggle()
        })
        m.addItem(closureToggle("Phụ âm Z, F, W, J", image: "character.cursor.ibeam", on: appState.allowConsonantZFWJ) {
            AppState.shared.allowConsonantZFWJ.toggle()
        })
        m.addItem(closureToggle("Phụ âm đầu nhanh", image: "arrow.right.to.line", on: appState.quickStartConsonant) {
            AppState.shared.quickStartConsonant.toggle()
        })
        m.addItem(closureToggle("Phụ âm cuối nhanh", image: "arrow.left.to.line", on: appState.quickEndConsonant) {
            AppState.shared.quickEndConsonant.toggle()
        })

        m.addItem(.separator())

        sectionHeader("Chính tả", in: m)
        m.addItem(closureToggle("Kiểm tra chính tả", image: "textformat.abc.dottedunderline", on: appState.checkSpelling) {
            AppState.shared.checkSpelling.toggle()
        })
        m.addItem(closureToggle("Chính tả mới (oà, uý)", image: "textformat.abc", on: appState.useModernOrthography) {
            AppState.shared.useModernOrthography.toggle()
        })

        return m
    }

    private func buildTinhNangMenu() -> NSMenu {
        let m = NSMenu()

        sectionHeader("Khôi phục", in: m)
        m.addItem(closureToggle("Tự động khôi phục tiếng Anh", image: "character.bubble", on: appState.autoRestoreEnglishWord) {
            AppState.shared.autoRestoreEnglishWord.toggle()
        })

        m.addItem(.separator())

        sectionHeader("Gõ tắt & Macro", in: m)
        m.addItem(closureToggle("Bật gõ tắt", image: "text.badge.plus", on: appState.useMacro) {
            AppState.shared.useMacro.toggle()
        })
        m.addItem(closureToggle("Gõ tắt khi ở chế độ Anh", image: "character.book.closed", on: appState.useMacroInEnglishMode) {
            AppState.shared.useMacroInEnglishMode.toggle()
        })
        m.addItem(closureToggle("Tự động viết hoa macro", image: "textformat.size", on: appState.autoCapsMacro) {
            AppState.shared.autoCapsMacro.toggle()
        })

        m.addItem(.separator())

        sectionHeader("Clipboard", in: m)
        m.addItem(closureToggle("Lịch sử Clipboard", image: "doc.on.clipboard.fill", on: appState.enableClipboardHistory) {
            AppState.shared.enableClipboardHistory.toggle()
        })

        m.addItem(.separator())

        sectionHeader("Chuyển đổi thông minh", in: m)
        m.addItem(closureToggle("Chuyển thông minh theo ứng dụng", image: "brain", on: appState.useSmartSwitchKey) {
            AppState.shared.useSmartSwitchKey.toggle()
        })
        m.addItem(closureToggle("Nhớ bảng mã theo ứng dụng", image: "memories", on: appState.rememberCode) {
            AppState.shared.rememberCode.toggle()
        })

        m.addItem(.separator())

        sectionHeader("Tạm dừng & phục hồi", in: m)
        m.addItem(closureToggle("Khôi phục khi nhấn \(appState.restoreKey.symbol)", image: "escape", on: appState.restoreOnEscape) {
            AppState.shared.restoreOnEscape.toggle()
        })
        m.addItem(closureToggle("Tạm dừng khi giữ \(appState.pauseKeyName)", image: "pause.circle", on: appState.pauseKeyEnabled) {
            AppState.shared.pauseKeyEnabled.toggle()
        })

        return m
    }

    private func buildTuongThichMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(closureToggle("Gửi phím từng bước", image: "arrow.down.to.line.compact", on: appState.sendKeyStepByStep) {
            AppState.shared.sendKeyStepByStep.toggle()
        })
        m.addItem(closureToggle("Tương thích layout", image: "keyboard.badge.ellipsis", on: appState.performLayoutCompat) {
            AppState.shared.performLayoutCompat.toggle()
        })
        return m
    }

    private func buildHeThongMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(closureToggle("Khởi động cùng máy", image: "power.circle", on: appState.runOnStartup) {
            AppState.shared.runOnStartup.toggle()
        })
        m.addItem(closureToggle("Hiện icon trên Dock", image: "dock.rectangle", on: appState.showIconOnDock) {
            AppState.shared.showIconOnDock.toggle()
        })
        m.addItem(closureToggle("Âm thanh khi chuyển chế độ", image: "speaker.wave.2", on: appState.beepOnModeSwitch) {
            AppState.shared.beepOnModeSwitch.toggle()
        })

        m.addItem(.separator())

        if appState.isTypingPermissionReady {
            let item = NSMenuItem(title: "Đã cấp quyền Accessibility", action: nil, keyEquivalent: "")
            item.image = sfImage("checkmark.shield")
            item.isEnabled = false
            m.addItem(item)
        } else if appState.hasAccessibilityPermission {
            let item = NSMenuItem(title: "Đã cấp quyền, đang khởi tạo", action: nil, keyEquivalent: "")
            item.image = sfImage("clock.badge.exclamationmark")
            item.isEnabled = false
            m.addItem(item)
        } else {
            m.addItem(actionItem("Cần cấp quyền Accessibility", image: "exclamationmark.shield", sel: #selector(openAccessibilityPrefs)))
        }

        return m
    }

    private func buildCongCuMenu() -> NSMenu {
        let m = NSMenu()

        sectionHeader("Chuyển nhanh Clipboard", in: m)
        m.addItem(closureAction("TCVN3 → Unicode", image: "arrow.right") { self.quickConvert(from: 1, to: 0) })
        m.addItem(closureAction("VNI → Unicode", image: "arrow.right") { self.quickConvert(from: 2, to: 0) })
        m.addItem(closureAction("Unicode → TCVN3", image: "arrow.right") { self.quickConvert(from: 0, to: 1) })
        m.addItem(closureAction("Tổ hợp → Unicode", image: "arrow.right") { self.quickConvert(from: 3, to: 0) })

        m.addItem(.separator())
        m.addItem(actionItem("Chuyển đổi bảng mã...", image: "arrow.triangle.2.circlepath", sel: #selector(openConvertTool)))

        return m
    }

    // MARK: - Item Factories

    private func submenu(_ title: String, image: String, build: () -> NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = sfImage(image)
        item.submenu = build()
        return item
    }

    private func actionItem(_ title: String, image: String? = nil, sel: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        item.target = self
        if let image { item.image = sfImage(image) }
        return item
    }

    private func radioItem(_ title: String, image: String? = nil, on: Bool, sel: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        if let image { item.image = sfImage(image) }
        return item
    }

    private func closureToggle(_ title: String, image: String? = nil, on: Bool, handler: @escaping () -> Void) -> NSMenuItem {
        let item = MenuCallbackItem(title: title, handler: handler)
        item.state = on ? .on : .off
        if let image { item.image = sfImage(image) }
        return item
    }

    private func closureRadio(_ title: String, image: String? = nil, on: Bool, handler: @escaping () -> Void) -> NSMenuItem {
        let item = MenuCallbackItem(title: title, handler: handler)
        item.state = on ? .on : .off
        if let image { item.image = sfImage(image) }
        return item
    }

    private func closureAction(_ title: String, image: String? = nil, handler: @escaping () -> Void) -> NSMenuItem {
        let item = MenuCallbackItem(title: title, handler: handler)
        if let image { item.image = sfImage(image) }
        return item
    }

    private func sectionHeader(_ title: String, in menu: NSMenu) {
        if #available(macOS 14, *) {
            menu.addItem(.sectionHeader(title: title))
        } else {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func sfImage(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    // MARK: - Actions

    @objc private func setVietnamese() { AppState.shared.isEnabled = true }
    @objc private func setEnglish() { AppState.shared.isEnabled = false }

    @objc private func openSettings() {
        SettingsWindowOpener.shared.requestOpenWindow()
    }

    @objc private func openAbout() {
        SettingsWindowOpener.shared.requestOpenWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NotificationName.showAboutTab, object: nil)
        }
    }

    @objc private func checkUpdates() {
        NotificationCenter.default.post(name: NotificationName.sparkleManualCheck, object: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func openAccessibilityPrefs() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openConvertTool() {
        SettingsWindowOpener.shared.requestOpenWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(name: NotificationName.showConvertToolSheet, object: nil)
        }
    }

    private func quickConvert(from source: Int, to target: Int) {
        let original = UserDefaults.standard.integer(forKey: UserDefaultsKey.codeTable)
        UserDefaults.standard.set(source, forKey: UserDefaultsKey.codeTable)
        if PHTVManager.quickConvert() { NSSound.beep() }
        UserDefaults.standard.set(original, forKey: UserDefaultsKey.codeTable)
    }
}

// MARK: - MenuCallbackItem

/// NSMenuItem subclass that stores and invokes a closure when selected.
/// NSMenuItem does NOT retain its target, so target = self is safe here.
private final class MenuCallbackItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func invoke() {
        handler()
    }
}
