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
    @State private var deactivationObserver: Any?
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

            // FIX: Add observer to keep settings window visible when app loses focus
            // This prevents the window from hiding in accessory mode
            setupDeactivationObserver()

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

            // Remove deactivation observer
            if let observer = deactivationObserver {
                NotificationCenter.default.removeObserver(observer)
            }

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
    private func setupDeactivationObserver() {
        // Remove any existing observer first
        if let observer = deactivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Listen for app deactivation to ensure window stays visible
        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Re-ensure window properties when app loses focus
            // This prevents macOS from hiding the window in accessory mode
            MainActor.assumeIsolated {
                for window in NSApp.windows {
                    if window.identifier?.rawValue.hasPrefix("settings") == true {
                        window.hidesOnDeactivate = false
                        break
                    }
                }
            }
        }
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
            for window in NSApp.windows {
                let identifier = window.identifier?.rawValue ?? ""
                if identifier.hasPrefix("settings") {
                    // Set window level based on user preference
                    // FIX: Use .floating (3) for always on top, .normal (0) for standard
                    // When in .normal mode, ensure it doesn't drop behind by forcing orderFront
                    window.level = appState.settingsWindowAlwaysOnTop ? .floating : .normal

                    // Keep content transparent but titlebar opaque (no glass effect on titlebar)
                    // DO NOT set titlebarAppearsTransparent - that creates unwanted glass titlebar
                    window.isOpaque = false
                    window.backgroundColor = .clear

                    // FIX: Ensure window doesn't disappear when app loses focus
                    window.hidesOnDeactivate = false
                    
                    // FIX: Ensure window is movable by background (critical for hiddenTitleBar)
                    window.isMovableByWindowBackground = true
                    
                    // FIX: standard behavior, participate in Cycle, move to active space
                    window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]

                    if appState.settingsWindowAlwaysOnTop {
                         window.orderFront(nil)
                    }

                    break
                }
            }
        }
    }
}
