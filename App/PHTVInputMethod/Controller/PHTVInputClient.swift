import AppKit
import InputMethodKit

struct PHTVInputClient {
    private let client: any IMKTextInput

    init?(_ sender: Any?) {
        guard let client = sender as? any IMKTextInput else { return nil }
        self.client = client
    }

    var selectedRange: NSRange {
        client.selectedRange()
    }

    var markedRange: NSRange {
        client.markedRange()
    }

    var bundleIdentifier: String {
        client.bundleIdentifier() ?? "unknown"
    }

    func mark(_ text: String, replacementRange: NSRange) {
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: NSColor.secondaryLabelColor,
            ]
        )

        client.setMarkedText(
            attributedText,
            selectionRange: NSRange(location: text.utf16.count, length: 0),
            replacementRange: replacementRange
        )
    }

    func clearMarkedText(replacementRange: NSRange) {
        client.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: replacementRange
        )
    }

    func commit(_ text: String, replacementRange: NSRange) {
        client.insertText(text, replacementRange: replacementRange)
    }
}
