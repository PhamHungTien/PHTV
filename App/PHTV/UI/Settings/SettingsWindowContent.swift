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
    @State private var isClosingSettingsWindow: Bool = false
    @State private var pendingDockShowWorkItem: DispatchWorkItem?
    @State private var pendingCloseWorkItem: DispatchWorkItem?
    @State private var windowLifecycleToken = UUID()

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
            isClosingSettingsWindow = false
            windowLifecycleToken = UUID()
            pendingDockShowWorkItem?.cancel()
            pendingDockShowWorkItem = nil
            pendingCloseWorkItem?.cancel()
            pendingCloseWorkItem = nil
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

            // Also post notification for AppDelegate to track state.
            // Guard with lifecycle token so delayed callbacks from a previous open
            // cannot revive a just-closed settings window.
            let lifecycleToken = windowLifecycleToken
            let showDockWorkItem = DispatchWorkItem { [lifecycleToken] in
                guard lifecycleToken == windowLifecycleToken, !isClosingSettingsWindow else { return }
                let hasVisibleSettingsWindow = NSApp.windows.contains { window in
                    window.identifier?.rawValue.hasPrefix("settings") == true && window.isVisible
                }
                guard hasVisibleSettingsWindow else { return }

                NotificationCenter.default.post(
                    name: NotificationName.phtvShowDockIcon,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.visible: true,
                        NotificationUserInfoKey.forceFront: true
                    ]
                )
            }
            pendingDockShowWorkItem = showDockWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: showDockWorkItem)

            // Update window level based on user preference
            updateSettingsWindowLevel()

            // Keep settings window stable and on top when needed
            setupWindowObservers()

            // Start login item monitoring only while Settings is open
            appState.systemState.startLoginItemStatusMonitoring()

            // Check if onboarding should be shown (first launch)
            checkAndShowOnboarding()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationName.showOnboarding)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showOnboarding = true
            }
        }
        .onDisappear {
            pendingDockShowWorkItem?.cancel()
            pendingDockShowWorkItem = nil
            // Remove window observers for this lifecycle.
            removeWindowObservers()

            // Delay close cleanup a bit to avoid transient SwiftUI disappear/reappear flapping.
            let lifecycleToken = windowLifecycleToken
            let closeWorkItem = DispatchWorkItem { [lifecycleToken] in
                guard lifecycleToken == windowLifecycleToken else { return }

                let hasVisibleSettingsWindow = NSApp.windows.contains { window in
                    window.identifier?.rawValue.hasPrefix("settings") == true && window.isVisible
                }
                let isActualClose = isClosingSettingsWindow || !hasVisibleSettingsWindow
                guard isActualClose else { return }

                finalizeSettingsWindowClose()
            }
            pendingCloseWorkItem = closeWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: closeWorkItem)
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
            Task { @MainActor in
                applySettingsWindowBehavior(forceFront: appState.settingsWindowAlwaysOnTop)
            }
        }

        let becomeObserver = center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                applySettingsWindowBehavior(forceFront: false)
            }
        }

        // If settings window loses key/main while "always on top" is enabled,
        // re-assert its level and order to prevent sinking.
        let resignKeyObserver = center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            let windowID = (notification.object as? NSWindow).map(ObjectIdentifier.init)
            Task { @MainActor in
                guard let windowID,
                      let window = NSApp.windows.first(where: { ObjectIdentifier($0) == windowID }),
                      isSettingsWindow(window) else { return }
                if appState.settingsWindowAlwaysOnTop, !isClosingSettingsWindow {
                    // Re-apply window level only. Do not force front here, otherwise
                    // clicking close can immediately reopen the settings window.
                    applySettingsWindowBehavior(forceFront: false)
                }
            }
        }

        let resignMainObserver = center.addObserver(
            forName: NSWindow.didResignMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            let windowID = (notification.object as? NSWindow).map(ObjectIdentifier.init)
            Task { @MainActor in
                guard let windowID,
                      let window = NSApp.windows.first(where: { ObjectIdentifier($0) == windowID }),
                      isSettingsWindow(window) else { return }
                if appState.settingsWindowAlwaysOnTop, !isClosingSettingsWindow {
                    applySettingsWindowBehavior(forceFront: false)
                }
            }
        }

        let willCloseObserver = center.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            let windowID = (notification.object as? NSWindow).map(ObjectIdentifier.init)
            Task { @MainActor in
                guard let windowID,
                      let window = NSApp.windows.first(where: { ObjectIdentifier($0) == windowID }),
                      isSettingsWindow(window) else { return }
                isClosingSettingsWindow = true
                pendingDockShowWorkItem?.cancel()
                pendingDockShowWorkItem = nil
                windowLifecycleToken = UUID()
                appState.systemState.stopLoginItemStatusMonitoring()
            }
        }

        let occlusionObserver = center.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { notification in
            let windowID = (notification.object as? NSWindow).map(ObjectIdentifier.init)
            Task { @MainActor in
                guard let windowID,
                      let window = NSApp.windows.first(where: { ObjectIdentifier($0) == windowID }),
                      isSettingsWindow(window),
                      !isClosingSettingsWindow,
                      appState.settingsWindowAlwaysOnTop,
                      !window.isMiniaturized else { return }
                // If the window is occluded while always-on-top is enabled, bring it back.
                window.level = .floating
                window.orderFrontRegardless()
            }
        }

        windowObservers = [
            resignObserver,
            becomeObserver,
            resignKeyObserver,
            resignMainObserver,
            willCloseObserver,
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

    @MainActor
    private func finalizeSettingsWindowClose() {
        pendingCloseWorkItem?.cancel()
        pendingCloseWorkItem = nil
        windowLifecycleToken = UUID()

        // Restore dock icon to user preference when settings closes.
        let userPrefersDock = appState.showIconOnDock

        // Stop login item monitoring when Settings closes.
        appState.systemState.stopLoginItemStatusMonitoring()

        // Clear transient caches to release memory.
        AppIconCache.shared.clear()

        NotificationCenter.default.post(
            name: NotificationName.phtvShowDockIcon,
            object: nil,
            userInfo: [
                NotificationUserInfoKey.visible: userPrefersDock,
                NotificationUserInfoKey.forceFront: false
            ]
        )

        DispatchQueue.main.async {
            let policy: NSApplication.ActivationPolicy = userPrefersDock ? .regular : .accessory
            NSApp.setActivationPolicy(policy)
        }

        isClosingSettingsWindow = false
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

    @MainActor
    private func updateSettingsWindowLevel() {
        applySettingsWindowBehavior(forceFront: appState.settingsWindowAlwaysOnTop)
    }

    @MainActor
    private func isSettingsWindow(_ window: NSWindow?) -> Bool {
        guard let identifier = window?.identifier?.rawValue else { return false }
        return identifier.hasPrefix("settings")
    }

    @MainActor
    private func applySettingsWindowBehavior(forceFront: Bool) {
        guard let window = NSApp.windows.first(where: { isSettingsWindow($0) }) else { return }

        // Set window level based on user preference
        // Use .floating for always-on-top, .normal for standard
        window.level = appState.settingsWindowAlwaysOnTop ? .floating : .normal

        // Use opaque window background for Settings
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor

        // Ensure window doesn't disappear when app loses focus
        window.hidesOnDeactivate = false

        // Ensure window is movable by background (critical for hiddenTitleBar)
        window.isMovableByWindowBackground = true

        // Standard behavior: participate in Cycle, move to active space
        window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]

        guard forceFront,
              !window.isMiniaturized,
              window.isVisible,
              !isClosingSettingsWindow else { return }

        if appState.settingsWindowAlwaysOnTop {
            window.orderFrontRegardless()
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
