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

        // Kiểu gõ submenu
        let styleMenu = NSMenu(title: "Kiểu gõ")
        for style in PHTVInputStyle.allCases {
            let item = NSMenuItem(
                title: style.displayName,
                action: #selector(selectInputStyle(_:)),
                keyEquivalent: ""
            )
            item.tag = style.rawValue
            item.target = self
            if config.inputStyle == style {
                item.state = .on
            }
            styleMenu.addItem(item)
        }
        let styleSubmenuItem = NSMenuItem(title: "Kiểu gõ", action: nil, keyEquivalent: "")
        styleSubmenuItem.submenu = styleMenu
        menu.addItem(styleSubmenuItem)

        // Bảng mã submenu
        let encodingMenu = NSMenu(title: "Bảng mã")
        for encoding in PHTVOutputEncoding.allCases {
            let item = NSMenuItem(
                title: encoding.displayName,
                action: #selector(selectOutputEncoding(_:)),
                keyEquivalent: ""
            )
            item.tag = encoding.rawValue
            item.target = self
            if config.outputEncoding == encoding {
                item.state = .on
            }
            encodingMenu.addItem(item)
        }
        let encodingSubmenuItem = NSMenuItem(title: "Bảng mã", action: nil, keyEquivalent: "")
        encodingSubmenuItem.submenu = encodingMenu
        menu.addItem(encodingSubmenuItem)

        // Tự động khôi phục tiếng Anh item
        let autoRestoreItem = NSMenuItem(
            title: "Tự động khôi phục tiếng Anh",
            action: #selector(toggleAutoRestoreEnglish(_:)),
            keyEquivalent: ""
        )
        autoRestoreItem.target = self
        autoRestoreItem.state = config.autoRestoreEnglishWord ? .on : .off
        menu.addItem(autoRestoreItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences button
        let preferencesItem = NSMenuItem(
            title: "Cấu hình...",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ""
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        return menu
    }

    @objc func selectInputStyle(_ sender: Any) {
        let menuItem: NSMenuItem?
        if let item = sender as? NSMenuItem {
            menuItem = item
        } else if let dict = sender as? [AnyHashable: Any],
                  let item = dict[kIMKCommandMenuItemName] as? NSMenuItem {
            menuItem = item
        } else {
            menuItem = nil
        }

        guard let item = menuItem,
              let style = PHTVInputStyle(rawValue: item.tag) else {
            PHTVInputMethodDiagnostics.log("selectInputStyle: failed to extract NSMenuItem from sender: \(sender)")
            return
        }
        PHTVInputMethodDiagnostics.log("selectInputStyle called with tag \(item.tag) -> \(style.displayName)")
        var config = PHTVInputMethodPreferences.currentConfiguration()
        config.inputStyle = style
        PHTVInputMethodPreferences.saveConfiguration(config)
    }

    @objc func selectOutputEncoding(_ sender: Any) {
        let menuItem: NSMenuItem?
        if let item = sender as? NSMenuItem {
            menuItem = item
        } else if let dict = sender as? [AnyHashable: Any],
                  let item = dict[kIMKCommandMenuItemName] as? NSMenuItem {
            menuItem = item
        } else {
            menuItem = nil
        }

        guard let item = menuItem,
              let encoding = PHTVOutputEncoding(rawValue: item.tag) else {
            PHTVInputMethodDiagnostics.log("selectOutputEncoding: failed to extract NSMenuItem from sender: \(sender)")
            return
        }
        PHTVInputMethodDiagnostics.log("selectOutputEncoding called with tag \(item.tag) -> \(encoding.displayName)")
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
