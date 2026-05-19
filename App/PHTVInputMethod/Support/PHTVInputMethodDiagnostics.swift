import Foundation
import os

enum PHTVInputMethodDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? PHTVInputMethodConstants.bundleIdentifierFallback,
        category: "InputMethod"
    )

    static func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}
