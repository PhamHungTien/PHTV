//
//  SparkleManager.swift
//  PHTV
//
//  Swift port of SparkleManager.mm while preserving ObjC API compatibility.
//

import AppKit
import Foundation
import Sparkle

@MainActor
@objcMembers
final class SparkleManager: NSObject, SPUUpdaterDelegate {
    // Sparkle error codes from SUErrors.h used for robust fallback handling.
    private enum SparkleErrorCode {
        static let noUpdate = 1001
        static let invalidFeedURL = 4
        static let appcastParse = 1000
        static let appcast = 1002
        static let resumeAppcast = 1004
        static let download = 2001
        static let releaseNotes = 1007
    }
    private enum UpdateCheckContext {
        case manual
        case background

        var logLabel: String {
            switch self {
            case .manual:
                return "manual"
            case .background:
                return "background"
            }
        }
    }

    private static let feedURLStrings: [String] = [
        "https://cdn.jsdelivr.net/gh/PhamHungTien/PHTV@main/docs/appcast.xml",
        "https://phamhungtien.github.io/PHTV/appcast.xml",
        "https://raw.githubusercontent.com/PhamHungTien/PHTV/main/docs/appcast.xml"
    ]

    private static let sharedInstance = SparkleManager()

    @objc(shared)
    class func shared() -> SparkleManager {
        return sharedInstance
    }

    private lazy var standardUserDriver: SPUStandardUserDriver = {
        return SPUStandardUserDriver(hostBundle: .main, delegate: nil)
    }()

    @objc private(set) lazy var updater: SPUUpdater = {
        return SPUUpdater(hostBundle: .main,
                          applicationBundle: .main,
                          userDriver: standardUserDriver,
                          delegate: self)
    }()

    private var currentFeedIndex = 0
    private var activeCheckContext: UpdateCheckContext?
    private var isRetryScheduled = false
    private var lastManualCheckRequestAt = Date.distantPast
    private let manualCheckThrottleInterval: TimeInterval = 1.5

    override init() {
        super.init()

        var startError: NSError?
        do {
            try updater.start()
        } catch let nsError as NSError {
            startError = nsError
        } catch {
            startError = NSError(domain: "SparkleManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Unknown Sparkle startup error"
            ])
        }

        if let startError {
            NSLog("[Sparkle] Failed to start updater: %@", startError.localizedDescription)
        }

        NSLog("[Sparkle] Initialized with SPUStandardUserDriver")
    }

    /// Manually trigger update check (user-initiated, shows feedback)
    @objc func checkForUpdatesWithFeedback() {
        let now = Date()
        if now.timeIntervalSince(lastManualCheckRequestAt) < manualCheckThrottleInterval {
            NSLog("[Sparkle] Ignoring duplicated manual update check request")
            return
        }
        lastManualCheckRequestAt = now

        NSLog("[Sparkle] User-initiated update check")
        NSApp.activate(ignoringOtherApps: true)
        performCheck(for: .manual, retryIfBusy: false)
    }

    /// Background update check (silent)
    @objc func checkForUpdates() {
        NSLog("[Sparkle] Background update check")
        performCheck(for: .background, retryIfBusy: false)
    }

    /// Configure update check interval in seconds
    @objc func setUpdateCheckInterval(_ interval: TimeInterval) {
        NSLog("[Sparkle] Update interval set to %.0f seconds", interval)
        UserDefaults.standard.set(interval, forKey: "SUScheduledCheckInterval")
    }

    // MARK: - SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? {
        let feed = Self.feedURLStrings[currentFeedIndex]
        NSLog("[Sparkle] Using feed[%ld]: %@", currentFeedIndex, feed)
        return feed
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        NSLog("[Sparkle] didFindValidUpdate: %@ (%@)", item.displayVersionString, item.versionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        NSLog("[Sparkle] No updates available")
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        NSLog("[Sparkle] Appcast loaded: %lu items", appcast.items.count)
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: any Error) {
        let nsError = error as NSError
        NSLog(
            "[Sparkle] Failed to download update %@: %@ (domain=%@ code=%ld)",
            item.displayVersionString,
            nsError.localizedDescription,
            nsError.domain,
            nsError.code
        )
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        NSLog("[Sparkle] Will install update: %@", item.displayVersionString)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let nsError = error as NSError
        NSLog(
            "[Sparkle] didAbortWithError: %@ (domain=%@ code=%ld userInfo=%@)",
            nsError.localizedDescription,
            nsError.domain,
            nsError.code,
            nsError.userInfo as NSDictionary
        )

        // SUNoUpdateError is a normal path; let Sparkle present standard feedback.
        if nsError.domain == SUSparkleErrorDomain,
           nsError.code == SparkleErrorCode.noUpdate {
            resetFeedSelectionIfNeeded()
            activeCheckContext = nil
            return
        }

        if retryWithNextFeedIfPossible(for: nsError) {
            return
        }

        resetFeedSelectionIfNeeded()
        activeCheckContext = nil
    }

    func updater(_ updater: SPUUpdater,
                 didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: (any Error)?) {
        if let error {
            let nsError = error as NSError
            NSLog(
                "[Sparkle] didFinishUpdateCycle error: %@ (domain=%@ code=%ld userInfo=%@)",
                nsError.localizedDescription,
                nsError.domain,
                nsError.code,
                nsError.userInfo as NSDictionary
            )

            if nsError.domain == SUSparkleErrorDomain,
               nsError.code == SparkleErrorCode.noUpdate {
                resetFeedSelectionIfNeeded()
                activeCheckContext = nil
                return
            }

            if retryWithNextFeedIfPossible(for: nsError) {
                return
            }
        } else {
            NSLog("[Sparkle] didFinishUpdateCycle success")
        }

        resetFeedSelectionIfNeeded()
        activeCheckContext = nil
    }

    private func performCheck(for context: UpdateCheckContext, retryIfBusy: Bool) {
        activeCheckContext = context

        guard updater.canCheckForUpdates else {
            NSLog("[Sparkle] Updater busy; check deferred (context=%@)", context.logLabel)
            guard retryIfBusy else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.performCheck(for: context, retryIfBusy: false)
            }
            return
        }

        isRetryScheduled = false
        switch context {
        case .manual:
            updater.checkForUpdates()
        case .background:
            updater.checkForUpdatesInBackground()
        }
    }

    private func retryWithNextFeedIfPossible(for error: NSError) -> Bool {
        if isRetryScheduled {
            return true
        }

        // Avoid showing repeated error dialogs to users on manual checks.
        // Manual check should surface at most one Sparkle error.
        guard activeCheckContext == .background else {
            return false
        }

        guard currentFeedIndex + 1 < Self.feedURLStrings.count else {
            return false
        }

        guard shouldRetryForError(error) else {
            return false
        }

        guard let context = activeCheckContext else {
            return false
        }

        currentFeedIndex += 1
        isRetryScheduled = true
        NSLog("[Sparkle] Retrying with fallback feed[%ld]", currentFeedIndex)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.performCheck(for: context, retryIfBusy: true)
        }

        return true
    }

    private func shouldRetryForError(_ error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain {
            return true
        }

        guard error.domain == SUSparkleErrorDomain else {
            return false
        }

        let retryableSparkleCodes: Set<Int> = [
            SparkleErrorCode.invalidFeedURL,
            SparkleErrorCode.appcastParse,
            SparkleErrorCode.appcast,
            SparkleErrorCode.resumeAppcast,
            SparkleErrorCode.download,
            SparkleErrorCode.releaseNotes
        ]
        return retryableSparkleCodes.contains(error.code)
    }

    private func resetFeedSelectionIfNeeded() {
        guard currentFeedIndex != 0 else { return }
        NSLog("[Sparkle] Resetting feed selection to primary")
        currentFeedIndex = 0
    }
}
