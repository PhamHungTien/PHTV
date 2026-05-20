import AppKit
import Foundation
import InputMethodKit

@objc(PHTVInputController)
final class PHTVInputController: IMKInputController {
    private let sessionStore = PHTVInputSessionStore()

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)

        if let client = PHTVInputClient(inputClient) {
            PHTVInputMethodDiagnostics.log("controller initialized for \(client.bundleIdentifier)")
        } else {
            PHTVInputMethodDiagnostics.log("controller initialized")
        }
    }

    @objc(inputText:client:)
    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let client = PHTVInputClient(sender) else { return false }
        return session(for: sender).handleText(string ?? "", client: client)
    }

    @objc(handleEvent:client:)
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = PHTVInputClient(sender) else { return false }
        return session(for: sender).handleEvent(event, client: client)
    }

    @objc(commitComposition:)
    override func commitComposition(_ sender: Any!) {
        guard let client = PHTVInputClient(sender) else { return }
        session(for: sender).commit(client: client)
    }

    @objc(composedString:)
    override func composedString(_ sender: Any!) -> Any! {
        nil
    }

    @objc(originalString:)
    override func originalString(_ sender: Any!) -> NSAttributedString! {
        nil
    }

    @objc(candidates:)
    override func candidates(_ sender: Any!) -> [Any]! {
        session(for: sender).candidates
    }

    private func session(for sender: Any!) -> PHTVInputSession {
        sessionStore.session(for: sender)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "PHTV")
        let config = PHTVInputMethodPreferences.currentConfiguration()

        let summaryItem = NSMenuItem(
            title: "\(config.inputStyle.displayName) • \(config.outputEncoding.displayName)",
            action: nil,
            keyEquivalent: ""
        )
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)
        menu.addItem(NSMenuItem.separator())

        let styleMenu = NSMenu(title: "Kiểu gõ")
        for style in PHTVInputStyle.allCases {
            let item = NSMenuItem(
                title: style.displayName,
                action: selector(for: style),
                keyEquivalent: ""
            )
            item.target = self
            if config.inputStyle == style {
                item.state = .on
            }
            styleMenu.addItem(item)
        }
        let styleSubmenuItem = NSMenuItem(title: "Kiểu gõ", action: nil, keyEquivalent: "")
        styleSubmenuItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        styleSubmenuItem.submenu = styleMenu
        menu.addItem(styleSubmenuItem)

        let encodingMenu = NSMenu(title: "Bảng mã")
        for encoding in PHTVOutputEncoding.allCases {
            let item = NSMenuItem(
                title: encoding.displayName,
                action: selector(for: encoding),
                keyEquivalent: ""
            )
            item.target = self
            if config.outputEncoding == encoding {
                item.state = .on
            }
            encodingMenu.addItem(item)
        }
        let encodingSubmenuItem = NSMenuItem(title: "Bảng mã", action: nil, keyEquivalent: "")
        encodingSubmenuItem.image = NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)
        encodingSubmenuItem.submenu = encodingMenu
        menu.addItem(encodingSubmenuItem)

        let autoRestoreItem = NSMenuItem(
            title: "Khôi phục từ tiếng Anh",
            action: #selector(toggleAutoRestoreEnglish(_:)),
            keyEquivalent: ""
        )
        autoRestoreItem.image = NSImage(systemSymbolName: "arrow.uturn.backward.circle", accessibilityDescription: nil)
        autoRestoreItem.target = self
        autoRestoreItem.state = config.autoRestoreEnglishWord ? .on : .off
        menu.addItem(autoRestoreItem)

        menu.addItem(NSMenuItem.separator())

        let preferencesItem = NSMenuItem(
            title: "Cài đặt PHTV...",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ""
        )
        preferencesItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        return menu
    }

    @objc func selectTelex(_ sender: Any) {
        selectInputStyle(.telex)
    }

    @objc func selectVNI(_ sender: Any) {
        selectInputStyle(.vni)
    }

    @objc func selectSimpleTelex1(_ sender: Any) {
        selectInputStyle(.simpleTelex1)
    }

    @objc func selectSimpleTelex2(_ sender: Any) {
        selectInputStyle(.simpleTelex2)
    }

    @objc func selectUnicode(_ sender: Any) {
        selectOutputEncoding(.unicode)
    }

    @objc func selectTCVN3(_ sender: Any) {
        selectOutputEncoding(.tcvn3)
    }

    @objc func selectVNIWindows(_ sender: Any) {
        selectOutputEncoding(.vniWindows)
    }

    @objc func selectUnicodeComposite(_ sender: Any) {
        selectOutputEncoding(.unicodeComposite)
    }

    @objc func selectCP1258(_ sender: Any) {
        selectOutputEncoding(.cp1258)
    }

    private func selector(for style: PHTVInputStyle) -> Selector {
        switch style {
        case .telex:
            return #selector(selectTelex(_:))
        case .vni:
            return #selector(selectVNI(_:))
        case .simpleTelex1:
            return #selector(selectSimpleTelex1(_:))
        case .simpleTelex2:
            return #selector(selectSimpleTelex2(_:))
        }
    }

    private func selector(for encoding: PHTVOutputEncoding) -> Selector {
        switch encoding {
        case .unicode:
            return #selector(selectUnicode(_:))
        case .tcvn3:
            return #selector(selectTCVN3(_:))
        case .vniWindows:
            return #selector(selectVNIWindows(_:))
        case .unicodeComposite:
            return #selector(selectUnicodeComposite(_:))
        case .cp1258:
            return #selector(selectCP1258(_:))
        }
    }

    private func selectInputStyle(_ style: PHTVInputStyle) {
        PHTVInputMethodDiagnostics.log("selectInputStyle -> \(style.displayName)")
        var config = PHTVInputMethodPreferences.currentConfiguration()
        config.inputStyle = style
        PHTVInputMethodPreferences.saveConfiguration(config)
    }

    private func selectOutputEncoding(_ encoding: PHTVOutputEncoding) {
        PHTVInputMethodDiagnostics.log("selectOutputEncoding -> \(encoding.displayName)")
        var config = PHTVInputMethodPreferences.currentConfiguration()
        config.outputEncoding = encoding
        PHTVInputMethodPreferences.saveConfiguration(config)
    }

    @objc func openPreferences(_ sender: Any) {
        PHTVInputMethodDiagnostics.log("openPreferences called")
        DispatchQueue.main.async {
            PHTVSettingsWindowController.shared.displayWindow()
        }
    }

    @objc func toggleAutoRestoreEnglish(_ sender: Any) {
        PHTVInputMethodDiagnostics.log("toggleAutoRestoreEnglish called")
        var config = PHTVInputMethodPreferences.currentConfiguration()
        config.autoRestoreEnglishWord.toggle()
        PHTVInputMethodPreferences.saveConfiguration(config)
    }
}
