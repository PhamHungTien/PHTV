//
//  PHTVBinaryIntegrityService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

@objcMembers
final class PHTVBinaryIntegrityService: NSObject {
    private static let binaryHashDefaultsKey = "BinaryHashAtLastRun"
    private static let binaryChangedNotification = Notification.Name("BinaryChangedBetweenRuns")
    private static let binaryModifiedWarningNotification = Notification.Name("BinaryModifiedWarning")
    private static let binarySignatureInvalidNotification = Notification.Name("BinarySignatureInvalid")

    private class func runProcess(
        executablePath: String,
        arguments: [String],
        captureStdErr: Bool = false
    ) -> (status: Int32, output: String?)? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        if captureStdErr {
            task.standardError = pipe
        }

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            return (task.terminationStatus, output)
        } catch {
            NSLog("[BinaryIntegrity] Process failed (%@): %@", executablePath, error.localizedDescription)
            return nil
        }
    }

    private class func normalizedBinaryPath() -> String? {
        Bundle.main.executablePath
    }

    private class func normalizedBundlePath() -> String? {
        Bundle.main.bundlePath
    }

    class func getBinaryArchitectures() -> String {
        guard let executablePath = normalizedBinaryPath() else {
            return "Unknown (no executable path)"
        }

        if let result = runProcess(executablePath: "/usr/bin/lipo", arguments: ["-archs", executablePath]),
           result.status == 0,
           let output = result.output {
            let tokens = output
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)

            let knownArchitectures: Set<String> = ["arm64", "arm64e", "x86_64", "i386"]
            let architectures = tokens.filter { knownArchitectures.contains($0) }

            if architectures.count >= 2 &&
                architectures.contains("arm64") &&
                architectures.contains("x86_64") {
                return "Universal (arm64 + x86_64)"
            }
            if architectures.count == 1 {
                return "\(architectures[0]) only"
            }
            if architectures.count > 1 {
                return "Multiple (\(architectures.joined(separator: " + ")))"
            }
        }

        if let fallback = runProcess(executablePath: "/usr/bin/file", arguments: [executablePath], captureStdErr: true),
           let output = fallback.output {
            if output.contains("arm64") && output.contains("x86_64") {
                return "Universal (arm64 + x86_64)"
            }
            if output.contains("arm64") {
                return "arm64 only"
            }
            if output.contains("x86_64") {
                return "x86_64 only"
            }
        }

        return "Unknown"
    }

    class func getBinaryHash() -> String? {
        guard let executablePath = normalizedBinaryPath() else {
            return nil
        }

        guard let result = runProcess(
            executablePath: "/usr/bin/shasum",
            arguments: ["-a", "256", executablePath]
        ),
        result.status == 0,
        let output = result.output else {
            return nil
        }

        let hash = output
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (hash?.isEmpty == false) ? hash : nil
    }

    class func hasBinaryChangedSinceLastRun() -> Bool {
        guard let currentHash = getBinaryHash() else {
            return false
        }

        let defaults = UserDefaults.standard
        guard let savedHash = defaults.string(forKey: binaryHashDefaultsKey) else {
            defaults.set(currentHash, forKey: binaryHashDefaultsKey)
            let prefix = String(currentHash.prefix(16))
            NSLog("[BinaryIntegrity] First run - saved hash: %@...", prefix)
            return false
        }

        let changed = (currentHash != savedHash)
        guard changed else {
            return false
        }

        NSLog("[BinaryIntegrity] 🚨 BINARY CHANGED DETECTED!")
        NSLog("[BinaryIntegrity] Previous: %@...", String(savedHash.prefix(16)))
        NSLog("[BinaryIntegrity] Current:  %@...", String(currentHash.prefix(16)))

        defaults.set(currentHash, forKey: binaryHashDefaultsKey)

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: binaryChangedNotification,
                object: [
                    "previousHash": savedHash,
                    "currentHash": currentHash,
                    "architecture": getBinaryArchitectures()
                ]
            )
        }

        return true
    }

    class func checkBinaryIntegrity() -> Bool {
        guard normalizedBinaryPath() != nil else {
            NSLog("[BinaryIntegrity] ❌ No executable path found")
            return false
        }
        guard let bundlePath = normalizedBundlePath() else {
            NSLog("[BinaryIntegrity] ❌ No bundle path found")
            return false
        }

        let binaryChanged = hasBinaryChangedSinceLastRun()
        if binaryChanged {
            NSLog("[BinaryIntegrity] ⚠️ Binary hash changed since last run")
        }

        let archInfo = getBinaryArchitectures()
        NSLog("[BinaryIntegrity] Binary architecture: %@", archInfo)

        let verifyArgs = ["--verify", "--deep", "--strict", bundlePath]
        guard let verifyResult = runProcess(
            executablePath: "/usr/bin/codesign",
            arguments: verifyArgs,
            captureStdErr: true
        ) else {
            NSLog("[BinaryIntegrity] ❌ Error verifying signature: failed to run codesign")
            return false
        }

        if verifyResult.status == 0 {
            NSLog("[BinaryIntegrity] ✅ Code signature is valid")

            if binaryChanged {
                NSLog("[BinaryIntegrity] ⚠️ WARNING: Binary appears to have been modified")
                NSLog("[BinaryIntegrity] ⚠️ This may cause Accessibility permission issues")
                NSLog("[BinaryIntegrity] ⚠️ Recommendation: Reinstall app from original build")

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: binaryModifiedWarningNotification,
                        object: archInfo
                    )
                }
            }

            return true
        }

        let errorOutput = (verifyResult.output ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("[BinaryIntegrity] ❌ Code signature verification failed: %@", errorOutput)

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: binarySignatureInvalidNotification,
                object: errorOutput
            )
        }

        return false
    }
}
