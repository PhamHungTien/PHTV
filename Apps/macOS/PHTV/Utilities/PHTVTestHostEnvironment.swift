import Foundation

/// The test host has its own preferences identity. CFFIXED_USER_HOME redirects
/// Foundation file paths, but cfprefsd can still persist defaults in the real
/// user's Preferences directory, so a different bundle identifier is essential.
enum PHTVTestHostEnvironment {
    static let bundleIdentifier = "com.phamhungtien.phtv.tests.host"

    static func prepareIfNeeded() {
        guard phtvIsRunningUnderXCTest() else { return }
        precondition(
            Bundle.main.bundleIdentifier == bundleIdentifier,
            "Run XCTest with the Testing configuration, never the user's Debug/Release app."
        )
        guard let path = ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"] else {
            preconditionFailure("The test host requires a test-owned Foundation home.")
        }
        let testHome = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        precondition(testHome.lastPathComponent == "PHTVTestHome")
        precondition(FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL == testHome)
        // Only the dedicated test-host domain, never Debug/Release or global
        // preferences. Start each host process with deterministic app settings.
        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
    }
}
