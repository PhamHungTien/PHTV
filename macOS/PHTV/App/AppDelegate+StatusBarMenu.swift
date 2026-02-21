//
//  AppDelegate+StatusBarMenu.swift
//  PHTV
//
//  Swift port of AppDelegate+StatusBarMenu.mm.
//

import AppKit
import Foundation

@MainActor
private enum PHTVStatusBarMenuCache {
    static var statusFont: NSFont?
    static var lastFontSize: CGFloat = 0
}

@MainActor @objc extension AppDelegate {
    func createStatusBarMenu() {
        if !Thread.isMainThread {
            NSLog("[StatusBar] createStatusBarMenu called off main thread - dispatching to main")
            DispatchQueue.main.sync {
                self.createStatusBarMenu()
            }
            return
        }

        NSLog("[StatusBar] Creating status bar menu...")

        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            NSLog("[StatusBar] FATAL - Status item has no button")
            return
        }

        button.title = "En"
        button.toolTip = "PHTV - Bộ gõ tiếng Việt"

        if #available(macOS 11.0, *) {
            button.bezelStyle = .texturedRounded
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        if #available(macOS 10.15, *) {
            menu.font = NSFont.menuFont(ofSize: 0)
        }
        statusMenu = menu

        menuInputMethod = NSMenuItem(title: "Bật Tiếng Việt",
                                     action: #selector(onInputMethodSelected),
                                     keyEquivalent: "v")
        menuInputMethod?.target = self
        menuInputMethod?.keyEquivalentModifierMask = [.command, .shift]
        if let menuInputMethod {
            menu.addItem(menuInputMethod)
        }

        menu.addItem(.separator())

        let menuInputType = NSMenuItem(title: "Kiểu gõ", action: nil, keyEquivalent: "")
        menuInputType.isEnabled = true
        menu.addItem(menuInputType)

        let menuCode = NSMenuItem(title: "Bảng mã", action: nil, keyEquivalent: "")
        menuCode.isEnabled = true
        menu.addItem(menuCode)

        let menuOptions = NSMenuItem(title: "Tùy chọn gõ", action: nil, keyEquivalent: "")
        menuOptions.isEnabled = true
        menu.addItem(menuOptions)

        menu.addItem(.separator())

        mnuQuickConvert = NSMenuItem(title: "Chuyển mã nhanh",
                                     action: #selector(onQuickConvert),
                                     keyEquivalent: "")
        mnuQuickConvert?.target = self
        if let mnuQuickConvert {
            menu.addItem(mnuQuickConvert)
        }

        menu.addItem(.separator())

        let startupItem = NSMenuItem(title: "Khởi động cùng hệ thống",
                                     action: #selector(toggleStartupItem(_:)),
                                     keyEquivalent: "")
        startupItem.target = self
        menu.addItem(startupItem)

        menu.addItem(.separator())

        let controlPanelItem = NSMenuItem(title: "Bảng điều khiển...",
                                          action: #selector(onControlPanelSelected),
                                          keyEquivalent: ",")
        controlPanelItem.target = self
        controlPanelItem.keyEquivalentModifierMask = [.command]
        menu.addItem(controlPanelItem)

        let macroItem = NSMenuItem(title: "Gõ tắt...",
                                   action: #selector(onMacroSelected),
                                   keyEquivalent: "m")
        macroItem.target = self
        macroItem.keyEquivalentModifierMask = [.command]
        menu.addItem(macroItem)

        let aboutItem = NSMenuItem(title: "Giới thiệu",
                                   action: #selector(onAboutSelected),
                                   keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Thoát PHTV",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        quitItem.target = NSApp
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        setInputTypeMenu(menuInputType)
        setCodeMenu(menuCode)
        setOptionsMenu(menuOptions)

        statusItem.menu = statusMenu

        NSLog("[StatusBar] Menu created successfully")
        NSLog("[StatusBar] Total items: %ld", statusMenu.numberOfItems)
        NSLog("[StatusBar] Button title: '%@'", button.title)
        NSLog("[StatusBar] Menu assigned: %@", statusItem.menu != nil ? "YES" : "NO")

        fillData(withAnimation: false)
    }

    func setQuickConvertString() {
        mnuQuickConvert?.title = PHTVEngineDataBridge.quickConvertMenuTitle()
    }

    func fillData() {
        fillData(withAnimation: true)
    }

    @objc(fillDataWithAnimation:)
    func fillData(withAnimation animated: Bool) {
        _ = animated

        guard let button = statusItem.button else {
            return
        }

        let inputMethod = Int(PHTVManager.currentLanguage())
        let inputType = Int(PHTVManager.currentInputType())
        let codeTable = Int(PHTVManager.currentCodeTable())
        let runtimeSettings = PHTVManager.runtimeSettingsSnapshot()

        let desiredSize = statusBarFontSize > 0 ? statusBarFontSize : 12.0
        if PHTVStatusBarMenuCache.statusFont == nil || PHTVStatusBarMenuCache.lastFontSize != desiredSize {
            PHTVStatusBarMenuCache.lastFontSize = desiredSize
            PHTVStatusBarMenuCache.statusFont = NSFont.monospacedSystemFont(ofSize: desiredSize,
                                                                             weight: .semibold)
        }

        let statusText = inputMethod == 1 ? "Vi" : "En"
        let textColor: NSColor = inputMethod == 1 ? .systemBlue : .secondaryLabelColor

        let attributes: [NSAttributedString.Key: Any] = [
            .font: PHTVStatusBarMenuCache.statusFont as Any,
            .foregroundColor: textColor
        ]

        button.attributedTitle = NSAttributedString(string: statusText, attributes: attributes)

        menuInputMethod?.state = inputMethod == 1 ? .on : .off

        mnuTelex?.state = inputType == 0 ? .on : .off
        mnuVNI?.state = inputType == 1 ? .on : .off
        mnuSimpleTelex1?.state = inputType == 2 ? .on : .off
        mnuSimpleTelex2?.state = inputType == 3 ? .on : .off

        mnuUnicode?.state = codeTable == 0 ? .on : .off
        mnuTCVN?.state = codeTable == 1 ? .on : .off
        mnuVNIWindows?.state = codeTable == 2 ? .on : .off
        mnuUnicodeComposite?.state = codeTable == 3 ? .on : .off
        mnuVietnameseLocaleCP1258?.state = codeTable == 4 ? .on : .off

        mnuSpellCheck?.state = (runtimeSettings["checkSpelling"]?.intValue ?? 0) != 0 ? .on : .off
        mnuModernOrthography?.state = (runtimeSettings["useModernOrthography"]?.intValue ?? 0) != 0 ? .on : .off
        mnuQuickTelex?.state = (runtimeSettings["quickTelex"]?.intValue ?? 0) != 0 ? .on : .off
        mnuAllowConsonantZFWJ?.state = (runtimeSettings["allowConsonantZFWJ"]?.intValue ?? 0) != 0 ? .on : .off
        mnuUpperCaseFirstChar?.state = (runtimeSettings["upperCaseFirstChar"]?.intValue ?? 0) != 0 ? .on : .off
        mnuAutoRestoreEnglishWord?.state = (runtimeSettings["autoRestoreEnglishWord"]?.intValue ?? 0) != 0 ? .on : .off
    }

    private func setInputTypeMenu(_ parent: NSMenuItem) {
        let sub = ensureSubmenu(for: parent)
        sub.removeAllItems()

        mnuTelex = NSMenuItem(title: "Telex", action: #selector(onInputTypeSelected(_:)), keyEquivalent: "")
        mnuTelex?.target = self
        mnuTelex?.tag = 0
        if let mnuTelex {
            sub.addItem(mnuTelex)
        }

        mnuVNI = NSMenuItem(title: "VNI", action: #selector(onInputTypeSelected(_:)), keyEquivalent: "")
        mnuVNI?.target = self
        mnuVNI?.tag = 1
        if let mnuVNI {
            sub.addItem(mnuVNI)
        }

        mnuSimpleTelex1 = NSMenuItem(title: "Simple Telex 1", action: #selector(onInputTypeSelected(_:)), keyEquivalent: "")
        mnuSimpleTelex1?.target = self
        mnuSimpleTelex1?.tag = 2
        if let mnuSimpleTelex1 {
            sub.addItem(mnuSimpleTelex1)
        }

        mnuSimpleTelex2 = NSMenuItem(title: "Simple Telex 2", action: #selector(onInputTypeSelected(_:)), keyEquivalent: "")
        mnuSimpleTelex2?.target = self
        mnuSimpleTelex2?.tag = 3
        if let mnuSimpleTelex2 {
            sub.addItem(mnuSimpleTelex2)
        }
    }

    private func setCodeMenu(_ parent: NSMenuItem) {
        let sub = ensureSubmenu(for: parent)
        sub.removeAllItems()

        mnuUnicode = NSMenuItem(title: "Unicode dựng sẵn", action: #selector(onCodeSelected(_:)), keyEquivalent: "")
        mnuUnicode?.target = self
        mnuUnicode?.tag = 0
        if let mnuUnicode {
            sub.addItem(mnuUnicode)
        }

        mnuTCVN = NSMenuItem(title: "TCVN3 (ABC)", action: #selector(onCodeSelected(_:)), keyEquivalent: "")
        mnuTCVN?.target = self
        mnuTCVN?.tag = 1
        if let mnuTCVN {
            sub.addItem(mnuTCVN)
        }

        mnuVNIWindows = NSMenuItem(title: "VNI Windows", action: #selector(onCodeSelected(_:)), keyEquivalent: "")
        mnuVNIWindows?.target = self
        mnuVNIWindows?.tag = 2
        if let mnuVNIWindows {
            sub.addItem(mnuVNIWindows)
        }

        mnuUnicodeComposite = NSMenuItem(title: "Unicode tổ hợp", action: #selector(onCodeSelected(_:)), keyEquivalent: "")
        mnuUnicodeComposite?.target = self
        mnuUnicodeComposite?.tag = 3
        if let mnuUnicodeComposite {
            sub.addItem(mnuUnicodeComposite)
        }

        mnuVietnameseLocaleCP1258 = NSMenuItem(title: "Vietnamese Locale CP 1258",
                                               action: #selector(onCodeSelected(_:)),
                                               keyEquivalent: "")
        mnuVietnameseLocaleCP1258?.target = self
        mnuVietnameseLocaleCP1258?.tag = 4
        if let mnuVietnameseLocaleCP1258 {
            sub.addItem(mnuVietnameseLocaleCP1258)
        }
    }

    private func setOptionsMenu(_ parent: NSMenuItem) {
        let sub = ensureSubmenu(for: parent)
        sub.removeAllItems()

        mnuSpellCheck = NSMenuItem(title: "Kiểm tra chính tả", action: #selector(toggleSpellCheck(_:)), keyEquivalent: "")
        mnuSpellCheck?.target = self
        if let mnuSpellCheck {
            sub.addItem(mnuSpellCheck)
        }

        mnuModernOrthography = NSMenuItem(title: "Chính tả mới (oà, uý)",
                                          action: #selector(toggleModernOrthography(_:)),
                                          keyEquivalent: "")
        mnuModernOrthography?.target = self
        if let mnuModernOrthography {
            sub.addItem(mnuModernOrthography)
        }

        sub.addItem(.separator())

        mnuQuickTelex = NSMenuItem(title: "Gõ nhanh Telex", action: #selector(toggleQuickTelex(_:)), keyEquivalent: "")
        mnuQuickTelex?.target = self
        if let mnuQuickTelex {
            sub.addItem(mnuQuickTelex)
        }

        mnuAllowConsonantZFWJ = NSMenuItem(title: "Phụ âm Z, F, W, J",
                                           action: #selector(toggleAllowConsonantZFWJ(_:)),
                                           keyEquivalent: "")
        mnuAllowConsonantZFWJ?.target = self
        if let mnuAllowConsonantZFWJ {
            sub.addItem(mnuAllowConsonantZFWJ)
        }

        sub.addItem(.separator())

        mnuUpperCaseFirstChar = NSMenuItem(title: "Viết hoa đầu câu",
                                           action: #selector(toggleUpperCaseFirstChar(_:)),
                                           keyEquivalent: "")
        mnuUpperCaseFirstChar?.target = self
        if let mnuUpperCaseFirstChar {
            sub.addItem(mnuUpperCaseFirstChar)
        }

        mnuAutoRestoreEnglishWord = NSMenuItem(title: "Tự động khôi phục tiếng Anh",
                                               action: #selector(toggleAutoRestoreEnglishWord(_:)),
                                               keyEquivalent: "")
        mnuAutoRestoreEnglishWord?.target = self
        if let mnuAutoRestoreEnglishWord {
            sub.addItem(mnuAutoRestoreEnglishWord)
        }
    }

    private func ensureSubmenu(for parent: NSMenuItem) -> NSMenu {
        if let sub = parent.submenu {
            sub.autoenablesItems = false
            return sub
        }

        let sub = NSMenu()
        sub.autoenablesItems = false
        parent.submenu = sub
        return sub
    }
}
