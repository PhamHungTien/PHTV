//
//  PHTVTCCMaintenanceService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation

@objcMembers
final class PHTVTCCMaintenanceService: NSObject {
    private class func runTask(
        launchPath: String,
        arguments: [String],
        captureStderr: Bool = false
    ) -> (status: Int32, output: String, errorText: String)? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments

        let stdoutPipe = Pipe()
        task.standardOutput = stdoutPipe

        let stderrPipe: Pipe? = captureStderr ? Pipe() : nil
        if let stderrPipe {
            task.standardError = stderrPipe
        }

        do {
            try task.run()
        } catch {
            NSLog("[TCC] Failed to launch %@: %@", launchPath, error.localizedDescription)
            return nil
        }

        task.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""

        let stderr: String
        if let stderrPipe {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stderr = String(data: stderrData, encoding: .utf8) ?? ""
        } else {
            stderr = ""
        }

        return (task.terminationStatus, stdout, stderr)
    }

    private class func shellEscapedSingleQuotedPath(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }

    @objc(isAppRegisteredInTCC)
    class func isAppRegisteredInTCC() -> Bool {
        guard let result = runTask(
            launchPath: "/usr/bin/tccutil",
            arguments: ["query", "Accessibility"],
            captureStderr: true
        ) else {
            // Preserve current behavior: if we cannot query, assume registered.
            return true
        }

        if result.status != 0 {
            NSLog("[TCC] Failed to query TCC database (status=%d): %@", result.status, result.errorText)
            return true
        }

        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            NSLog("[TCC] Bundle identifier unavailable while checking TCC registration")
            return true
        }

        let isRegistered = result.output.contains(bundleID)
        NSLog(
            "[TCC] App registration check: %@ (bundleID: %@)",
            isRegistered ? "REGISTERED" : "NOT FOUND",
            bundleID
        )
        return isRegistered
    }

    @objc(autoFixTCCEntryWithError:)
    class func autoFixTCCEntry(withError error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        NSLog("[TCC] Auto-fix initiated...")

        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            let missingBundleError = NSError(
                domain: "com.phamhungtien.phtv.tcc",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Missing bundle identifier"]
            )
            error?.pointee = missingBundleError
            return false
        }

        let script = "#!/bin/sh\ntccutil reset Accessibility \(bundleID)\nexit 0\n"
        let tempPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("phtv_tcc_reset_\(UUID().uuidString).sh")

        do {
            try script.write(toFile: tempPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o755))],
                ofItemAtPath: tempPath
            )
        } catch let writeScriptError {
            NSLog("[TCC] Failed to prepare reset script: %@", writeScriptError.localizedDescription)
            error?.pointee = writeScriptError as NSError
            return false
        }

        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }

        let quotedPath = shellEscapedSingleQuotedPath(tempPath)
        let osascriptSource = "do shell script \"sh '\(quotedPath)'\" with administrator privileges"

        let appleScript = NSAppleScript(source: osascriptSource)
        var errorDict: NSDictionary?
        _ = appleScript?.executeAndReturnError(&errorDict)

        if let errorDict {
            NSLog("[TCC] Auto-fix failed or cancelled: %@", errorDict)
            let userInfo = errorDict as? [String: Any]
            let scriptError = NSError(
                domain: "com.phamhungtien.phtv.tcc",
                code: -1,
                userInfo: userInfo
            )
            error?.pointee = scriptError
            return false
        }

        NSLog("[TCC] Auto-fix completed successfully")
        PHTVManager.invalidatePermissionCache()
        usleep(200_000)
        return true
    }

    @objc(restartTCCDaemon)
    class func restartTCCDaemon() {
        NSLog("[TCC] Restarting tccd daemon to refresh permissions...")

        let service = "gui/\(getuid())/com.apple.tccd"

        let launchctlResult = runTask(
            launchPath: "/bin/launchctl",
            arguments: ["kickstart", "-k", service],
            captureStderr: true
        )

        if let result = launchctlResult, result.status == 0 {
            NSLog("[TCC] launchctl kickstart succeeded (status=%d)", result.status)
            usleep(150_000)
            return
        } else if let result = launchctlResult {
            NSLog(
                "[TCC] launchctl kickstart failed (status=%d, output=%@)",
                result.status,
                result.errorText.isEmpty ? "-" : result.errorText
            )
        }

        if let fallback = runTask(
            launchPath: "/usr/bin/killall",
            arguments: ["-KILL", "tccd"],
            captureStderr: true
        ) {
            NSLog("[TCC] killall tccd fallback status=%d", fallback.status)
        } else {
            NSLog("[TCC] killall fallback failed to start")
        }

        usleep(150_000)
    }
}
