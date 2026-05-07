//
//  PHSilentUserDriver.swift
//  PHTV
//
//  Silent Sparkle update user driver.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import Sparkle

final class PHSilentUserDriver: SPUStandardUserDriver {
    private var currentCheckWasUserInitiated = false
    private var autoInstallingCurrentSession = false

    override init(hostBundle: Bundle, delegate: SPUStandardUserDriverDelegate?) {
        super.init(hostBundle: hostBundle, delegate: delegate)
        NSLog("[PHSilentUserDriver] Initialized - automatic future installs enabled")
    }

    override func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        currentCheckWasUserInitiated = true
        autoInstallingCurrentSession = false
        super.showUserInitiatedUpdateCheck(cancellation: cancellation)
    }

    override func showUpdateFound(with appcastItem: SUAppcastItem,
                                  state: SPUUserUpdateState,
                                  reply: @escaping @Sendable (SPUUserUpdateChoice) -> Void) {
        UserDefaults.standard.enforceStableUpdateChannel()
        currentCheckWasUserInitiated = state.userInitiated

        NSLog("[PHSilentUserDriver] Update found: %@ (stage: %ld, userInitiated: %@, autoInstall: %@)",
              appcastItem.displayVersionString,
              state.stage.rawValue,
              state.userInitiated ? "YES" : "NO",
              automaticInstallEnabled ? "YES" : "NO")

        let info: [String: String] = [
            "version": appcastItem.displayVersionString,
            "releaseNotes": appcastItem.itemDescription ?? "",
            "downloadURL": appcastItem.fileURL?.absoluteString ?? ""
        ]
        NotificationCenter.default.post(name: NotificationName.sparkleUpdateFound, object: info)

        if shouldInstallAutomatically(appcastItem: appcastItem, state: state) {
            autoInstallingCurrentSession = true
            NSLog("[PHSilentUserDriver] Future auto-install preference is enabled - installing update without another prompt")
            reply(.install)
            return
        }

        autoInstallingCurrentSession = false
        super.showUpdateFound(with: appcastItem, state: state, reply: reply)
    }

    override func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        NSLog("[PHSilentUserDriver] No update found (userInitiated: %@, error: %@)",
              currentCheckWasUserInitiated ? "YES" : "NO",
              nsError.localizedDescription.isEmpty ? "none" : nsError.localizedDescription)

        guard currentCheckWasUserInitiated else {
            resetSession()
            acknowledgement()
            return
        }

        super.showUpdateNotFoundWithError(error) { [weak self] in
            self?.resetSession()
            acknowledgement()
        }
    }

    override func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        NSLog("[PHSilentUserDriver] Updater error: %@ (code: %ld, userInitiated: %@)",
              nsError.localizedDescription,
              nsError.code,
              currentCheckWasUserInitiated ? "YES" : "NO")

        guard currentCheckWasUserInitiated else {
            resetSession()
            acknowledgement()
            return
        }

        super.showUpdaterError(error) { [weak self] in
            self?.resetSession()
            acknowledgement()
        }
    }

    override func showDownloadInitiated(cancellation: @escaping () -> Void) {
        NSLog("[PHSilentUserDriver] Download initiated")
        guard !autoInstallingCurrentSession else { return }
        super.showDownloadInitiated(cancellation: cancellation)
    }

    override func showReady(toInstallAndRelaunch reply: @escaping @Sendable (SPUUserUpdateChoice) -> Void) {
        guard autoInstallingCurrentSession || automaticInstallEnabled else {
            super.showReady(toInstallAndRelaunch: reply)
            return
        }

        NSLog("[PHSilentUserDriver] Ready to install and relaunch - continuing automatically")
        reply(.install)
    }

    override func showUpdateInstalledAndRelaunched(_ relaunched: Bool,
                                                   acknowledgement: @escaping () -> Void) {
        NSLog("[PHSilentUserDriver] Update installed (relaunched: %@)", relaunched ? "YES" : "NO")
        resetSession()
        acknowledgement()
    }

    private var automaticInstallEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKey.autoInstallUpdates, default: true)
    }

    private func shouldInstallAutomatically(appcastItem: SUAppcastItem, state: SPUUserUpdateState) -> Bool {
        guard automaticInstallEnabled else { return false }
        guard !state.userInitiated else { return false }
        guard !appcastItem.isInformationOnlyUpdate else { return false }
        guard !appcastItem.isMajorUpgrade else { return false }
        return true
    }

    private func resetSession() {
        currentCheckWasUserInitiated = false
        autoInstallingCurrentSession = false
    }
}
