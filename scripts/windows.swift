#!/usr/bin/env swift
// PHTV Windows development entrypoint.
// This script intentionally uses Foundation.Process instead of shell scripts so
// the same commands work from PowerShell, cmd.exe and CI runners.

import Foundation

enum WindowsToolError: Error, CustomStringConvertible {
    case usage
    case missingTool(String)
    case missingPath(String)
    case commandFailed(String, Int32)
    case invalidCoreArtifacts

    var description: String {
        switch self {
        case .usage:
            return "Usage: scripts/windows.swift <doctor|core-build|core-test|native-test|app-build|build|test>"
        case .missingTool(let name):
            return "Required tool was not found on PATH: \(name)"
        case .missingPath(let path):
            return "Required Windows project path was not found: \(path)"
        case .commandFailed(let command, let status):
            return "Command failed (\(status)): \(command)"
        case .invalidCoreArtifacts:
            return "Swift Core build completed without producing PHTVCore.lib."
        }
    }
}

let scriptURL = URL(fileURLWithPath: #filePath)
let rootURL = scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let coreURL = rootURL.appendingPathComponent("Shared/PHTVCore")
let commandName = CommandLine.arguments.dropFirst().first ?? ""

func pathEntries() -> [String] {
    let separator: Character = isWindows() ? ";" : ":"
    return (ProcessInfo.processInfo.environment["PATH"] ?? "")
        .split(separator: separator, omittingEmptySubsequences: true)
        .map(String.init)
}

func resolveTool(_ name: String) -> URL? {
    let candidateNames: [String]
    if name.contains("/") || name.contains("\\") {
        candidateNames = [name]
    } else if isWindows() {
        candidateNames = [name, "\(name).exe", "\(name).cmd", "\(name).bat"]
    } else {
        candidateNames = [name]
    }

    for directory in pathEntries() {
        for candidate in candidateNames {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(candidate)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
    }
    return candidateNames
        .map { URL(fileURLWithPath: $0) }
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }
}

func requireTool(_ name: String) throws -> URL {
    guard let tool = resolveTool(name) else {
        throw WindowsToolError.missingTool(name)
    }
    return tool
}

func requirePath(_ relativePath: String) throws -> URL {
    let url = rootURL.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw WindowsToolError.missingPath(relativePath)
    }
    return url
}

@discardableResult
func run(_ toolName: String, _ arguments: [String], workingDirectory: URL = rootURL) throws -> Int32 {
    let tool = try requireTool(toolName)
    let process = Process()
    process.executableURL = tool
    process.arguments = arguments
    process.currentDirectoryURL = workingDirectory
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let command = ([tool.path] + arguments).joined(separator: " ")
        throw WindowsToolError.commandFailed(command, process.terminationStatus)
    }
    return process.terminationStatus
}

func isWindows() -> Bool {
    #if os(Windows)
    return true
    #else
    return false
    #endif
}

func printToolVersion(_ name: String, arguments: [String] = ["--version"], required: Bool = true) throws {
    guard resolveTool(name) != nil else {
        if required { throw WindowsToolError.missingTool(name) }
        print("  - \(name): not available")
        return
    }
    print("  - \(name):")
    try run(name, arguments)
}

func coreBuild() throws {
    _ = try requirePath("Shared/PHTVCore/Package.swift")
    try run("swift", ["build", "--package-path", coreURL.path])
}

func coreTest() throws {
    try run("swift", ["test", "--package-path", coreURL.path])
    try run("swift", ["run", "--package-path", coreURL.path, "PHTVCoreABISmoke"])
}

func coreLibraryDirectory() throws -> URL {
    let enumerator = FileManager.default.enumerator(
        at: coreURL.appendingPathComponent(".build"),
        includingPropertiesForKeys: [.isRegularFileKey],
        options: []
    )
    while let item = enumerator?.nextObject() as? URL {
        if item.lastPathComponent == "PHTVCore.lib" {
            return item.deletingLastPathComponent()
        }
    }
    throw WindowsToolError.invalidCoreArtifacts
}

func requireWindowsCommand(_ message: String) throws {
    guard isWindows() else {
        throw WindowsToolError.commandFailed(message, 1)
    }
}

func buildAndRunNativeTest(_ relativeProject: String, executableName: String, coreDirectory: URL? = nil) throws {
    let projectURL = try requirePath(relativeProject)
    var arguments = [projectURL.path, "/m", "/p:Configuration=Release", "/p:Platform=x64"]
    if let coreDirectory {
        arguments.append("/p:PHTVCoreLibraryDir=\(coreDirectory.path)")
    }
    try run("msbuild", arguments)

    let projectDirectory = projectURL.deletingLastPathComponent()
    guard let executable = FileManager.default.enumerator(
        at: projectDirectory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: []
    )?.compactMap({ $0 as? URL }).first(where: { $0.lastPathComponent == executableName }) else {
        throw WindowsToolError.missingPath("\(relativeProject) -> \(executableName)")
    }
    try run(executable.path, [], workingDirectory: executable.deletingLastPathComponent())
}

func nativeTests() throws {
    try requireWindowsCommand("Native Windows tests require a Windows runner.")
    let coreDirectory = try coreLibraryDirectory()
    try buildAndRunNativeTest(
        "Apps/Windows/tests/PHTV.Windows.InputModeState.Tests/PHTV.Windows.InputModeState.Tests.vcxproj",
        executableName: "PHTV.Windows.InputModeState.Tests.exe"
    )
    try buildAndRunNativeTest(
        "Apps/Windows/tests/PHTV.Windows.InputScopePolicy.Tests/PHTV.Windows.InputScopePolicy.Tests.vcxproj",
        executableName: "PHTV.Windows.InputScopePolicy.Tests.exe"
    )
    try buildAndRunNativeTest(
        "Apps/Windows/tests/PHTV.Windows.SettingsSnapshot.Tests/PHTV.Windows.SettingsSnapshot.Tests.vcxproj",
        executableName: "PHTV.Windows.SettingsSnapshot.Tests.exe"
    )
    try buildAndRunNativeTest(
        "Apps/Windows/tests/PHTV.Windows.ApplicationRulesSnapshot.Tests/PHTV.Windows.ApplicationRulesSnapshot.Tests.vcxproj",
        executableName: "PHTV.Windows.ApplicationRulesSnapshot.Tests.exe"
    )
    try buildAndRunNativeTest(
        "Apps/Windows/tests/PHTV.Windows.CoreBridge.Tests/PHTV.Windows.CoreBridge.Tests.vcxproj",
        executableName: "PHTV.Windows.CoreBridge.Tests.exe",
        coreDirectory: coreDirectory
    )
    try run("dotnet", [
        "run",
        "--project", rootURL.appendingPathComponent("Apps/Windows/tests/PHTV.Windows.Contracts.Tests/PHTV.Windows.Contracts.Tests.csproj").path,
        "--configuration", "Release",
    ])
}

func appBuild() throws {
    try requireWindowsCommand("WinUI build requires a Windows runner.")
    let project = try requirePath("Apps/Windows/src/PHTV.Windows.App/PHTV.Windows.App.csproj")
    try run("dotnet", [
        "build", project.path,
        "--configuration", "Release",
        "--runtime", "win-x64",
        "/p:Platform=x64",
    ])
}

do {
    switch commandName {
    case "doctor":
        print("PHTV Windows toolchain doctor")
        print("  - repository: \(rootURL.path)")
        print("  - host: \(isWindows() ? "Windows" : "non-Windows (Core-only)")")
        for path in [
            "Apps/Windows/PHTV.Windows.slnx",
            "Apps/Windows/src/PHTV.Windows.IME/PHTV.Windows.IME.vcxproj",
            "Apps/Windows/src/PHTV.Windows.App/PHTV.Windows.App.csproj",
        ] {
            _ = try requirePath(path)
            print("  - path ok: \(path)")
        }
        try printToolVersion("swift")
        try printToolVersion("dotnet", required: isWindows())
        try printToolVersion("msbuild", arguments: ["-version"], required: isWindows())
    case "core-build":
        try coreBuild()
    case "core-test":
        try coreTest()
    case "native-test":
        try nativeTests()
    case "app-build":
        try appBuild()
    case "build":
        try coreBuild()
        try nativeTests()
        try appBuild()
    case "test":
        try coreTest()
        try nativeTests()
    default:
        throw WindowsToolError.usage
    }
} catch {
    fputs("windows.swift: \(error)\n", stderr)
    exit(1)
}
