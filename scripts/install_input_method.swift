#!/usr/bin/env swift

import Carbon
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
let releaseEntitlements = repositoryRoot.appendingPathComponent("App/PHTVInputMethod/PHTVInputMethodRelease.entitlements")
let installDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods", isDirectory: true)
let installedApp = installDirectory.appendingPathComponent("PHTVInputMethod.app", isDirectory: true)
let launchServicesRegister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

func unregisterLocalBuildProducts() {
    guard let enumerator = FileManager.default.enumerator(
        at: repositoryRoot.appendingPathComponent(".build", isDirectory: true),
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else { return }

    for case let appURL as URL in enumerator where appURL.lastPathComponent == "PHTVInputMethod.app" {
        try? runner.run(launchServicesRegister, ["-u", appURL.path])
        enumerator.skipDescendants()
    }
}

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

    unregisterLocalBuildProducts()

    if buildOnly {
        print("Built PHTVInputMethod.app at \(builtApp.path)")
        exit(0)
    }

    try FileManager.default.createDirectory(at: installDirectory, withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: installedApp.path) {
        try? runner.run(launchServicesRegister, ["-u", installedApp.path])
        try FileManager.default.removeItem(at: installedApp)
    }
    try FileManager.default.copyItem(at: builtApp, to: installedApp)

    if unsigned {
        try runner.run(
            "/usr/bin/codesign",
            [
                "--force",
                "--deep",
                "--sign",
                "-",
                "--entitlements",
                releaseEntitlements.path,
                installedApp.path,
            ]
        )
    } else {
        try runner.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", installedApp.path])
    }
    try? runner.run(launchServicesRegister, ["-u", builtApp.path])
    try runner.run(launchServicesRegister, ["-f", installedApp.path])

    let registrationStatus = TISRegisterInputSource(installedApp as CFURL)
    guard registrationStatus == noErr else {
        throw InstallInputMethodError.commandFailed("TISRegisterInputSource \(installedApp.path)", registrationStatus)
    }

    try? runner.run("/usr/bin/pkill", ["-f", "PHTVInputMethod"])
    try? runner.run("/usr/bin/killall", ["TextInputMenuAgent", "TextInputSwitcher", "keyboardservicesd", "cfprefsd"])

    print("Installed PHTVInputMethod.app to \(installedApp.path)")
    print("Registered input source with macOS. If it is still hidden, log out and log back in once.")
    print("Open System Settings > Keyboard > Text Input > Edit, then add PHTV Vietnamese.")
} catch {
    fputs("Install failed: \(error)\n", stderr)
    exit(1)
}
