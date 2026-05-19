import Foundation

final class PHTVTelexInputEngine: PHTVInputEngine {
    private var rawBuffer = ""
    private let composer = PHTVTelexComposer()

    var rawText: String {
        rawBuffer
    }

    var composedText: String {
        composer.compose(rawBuffer)
    }

    var candidates: [String] {
        let composed = composedText
        guard !composed.isEmpty, composed != rawBuffer else { return [] }
        return [composed, rawBuffer]
    }

    var isComposing: Bool {
        !rawBuffer.isEmpty
    }

    func insert(_ text: String) {
        rawBuffer.append(text)
    }

    func deleteBackward() {
        guard !rawBuffer.isEmpty else { return }
        rawBuffer.removeLast()
    }

    func reset() {
        rawBuffer.removeAll(keepingCapacity: true)
    }
}
