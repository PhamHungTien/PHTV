#!/usr/bin/env swift

import Foundation

enum RunnerError: Error, CustomStringConvertible {
    case commandFailed(String, Int32)
    case missingExecutable(String)
    case invalidMode(String)

    var description: String {
        switch self {
        case .commandFailed(let command, let status):
            return "Command failed (\(status)): \(command)"
        case .missingExecutable(let path):
            return "Built app executable not found: \(path)"
        case .invalidMode(let mode):
            return "Unknown mode '\(mode)'. Use run, debug, logs, telemetry, or verify."
        }
    }
}

let scriptURL = URL(fileURLWithPath: #filePath)
let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let derivedDataURL = URL(
    fileURLWithPath: ProcessInfo.processInfo.environment["DERIVED_DATA_PATH"]
        ?? rootURL.appendingPathComponent(".build/derived-data").path
)
let appURL = derivedDataURL.appendingPathComponent("Build/Products/Debug/PHTV.app")
let executableURL = appURL.appendingPathComponent("Contents/MacOS/PHTV")
let mode = CommandLine.arguments.dropFirst().first?.replacingOccurrences(of: "--", with: "") ?? "run"

@discardableResult
func run(
    _ executable: String,
    _ arguments: [String],
    environment: [String: String] = [:],
    allowFailure: Bool = false,
    interactive: Bool = false
) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = rootURL
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    if interactive {
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
    }
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 && !allowFailure {
        throw RunnerError.commandFailed(([executable] + arguments).joined(separator: " "), process.terminationStatus)
    }
    return process.terminationStatus
}

do {
    try run("/usr/bin/pkill", ["-x", "PHTV"], allowFailure: true)
    try run(
        rootURL.appendingPathComponent("scripts/dev.swift").path,
        ["build"],
        environment: ["DERIVED_DATA_PATH": derivedDataURL.path],
        interactive: true
    )

    guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
        throw RunnerError.missingExecutable(executableURL.path)
    }

    switch mode {
    case "run":
        try run("/usr/bin/open", ["-n", appURL.path])
    case "debug":
        try run("/usr/bin/lldb", ["--", executableURL.path], interactive: true)
    case "logs":
        try run("/usr/bin/open", ["-n", appURL.path])
        try run(
            "/usr/bin/log",
            ["stream", "--info", "--style", "compact", "--predicate", "process == \"PHTV\""],
            interactive: true
        )
    case "telemetry":
        try run("/usr/bin/open", ["-n", appURL.path])
        try run(
            "/usr/bin/log",
            [
                "stream", "--info", "--style", "compact", "--predicate",
                "subsystem BEGINSWITH \"com.phamhungtien.phtv\"",
            ],
            interactive: true
        )
    case "verify":
        try run("/usr/bin/open", ["-n", appURL.path])
        for _ in 0..<5 {
            if run("/usr/bin/pgrep", ["-x", "PHTV"], allowFailure: true) == 0 {
                print("PHTV launched successfully.")
                exit(0)
            }
            Thread.sleep(forTimeInterval: 1)
        }
        throw RunnerError.commandFailed("PHTV launch verification", 1)
    default:
        throw RunnerError.invalidMode(mode)
    }
} catch {
    fputs("build-and-run: \(error)\n", stderr)
    exit(1)
}
