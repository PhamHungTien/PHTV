import AppKit
import Foundation

final class PHTVInputSession {
    private let engine: PHTVInputEngine
    private var markedTextStartLocation = NSNotFound
    private var markedTextLength = 0
    private var autoCapitalization = PHTVInputMethodAutoCapitalizationState()

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
        let config = PHTVInputMethodPreferences.currentConfiguration()

        if text.isPHTVInputCommitBoundary {
            autoCapitalization.observeCommittedText(text, enabled: config.upperCaseFirstChar)
            return commitBoundary(text, client: client)
        }

        guard text.isPHTVInputComposableText else {
            commit(client: client)
            autoCapitalization.observeCommittedText(text, enabled: config.upperCaseFirstChar)
            return false
        }

        let inputText = autoCapitalization.prepareComposableText(text, enabled: config.upperCaseFirstChar)
        engine.insert(inputText)
        markComposition(client: client)
        return true
    }

    func handleEvent(_ event: NSEvent, client: PHTVInputClient) -> Bool {
        guard event.type == .keyDown else { return false }

        if event.isPHTVPassthroughModifiedKey {
            commit(client: client)
            return false
        }

        let config = PHTVInputMethodPreferences.currentConfiguration()

        switch Int(event.keyCode) {
        case PHTVInputMethodConstants.tabKeyCode:
            return commitBoundary("\t", client: client)
        case PHTVInputMethodConstants.deleteKeyCode:
            return deleteBackward(client: client)
        case PHTVInputMethodConstants.escapeKeyCode:
            return cancelComposition(client: client)
        case PHTVInputMethodConstants.returnKeyCode,
             PHTVInputMethodConstants.enterKeyCode:
            autoCapitalization.observeCommittedText("\n", enabled: config.upperCaseFirstChar)
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
            autoCapitalization.reset()
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
        autoCapitalization.reset()
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

private struct PHTVInputMethodAutoCapitalizationState {
    private var pending = true
    private var needsSpaceConfirm = false
    private var ellipsisContinuation = false

    mutating func reset() {
        pending = true
        needsSpaceConfirm = false
        ellipsisContinuation = false
    }

    mutating func prepareComposableText(_ text: String, enabled: Bool) -> String {
        guard enabled else {
            clear()
            return text
        }

        guard let firstCharacter = text.first else { return text }
        defer {
            pending = false
            needsSpaceConfirm = false
            ellipsisContinuation = false
        }

        guard pending, !needsSpaceConfirm, firstCharacter.isPHTVLetter else {
            return text
        }

        return firstCharacter.uppercased() + String(text.dropFirst())
    }

    mutating func observeCommittedText(_ text: String, enabled: Bool) {
        guard enabled else {
            clear()
            return
        }

        for character in text {
            observeCommittedCharacter(character)
        }
    }

    private mutating func observeCommittedCharacter(_ character: Character) {
        if character.isPHTVNewline {
            pending = true
            needsSpaceConfirm = false
            ellipsisContinuation = false
            return
        }

        if character.isPHTVWhitespace {
            if pending && needsSpaceConfirm && !ellipsisContinuation {
                needsSpaceConfirm = false
            } else if ellipsisContinuation {
                clear()
            }
            return
        }

        if character == "." {
            if pending && needsSpaceConfirm {
                clear()
                ellipsisContinuation = true
            } else if ellipsisContinuation {
                ellipsisContinuation = true
            } else {
                pending = true
                needsSpaceConfirm = true
                ellipsisContinuation = false
            }
            return
        }

        if character == "!" || character == "?" {
            pending = true
            needsSpaceConfirm = true
            ellipsisContinuation = false
            return
        }

        if pending && !needsSpaceConfirm && character.isPHTVUppercaseSkippablePunctuation {
            return
        }

        clear()
    }

    private mutating func clear() {
        pending = false
        needsSpaceConfirm = false
        ellipsisContinuation = false
    }
}

private extension Character {
    var isPHTVLetter: Bool {
        unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }

    var isPHTVWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
    }

    var isPHTVNewline: Bool {
        unicodeScalars.allSatisfy { CharacterSet.newlines.contains($0) }
    }

    var isPHTVUppercaseSkippablePunctuation: Bool {
        switch self {
        case "\"", "'", "”", "’", ")", "]", "}", "»":
            return true
        default:
            return false
        }
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
