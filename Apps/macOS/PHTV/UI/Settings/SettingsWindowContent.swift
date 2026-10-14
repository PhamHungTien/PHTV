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
    @State private var onboardingInitialStep: Int = 0
    @State private var isClosingSettingsWindow: Bool = false
    @State private var pendingCloseTask: Task<Void, Never>?
    @State private var onboardingTask: Task<Void, Never>?
    @State private var windowLifecycleToken = UUID()
    @State private var showDonatePopover = false

    var body: some View {
        settingsWindowContent
            .background(SettingsWindowMinimumSize())
            .toolbar { settingsToolbarContent }
    }

    private var settingsWindowContent: some View {
        OnboardingContainer(showOnboarding: $showOnboarding, initialStep: onboardingInitialStep) {
            SettingsView()
                .overlay(alignment: .top) {
                    UpdateBannerView()
                }
        }
        .onChange(of: appState.donatePopoverRequested, initial: true) { _, requested in
            guard requested else { return }
            showDonatePopover = true
            appState.donatePopoverRequested = false
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
        for await notification in NotificationCenter.default.notifications(named: NotificationName.showOnboarding) {
            guard !Task.isCancelled else { return }
            let requestedStep = notification.userInfo?[NotificationUserInfoKey.onboardingInitialStep] as? Int
            onboardingInitialStep = requestedStep ?? 0
            withAnimation(.easeInOut(duration: 0.3)) {
                showOnboarding = true
            }
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbarContent: some ToolbarContent {
        ToolbarItem(id: "settings-pin", placement: .primaryAction) {
            Toggle(isOn: Binding(
                get: { appState.settingsWindowAlwaysOnTop },
                set: { appState.settingsWindowAlwaysOnTop = $0 }
            )) {
                Label("Ghim cửa sổ", systemImage: "pin")
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .fixedSize()
            .help("Giữ cửa sổ Cài đặt ở phía trước")
        }
        ToolbarItem(id: "settings-support", placement: .primaryAction) {
            donateToolbarButton
        }
    }

    private var donateToolbarButton: some View {
        Button {
            showDonatePopover.toggle()
        } label: {
            Label("Ủng hộ PHTV", systemImage: "heart")
        }
        .labelStyle(.iconOnly)
        .fixedSize()
        .popover(isPresented: $showDonatePopover, arrowEdge: .bottom) {
            DonateQRPopoverView()
        }
        .help("Ủng hộ phát triển")
    }

    /// Observe close only; native window focus and floating level need no reassertion.
    @MainActor
    private func setupWindowObservers() {
        removeWindowObservers()

        windowObserverTasks = [
            makeWindowObserverTask(name: NSWindow.willCloseNotification) { notification in
                let window = notification.object as? NSWindow
                guard isSettingsWindow(window) else { return }
                isClosingSettingsWindow = true
                appState.flushPendingSettingsForWindowClose()
                windowLifecycleToken = UUID()
                appState.systemState.stopLoginItemStatusMonitoring()
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
                onboardingInitialStep = 0
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
