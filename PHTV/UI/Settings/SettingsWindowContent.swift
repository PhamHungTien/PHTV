//
//  SettingsWindowContent.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

struct SettingsWindowContent: View {
    @EnvironmentObject var appState: AppState
    @State private var windowObservers: [NSObjectProtocol] = []
    @State private var showOnboarding: Bool = false

    var body: some View {
        OnboardingContainer(showOnboarding: $showOnboarding) {
            ZStack(alignment: .top) {
                SettingsView()

                // Update banner overlay
                UpdateBannerView()
                    .zIndex(1000)
            }
        }
        .onAppear {
            // Show dock icon when settings window opens
            // This prevents the window from being hidden when app loses focus

            // Use DispatchQueue.main.async to ensure run loop is ready
            // This is crucial on first launch when app just started
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)

                // Force dock to refresh by calling activate
                NSApp.activate(ignoringOtherApps: true)

                // Bring settings window to front and ensure it stays visible
                for window in NSApp.windows {
                    if window.identifier?.rawValue.hasPrefix("settings") == true {
                        // CRITICAL: Ensure window doesn't hide when app loses focus
                        window.hidesOnDeactivate = false
                        window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]
                        window.makeKeyAndOrderFront(nil)
                        break
                    }
                }

                // Sometimes first activate doesn't work, try again after a tiny delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSApp.activate(ignoringOtherApps: true)
                    // Bring window to front again and re-ensure hidesOnDeactivate is false
                    for window in NSApp.windows {
                        if window.identifier?.rawValue.hasPrefix("settings") == true {
                            window.hidesOnDeactivate = false
                            window.makeKeyAndOrderFront(nil)
                            break
                        }
                    }
                }
            }

            // Also post notification for AppDelegate to track state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(name: NSNotification.Name("PHTVShowDockIcon"), object: nil, userInfo: ["visible": true])
            }

            // Update window level based on user preference
            updateSettingsWindowLevel()

            // Keep settings window stable and on top when needed
            setupWindowObservers()

            // Check if onboarding should be shown (first launch)
            checkAndShowOnboarding()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowOnboarding"))) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showOnboarding = true
            }
        }
        .onDisappear {
            // Restore dock icon to user preference when settings closes
            let userPrefersDock = appState.showIconOnDock

            // Remove window observers
            removeWindowObservers()

            // Post notification for AppDelegate to restore state
            NotificationCenter.default.post(name: NSNotification.Name("PHTVShowDockIcon"), object: nil, userInfo: ["visible": userPrefersDock])

            // Also set activation policy directly
            DispatchQueue.main.async {
                let policy: NSApplication.ActivationPolicy = userPrefersDock ? .regular : .accessory
                NSApp.setActivationPolicy(policy)
            }
        }
        .onChange(of: appState.settingsWindowAlwaysOnTop) { _ in
            // Update window level when user toggles the setting
            updateSettingsWindowLevel()
        }
    }

    /// Setup observer to ensure settings window stays visible when app loses focus
    /// This is critical for accessory mode (no dock icon) where windows can hide unexpectedly
    private func setupWindowObservers() {
        removeWindowObservers()

        let center = NotificationCenter.default

        // App deactivation/activation can cause accessory windows to sink or hide.
        let resignObserver = center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            applySettingsWindowBehavior(forceFront: appState.settingsWindowAlwaysOnTop)
        }

        let becomeObserver = center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            applySettingsWindowBehavior(forceFront: false)
        }

        // If settings window loses key/main while "always on top" is enabled,
        // re-assert its level and order to prevent sinking.
        let resignKeyObserver = center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard isSettingsWindow(notification.object as? NSWindow) else { return }
            if appState.settingsWindowAlwaysOnTop {
                applySettingsWindowBehavior(forceFront: true)
            }
        }

        let resignMainObserver = center.addObserver(
            forName: NSWindow.didResignMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard isSettingsWindow(notification.object as? NSWindow) else { return }
            if appState.settingsWindowAlwaysOnTop {
                applySettingsWindowBehavior(forceFront: true)
            }
        }

        let occlusionObserver = center.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  isSettingsWindow(window),
                  appState.settingsWindowAlwaysOnTop,
                  !window.isMiniaturized else { return }
            // If the window is occluded while always-on-top is enabled, bring it back.
            window.level = .floating
            window.orderFrontRegardless()
        }

        windowObservers = [
            resignObserver,
            becomeObserver,
            resignKeyObserver,
            resignMainObserver,
            occlusionObserver
        ]
    }

    private func removeWindowObservers() {
        if windowObservers.isEmpty { return }
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers.removeAll()
    }

    /// Check if onboarding should be shown (first time user)
    private func checkAndShowOnboarding() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKey.onboardingCompleted)
        if !hasCompletedOnboarding {
            // Small delay to ensure window is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showOnboarding = true
                }
            }
        }
    }

    private func updateSettingsWindowLevel() {
        DispatchQueue.main.async {
            applySettingsWindowBehavior(forceFront: appState.settingsWindowAlwaysOnTop)
        }
    }

    private func isSettingsWindow(_ window: NSWindow?) -> Bool {
        guard let identifier = window?.identifier?.rawValue else { return false }
        return identifier.hasPrefix("settings")
    }

    private func applySettingsWindowBehavior(forceFront: Bool) {
        guard let window = NSApp.windows.first(where: { isSettingsWindow($0) }) else { return }

        // Set window level based on user preference
        // Use .floating for always-on-top, .normal for standard
        window.level = appState.settingsWindowAlwaysOnTop ? .floating : .normal

        // Keep content transparent but titlebar opaque (no glass effect on titlebar)
        // DO NOT set titlebarAppearsTransparent - that creates unwanted glass titlebar
        window.isOpaque = false
        window.backgroundColor = .clear

        // Ensure window doesn't disappear when app loses focus
        window.hidesOnDeactivate = false

        // Ensure window is movable by background (critical for hiddenTitleBar)
        window.isMovableByWindowBackground = true

        // Standard behavior: participate in Cycle, move to active space
        window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]

        guard forceFront, !window.isMiniaturized else { return }

        if appState.settingsWindowAlwaysOnTop {
            window.orderFrontRegardless()
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
