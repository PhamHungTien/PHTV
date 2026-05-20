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

        let upperCaseItem = NSMenuItem(
            title: "Viết hoa đầu câu",
            action: #selector(toggleUpperCaseFirstChar(_:)),
            keyEquivalent: ""
        )
        upperCaseItem.image = NSImage(systemSymbolName: "textformat.size.larger", accessibilityDescription: nil)
        upperCaseItem.target = self
        upperCaseItem.state = config.upperCaseFirstChar ? .on : .off
        menu.addItem(upperCaseItem)

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

    @objc func toggleUpperCaseFirstChar(_ sender: Any) {
        PHTVInputMethodDiagnostics.log("toggleUpperCaseFirstChar called")
        var config = PHTVInputMethodPreferences.currentConfiguration()
        config.upperCaseFirstChar.toggle()
        PHTVInputMethodPreferences.saveConfiguration(config)
    }
}
