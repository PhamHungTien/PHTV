//
//  ClaudeCodePatcher.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

/// Installation type of Claude Code
enum ClaudeInstallationType {
    case notInstalled
    case nativeBinary  // Binary from native install (curl script) - cannot be patched
    case homebrew      // Binary from Homebrew - cannot be patched
    case npm           // JavaScript from npm - can be patched
}

/// Utility class to patch Claude Code CLI for Vietnamese input support
/// Claude Code has a bug where it processes backspace but doesn't insert replacement text
/// This patcher fixes that bug by modifying the cli.js file
final class ClaudeCodePatcher: @unchecked Sendable {
    static let shared = ClaudeCodePatcher()

    /// Marker to identify patched files
    private let patchMarker = "/* PHTV Vietnamese IME fix */"

    /// The fix code that handles Vietnamese IME input correctly (v2.0.76+)
    /// The new Claude Code uses minified variable names like $A, M, DA, etc.
    /// Bug: After processing DEL characters, code returns without inserting remaining text
    /// Fix: Filter out DEL characters and insert the clean text
    private let patchCodeV2 = """
/* PHTV Vietnamese IME fix v2 */
// After backspacing, insert remaining characters (filter out DEL)
let cleanText = DA.replace(/\\x7f/g, '');
if (cleanText.length > 0) {
    for (const char of cleanText) {
        $A = $A.insert(char);
    }
    if (!M.equals($A)) {
        if (M.text !== $A.text) Q($A.text);
        N($A.offset);
    }
}
_eA(), jeA();
return;
"""

    /// Legacy fix code for older versions (pre-2.0.70)
    private let patchCodeLegacy = """
/* PHTV Vietnamese IME fix */
// Process each character: DEL (0x7f) or BS (0x08) = backspace, others = insert
for (const char of e2) {
    const code = char.charCodeAt(0);
    if (code === 127 || code === 8) {
        this.backspace();
    } else {
        this.insert(char);
    }
}
this.render();
return;
"""

    // Multiple patterns to find the buggy code block
    private let searchPatternsV2 = [
        // Pattern for Claude Code 2.0.76+: buggy block that processes DEL but returns without insert
        // Match the entire if block that checks for DEL character and returns
        #"if\s*\(\s*!\s*mA\.backspace\s*&&\s*!\s*mA\.delete\s*&&\s*DA\.includes\s*\([^)]*\)\s*\)\s*\{[^}]*\.match\s*\([^)]*\\x7f[^)]*\)[^}]*backspace[^}]*_eA\s*\(\s*\)\s*,\s*jeA\s*\(\s*\)\s*;\s*return\s*;?\s*\}"#
    ]

    private let searchPatternsLegacy = [
        // Pattern 1: Full block with DEL check (legacy)
        #"if\s*\(\s*e2\.charCodeAt\s*\(\s*0\s*\)\s*===?\s*127\s*\)\s*\{[^}]*this\.backspace\s*\(\s*\)[^}]*\}[^}]*return\s*;?"#,
        // Pattern 2: Simpler pattern
        #"if\s*\([^)]*charCodeAt[^)]*127[^}]*\{[^}]*backspace[^}]*\}"#,
        // Pattern 3: Direct string search
        "e2.charCodeAt(0) === 127"
    ]

    private init() {}

    // MARK: - Public Methods

    /// Detect how Claude Code was installed
    func getInstallationType() -> ClaudeInstallationType {
        let fileManager = FileManager.default
        let homeDir = NSHomeDirectory()

        // Method 1: Check native binary install path first (~/.local/bin/claude)
        let nativePaths = [
            homeDir + "/.local/bin/claude",
            homeDir + "/.claude/bin/claude"
        ]

        for path in nativePaths {
            if fileManager.fileExists(atPath: path) {
                // Check if it's a binary file
                let fileProcess = Process()
                fileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/file")
                fileProcess.arguments = [path]

                let filePipe = Pipe()
                fileProcess.standardOutput = filePipe
                fileProcess.standardError = FileHandle.nullDevice

                do {
                    try fileProcess.run()
                    fileProcess.waitUntilExit()

                    let fileData = filePipe.fileHandleForReading.readDataToEndOfFile()
                    if let fileOutput = String(data: fileData, encoding: .utf8) {
                        if fileOutput.contains("Mach-O") || fileOutput.contains("executable") {
                            return .nativeBinary
                        }
                    }
                } catch {
                    // If we can't check file type but it exists in .local/bin, assume native
                    return .nativeBinary
                }
            }
        }

        // Method 2: Check common Homebrew paths (most reliable in sandbox)
        let homebrewPaths = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/Caskroom/claude-code"
        ]

        for path in homebrewPaths {
            if fileManager.fileExists(atPath: path) {
                // Verify it's actually a Homebrew binary install
                if path.contains("Caskroom") {
                    return .homebrew
                }
                // Check if it's a symlink to Caskroom
                if let resolved = try? fileManager.destinationOfSymbolicLink(atPath: path),
                   resolved.contains("Caskroom") {
                    return .homebrew
                }
                // Check file type
                if let attrs = try? fileManager.attributesOfItem(atPath: path),
                   let type = attrs[.type] as? FileAttributeType {
                    if type == .typeSymbolicLink {
                        // Resolve and check
                        var resolvedPath = path
                        while let resolved = try? fileManager.destinationOfSymbolicLink(atPath: resolvedPath) {
                            resolvedPath = resolved.hasPrefix("/") ? resolved :
                                ((resolvedPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(resolved)
                        }
                        if resolvedPath.contains("Caskroom") || resolvedPath.contains("homebrew") {
                            return .homebrew
                        }
                    }
                }
                // It exists at Homebrew path, assume Homebrew
                return .homebrew
            }
        }

        // Method 2: Check if npm cli.js exists
        if getClaudeCliPath() != nil {
            return .npm
        }

        // Method 3: Try 'which claude' command as fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "claude"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let claudePath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !claudePath.isEmpty else {
                return .notInstalled
            }

            // Check if it's Homebrew installation
            if claudePath.contains("homebrew") || claudePath.contains("Caskroom") {
                return .homebrew
            }

            // Resolve symlinks
            var resolvedPath = claudePath
            while let resolved = try? fileManager.destinationOfSymbolicLink(atPath: resolvedPath) {
                resolvedPath = resolved.hasPrefix("/") ? resolved :
                    ((resolvedPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(resolved)
            }

            if resolvedPath.contains("homebrew") || resolvedPath.contains("Caskroom") {
                return .homebrew
            }

            // Check if it's native binary install (.claude directory)
            if resolvedPath.contains(".claude") {
                return .nativeBinary
            }

            // Check if it's a binary (could be native or homebrew)
            let fileProcess = Process()
            fileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/file")
            fileProcess.arguments = [resolvedPath]

            let filePipe = Pipe()
            fileProcess.standardOutput = filePipe
            fileProcess.standardError = FileHandle.nullDevice

            try fileProcess.run()
            fileProcess.waitUntilExit()

            let fileData = filePipe.fileHandleForReading.readDataToEndOfFile()
            if let fileOutput = String(data: fileData, encoding: .utf8) {
                if fileOutput.contains("Mach-O") || fileOutput.contains("executable") {
                    // It's a binary, but not in homebrew or .claude - assume native install
                    return .nativeBinary
                }
            }

            return .npm

        } catch {
            return .notInstalled
        }
    }

    /// Check if Claude Code is installed
    func isClaudeCodeInstalled() -> Bool {
        return getInstallationType() != .notInstalled
    }

    /// Check if Claude Code is already patched
    func isPatched() -> Bool {
        guard let cliPath = getClaudeCliPath(),
              let content = try? String(contentsOfFile: cliPath, encoding: .utf8) else {
            return false
        }
        // Check for both legacy and v2 markers
        return content.contains(patchMarker) || content.contains("PHTV Vietnamese IME fix v2")
    }

    /// Get Claude Code version
    func getClaudeVersion() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["claude", "--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Apply the Vietnamese input fix patch
    func applyPatch() -> Result<String, PatchError> {
        guard let cliPath = getClaudeCliPath() else {
            return .failure(.claudeNotFound)
        }

        // Check if already patched
        if isPatched() {
            return .success("Claude Code đã được vá trước đó")
        }

        // Read the CLI file
        guard let content = try? String(contentsOfFile: cliPath, encoding: .utf8) else {
            return .failure(.cannotReadFile)
        }

        // Create backup
        let backupPath = cliPath + ".phtv-backup-\(Int(Date().timeIntervalSince1970))"
        do {
            try content.write(toFile: backupPath, atomically: true, encoding: .utf8)
        } catch {
            return .failure(.cannotCreateBackup)
        }

        // Try to find and replace the buggy code
        var patchedContent: String?

        // Method 1: Try V2 patterns first (Claude Code 2.0.76+)
        for pattern in searchPatternsV2 {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(content.startIndex..., in: content)
                if let match = regex.firstMatch(in: content, options: [], range: range) {
                    let matchRange = Range(match.range, in: content)!
                    patchedContent = content.replacingCharacters(in: matchRange, with: patchCodeV2)
                    break
                }
            }
        }

        // Method 2: Try V2 direct string matching (simpler but reliable)
        if patchedContent == nil && content.contains("DA.includes(\"\u{7f}\")") {
            patchedContent = applyV2Patch(content: content)
        }

        // Method 3: Alternative V2 pattern - find the return after DEL processing
        if patchedContent == nil && content.contains(".match(/\\x7f/g)") {
            patchedContent = applyV2PatchAlternative(content: content)
        }

        // Method 4: Try legacy patterns (older Claude Code versions)
        if patchedContent == nil {
            for pattern in searchPatternsLegacy {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                    let range = NSRange(content.startIndex..., in: content)
                    if let match = regex.firstMatch(in: content, options: [], range: range) {
                        let matchRange = Range(match.range, in: content)!
                        patchedContent = content.replacingCharacters(in: matchRange, with: patchCodeLegacy)
                        break
                    }
                }
            }
        }

        // Method 5: Fallback - legacy direct string replacement
        if patchedContent == nil {
            if content.contains("e2.charCodeAt(0) === 127") || content.contains("e2.charCodeAt(0)===127") {
                let lines = content.components(separatedBy: "\n")
                var newLines: [String] = []
                var skipUntilReturn = false
                var foundBuggyCode = false

                for line in lines {
                    if line.contains("e2.charCodeAt(0)") && line.contains("127") {
                        newLines.append(patchCodeLegacy)
                        skipUntilReturn = true
                        foundBuggyCode = true
                        continue
                    }

                    if skipUntilReturn {
                        if line.contains("return") {
                            skipUntilReturn = false
                        }
                        continue
                    }

                    newLines.append(line)
                }

                if foundBuggyCode {
                    patchedContent = newLines.joined(separator: "\n")
                }
            }
        }

        guard let finalContent = patchedContent else {
            return .failure(.patternNotFound)
        }

        // Write the patched content
        do {
            try finalContent.write(toFile: cliPath, atomically: true, encoding: .utf8)
        } catch {
            // Try to restore backup
            try? content.write(toFile: cliPath, atomically: true, encoding: .utf8)
            return .failure(.cannotWriteFile)
        }

        return .success("Đã vá Claude Code thành công! Vui lòng khởi động lại Claude Code.")
    }

    /// Find the brew executable path
    private func findBrewPath() -> String? {
        let brewPaths = [
            "/opt/homebrew/bin/brew",   // Apple Silicon
            "/usr/local/bin/brew",       // Intel Mac
            "/home/linuxbrew/.linuxbrew/bin/brew"  // Linux
        ]

        for path in brewPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback: use 'which brew'
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "brew"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let brewPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !brewPath.isEmpty,
               FileManager.default.fileExists(atPath: brewPath) {
                return brewPath
            }
        } catch {}

        return nil
    }

    /// Reinstall Claude Code from npm (uninstall binary version first)
    /// Returns progress updates via callback
    func reinstallFromNpm(progress: @escaping (String) -> Void, completion: @escaping (Result<String, PatchError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Check installation type and uninstall if needed
            let installType = self.getInstallationType()

            // Handle native binary install
            if installType == .nativeBinary {
                progress("Đang gỡ Claude Code native binary...")

                // Try to remove native binary installation
                let homeDir = NSHomeDirectory()
                let possiblePaths = [
                    homeDir + "/.local/bin/claude",  // Primary native install location
                    homeDir + "/.claude",            // Alternative native install location
                    "/usr/local/bin/claude",
                    "/opt/homebrew/bin/claude"
                ]

                for path in possiblePaths {
                    if FileManager.default.fileExists(atPath: path) {
                        // Check if this is native install (not homebrew)
                        var shouldRemove = false
                        if path.contains(".local/bin") || path.contains(".claude") {
                            shouldRemove = true
                        } else if let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: path),
                                  !resolved.contains("homebrew") && !resolved.contains("Caskroom") {
                            shouldRemove = true
                        }

                        if shouldRemove {
                            try? FileManager.default.removeItem(atPath: path)
                        }
                    }
                }

                // Continue to npm install
                self.installViaAndPatch(progress: progress, completion: completion)
                return
            }

            // Handle Homebrew install
            if installType == .homebrew {
                progress("Đang gỡ Claude Code Homebrew...")

                guard let brewPath = self.findBrewPath() else {
                    // No brew found, but Homebrew was detected - try to continue anyway
                    progress("Không tìm thấy brew, bỏ qua gỡ cài đặt...")
                    // Continue to npm install
                    self.installViaAndPatch(progress: progress, completion: completion)
                    return
                }

                // Try multiple uninstall commands
                let uninstallCommands: [[String]] = [
                    ["uninstall", "--cask", "claude-code"],
                    ["uninstall", "claude-code"],
                    ["uninstall", "--cask", "--force", "claude-code"],
                    ["uninstall", "--force", "claude-code"]
                ]

                var uninstalled = false
                for args in uninstallCommands {
                    let uninstallProcess = Process()
                    uninstallProcess.executableURL = URL(fileURLWithPath: brewPath)
                    uninstallProcess.arguments = args
                    uninstallProcess.standardOutput = FileHandle.nullDevice
                    uninstallProcess.standardError = FileHandle.nullDevice

                    do {
                        try uninstallProcess.run()
                        uninstallProcess.waitUntilExit()
                        if uninstallProcess.terminationStatus == 0 {
                            uninstalled = true
                            break
                        }
                    } catch {
                        continue
                    }
                }

                // Also try to remove the symlink manually if it still exists
                let symlinkPaths = [
                    "/opt/homebrew/bin/claude",
                    "/usr/local/bin/claude"
                ]

                for path in symlinkPaths {
                    if FileManager.default.fileExists(atPath: path) {
                        // Check if it's a symlink to Homebrew/Caskroom
                        if let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: path),
                           resolved.contains("Caskroom") || resolved.contains("homebrew") {
                            try? FileManager.default.removeItem(atPath: path)
                        }
                    }
                }

                if !uninstalled {
                    progress("Không thể gỡ Homebrew, thử cài npm...")
                }
            }

            // Step 2 & 3: Install via npm and apply patch
            self.installViaAndPatch(progress: progress, completion: completion)
        }
    }

    /// Install Claude Code via npm and apply patch
    private func installViaAndPatch(progress: @escaping (String) -> Void, completion: @escaping (Result<String, PatchError>) -> Void) {
        progress("Đang cài đặt Claude Code qua npm...")

        // Find npm path (including nvm)
        let homeDir = NSHomeDirectory()
        var npmPaths = [
            "/opt/homebrew/bin/npm",
            "/usr/local/bin/npm",
            "/usr/bin/npm"
        ]

        // Add nvm paths (prefer newer versions)
        let nvmDir = homeDir + "/.nvm/versions/node"
        if let nodeVersions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for version in nodeVersions.sorted().reversed() {
                npmPaths.insert(nvmDir + "/" + version + "/bin/npm", at: 0)
            }
        }

        // Also check fnm paths
        let fnmDir = homeDir + "/Library/Application Support/fnm/node-versions"
        if let nodeVersions = try? FileManager.default.contentsOfDirectory(atPath: fnmDir) {
            for version in nodeVersions.sorted().reversed() {
                npmPaths.insert(fnmDir + "/" + version + "/installation/bin/npm", at: 0)
            }
        }

        var npmPath: String?
        for path in npmPaths {
            if FileManager.default.fileExists(atPath: path) {
                npmPath = path
                break
            }
        }

        guard let npm = npmPath else {
            completion(.failure(.npmNotFound))
            return
        }

        progress("Tìm thấy npm tại: \(npm)")

        // Build full PATH including node bin directory
        let nodeBinDir = (npm as NSString).deletingLastPathComponent
        var fullPath = nodeBinDir

        // Add common paths
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        for path in commonPaths {
            if !fullPath.contains(path) {
                fullPath += ":" + path
            }
        }

        // Use /bin/sh to run npm with proper environment
        let installProcess = Process()
        installProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
        installProcess.arguments = ["-c", "export PATH=\"\(fullPath):$PATH\" && \"\(npm)\" install -g @anthropic-ai/claude-code 2>&1"]

        // Set up environment
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = fullPath
        env["HOME"] = homeDir
        // Ensure npm uses the correct prefix for global installs (nvm)
        if npm.contains(".nvm") {
            env["npm_config_prefix"] = (nodeBinDir as NSString).deletingLastPathComponent
        }
        installProcess.environment = env

        let pipe = Pipe()
        installProcess.standardOutput = pipe
        installProcess.standardError = pipe

        do {
            try installProcess.run()
            installProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if installProcess.terminationStatus != 0 {
                // Check for specific error types
                if output.contains("permission denied") || output.contains("EACCES") {
                    completion(.failure(.npmPermissionDenied))
                } else if output.contains("npm ERR!") {
                    // Extract the actual npm error for better debugging
                    completion(.failure(.npmInstallFailedWithDetails(output)))
                } else {
                    completion(.failure(.npmInstallFailedWithDetails(output)))
                }
                return
            }

            // Verify installation succeeded by checking if claude is now available
            progress("Đang kiểm tra cài đặt...")
            Thread.sleep(forTimeInterval: 0.5)

            // Check if cli.js now exists
            if self.getClaudeCliPath() == nil {
                // npm reported success but claude is not found
                completion(.failure(.npmInstallFailedWithDetails("npm báo thành công nhưng không tìm thấy Claude Code. Output: \(output)")))
                return
            }

        } catch {
            completion(.failure(.npmInstallFailedWithDetails("Lỗi chạy npm: \(error.localizedDescription)")))
            return
        }

        // Step 3: Apply patch
        progress("Đang vá Claude Code...")

        let patchResult = self.applyPatch()
        switch patchResult {
        case .success:
            completion(.success("Đã cài đặt và vá Claude Code thành công!"))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    /// Remove the patch and restore original
    func removePatch() -> Result<String, PatchError> {
        guard let cliPath = getClaudeCliPath() else {
            return .failure(.claudeNotFound)
        }

        // Find the latest backup
        let cliDir = (cliPath as NSString).deletingLastPathComponent
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(atPath: cliDir) else {
            return .failure(.noBackupFound)
        }

        let backups = files.filter { $0.contains(".phtv-backup-") }
            .sorted()
            .reversed()

        guard let latestBackup = backups.first else {
            return .failure(.noBackupFound)
        }

        let backupPath = (cliDir as NSString).appendingPathComponent(latestBackup)

        do {
            let backupContent = try String(contentsOfFile: backupPath, encoding: .utf8)
            try backupContent.write(toFile: cliPath, atomically: true, encoding: .utf8)
            try fileManager.removeItem(atPath: backupPath)
            return .success("Đã khôi phục Claude Code về bản gốc")
        } catch {
            return .failure(.cannotRestoreBackup)
        }
    }

    // MARK: - Manual Installation Helper

    /// Get the command to manually install Claude Code via npm
    func getManualInstallCommand() -> String {
        return "npm install -g @anthropic-ai/claude-code"
    }

    /// Get the full command to uninstall homebrew and install npm version
    func getFullManualCommand(isHomebrew: Bool) -> String {
        if isHomebrew {
            return """
            brew uninstall --cask claude-code 2>/dev/null || brew uninstall claude-code 2>/dev/null
            npm install -g @anthropic-ai/claude-code
            """
        } else {
            return "npm install -g @anthropic-ai/claude-code"
        }
    }

    /// Open Terminal with installation command
    func openTerminalWithInstallCommand(isHomebrew: Bool) {
        let command = isHomebrew
            ? "brew uninstall --cask claude-code; npm install -g @anthropic-ai/claude-code"
            : "npm install -g @anthropic-ai/claude-code"

        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }

    // MARK: - Private Methods

    /// Apply V2 patch by finding the buggy block that handles DEL characters
    /// Claude Code 2.0.76+ uses minified variable names
    private func applyV2Patch(content: String) -> String? {
        // The buggy pattern in v2.0.76:
        // if(!mA.backspace&&!mA.delete&&DA.includes("")){
        //   let qA=(DA.match(/\x7f/g)||[]).length,$A=M;
        //   for(let KA=0;KA<qA;KA++)$A=$A.backspace();
        //   if(!M.equals($A)){if(M.text!==$A.text)Q($A.text);N($A.offset)}
        //   _eA(),jeA();
        //   return  <-- BUG: returns without inserting remaining text
        // }

        // More specific pattern that only matches the DEL handling block
        // The buggy pattern ends with: N($A.offset)}_eA(),jeA();return
        let buggyPattern = "N($A.offset)}_eA(),jeA();return"

        // The fix: after backspacing, insert remaining characters
        // We replace the return with code that inserts clean text first
        let fixCode = """
N($A.offset)}/* PHTV Vietnamese IME fix v2 */let _phtv_clean=DA.replace(/\\x7f/g,'');if(_phtv_clean.length>0){for(const _phtv_c of _phtv_clean){$A=$A.insert(_phtv_c)}if(!M.equals($A)){if(M.text!==$A.text)Q($A.text);N($A.offset)}}_eA(),jeA();return
"""

        if content.contains(buggyPattern) {
            return content.replacingOccurrences(of: buggyPattern, with: fixCode)
        }

        return nil
    }

    /// Alternative V2 patch method - more targeted replacement
    private func applyV2PatchAlternative(content: String) -> String? {
        // Look for the pattern where DEL is processed but return happens without insert
        // Find: .match(/\x7f/g) ... _eA(),jeA();return
        // The key is to insert remaining text before return

        // Use regex to find the exact block
        let pattern = #"\$A=\$A\.backspace\(\)\}if\(!M\.equals\(\$A\)\)\{if\(M\.text!==\$A\.text\)Q\(\$A\.text\);N\(\$A\.offset\)\}_eA\(\),jeA\(\);return"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(content.startIndex..., in: content)
        guard regex.firstMatch(in: content, options: [], range: range) != nil else {
            return nil
        }

        // Replace with fixed version that inserts clean text
        let replacement = """
$A=$A.backspace()}/* PHTV Vietnamese IME fix v2 */let _phtv_clean=DA.replace(/\\x7f/g,'');if(_phtv_clean.length>0){for(const _phtv_c of _phtv_clean){$A=$A.insert(_phtv_c)}}if(!M.equals($A)){if(M.text!==$A.text)Q($A.text);N($A.offset)}_eA(),jeA();return
"""

        return regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
    }

    /// Get the path to Claude CLI's main JavaScript file
    private func getClaudeCliPath() -> String? {
        // Method 1: Use 'which claude' command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "claude"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if var claudePath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !claudePath.isEmpty {

                // Resolve symlinks
                let fileManager = FileManager.default
                while let resolved = try? fileManager.destinationOfSymbolicLink(atPath: claudePath) {
                    if resolved.hasPrefix("/") {
                        claudePath = resolved
                    } else {
                        claudePath = ((claudePath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(resolved)
                    }
                }

                // The actual cli.js is usually in the same directory or parent
                // Common locations:
                // - /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js
                // - ~/.npm/_npx/.../node_modules/@anthropic-ai/claude-code/cli.js

                let possiblePaths = [
                    claudePath, // The symlink target itself might be cli.js
                    (claudePath as NSString).deletingLastPathComponent + "/cli.js",
                    (claudePath as NSString).deletingLastPathComponent + "/../cli.js",
                    ((claudePath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent + "/cli.js"
                ]

                for path in possiblePaths {
                    let normalizedPath = (path as NSString).standardizingPath
                    if fileManager.fileExists(atPath: normalizedPath),
                       normalizedPath.hasSuffix(".js") {
                        return normalizedPath
                    }
                }

                // Search for cli.js in the directory structure
                if let cliPath = findCliJs(in: (claudePath as NSString).deletingLastPathComponent) {
                    return cliPath
                }
            }
        } catch {
            // Continue to other methods
        }

        // Method 2: Check common installation paths (including nvm)
        let homeDir = NSHomeDirectory()
        var commonPaths = [
            "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js",
            "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js",
            homeDir + "/.npm/_npx/*/node_modules/@anthropic-ai/claude-code/cli.js"
        ]

        // Add nvm paths
        let nvmDir = homeDir + "/.nvm/versions/node"
        if let nodeVersions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for version in nodeVersions.sorted().reversed() {
                commonPaths.insert(nvmDir + "/" + version + "/lib/node_modules/@anthropic-ai/claude-code/cli.js", at: 0)
            }
        }

        let fileManager = FileManager.default
        for path in commonPaths {
            if path.contains("*") {
                // Handle glob pattern
                let basePath = (path as NSString).deletingLastPathComponent
                let pattern = (path as NSString).lastPathComponent
                if let files = try? fileManager.contentsOfDirectory(atPath: (basePath as NSString).deletingLastPathComponent) {
                    for file in files {
                        let fullPath = ((basePath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(file)
                        let cliPath = (fullPath as NSString).appendingPathComponent(pattern)
                        if fileManager.fileExists(atPath: cliPath) {
                            return cliPath
                        }
                    }
                }
            } else if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    /// Recursively search for cli.js in a directory
    private func findCliJs(in directory: String, maxDepth: Int = 5) -> String? {
        guard maxDepth > 0 else { return nil }

        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        for item in contents {
            let itemPath = (directory as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if item == "cli.js" {
                    // Verify it's the Claude Code cli.js by checking content
                    if let content = try? String(contentsOfFile: itemPath, encoding: .utf8),
                       content.contains("anthropic") || content.contains("claude") {
                        return itemPath
                    }
                } else if isDirectory.boolValue && !item.hasPrefix(".") {
                    if let found = findCliJs(in: itemPath, maxDepth: maxDepth - 1) {
                        return found
                    }
                }
            }
        }

        return nil
    }
}

// MARK: - Error Types

enum PatchError: Error, LocalizedError {
    case claudeNotFound
    case cannotReadFile
    case cannotWriteFile
    case cannotCreateBackup
    case cannotRestoreBackup
    case noBackupFound
    case patternNotFound
    case npmNotFound
    case npmInstallFailed
    case npmInstallFailedWithDetails(String)
    case npmPermissionDenied
    case requiresManualInstall(isHomebrew: Bool)

    var errorDescription: String? {
        switch self {
        case .claudeNotFound:
            return "Không tìm thấy Claude Code. Vui lòng cài đặt Claude Code trước."
        case .cannotReadFile:
            return "Không thể đọc file Claude Code CLI."
        case .cannotWriteFile:
            return "Không thể ghi file. Có thể cần quyền admin."
        case .cannotCreateBackup:
            return "Không thể tạo bản sao lưu."
        case .cannotRestoreBackup:
            return "Không thể khôi phục bản sao lưu."
        case .noBackupFound:
            return "Không tìm thấy bản sao lưu nào."
        case .patternNotFound:
            return "Không tìm thấy đoạn code cần vá. Có thể Claude Code đã được cập nhật."
        case .npmNotFound:
            return "Không tìm thấy npm. Vui lòng cài đặt Node.js trước."
        case .npmInstallFailed:
            return "Không thể cài đặt Claude Code qua npm."
        case .npmInstallFailedWithDetails(let details):
            // Truncate details if too long
            let maxLength = 500
            let truncatedDetails = details.count > maxLength
                ? String(details.prefix(maxLength)) + "..."
                : details
            return "Không thể cài đặt Claude Code qua npm.\n\nChi tiết: \(truncatedDetails)\n\nBạn có thể thử chạy thủ công trong Terminal:\nnpm install -g @anthropic-ai/claude-code"
        case .npmPermissionDenied:
            return "Không có quyền cài đặt. Hãy thử chạy trong Terminal:\nnpm install -g @anthropic-ai/claude-code\n\nHoặc với quyền admin:\nsudo npm install -g @anthropic-ai/claude-code"
        case .requiresManualInstall(let isHomebrew):
            if isHomebrew {
                return "Cần cài đặt thủ công. Vui lòng chạy trong Terminal:\n\nbrew uninstall --cask claude-code\nnpm install -g @anthropic-ai/claude-code"
            } else {
                return "Cần cài đặt thủ công. Vui lòng chạy trong Terminal:\n\nnpm install -g @anthropic-ai/claude-code"
            }
        }
    }

    /// Check if this error can be resolved by manual installation
    var canOpenTerminal: Bool {
        switch self {
        case .npmInstallFailed, .npmInstallFailedWithDetails, .npmPermissionDenied, .requiresManualInstall:
            return true
        default:
            return false
        }
    }
}
