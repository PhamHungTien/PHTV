#!/usr/bin/env swift

import Foundation

enum CaskError: Error, CustomStringConvertible {
    case message(String)
    var description: String { if case .message(let value) = self { return value }; return "Unknown error" }
}

func argument(_ name: String, arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw CaskError.message("Missing \(name)")
    }
    return arguments[index + 1]
}

func replacing(
    _ source: String,
    pattern: String,
    template: String,
    options: NSRegularExpression.Options = []
) throws -> (String, Int) {
    let expression = try NSRegularExpression(pattern: pattern, options: options)
    let matches = expression.matches(in: source, range: NSRange(source.startIndex..., in: source))
    return (
        expression.stringByReplacingMatches(
            in: source,
            range: NSRange(source.startIndex..., in: source),
            withTemplate: template
        ),
        matches.count
    )
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let path = try argument("--cask", arguments: arguments)
    let version = try argument("--version", arguments: arguments)
    let armSHA = try argument("--arm64-sha256", arguments: arguments)
    let intelSHA = try argument("--intel-sha256", arguments: arguments)
    var text = try String(contentsOfFile: path, encoding: .utf8)

    let versionResult = try replacing(
        text,
        pattern: #"(?m)^(\s*)version\s+\"[^\"]+\"\s*$"#,
        template: #"$1version \""# + version + #"\""#
    )
    guard versionResult.1 == 1 else { throw CaskError.message("Could not find exactly one version line") }
    text = versionResult.0

    if text.contains("on_arm") || text.contains("arch do") {
        let arm = try replacing(
            text,
            pattern: #"(on_arm\s+do.*?sha256\s+\")[^\"]+(\")"#,
            template: "$1" + armSHA + "$2",
            options: [.dotMatchesLineSeparators]
        )
        let intel = try replacing(
            arm.0,
            pattern: #"(on_intel\s+do.*?sha256\s+\")[^\"]+(\")"#,
            template: "$1" + intelSHA + "$2",
            options: [.dotMatchesLineSeparators]
        )
        guard arm.1 == 1, intel.1 == 1 else { throw CaskError.message("Could not update both architecture SHA values") }
        text = intel.0
    } else {
        let prefix = "https://github.com/PhamHungTien/PHTV/releases/download/v\(version)"
        let replacement = """
        $1on_arm do
        $1  url "\(prefix)/PHTV-\(version)-arm64.dmg"
        $1  sha256 "\(armSHA)"
        $1end
        $1on_intel do
        $1  url "\(prefix)/PHTV-\(version)-intel.dmg"
        $1  sha256 "\(intelSHA)"
        $1end
        """
        let legacy = try replacing(
            text,
            pattern: #"(?m)^(\s*)url\s+\"[^\"]+\"\s*\n\s*sha256\s+\"[^\"]+\"\s*$"#,
            template: replacement
        )
        guard legacy.1 == 1 else { throw CaskError.message("Could not migrate legacy URL/SHA block") }
        text = legacy.0
    }

    try text.write(toFile: path, atomically: true, encoding: .utf8)
    print("Updated \(path) for PHTV \(version)")
} catch {
    fputs("update-homebrew-cask: \(error)\n", stderr)
    exit(1)
}
