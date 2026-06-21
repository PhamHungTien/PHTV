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
    @AppStorage(UserDefaultsKey.onboardingCompleted) private var hasCompletedOnboarding = false
    @State private var windowObserverTasks: [Task<Void, Never>] = []
    @State private var showOnboarding: Bool = false
    @State private var isClosingSettingsWindow: Bool = false
    @State private var pendingCloseTask: Task<Void, Never>?
    @State private var onboardingTask: Task<Void, Never>?
    @State private var windowLifecycleToken = UUID()
    @State private var showDonatePopover = false

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            settingsWindowContent
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .containerBackground(.thinMaterial, for: .window)
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
        .task {
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
        .background(SettingsWindowConfigurator(alwaysOnTop: appState.settingsWindowAlwaysOnTop))
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
            ToolbarItem(placement: .primaryAction) {
                pinToolbarButton
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItemGroup(placement: .primaryAction) {
                updateToolbarButton
                donateToolbarButton
            }
        } else {
            ToolbarItemGroup(placement: .primaryAction) {
                pinToolbarButton
                updateToolbarButton
                donateToolbarButton
            }
        }
    }

    private var pinToolbarButton: some View {
        Button {
            appState.settingsWindowAlwaysOnTop.toggle()
        } label: {
            Image(systemName: appState.settingsWindowAlwaysOnTop ? "pin.fill" : "pin")
        }
        .help(appState.settingsWindowAlwaysOnTop ? "Bỏ ghim cửa sổ Cài đặt" : "Ghim cửa sổ Cài đặt")
    }

    private var updateToolbarButton: some View {
        Button {
            NotificationCenter.default.post(name: NotificationName.sparkleManualCheck, object: nil)
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .help("Kiểm tra cập nhật")
    }

    private var donateToolbarButton: some View {
        Button {
            showDonatePopover.toggle()
        } label: {
            Image(systemName: "heart")
        }
        .popover(isPresented: $showDonatePopover, arrowEdge: .bottom) {
            DonateQRPopoverView()
        }
        .help("Ủng hộ phát triển")
    }

    /// Setup observer to ensure settings window stays visible when app loses focus
    /// This is critical for accessory mode (no dock icon) where windows can hide unexpectedly
    @MainActor
    private func setupWindowObservers() {
        removeWindowObservers()

        windowObserverTasks = [
            // App deactivation/activation can cause accessory windows to sink or hide.
            makeWindowObserverTask(name: NSApplication.didResignActiveNotification) { _ in
                applySettingsWindowBehavior(forceFront: false)
            },
            makeWindowObserverTask(name: NSApplication.didBecomeActiveNotification) { _ in
                applySettingsWindowBehavior(forceFront: false)
            },
            // If settings window loses key/main while "always on top" is enabled,
            // re-assert its level and order to prevent sinking.
            makeWindowObserverTask(name: NSWindow.didResignKeyNotification) { notification in
                guard resolveSettingsWindow(from: notification) != nil else { return }
                if appState.settingsWindowAlwaysOnTop, !isClosingSettingsWindow {
                    // Re-apply window level only. Do not force front here, otherwise
                    // clicking close can immediately reopen the settings window.
                    applySettingsWindowBehavior(forceFront: false)
                }
            },
            makeWindowObserverTask(name: NSWindow.didResignMainNotification) { notification in
                guard resolveSettingsWindow(from: notification) != nil else { return }
                if appState.settingsWindowAlwaysOnTop, !isClosingSettingsWindow {
                    applySettingsWindowBehavior(forceFront: false)
                }
            },
            makeWindowObserverTask(name: NSWindow.willCloseNotification) { notification in
                let window = notification.object as? NSWindow
                guard isSettingsWindow(window) else { return }
                isClosingSettingsWindow = true
                appState.flushPendingSettingsForWindowClose()
                windowLifecycleToken = UUID()
                appState.systemState.stopLoginItemStatusMonitoring()
            },
            makeWindowObserverTask(name: NSWindow.didChangeOcclusionStateNotification) { notification in
                guard let window = resolveSettingsWindow(from: notification),
                      !isClosingSettingsWindow,
                      appState.settingsWindowAlwaysOnTop,
                      !window.isMiniaturized else { return }
                // Re-assert the floating level only; forcing front here can create
                // a focus tug-of-war with system UI and continuously invalidate layout.
                window.level = .floating
            }
        ]
    }

    @MainActor
    private func removeWindowObservers() {
        guard !windowObserverTasks.isEmpty else { return }
        windowObserverTasks.forEach { $0.cancel() }
        windowObserverTasks.removeAll()
    }

    @MainActor
    private func makeWindowObserverTask(
        name: Notification.Name,
        object: AnyObject? = nil,
        handler: @escaping @MainActor (Notification) -> Void
    ) -> Task<Void, Never> {
        let observedObjectID = object.map(ObjectIdentifier.init)
        return Task { @MainActor in
            for await notification in NotificationCenter.default.notifications(named: name) {
                guard !Task.isCancelled else { break }
                if let observedObjectID {
                    guard let notificationObject = notification.object as AnyObject?,
                          ObjectIdentifier(notificationObject) == observedObjectID else {
                        continue
                    }
                }
                handler(notification)
            }
        }
    }

    @MainActor
    private func resolveSettingsWindow(from notification: Notification) -> NSWindow? {
        let windowID = (notification.object as? NSWindow).map(ObjectIdentifier.init)
        guard let windowID else { return nil }
        return NSApp.windows.first(where: { ObjectIdentifier($0) == windowID && isSettingsWindow($0) })
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

        if appState.autoRestartOnSettingsClose {
            performAutoRestart()
        }
    }

    @MainActor
    private func performAutoRestart() {
        // Spawn a detached shell that waits for this process to exit, then relaunches.
        // NSWorkspace.openApplication while still running routes to the existing instance
        // instead of starting a new one, so we must terminate first.
        let appPath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 0.5 && open -a \"\(appPath)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    /// Check if onboarding should be shown (first time user)
    private func checkAndShowOnboarding() {
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
        return identifier.hasPrefix("settings") || identifier == "com_apple_SwiftUI_Settings_window"
    }

    @MainActor
    private func applySettingsWindowBehavior(forceFront: Bool) {
        guard let window = NSApp.windows.first(where: { isSettingsWindow($0) }) else { return }

        SettingsWindowHelper.applyWindowConfiguration(
            to: window,
            alwaysOnTop: appState.settingsWindowAlwaysOnTop
        )

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

private struct SettingsWindowConfigurator: NSViewRepresentable {
    let alwaysOnTop: Bool

    func makeNSView(context: Context) -> SettingsWindowConfigurationView {
        let view = SettingsWindowConfigurationView()
        view.alwaysOnTop = alwaysOnTop
        view.configureCurrentWindow()
        return view
    }

    func updateNSView(_ nsView: SettingsWindowConfigurationView, context: Context) {
        nsView.alwaysOnTop = alwaysOnTop
        nsView.configureCurrentWindow()
    }
}

private final class SettingsWindowConfigurationView: NSView {
    var alwaysOnTop = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureCurrentWindow()
    }

    func configureCurrentWindow() {
        guard let window else { return }
        SettingsWindowHelper.configureSettingsSceneWindow(window, alwaysOnTop: alwaysOnTop)
    }
}
