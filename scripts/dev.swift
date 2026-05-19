#!/usr/bin/env swift
import Foundation

enum DevError: Error {
    case invalidUTF8
    case commandFailed(String, Int32)
}

let fileURL = URL(fileURLWithPath: #filePath)
let rootURL = fileURL.deletingLastPathComponent().deletingLastPathComponent()
let rootPath = rootURL.path
let projectPath = rootURL.appendingPathComponent("App/PHTV.xcodeproj").path
let scheme = "PHTV"
let destination = "platform=macOS"
let derivedDataPath = ProcessInfo.processInfo.environment["DERIVED_DATA_PATH"]
    ?? rootURL.appendingPathComponent(".build/derived-data").path
let developerDir = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
    ?? "/Applications/Xcode.app/Contents/Developer"

let command = CommandLine.arguments.dropFirst().first ?? ""

func usage() {
    print("""
    Usage: scripts/dev.swift <command>

    Commands:
      env-check     Print the local toolchain setup used by this project
      build         Build the macOS app in Debug
      test          Run all XCTest tests
      engine-test   Run EngineRegressionTests only
      hotkey-test   Run HotkeyReliabilityTests only
      dict-check    Validate checked-in dictionary sources
      clean         Remove local DerivedData used by this script

    Environment:
      DEVELOPER_DIR       Override Xcode path, defaults to /Applications/Xcode.app/Contents/Developer
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
