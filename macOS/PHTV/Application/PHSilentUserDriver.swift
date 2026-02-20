//
//  PHSilentUserDriver.swift
//  PHTV
//
//  Swift port of PHSilentUserDriver.m.
//

import Foundation
import Sparkle

final class PHSilentUserDriver: SPUStandardUserDriver {
    override init(hostBundle: Bundle, delegate: SPUStandardUserDriverDelegate?) {
        super.init(hostBundle: hostBundle, delegate: delegate)
        NSLog("[PHSilentUserDriver] Initialized - silent auto-install: ON")
    }

    override func showUpdateFound(with appcastItem: SUAppcastItem,
                                  state: SPUUserUpdateState,
                                  reply: @escaping (SPUUserUpdateChoice) -> Void) {
        NSLog("[PHSilentUserDriver] Update found: %@ (state: %ld, userInitiated: %@)",
              appcastItem.displayVersionString,
              state.stage.rawValue,
              state.userInitiated ? "YES" : "NO")

        let info: [String: String] = [
            "version": appcastItem.displayVersionString,
            "releaseNotes": appcastItem.itemDescription ?? "",
            "downloadURL": appcastItem.fileURL?.absoluteString ?? ""
        ]
        NotificationCenter.default.post(name: NSNotification.Name("SparkleUpdateFound"), object: info)

        NSLog("[PHSilentUserDriver] Silent auto-install enabled - installing update automatically")
        reply(.install)
    }

    override func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        NSLog("[PHSilentUserDriver] No update found (error: %@)",
              nsError.localizedDescription.isEmpty ? "none" : nsError.localizedDescription)
        acknowledgement()
    }

    override func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        NSLog("[PHSilentUserDriver] Updater error suppressed: %@ (code: %ld)",
              nsError.localizedDescription,
              nsError.code)
        acknowledgement()
    }

    override func showDownloadInitiated(cancellation: @escaping () -> Void) {
        NSLog("[PHSilentUserDriver] Download initiated")
        super.showDownloadInitiated(cancellation: cancellation)
    }

    override func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        NSLog("[PHSilentUserDriver] Ready to install and relaunch")
        NSLog("[PHSilentUserDriver] Auto-installing and relaunching")
        reply(.install)
    }

    override func showUpdateInstalledAndRelaunched(_ relaunched: Bool,
                                                   acknowledgement: @escaping () -> Void) {
        NSLog("[PHSilentUserDriver] Update installed (relaunched: %@)", relaunched ? "YES" : "NO")
        acknowledgement()
    }
}
