//
//  AppDelegate+LoginItem.swift
//  PHTV
//
//  Swift port of AppDelegate+LoginItem.mm.
//

import AppKit
import Foundation
import ServiceManagement

private let phtvDefaultsKeyRunOnStartup = "RunOnStartup"
private let phtvDefaultsKeyRunOnStartupLegacy = "PHTV_RunOnStartup"
private let phtvNotificationRunOnStartupChanged = Notification.Name("RunOnStartupChanged")
private let phtvNotificationUserInfoEnabledKey = "enabled"

@MainActor @objc extension AppDelegate {
    @objc(syncRunOnStartupStatusWithFirstLaunch:)
    func syncRunOnStartupStatus(withFirstLaunch isFirstLaunch: Bool) {
        if #available(macOS 13.0, *) {
            let appService = SMAppService.mainApp
            let actualStatus = appService.status
            let actuallyEnabled = (actualStatus == .enabled)

            let savedValue = UserDefaults.standard.integer(forKey: phtvDefaultsKeyRunOnStartup)
            let savedEnabled = (savedValue == 1)

            NSLog("[LoginItem] Startup sync - Actual: %d, Saved: %d, Status: %ld",
                  actuallyEnabled, savedEnabled, actualStatus.rawValue)

            if isFirstLaunch {
                NSLog("[LoginItem] First launch detected - enabling Launch at Login")
                setRunOnStartup(true)
            } else if actuallyEnabled != savedEnabled {
                if savedEnabled && !actuallyEnabled {
                    NSLog("[LoginItem] ⚠️ User enabled but SMAppService is disabled - syncing UI to OFF")
                    NSLog("[LoginItem] Possible causes: code signature, system policy, or macOS disabled it")

                    UserDefaults.standard.set(0, forKey: phtvDefaultsKeyRunOnStartup)
                    UserDefaults.standard.set(false, forKey: phtvDefaultsKeyRunOnStartupLegacy)
                    NotificationCenter.default.post(name: phtvNotificationRunOnStartupChanged,
                                                    object: nil,
                                                    userInfo: [phtvNotificationUserInfoEnabledKey: false])
                } else if !savedEnabled && actuallyEnabled {
                    NSLog("[LoginItem] User disabled but SMAppService still enabled - disabling")
                    setRunOnStartup(false)
                }
            } else {
                NSLog("[LoginItem] ✅ Status consistent: %@", actuallyEnabled ? "ENABLED" : "DISABLED")
            }
        } else {
            let val = UserDefaults.standard.integer(forKey: phtvDefaultsKeyRunOnStartup)
            setRunOnStartup(val != 0)
        }
    }

    @objc(setRunOnStartup:)
    func setRunOnStartup(_ val: Bool) {
        if #available(macOS 13.0, *) {
            let appService = SMAppService.mainApp
            var actualSuccess = false

            NSLog("[LoginItem] Current SMAppService status: %ld", appService.status.rawValue)

            if val {
                if appService.status != .enabled {
                    let bundlePath = Bundle.main.bundlePath
                    let verifyTask = Process()
                    verifyTask.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
                    verifyTask.arguments = ["--verify", "--deep", "--strict", bundlePath]

                    let pipe = Pipe()
                    verifyTask.standardError = pipe

                    do {
                        try verifyTask.run()
                        verifyTask.waitUntilExit()

                        if verifyTask.terminationStatus != 0 {
                            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                            let errorString = String(data: errorData, encoding: .utf8) ?? ""
                            NSLog("⚠️ [LoginItem] Code signature verification failed: %@", errorString)
                            NSLog("⚠️ [LoginItem] SMAppService may reject unsigned/ad-hoc signed apps")
                        } else {
                            NSLog("✅ [LoginItem] Code signature verified")
                        }
                    } catch {
                        NSLog("⚠️ [LoginItem] Failed to verify code signature: %@", String(describing: error))
                    }

                    do {
                        try appService.register()
                        NSLog("✅ [LoginItem] Registered with SMAppService")
                        actualSuccess = true
                    } catch {
                        let nsError = error as NSError
                        NSLog("❌ [LoginItem] Failed to register with SMAppService")
                        NSLog("   Error: %@", nsError.localizedDescription)
                        NSLog("   Error Domain: %@", nsError.domain)
                        NSLog("   Error Code: %ld", nsError.code)

                        if !nsError.userInfo.isEmpty {
                            NSLog("   Error UserInfo: %@", nsError.userInfo)
                        }

                        if nsError.domain == "SMAppServiceErrorDomain" {
                            switch nsError.code {
                            case 1:
                                NSLog("   → App already registered (stale state). Trying to unregister first...")
                                try? appService.unregister()

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    do {
                                        try appService.register()
                                        NSLog("✅ [LoginItem] Registration succeeded on retry")

                                        UserDefaults.standard.set(true, forKey: phtvDefaultsKeyRunOnStartupLegacy)
                                        UserDefaults.standard.set(1, forKey: phtvDefaultsKeyRunOnStartup)
                                        NotificationCenter.default.post(name: phtvNotificationRunOnStartupChanged,
                                                                        object: nil,
                                                                        userInfo: [phtvNotificationUserInfoEnabledKey: true])
                                    } catch {
                                        let retryError = error as NSError
                                        NSLog("❌ [LoginItem] Registration still failed: %@", retryError.localizedDescription)
                                        NotificationCenter.default.post(name: phtvNotificationRunOnStartupChanged,
                                                                        object: nil,
                                                                        userInfo: [phtvNotificationUserInfoEnabledKey: false])
                                    }
                                }
                                return
                            case 2:
                                NSLog("   → Invalid code signature. App must be properly signed with Developer ID")
                                NSLog("   → Ad-hoc signed apps (for development) are NOT supported by SMAppService")
                                NSLog("   → Solution: Sign with Apple Developer ID certificate or use notarization")
                            case 3:
                                NSLog("   → Invalid Info.plist configuration")
                            default:
                                NSLog("   → Unknown SMAppService error")
                            }
                        }

                        actualSuccess = false
                    }
                } else {
                    NSLog("ℹ️ [LoginItem] Already enabled, skipping registration")
                    actualSuccess = true
                }
            } else {
                if appService.status == .enabled {
                    do {
                        try appService.unregister()
                        NSLog("✅ [LoginItem] Unregistered from SMAppService")
                        actualSuccess = true
                    } catch {
                        let nsError = error as NSError
                        NSLog("❌ [LoginItem] Failed to unregister: %@", nsError.localizedDescription)
                        NSLog("   Error Domain: %@, Code: %ld", nsError.domain, nsError.code)
                        actualSuccess = false
                    }
                } else {
                    NSLog("ℹ️ [LoginItem] Already disabled, skipping unregistration")
                    actualSuccess = true
                }
            }

            if actualSuccess {
                UserDefaults.standard.set(val, forKey: phtvDefaultsKeyRunOnStartupLegacy)
                UserDefaults.standard.set(val ? 1 : 0, forKey: phtvDefaultsKeyRunOnStartup)
                NotificationCenter.default.post(name: phtvNotificationRunOnStartupChanged,
                                                object: nil,
                                                userInfo: [phtvNotificationUserInfoEnabledKey: val])
                NSLog("[LoginItem] ✅ Launch at Login %@ - UserDefaults saved and UI notified",
                      val ? "ENABLED" : "DISABLED")
            } else {
                NSLog("[LoginItem] ❌ Operation failed - reverting toggle to %@", val ? "OFF" : "ON")
                NotificationCenter.default.post(name: phtvNotificationRunOnStartupChanged,
                                                object: nil,
                                                userInfo: [phtvNotificationUserInfoEnabledKey: !val])
            }
        }
    }

    @objc(toggleStartupItem:)
    func toggleStartupItem(_ sender: NSMenuItem) {
        _ = sender

        let currentValue = UserDefaults.standard.integer(forKey: phtvDefaultsKeyRunOnStartup)
        let newValue = (currentValue == 0)

        setRunOnStartup(newValue)
        fillData()

        let message = newValue
            ? "✅ PHTV sẽ tự động khởi động cùng hệ thống"
            : "❌ Đã tắt khởi động cùng hệ thống"
        NSLog("%@", message)
    }
}
