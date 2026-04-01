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
    @Environment(AppState.self) private var appState
    @State private var windowObservers: [NSObjectProtocol] = []
    @State private var showOnboarding: Bool = false
    @State private var isClosingSettingsWindow: Bool = false
    @State private var pendingCloseTask: Task<Void, Never>?
    @State private var onboardingTask: Task<Void, Never>?
    @State private var windowLifecycleToken = UUID()
    @State private var showDonatePopover = false

    var body: some View {
        configuredSettingsWindowContent
    }

    @ViewBuilder
    private var configuredSettingsWindowContent: some View {
        if #available(macOS 26.0, *) {
            settingsWindowContent
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .toolbar { settingsToolbarContent }
        } else if #available(macOS 15.0, *) {
            settingsWindowContent
                .toolbar(removing: .title)
                .toolbar { settingsToolbarContent }
        } else {
            settingsWindowContent
                .toolbar { settingsToolbarContent }
        }
    }

    private var settingsWindowContent: some View {
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
            pendingCloseTask?.cancel()
            pendingCloseTask = nil
            onboardingTask?.cancel()
            onboardingTask = nil
            applySettingsWindowBehavior(forceFront: false)

            // Update window level based on user preference
            updateSettingsWindowLevel()

            // Keep settings window stable and on top when needed
            setupWindowObservers()

            // Start login item monitoring only while Settings is open
            appState.systemState.startLoginItemStatusMonitoring()

            // Check if onboarding should be shown (first launch)
            checkAndShowOnboarding()
        }
        .task {
            await observeShowOnboardingNotifications()
        }
        .onDisappear {
            appState.flushPendingSettingsForWindowClose()
            onboardingTask?.cancel()
            onboardingTask = nil
            // Remove window observers for this lifecycle.
            removeWindowObservers()

            // Delay close cleanup a bit to avoid transient SwiftUI disappear/reappear flapping.
            let lifecycleToken = windowLifecycleToken
            pendingCloseTask?.cancel()
            pendingCloseTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.15))
                guard !Task.isCancelled else { return }
                guard lifecycleToken == windowLifecycleToken else { return }

                let hasVisibleSettingsWindow = NSApp.windows.contains { window in
                    window.identifier?.rawValue.hasPrefix("settings") == true && window.isVisible
                }
                let isActualClose = isClosingSettingsWindow || !hasVisibleSettingsWindow
                guard isActualClose else { return }

                finalizeSettingsWindowClose()
            }
        }
        .onChange(of: appState.settingsWindowAlwaysOnTop) { _, _ in
            // Update window level when user toggles the setting
            updateSettingsWindowLevel()
        }
    }

    @MainActor
    private func observeShowOnboardingNotifications() async {
        for await _ in NotificationCenter.default.notifications(named: NotificationName.showOnboarding) {
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showOnboarding = true
            }
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbarContent: some ToolbarContent {
        if #available(macOS 26.0, *) {
            // Flexible spacer pushes the trio to the right edge.
            // Flexible spacers *between* items break them into separate
            // glass pills on macOS 26 instead of one merged capsule.
            ToolbarSpacer(.flexible, placement: .primaryAction)
            pinToolbarItem
            ToolbarSpacer(.fixed, placement: .primaryAction)
            checkForUpdatesToolbarItem
            ToolbarSpacer(.fixed, placement: .primaryAction)
            donateToolbarItem
        } else {
            pinToolbarItem
            checkForUpdatesToolbarItem
            donateToolbarItem
        }
    }

    private var pinToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                appState.settingsWindowAlwaysOnTop.toggle()
            } label: {
                Image(systemName: appState.settingsWindowAlwaysOnTop ? "pin.fill" : "pin")
            }
            .help(
                appState.settingsWindowAlwaysOnTop
                ? "Bỏ ghim cửa sổ Cài đặt"
                : "Ghim cửa sổ Cài đặt luôn ở trên"
            )
        }
    }

    private var checkForUpdatesToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                NotificationCenter.default.post(name: NotificationName.sparkleManualCheck, object: nil)
            } label: {
                Image(systemName: "arrow.clockwise.circle")
            }
            .help("Kiểm tra cập nhật")
        }
    }

    private var donateToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showDonatePopover.toggle()
            } label: {
                Image(systemName: "cup.and.saucer.fill")
            }
            .popover(isPresented: $showDonatePopover, arrowEdge: .bottom) {
                DonateQRPopoverView()
            }
            .help("Ủng hộ phát triển")
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
                applySettingsWindowBehavior(forceFront: false)
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
            let window = notification.object as? NSWindow
            Task { @MainActor in
                guard isSettingsWindow(window) else { return }
                isClosingSettingsWindow = true
                appState.flushPendingSettingsForWindowClose()
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
                // Re-assert the floating level only; forcing front here can create
                // a focus tug-of-war with system UI and continuously invalidate layout.
                window.level = .floating
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
        pendingCloseTask?.cancel()
        pendingCloseTask = nil
        onboardingTask?.cancel()
        onboardingTask = nil
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

        let policy: NSApplication.ActivationPolicy = userPrefersDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)

        isClosingSettingsWindow = false
    }

    /// Check if onboarding should be shown (first time user)
    private func checkAndShowOnboarding() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKey.onboardingCompleted)
        if !hasCompletedOnboarding {
            onboardingTask?.cancel()
            // Small delay to ensure window is fully loaded
            onboardingTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
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

        // On macOS 26+, allow transparency so backgroundExtensionEffect() can
        // render the glass material behind the toolbar.  On older versions keep
        // the window fully opaque for a solid, consistent appearance.
        if #available(macOS 26.0, *) {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else {
            window.isOpaque = true
            window.backgroundColor = NSColor.windowBackgroundColor
        }

        // Ensure window doesn't disappear when app loses focus
        window.hidesOnDeactivate = false

        // Keep dragging constrained to the real titlebar/toolbar area so
        // sidebar clicks are never interpreted as window-drag gestures.
        window.isMovableByWindowBackground = false

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
