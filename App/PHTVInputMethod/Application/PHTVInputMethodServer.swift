import Cocoa
import InputMethodKit

final class PHTVInputMethodServer {
    private var server: IMKServer?

    @MainActor
    func run() {
        let bundle = Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier ?? PHTVInputMethodConstants.bundleIdentifierFallback
        let connectionName = bundle.object(forInfoDictionaryKey: PHTVInputMethodConstants.connectionNameInfoKey) as? String
            ?? PHTVInputMethodConstants.connectionNameFallback

        server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)
        NSApplication.shared.run()
    }
}
