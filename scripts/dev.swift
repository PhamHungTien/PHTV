#!/usr/bin/env swift
import Foundation

enum DevError: Error {
    case invalidUTF8
    case commandFailed(String, Int32)
}

func selectedDeveloperDirectory() -> String? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    process.arguments = ["-p"]
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return nil
    }
}

func resolveDeveloperDirectory() -> String {
    let fileManager = FileManager.default
    if let override = ProcessInfo.processInfo.environment["DEVELOPER_DIR"],
       !override.isEmpty {
        return override
    }

    if let selected = selectedDeveloperDirectory(),
       selected.contains(".app/Contents/Developer"),
       fileManager.fileExists(atPath: selected) {
        return selected
    }

    let stable = "/Applications/Xcode.app/Contents/Developer"
    if fileManager.fileExists(atPath: stable) {
        return stable
    }

    if let applicationNames = try? fileManager.contentsOfDirectory(atPath: "/Applications") {
        let candidates = applicationNames
            .filter { $0.hasPrefix("Xcode") && $0.hasSuffix(".app") }
            .map { "/Applications/\($0)/Contents/Developer" }
            .filter { fileManager.fileExists(atPath: $0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedDescending }
        if let candidate = candidates.first {
            return candidate
        }
    }

    return stable
}

let fileURL = URL(fileURLWithPath: #filePath)
let rootURL = fileURL.deletingLastPathComponent().deletingLastPathComponent()
let rootPath = rootURL.path
let projectPath = rootURL.appendingPathComponent("App/PHTV.xcodeproj").path
let scheme = "PHTV"
let destination = "platform=macOS"
let derivedDataPath = ProcessInfo.processInfo.environment["DERIVED_DATA_PATH"]
    ?? rootURL.appendingPathComponent(".build/derived-data").path
let developerDir = resolveDeveloperDirectory()

let command = CommandLine.arguments.dropFirst().first ?? ""

func usage() {
    print("""
    Usage: scripts/dev.swift <command>

    Commands:
      env-check     Print the local toolchain setup used by this project
      build         Build the macOS app in Debug
      release-build Build the macOS app in Release without distribution signing
      analyze       Run Xcode static analysis in Debug
      test          Run all XCTest tests
      engine-test   Run EngineRegressionTests only
      hotkey-test   Run HotkeyReliabilityTests only
      dict-check    Validate checked-in dictionary sources
      metadata-check Validate release notes, appcasts, plists, and Python tools
      format        Format Swift sources with the repository configuration
      format-check  Report Swift formatting differences without editing files
      clean         Remove local DerivedData used by this script

    Environment:
      DEVELOPER_DIR       Override Xcode path; otherwise auto-discovers stable or beta Xcode
      DERIVED_DATA_PATH   Override build cache path, defaults to .build/derived-data
    """)
}

func requireXcode() {
    guard FileManager.default.fileExists(atPath: developerDir) else {
        fputs("""
        Xcode developer directory not found:
          \(developerDir)

        Install Xcode or run with:
          DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer scripts/dev.swift \(command)

        """, stderr)
        exit(1)
    }
}

@discardableResult
func run(_ executable: String, _ arguments: [String], allowFailure: Bool = false) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment.merging(["DEVELOPER_DIR": developerDir]) { _, new in new }
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 && !allowFailure {
        throw DevError.commandFailed(([executable] + arguments).joined(separator: " "), process.terminationStatus)
    }
    return process.terminationStatus
}

func capture(_ executable: String, _ arguments: [String], allowFailure: Bool = false) throws -> String {
    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment.merging(["DEVELOPER_DIR": developerDir]) { _, new in new }
    process.standardOutput = pipe
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 && !allowFailure {
        throw DevError.commandFailed(([executable] + arguments).joined(separator: " "), process.terminationStatus)
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
        throw DevError.invalidUTF8
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func xcodebuildProject(_ extraArguments: [String]) throws {
    requireXcode()
    try run("/usr/bin/xcodebuild", [
        "-project", projectPath,
        "-scheme", scheme,
        "-configuration", "Debug",
        "-destination", destination,
        "-derivedDataPath", derivedDataPath,
    ] + extraArguments)
}

func swiftFormat(_ extraArguments: [String]) throws {
    requireXcode()
    try run("/usr/bin/xcrun", [
        "swift", "format",
    ] + extraArguments + [
        "--configuration", rootURL.appendingPathComponent(".swift-format").path,
        "--recursive", "--parallel",
        rootURL.appendingPathComponent("App/PHTV").path,
        rootURL.appendingPathComponent("App/Tests").path,
    ])
}

do {
    switch command {
    case "env-check":
        requireXcode()
        print("repo: \(rootPath)")
        let selectedXcode = try capture("/usr/bin/xcode-select", ["-p"], allowFailure: true)
        print("xcode-select: \(selectedXcode)")
        print("DEVELOPER_DIR: \(developerDir)")
        fflush(stdout)
        try run("/usr/bin/xcodebuild", ["-version"])
        try run("/usr/bin/xcrun", ["swift", "--version"])
        print("derived data: \(derivedDataPath)")

    case "build":
        try xcodebuildProject(["build"])

    case "release-build":
        requireXcode()
        try run("/usr/bin/xcodebuild", [
            "-project", projectPath,
            "-scheme", scheme,
            "-configuration", "Release",
            "-destination", destination,
            "-derivedDataPath", derivedDataPath,
            "CODE_SIGN_IDENTITY=-",
            "CODE_SIGNING_REQUIRED=NO",
            "CODE_SIGNING_ALLOWED=NO",
            "DEVELOPMENT_TEAM=",
            "build",
        ])

    case "analyze":
        try xcodebuildProject(["analyze"])

    case "test":
        try xcodebuildProject(["test"])

    case "engine-test":
        try xcodebuildProject(["test", "-only-testing:PHEngineTests/EngineRegressionTests"])

    case "hotkey-test":
        try xcodebuildProject(["test", "-only-testing:PHEngineTests/HotkeyReliabilityTests"])

    case "dict-check":
        try run("/usr/bin/xcrun", [
            "swift",
            rootURL.appendingPathComponent("scripts/tools/generate_dict_binary.swift").path,
            "--strict-check-sources",
        ])

    case "metadata-check":
        let releaseNotesTool = rootURL.appendingPathComponent("scripts/tools/release_notes.swift").path
        let latestVersion = try capture(
            releaseNotesTool,
            [
                "appcast-version", "--appcast",
                rootURL.appendingPathComponent("docs/appcast.xml").path,
            ]
        )
        let latestIntelVersion = try capture(
            releaseNotesTool,
            [
                "appcast-version", "--appcast",
                rootURL.appendingPathComponent("docs/appcast-intel.xml").path,
            ]
        )
        guard latestVersion == latestIntelVersion else {
            throw DevError.commandFailed("arm64 and Intel appcast versions differ", 1)
        }
        try run(releaseNotesTool, ["self-test"])
        try run(rootURL.appendingPathComponent("scripts/tools/repository_policy.swift").path, ["check"])
        try run(releaseNotesTool, [
            "check", "--version", latestVersion,
            "--appcast", rootURL.appendingPathComponent("docs/appcast.xml").path,
            "--appcast", rootURL.appendingPathComponent("docs/appcast-intel.xml").path,
        ])
        try run("/usr/bin/xmllint", [
            "--noout",
            rootURL.appendingPathComponent("docs/appcast.xml").path,
            rootURL.appendingPathComponent("docs/appcast-intel.xml").path,
            rootURL.appendingPathComponent("docs/appcast-beta.xml").path,
        ])
        for plist in ["Info.plist", "PHTV.entitlements", "PrivacyInfo.xcprivacy"] {
            try run("/usr/bin/plutil", [
                "-lint", rootURL.appendingPathComponent("App/PHTV/\(plist)").path,
            ])
        }

    case "format":
        try swiftFormat(["format", "--in-place"])

    case "format-check":
        try swiftFormat(["lint"])

    case "clean":
        if FileManager.default.fileExists(atPath: derivedDataPath) {
            try FileManager.default.removeItem(atPath: derivedDataPath)
        }

    case "", "-h", "--help", "help":
        usage()

    default:
        fputs("Unknown command: \(command)\n", stderr)
        usage()
        exit(2)
    }
} catch DevError.commandFailed(let command, let status) {
    fputs("Command failed with exit code \(status): \(command)\n", stderr)
    exit(status)
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
