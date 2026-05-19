#!/usr/bin/env swift

import Foundation

enum InstallInputMethodError: Error, CustomStringConvertible {
    case commandFailed(String, Int32)
    case missingBuiltProduct(String)

    var description: String {
        switch self {
        case let .commandFailed(command, status):
            return "Command failed (\(status)): \(command)"
        case let .missingBuiltProduct(path):
            return "Missing built input method at \(path)"
        }
    }
}

struct CommandRunner {
    let workingDirectory: URL

    func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw InstallInputMethodError.commandFailed(([executable] + arguments).joined(separator: " "), process.terminationStatus)
        }
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let runner = CommandRunner(workingDirectory: repositoryRoot)
let arguments = Set(CommandLine.arguments.dropFirst())
let buildOnly = arguments.contains("--build-only")
let unsigned = arguments.contains("--unsigned")
let buildDirectory = repositoryRoot.appendingPathComponent(".build/imk-install", isDirectory: true)
let builtApp = buildDirectory.appendingPathComponent("Build/Products/Release/PHTVInputMethod.app", isDirectory: true)
let installDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods", isDirectory: true)
let installedApp = installDirectory.appendingPathComponent("PHTVInputMethod.app", isDirectory: true)

do {
    var buildArguments = [
        "-project", "App/PHTV.xcodeproj",
        "-scheme", "PHTVInputMethod",
        "-configuration", "Release",
        "-derivedDataPath", buildDirectory.path,
        "build",
    ]

    if unsigned {
        buildArguments.append("CODE_SIGNING_ALLOWED=NO")
    }

    try runner.run(
        "/usr/bin/xcodebuild",
        buildArguments
    )

    guard FileManager.default.fileExists(atPath: builtApp.path) else {
        throw InstallInputMethodError.missingBuiltProduct(builtApp.path)
    }

    if buildOnly {
        print("Built PHTVInputMethod.app at \(builtApp.path)")
        exit(0)
    }

    try FileManager.default.createDirectory(at: installDirectory, withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: installedApp.path) {
        try FileManager.default.removeItem(at: installedApp)
    }
    try FileManager.default.copyItem(at: builtApp, to: installedApp)

    try? runner.run("/usr/bin/pkill", ["-f", "PHTVInputMethod"])

    print("Installed PHTVInputMethod.app to \(installedApp.path)")
    print("Open System Settings > Keyboard > Text Input > Edit, then add PHTV Vietnamese.")
} catch {
    fputs("Install failed: \(error)\n", stderr)
    exit(1)
}
