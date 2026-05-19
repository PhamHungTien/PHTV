import Foundation
import InputMethodKit

struct PHTVInputClient {
    private let client: any IMKTextInput

    init?(_ sender: Any?) {
        guard let client = sender as? any IMKTextInput else { return nil }
        self.client = client
    }

    func mark(_ text: String) {
        client.setMarkedText(
            text,
            selectionRange: NSRange(location: text.utf16.count, length: 0),
            replacementRange: PHTVInputMethodConstants.notFoundRange
        )
    }

    func commit(_ text: String) {
        client.insertText(text, replacementRange: PHTVInputMethodConstants.notFoundRange)
    }
}
