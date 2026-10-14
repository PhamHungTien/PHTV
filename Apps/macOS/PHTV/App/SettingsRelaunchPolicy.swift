import Foundation

enum SettingsRelaunchPolicy {
    static let backgroundArgument = "--phtv-background"

    static func shouldShowSettingsOnStartup(arguments: [String], preference: Bool) -> Bool {
        preference && !arguments.contains(backgroundArgument)
    }
}
