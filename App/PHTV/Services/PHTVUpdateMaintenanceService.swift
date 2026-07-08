//
//  PHTVUpdateMaintenanceService.swift
//  PHTV
//
//  Post-update cleanup of leftovers from previous app versions.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Policy (pure, unit-testable)

enum PHTVUpdateMaintenancePolicy {
    /// Maintenance runs once per app build change: right after an update is
    /// installed, or on the first launch after this mechanism shipped.
    static func shouldRunMaintenance(lastRunBuild: String?, currentBuild: String) -> Bool {
        guard !currentBuild.isEmpty else { return false }
        return lastRunBuild != currentBuild
    }

    /// A migrated legacy key may be deleted only after the replacement key
    /// holds a persisted value — never destroy the only copy of a setting.
    static func canRemoveLegacyKey(replacementHasValue: Bool) -> Bool {
        replacementHasValue
    }

    /// Temporary media files are transient paste artifacts; anything older
    /// than `maxAge` is safe to reclaim. Files with unknown dates are kept.
    static func isStaleTemporaryFile(modificationDate: Date?, now: Date, maxAge: TimeInterval) -> Bool {
        guard let modificationDate else { return false }
        return now.timeIntervalSince(modificationDate) > maxAge
    }
}

// MARK: - Service

/// Cleans up artifacts left behind by previous versions after the user
/// updates. Every step is idempotent, restricted to app-owned locations, and
/// guarded by an explicit registry — nothing outside it is ever touched.
/// Future versions extend the registry instead of writing ad-hoc cleanup.
@objcMembers
final class PHTVUpdateMaintenanceService: NSObject {

    private static let lastMaintenanceBuildKey = "PHTV_LastMaintenanceBuild"
    private static let staleMediaMaxAge: TimeInterval = 3 * 24 * 60 * 60

    /// Legacy UserDefaults keys superseded in earlier releases. Each entry is
    /// removed only when its replacement key already has a persisted value,
    /// so a user's setting can never be lost mid-migration.
    private static let migratedLegacyDefaultsKeys: [(legacy: String, replacement: String)] = [
        ("RestoreIfInvalidWord", UserDefaultsKey.autoRestoreEnglishWord)
    ]

    /// Entry point, called once at launch. Cheap when nothing to do: a single
    /// UserDefaults read decides whether the background pass runs at all.
    class func runAfterUpdateIfNeeded() {
        let defaults = UserDefaults.standard
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let lastRunBuild = defaults.string(forKey: lastMaintenanceBuildKey)

        guard PHTVUpdateMaintenancePolicy.shouldRunMaintenance(
            lastRunBuild: lastRunBuild,
            currentBuild: currentBuild
        ) else {
            return
        }

        Task.detached(priority: .utility) {
            cleanupMigratedLegacyDefaults()
            cleanupStaleTemporaryMedia()

            UserDefaults.standard.set(currentBuild, forKey: lastMaintenanceBuildKey)
            NSLog("[UpdateMaintenance] Post-update cleanup finished (build %@)",
                  currentBuild.isEmpty ? "?" : currentBuild)
        }
    }

    // MARK: - Cleanup steps

    private static func cleanupMigratedLegacyDefaults() {
        let defaults = UserDefaults.standard
        for entry in migratedLegacyDefaultsKeys {
            guard defaults.object(forKey: entry.legacy) != nil else { continue }
            let replacementHasValue = defaults.object(forKey: entry.replacement) != nil
            guard PHTVUpdateMaintenancePolicy.canRemoveLegacyKey(
                replacementHasValue: replacementHasValue
            ) else {
                continue
            }
            defaults.removeObject(forKey: entry.legacy)
            NSLog("[UpdateMaintenance] Removed migrated legacy defaults key '%@'", entry.legacy)
        }
    }

    /// Reclaims stale files inside the app-owned temporary media directory
    /// (tmp/PHTPMedia). This also covers users who never open the media
    /// picker, whose cache would otherwise only be cleaned by the picker.
    private static func cleanupStaleTemporaryMedia() {
        let fileManager = FileManager.default
        let mediaDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PHTPMedia", isDirectory: true)

        guard let entries = try? fileManager.contentsOfDirectory(
            at: mediaDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let now = Date()
        var removedCount = 0
        for entry in entries {
            let modificationDate = (try? entry.resourceValues(
                forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard PHTVUpdateMaintenancePolicy.isStaleTemporaryFile(
                modificationDate: modificationDate,
                now: now,
                maxAge: staleMediaMaxAge
            ) else {
                continue
            }
            if (try? fileManager.removeItem(at: entry)) != nil {
                removedCount += 1
            }
        }

        if removedCount > 0 {
            NSLog("[UpdateMaintenance] Removed %d stale temporary media file(s)", removedCount)
        }
    }
}
