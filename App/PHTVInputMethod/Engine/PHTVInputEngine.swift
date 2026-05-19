import Foundation

protocol PHTVInputEngine: AnyObject {
    var rawText: String { get }
    var composedText: String { get }
    var candidates: [String] { get }
    var isComposing: Bool { get }

    func insert(_ text: String)
    func deleteBackward()
    func reset()
}
