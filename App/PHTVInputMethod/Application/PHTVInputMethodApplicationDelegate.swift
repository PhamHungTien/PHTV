import Cocoa
import InputMethodKit

final class PHTVInputMethodApplicationDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundle = Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier ?? PHTVInputMethodConstants.bundleIdentifierFallback
        let connectionName = bundle.object(forInfoDictionaryKey: PHTVInputMethodConstants.connectionNameInfoKey) as? String
            ?? PHTVInputMethodConstants.connectionNameFallback

        server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)
        PHTVInputMethodDiagnostics.log("server started: \(bundleIdentifier) / \(connectionName)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        PHTVInputMethodDiagnostics.log("server stopping")
    }
}
