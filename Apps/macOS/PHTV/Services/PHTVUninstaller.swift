//
//  PHTVUninstaller.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation
import ServiceManagement

struct PHTVUninstallPlan {
    let appURL: URL
    let cleanupURLs: [URL]
}

enum PHTVUninstallError: LocalizedError {
    case invalidAppBundle(URL)
    case scriptCreationFailed(Error)
    case scriptLaunchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAppBundle:
            return "Không thể xác định app bundle PHTV để gỡ cài đặt an toàn."
        case .scriptCreationFailed(let error):
            return "Không thể chuẩn bị trình gỡ cài đặt: \(error.localizedDescription)"
        case .scriptLaunchFailed(let error):
            return "Không thể chạy trình gỡ cài đặt: \(error.localizedDescription)"
        }
    }
}

enum PHTVUninstaller {
    @MainActor
    static func scheduleCleanUninstall() throws {
        let fileManager = FileManager.default
        let plan = makePlan(fileManager: fileManager)

        guard plan.appURL.pathExtension == "app" else {
            throw PHTVUninstallError.invalidAppBundle(plan.appURL)
        }

        prepareForUninstall()

        let scriptURL: URL
        do {
            scriptURL = try writeUninstallScript(fileManager: fileManager)
        } catch {
            throw PHTVUninstallError.scriptCreationFailed(error)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            scriptURL.path,
            "\(ProcessInfo.processInfo.processIdentifier)",
            plan.appURL.path
        ] + plan.cleanupURLs.map(\.path)

        do {
            try process.run()
        } catch {
            throw PHTVUninstallError.scriptLaunchFailed(error)
        }

        NSApp.terminate(nil)
    }

    static func makePlan(
        fileManager: FileManager = .default,
        bundle: Bundle = .main
    ) -> PHTVUninstallPlan {
        let home = fileManager.homeDirectoryForCurrentUser
        let temporaryDirectory = fileManager.temporaryDirectory
        let appURL = bundle.bundleURL.standardizedFileURL

        let bundleIdentifiers = orderedUnique([
            bundle.bundleIdentifier,
            "com.phamhungtien.phtv",
            "com.phamhungtien.phtv.debug"
        ].compactMap { $0 })

        let appNames = orderedUnique([
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
            "PHTV"
        ].compactMap { $0 })

        var urls: [URL] = []

        for appName in appNames {
            urls.append(libraryURL(home, "Application Support", appName, isDirectory: true))
            urls.append(libraryURL(home, "Caches", appName, isDirectory: true))
            urls.append(libraryURL(home, "Logs", appName, isDirectory: true))
            urls.append(libraryURL(home, "HTTPStorages", appName, isDirectory: true))
        }

        for bundleIdentifier in bundleIdentifiers {
            urls.append(libraryURL(home, "Preferences", "\(bundleIdentifier).plist"))
            urls.append(libraryURL(home, "Caches", bundleIdentifier, isDirectory: true))
            urls.append(libraryURL(home, "HTTPStorages", bundleIdentifier, isDirectory: true))
            urls.append(libraryURL(home, "Saved Application State", "\(bundleIdentifier).savedState", isDirectory: true))
            urls.append(libraryURL(home, "Containers", bundleIdentifier, isDirectory: true))
            urls.append(libraryURL(home, "Group Containers", bundleIdentifier, isDirectory: true))
            urls.append(libraryURL(home, "Application Scripts", bundleIdentifier, isDirectory: true))
        }

        urls.append(temporaryDirectory.appendingPathComponent("PHTPMedia", isDirectory: true))
        urls.append(temporaryDirectory.appendingPathComponent("PHTV", isDirectory: true))
        urls.append(contentsOf: byHostPreferenceURLs(home: home, bundleIdentifiers: bundleIdentifiers, fileManager: fileManager))
        urls.append(contentsOf: diagnosticReportURLs(home: home, bundleIdentifiers: bundleIdentifiers, appNames: appNames, fileManager: fileManager))

        return PHTVUninstallPlan(
            appURL: appURL,
            cleanupURLs: uniqueURLs(urls).filter { $0.standardizedFileURL.path != appURL.path }
        )
    }

    @MainActor
    private static func prepareForUninstall() {
        SettingsObserver.shared.suspendNotifications(for: 5.0)
        AppState.shared.systemState.stopLoginItemStatusMonitoring()
        try? SMAppService.mainApp.unregister()

        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKey.runOnStartup)
        defaults.set(0, forKey: UserDefaultsKey.runOnStartupLegacy)
        defaults.synchronize()
    }

    private static func writeUninstallScript(fileManager: FileManager) throws -> URL {
        let scriptDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PHTVUninstall-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: scriptDirectory, withIntermediateDirectories: true)

        let scriptURL = scriptDirectory.appendingPathComponent("uninstall.zsh")
        try uninstallScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    private static var uninstallScript: String {
        """
        #!/bin/zsh
        set +e

        app_pid="$1"
        app_path="$2"
        shift 2

        while /bin/kill -0 "$app_pid" >/dev/null 2>&1; do
            /bin/sleep 0.2
        done

        is_safe_data_path() {
            local target="$1"
            [[ -z "$target" ]] && return 1
            [[ "$target" == "$HOME"/Library/* ]] && return 0
            [[ -n "$TMPDIR" && "$target" == "$TMPDIR"* ]] && return 0
            return 1
        }

        for target in "$@"; do
            if is_safe_data_path "$target"; then
                /bin/rm -rf -- "$target"
            fi
        done

        if [[ -n "$app_path" && "$app_path" == *.app && -d "$app_path" ]]; then
            case "$app_path" in
                /Applications/*|"$HOME"/*|/private/var/folders/*|/var/folders/*)
                    /bin/rm -rf -- "$app_path"
                    ;;
            esac
        fi

        /usr/bin/killall cfprefsd >/dev/null 2>&1 || true

        script_dir="$(/usr/bin/dirname "$0")"
        /bin/rm -rf -- "$script_dir"
        """
    }

    private static func libraryURL(_ home: URL, _ components: String..., isDirectory: Bool = false) -> URL {
        var url = home.appendingPathComponent("Library", isDirectory: true)
        for (index, component) in components.enumerated() {
            url.appendPathComponent(component, isDirectory: isDirectory && index == components.count - 1)
        }
        return url
    }

    private static func byHostPreferenceURLs(
        home: URL,
        bundleIdentifiers: [String],
        fileManager: FileManager
    ) -> [URL] {
        let byHostDirectory = libraryURL(home, "Preferences", "ByHost", isDirectory: true)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: byHostDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return contents.filter { url in
            let filename = url.lastPathComponent
            return bundleIdentifiers.contains { bundleIdentifier in
                filename.hasPrefix("\(bundleIdentifier).") && filename.hasSuffix(".plist")
            }
        }
    }

    private static func diagnosticReportURLs(
        home: URL,
        bundleIdentifiers: [String],
        appNames: [String],
        fileManager: FileManager
    ) -> [URL] {
        let diagnosticReportsDirectory = libraryURL(home, "Logs", "DiagnosticReports", isDirectory: true)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: diagnosticReportsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return contents.filter { url in
            let filename = url.lastPathComponent
            return appNames.contains { filename.hasPrefix($0) }
                || bundleIdentifiers.contains { filename.contains($0) }
        }
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.compactMap { url in
            let standardizedURL = url.standardizedFileURL
            guard seen.insert(standardizedURL.path).inserted else { return nil }
            return standardizedURL
        }
    }
}
