import AppKit
import Foundation

final class PHTVInputSession {
    private let engine: PHTVInputEngine

    init(engine: PHTVInputEngine = PHTVTelexInputEngine()) {
        self.engine = engine
    }

    var rawText: String {
        engine.rawText
    }

    var composedText: String {
        engine.composedText
    }

    var candidates: [String] {
        engine.candidates
    }

    func handleText(_ text: String, client: PHTVInputClient) -> Bool {
        guard !text.isEmpty else { return false }

        if text.isPHTVInputCommitBoundary {
            let handled = engine.isComposing
            commitBoundary(text, client: client)
            return handled
        }

        guard text.isPHTVInputComposableText else {
            commit(client: client)
            return false
        }

        engine.insert(text)
        client.mark(engine.composedText)
        return true
    }

    func handleEvent(_ event: NSEvent, client: PHTVInputClient) -> Bool {
        guard event.type == .keyDown else { return false }

        switch Int(event.keyCode) {
        case PHTVInputMethodConstants.deleteKeyCode:
            return deleteBackward(client: client)
        case PHTVInputMethodConstants.escapeKeyCode:
            return cancelComposition(client: client)
        case PHTVInputMethodConstants.returnKeyCode,
             PHTVInputMethodConstants.enterKeyCode:
            let handled = engine.isComposing
            commitBoundary("\n", client: client)
            return handled
        default:
            return false
        }
    }

    func commit(client: PHTVInputClient) {
        guard engine.isComposing else { return }
        client.commit(engine.composedText)
        engine.reset()
    }

    private func commitBoundary(_ boundary: String, client: PHTVInputClient) {
        guard engine.isComposing else { return }
        client.commit(engine.composedText + boundary)
        engine.reset()
    }

    private func deleteBackward(client: PHTVInputClient) -> Bool {
        guard engine.isComposing else { return false }
        engine.deleteBackward()
        if engine.isComposing {
            client.mark(engine.composedText)
        } else {
            client.mark("")
        }
        return true
    }

    private func cancelComposition(client: PHTVInputClient) -> Bool {
        guard engine.isComposing else { return false }
        client.commit(engine.rawText)
        engine.reset()
        return true
    }
}
