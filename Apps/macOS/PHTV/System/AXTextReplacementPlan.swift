import Foundation

/// A text edit is safe only when the target reports a valid UTF-16 selection.
struct AXTextReplacementPlan {
    let value: String
    let caret: Int
    let includesTrailingSelection: Bool

    static func make(value: String, selection: NSRange?, backspaceCount: Int, insertion: String) -> Self? {
        let source = value as NSString
        guard let selection,
              selection.location >= 0, selection.length >= 0,
              selection.location <= source.length,
              selection.length <= source.length - selection.location else { return nil }

        let trailing = selection.length > 0 && NSMaxRange(selection) == source.length
        let range: NSRange
        if selection.length > 0 && !trailing {
            range = selection
        } else {
            let start = PHTVAccessibilityService.calculateDeleteStartForAX(
                value, caretLocation: selection.location, backspaceCount: backspaceCount)
            range = NSRange(location: start, length: selection.location - start + selection.length)
        }
        let replacement = source.replacingCharacters(in: range, with: insertion)
        return Self(value: replacement, caret: range.location + (insertion as NSString).length,
                    includesTrailingSelection: trailing)
    }
}
