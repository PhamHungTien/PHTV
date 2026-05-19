import Foundation

final class PHTVVietnameseInputEngine: PHTVInputEngine {
    private var rawBuffer = ""
    private let composer = PHTVVietnameseComposer()
    private let transcoder = PHTVOutputTranscoder()

    private var configuration: PHTVInputMethodConfiguration {
        PHTVInputMethodPreferences.currentConfiguration()
    }

    var rawText: String {
        rawBuffer
    }

    var composedText: String {
        let configuration = configuration
        let unicodeText = composer.compose(
            rawBuffer,
            style: configuration.inputStyle,
            autoRestore: configuration.autoRestoreEnglishWord
        )
        return transcoder.transcode(unicodeText, to: configuration.outputEncoding)
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
