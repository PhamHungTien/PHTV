import AppKit
import Foundation

final class PHTVInputSession {
    private let engine: PHTVInputEngine
    private var markedTextStartLocation = NSNotFound
    private var markedTextLength = 0

    init(engine: PHTVInputEngine = PHTVVietnameseInputEngine()) {
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
            return commitBoundary(text, client: client)
        }

        guard text.isPHTVInputComposableText else {
            commit(client: client)
            return false
        }

        engine.insert(text)
        markComposition(client: client)
        return true
    }

    func handleEvent(_ event: NSEvent, client: PHTVInputClient) -> Bool {
        guard event.type == .keyDown else { return false }

        if event.isPHTVPassthroughModifiedKey {
            commit(client: client)
            return false
        }

        switch Int(event.keyCode) {
        case PHTVInputMethodConstants.tabKeyCode:
            return commitBoundary("\t", client: client)
        case PHTVInputMethodConstants.deleteKeyCode:
            return deleteBackward(client: client)
        case PHTVInputMethodConstants.escapeKeyCode:
            return cancelComposition(client: client)
        case PHTVInputMethodConstants.returnKeyCode,
             PHTVInputMethodConstants.enterKeyCode:
            return commitBoundary("\n", client: client)
        default:
            guard let text = event.characters, !text.isEmpty else {
                commit(client: client)
                return false
            }

            return handleText(text, client: client)
        }
    }

    func commit(client: PHTVInputClient) {
        guard engine.isComposing else {
            resetMarkedTextTracking()
            return
        }

        client.commit(engine.composedText, replacementRange: replacementRangeForCommit(client: client))
        engine.reset()
        resetMarkedTextTracking()
    }

    private func commitBoundary(_ boundary: String, client: PHTVInputClient) -> Bool {
        guard engine.isComposing else { return false }
        client.commit(engine.composedText + boundary, replacementRange: replacementRangeForCommit(client: client))
        engine.reset()
        resetMarkedTextTracking()
        return true
    }

    private func deleteBackward(client: PHTVInputClient) -> Bool {
        if client.hasSelectedText {
            engine.reset()
            resetMarkedTextTracking()
            return false
        }

        guard engine.isComposing else { return false }
        engine.deleteBackward()
        if engine.isComposing {
            markComposition(client: client)
        } else {
            client.commit("", replacementRange: replacementRangeForCommit(client: client))
            resetMarkedTextTracking()
        }
        return true
    }

    private func cancelComposition(client: PHTVInputClient) -> Bool {
        guard engine.isComposing else { return false }
        client.commit(engine.rawText, replacementRange: replacementRangeForCommit(client: client))
        engine.reset()
        resetMarkedTextTracking()
        return true
    }

    private func markComposition(client: PHTVInputClient) {
        if markedTextStartLocation == NSNotFound {
            let selectedRange = client.selectedRange
            if selectedRange.location != NSNotFound {
                markedTextStartLocation = selectedRange.location
            }
        }

        let text = engine.composedText
        client.commit(text, replacementRange: replacementRangeForMark(client: client))
        markedTextLength = text.utf16.count
    }

    private func replacementRangeForMark(client: PHTVInputClient) -> NSRange {
        let markedRange = client.markedRange
        if markedRange.location != NSNotFound, markedRange.length > 0 {
            return markedRange
        }

        if markedTextStartLocation != NSNotFound, markedTextLength > 0 {
            return NSRange(location: markedTextStartLocation, length: markedTextLength)
        }

        return PHTVInputMethodConstants.notFoundRange
    }

    private func replacementRangeForCommit(client: PHTVInputClient) -> NSRange {
        let markedRange = client.markedRange
        if markedRange.location != NSNotFound, markedRange.length > 0 {
            return markedRange
        }

        if markedTextStartLocation != NSNotFound, markedTextLength > 0 {
            return NSRange(location: markedTextStartLocation, length: markedTextLength)
        }

        return PHTVInputMethodConstants.notFoundRange
    }

    private func resetMarkedTextTracking() {
        markedTextStartLocation = NSNotFound
        markedTextLength = 0
    }
}

private extension NSEvent {
    var isPHTVPassthroughModifiedKey: Bool {
        let deviceIndependentFlags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        return deviceIndependentFlags.contains(.command)
            || deviceIndependentFlags.contains(.control)
            || deviceIndependentFlags.contains(.option)
    }
}
