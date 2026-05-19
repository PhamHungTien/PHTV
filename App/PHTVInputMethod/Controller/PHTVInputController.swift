import AppKit
import Foundation
import InputMethodKit

@objc(PHTVInputController)
final class PHTVInputController: IMKInputController {
    private let sessionStore = PHTVInputSessionStore()

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
        session(for: sender).composedText
    }

    @objc(originalString:)
    override func originalString(_ sender: Any!) -> NSAttributedString! {
        NSAttributedString(string: session(for: sender).rawText)
    }

    @objc(candidates:)
    override func candidates(_ sender: Any!) -> [Any]! {
        session(for: sender).candidates
    }

    private func session(for sender: Any!) -> PHTVInputSession {
        sessionStore.session(for: sender)
    }
}
