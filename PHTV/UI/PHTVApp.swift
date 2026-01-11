//
//  PHTVApp.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import ApplicationServices
import AudioToolbox
import Carbon
import Combine
import ServiceManagement
import SwiftUI

@main
struct PHTVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var windowOpener = SettingsWindowOpener.shared

    init() {
        NSLog("PHTV-APP-INIT-START")

        // CRITICAL: Initialize AppState FIRST to avoid recursive dispatch_once lock
        // EmojiHotkeyManager.handleSettingsChanged() calls AppState.shared
        // If AppState is initializing when the notification fires, we get recursive lock
        _ = AppState.shared

        // Initialize SettingsNotificationObserver to listen for notifications
        _ = SettingsNotificationObserver.shared

        // Initialize EmojiHotkeyManager directly in SwiftUI init
        NSLog("PHTV-APP-INIT-EMOJI")
        _ = EmojiHotkeyManager.shared
        NSLog("PHTV-APP-INIT-END")
    }

    var body: some Scene {
        // Menu bar extra - using native menu style
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(appState)
        } label: {
            // Use app icon (template); add slash when in English mode
            let size = CGFloat(appState.menuBarIconSize)
            Image(nsImage: makeMenuBarIconImage(size: size, slashed: !appState.isEnabled, useVietnameseIcon: appState.useVietnameseMenubarIcon))
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
        // Note: MenuBarExtra automatically updates when appState.isEnabled changes
        // No need for empty onChange handler that triggers unnecessary redraws

        // Settings window - managed by SwiftUI to avoid crashes
        Window("", id: "settings") {
            SettingsWindowContent()
                .environmentObject(appState)
                .frame(minWidth: 800, maxWidth: 1000, minHeight: 600, maxHeight: 900)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 950, height: 680)
        .windowResizability(.contentSize)
    }
}

/// Wrapper view for settings window content
/// This helps with proper lifecycle management
struct SettingsWindowContent: View {
    @EnvironmentObject var appState: AppState
    @State private var deactivationObserver: Any?

    var body: some View {
        ZStack(alignment: .top) {
            SettingsView()

            // Update banner overlay
            UpdateBannerView()
                .zIndex(1000)
        }
        .onAppear {
            // Show dock icon when settings window opens
            // This prevents the window from being hidden when app loses focus
            NSLog("[SettingsWindowContent] onAppear - showing dock icon")

            // Use DispatchQueue.main.async to ensure run loop is ready
            // This is crucial on first launch when app just started
            DispatchQueue.main.async {
                NSLog("[SettingsWindowContent] Setting activation policy to .regular")
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
                        NSLog("[SettingsWindowContent] Brought settings window to front, hidesOnDeactivate=false")
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
                    NSLog("[SettingsWindowContent] Dock icon activation complete")
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
        }
        .onDisappear {
            // Restore dock icon to user preference when settings closes
            let userPrefersDock = appState.showIconOnDock
            NSLog("[SettingsWindowContent] onDisappear - restoring dock icon, userPrefers: %@", userPrefersDock ? "true" : "false")

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
                        // Keep window visible even when not active
                        if window.isVisible {
                            NSLog("[SettingsWindowContent] App deactivated - ensuring settings window stays visible")
                        }
                        break
                    }
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

                    NSLog("[SettingsWindowContent] Set window.level = %@ for window: %@",
                          appState.settingsWindowAlwaysOnTop ? ".floating" : ".normal", identifier)
                    break
                }
            }
        }
    }
}



/// Helper to open the settings window using SwiftUI's Window scene
/// This avoids manual NSHostingController management which causes crashes
@MainActor
enum SettingsWindowHelper {
    static func openSettingsWindow() {
        NSLog("[SettingsWindowHelper] openSettingsWindow called")

        // First, try to find and show existing settings window
        for window in NSApp.windows {
            let identifier = window.identifier?.rawValue ?? ""
            // SwiftUI Window scenes have identifiers like "settings-AppWindow-1"
            if identifier.hasPrefix("settings") {
                NSLog("[SettingsWindowHelper] Found existing settings window: %@", identifier)

                // Set window level based on user preference
                let alwaysOnTop = UserDefaults.standard.bool(forKey: "vSettingsWindowAlwaysOnTop")
                window.level = alwaysOnTop ? .floating : .normal
                
                // FIX: Ensure robust window behavior matching SettingsWindowContent
                window.hidesOnDeactivate = false
                window.isMovableByWindowBackground = true
                window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]
                
                NSLog("[SettingsWindowHelper] Set window.level = %@", alwaysOnTop ? ".floating" : ".normal")

                // Bring window to front
                window.makeKeyAndOrderFront(nil)

                // Ensure window is not minimized
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }

                // Activate app
                NSApp.activate(ignoringOtherApps: true)

                return
            }
        }

        NSLog("[SettingsWindowHelper] No existing window found, triggering openWindow")

        // Trigger the window opening via notification that SettingsWindowOpener listens to
        SettingsWindowOpener.shared.requestOpenWindow()
    }
}

/// Observable object to trigger window opening from SwiftUI context
/// Uses Environment openWindow action which is the proper way to open SwiftUI windows
@MainActor
final class SettingsWindowOpener: ObservableObject {
    static let shared = SettingsWindowOpener()
    @Published var shouldOpenWindow = false

    func requestOpenWindow() {
        // Set flag that will be observed by SwiftUI
        shouldOpenWindow = true

        // Also try to open window directly using NSApp
        // This works because SwiftUI Window scene registers with NSApp
        DispatchQueue.main.async {
            // Find the window by checking all windows
            for window in NSApp.windows {
                let identifier = window.identifier?.rawValue ?? ""
                if identifier.hasPrefix("settings") {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    self.shouldOpenWindow = false
                    return
                }
            }

            // If no window found, the SwiftUI scene might create one
            // We need to activate the app to trigger scene creation
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// Class to setup notification observers for settings window
final class SettingsNotificationObserver: @unchecked Sendable {
    static let shared = SettingsNotificationObserver()
    private var observers: [Any] = []

    private init() {
        setupObservers()
        NSLog("[SettingsNotificationObserver] Initialized")
    }

    private func setupObservers() {
        // Listen for ShowSettings notification
        let showSettingsObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowSettings"),
            object: nil,
            queue: .main
        ) { _ in
            NSLog("[SettingsNotificationObserver] Received ShowSettings notification")
            Task { @MainActor in
                SettingsWindowHelper.openSettingsWindow()
            }
        }
        observers.append(showSettingsObserver)

        // Listen for CreateSettingsWindow notification
        let createWindowObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CreateSettingsWindow"),
            object: nil,
            queue: .main
        ) { _ in
            NSLog("[SettingsNotificationObserver] Received CreateSettingsWindow notification")
            Task { @MainActor in
                SettingsWindowHelper.openSettingsWindow()
            }
        }
        observers.append(createWindowObserver)
    }
}

@MainActor
func openSettingsWindow(with appState: AppState) {
    SettingsWindowHelper.openSettingsWindow()
}

// MARK: - App State Management
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // Helper to access AppDelegate via C function (bypasses Swift concurrency checks)
    // Note: GetAppDelegateInstance() is a C function that returns the global appDelegate
    @MainActor
    private func getAppDelegate() -> AppDelegate? {
        // Use the C function to get the global appDelegate instance
        // This bypasses Swift's concurrency safety checks
        return GetAppDelegateInstance()
    }

    private static var liveDebugEnabled: Bool {
        let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"]
        if let env, !env.isEmpty {
            return env != "0"
        }
        // Fallback: allow enabling via UserDefaults for easier debugging.
        // Example: defaults write com.phamhungtien.phtv PHTV_LIVE_DEBUG -int 1
        return UserDefaults.standard.integer(forKey: "PHTV_LIVE_DEBUG") != 0
    }

    private func liveLog(_ message: String) {
        guard Self.liveDebugEnabled else { return }
        NSLog("[PHTV Live] %@", message)
    }

    // Input method settings
    @Published var inputMethod: InputMethod = .telex
    @Published var codeTable: CodeTable = .unicode

    // Features
    @Published var isEnabled: Bool = true
    @Published var checkSpelling: Bool = true
    @Published var useModernOrthography: Bool = true
    @Published var quickTelex: Bool = false
    @Published var restoreOnInvalidWord: Bool = false
    @Published var sendKeyStepByStep: Bool = false
    @Published var useMacro: Bool = true
    @Published var useMacroInEnglishMode: Bool = false
    @Published var autoCapsMacro: Bool = false
    @Published var macroCategories: [MacroCategory] = []
    @Published var useSmartSwitchKey: Bool = true
    @Published var upperCaseFirstChar: Bool = false
    @Published var allowConsonantZFWJ: Bool = false
    @Published var quickStartConsonant: Bool = false
    @Published var quickEndConsonant: Bool = false
    @Published var rememberCode: Bool = true

    // Auto restore English words - default: ON for new users
    @Published var autoRestoreEnglishWord: Bool = true

    // Restore to raw keys (customizable key)
    @Published var restoreOnEscape: Bool = true
    @Published var restoreKey: RestoreKey = .esc

    // Pause Vietnamese input when holding a key
    @Published var pauseKeyEnabled: Bool = false
    @Published var pauseKey: UInt16 = 58  // Default: Left Option (same as RestoreKey.option)
    @Published var pauseKeyName: String = "Option"

    // Emoji Hotkey Settings
    @Published var enableEmojiHotkey: Bool = true
    @Published var emojiHotkeyModifiersRaw: Int = Int(NSEvent.ModifierFlags.command.rawValue)
    @Published var emojiHotkeyKeyCode: UInt16 = 14  // E key default

    /// Computed property for emoji hotkey modifiers
    var emojiHotkeyModifiers: NSEvent.ModifierFlags {
        get {
            NSEvent.ModifierFlags(rawValue: UInt(emojiHotkeyModifiersRaw))
        }
        set {
            emojiHotkeyModifiersRaw = Int(newValue.rawValue)
            // Trigger sync when modifiers change
            NotificationCenter.default.post(name: NSNotification.Name("EmojiHotkeySettingsChanged"), object: nil)
        }
    }

    // System settings
    @Published var runOnStartup: Bool = false
    @Published var performLayoutCompat: Bool = false
    @Published var showIconOnDock: Bool = false
    @Published var settingsWindowAlwaysOnTop: Bool = false  // Settings window always appears above other apps
    @Published var safeMode: Bool = false  // Safe mode disables Accessibility API for OCLP Macs
    @Published var enableLiquidGlassBackground: Bool = true {  // Enable liquid glass background for settings window
        didSet {
            UserDefaults.standard.set(enableLiquidGlassBackground, forKey: "vEnableLiquidGlassBackground")
        }
    }
    @Published var settingsBackgroundOpacity: Double = 1.0 {  // Background opacity for settings window (0.0-1.0)
        didSet {
            UserDefaults.standard.set(settingsBackgroundOpacity, forKey: "vSettingsBackgroundOpacity")
        }
    }
    // Text Replacement Fix is always enabled (no user setting)
    var enableTextReplacementFix: Bool { return true }

    // Claude Code patch setting
    @Published var claudeCodePatchEnabled: Bool = false

    // Hotkey settings - Default: Ctrl + Shift (modifier only mode)
    // 0xFE = no key needed, just use modifiers
    @Published var switchKeyCommand: Bool = false
    @Published var switchKeyOption: Bool = false
    @Published var switchKeyControl: Bool = true
    @Published var switchKeyShift: Bool = true
    @Published var switchKeyFn: Bool = false
    @Published var switchKeyCode: UInt16 = 0xFE  // 0xFE = modifier only mode
    @Published var switchKeyName: String = "Không"  // Display name for the key
    @Published var beepOnModeSwitch: Bool = false  // Play beep sound when switching mode

    // Audio and Display settings
    @Published var beepVolume: Double = 0.5  // Range: 0.0 to 1.0
    // Removed fontSize setting
    @Published var menuBarIconSize: Double = 18.0  // Increased default
    @Published var useVietnameseMenubarIcon: Bool = false  // Use Vietnamese menubar icon in Vietnamese mode

    // Excluded apps - auto switch to English when these apps are active
    @Published var excludedApps: [ExcludedApp] = []

    // Send key step by step apps - auto enable send key step by step when these apps are active
    @Published var sendKeyStepByStepApps: [SendKeyStepByStepApp] = []

    // Accessibility
    @Published var hasAccessibilityPermission: Bool = false

    // Update notification - shown when new version is available on startup
    @Published var updateAvailableMessage: String = ""
    @Published var showUpdateBanner: Bool = false
    @Published var latestVersion: String = ""

    // Sparkle update configuration
    @Published var updateCheckFrequency: UpdateCheckFrequency = .daily
    @Published var betaChannelEnabled: Bool = false
    @Published var autoInstallUpdates: Bool = true  // Tự động cài đặt cập nhật
    @Published var showCustomUpdateBanner: Bool = false
    @Published var customUpdateBannerInfo: UpdateBannerInfo? = nil
    // showNoUpdateAlert removed - now handled by AppDelegate with NSAlert directly

    private var cancellables = Set<AnyCancellable>()
    private var notificationObservers: [NSObjectProtocol] = []
    private var isLoadingSettings = false
    private var isUpdatingRunOnStartup = false
    private var loginItemCheckTimer: Timer?
    private var lastRunOnStartupChangeTime: Date?  // Track user interactions

    private init() {
        isLoadingSettings = true
        loadSettings()
        isLoadingSettings = false
        print("[AppState] Init complete, beepVolume=\(beepVolume), menuBarIconSize=\(menuBarIconSize)")

        // Delay observer setup to avoid crashes during initialization
        // This ensures AppState is fully initialized before observers start firing
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupObservers()
            self.setupNotificationObservers()
            self.setupExternalSettingsObserver()
            self.checkAccessibilityPermission()
        }
    }

    /// Monitor external UserDefaults changes and reload settings in real-time
    private func setupExternalSettingsObserver() {
        SettingsObserver.shared.$settingsDidChange
            .debounce(for: 0.1, scheduler: DispatchQueue.main)
            .sink { [weak self] (_: Date?) in
                guard let self = self else { return }
                self.reloadSettingsFromDefaults()
            }
            .store(in: &cancellables)
    }

    /// Reload only settings that may have changed externally
    private func reloadSettingsFromDefaults() {
        let defaults = UserDefaults.standard

        isLoadingSettings = true
        defer { isLoadingSettings = false }

        // Only reload settings that may change from external sources
        let inputMethod_saved = defaults.integer(forKey: "InputMethod")
        let newIsEnabled = (inputMethod_saved == 1)

        let inputTypeIndex = defaults.integer(forKey: "InputType")
        let newInputMethod = InputMethod.from(index: inputTypeIndex)

        let codeTableIndex = defaults.integer(forKey: "CodeTable")
        let newCodeTable = CodeTable.from(index: codeTableIndex)

        let switchKeyStatus = defaults.integer(forKey: "SwitchKeyStatus")

        // Update only if values changed to avoid unnecessary refreshes
        if newIsEnabled != isEnabled {
            isEnabled = newIsEnabled
        }

        if newInputMethod != inputMethod {
            inputMethod = newInputMethod
        }

        if newCodeTable != codeTable {
            codeTable = newCodeTable
        }

        if switchKeyStatus != 0 {
            let oldStatus = encodeSwitchKeyStatus()
            if switchKeyStatus != oldStatus {
                decodeSwitchKeyStatus(switchKeyStatus)
            }
        }

        // Reload excluded apps if changed
        if let data = defaults.data(forKey: "ExcludedApps"),
            let newApps = try? JSONDecoder().decode([ExcludedApp].self, from: data)
        {
            if newApps != excludedApps {
                excludedApps = newApps
            }
        }

        // Reload send key step by step apps if changed
        if let data = defaults.data(forKey: "SendKeyStepByStepApps"),
            let newApps = try? JSONDecoder().decode([SendKeyStepByStepApp].self, from: data)
        {
            if newApps != sendKeyStepByStepApps {
                sendKeyStepByStepApps = newApps
            }
        }
    }

    private func setupNotificationObservers() {
        let observer1 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AccessibilityStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let isEnabled = notification.object as? NSNumber {
                Task { @MainActor in
                    self.hasAccessibilityPermission = isEnabled.boolValue
                }
            }
        }
        notificationObservers.append(observer1)

        // Listen for language changes from manual actions (hotkey, UI, input type change)
        let observer2 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LanguageChangedFromBackend"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    self.isLoadingSettings = true
                    self.isEnabled = language.intValue == 1
                    self.isLoadingSettings = false

                    // Play beep for manual mode changes (if enabled)
                    if self.beepOnModeSwitch && self.beepVolume > 0.0 {
                        BeepManager.shared.play(volume: self.beepVolume)
                    }
                }
            }
        }
        notificationObservers.append(observer2)

        // Listen for language changes from excluded apps (no beep sound)
        let observer3 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LanguageChangedFromExcludedApp"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    self.isLoadingSettings = true
                    self.isEnabled = language.intValue == 1
                    self.isLoadingSettings = false
                    // No beep sound for excluded app auto-switch
                }
            }
        }
        notificationObservers.append(observer3)

        // Listen for language changes from smart switch (no beep sound)
        let observer4 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LanguageChangedFromSmartSwitch"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    self.isLoadingSettings = true
                    self.isEnabled = language.intValue == 1
                    self.isLoadingSettings = false
                    // No beep sound for smart auto-switch
                }
            }
        }
        notificationObservers.append(observer4)

        // Listen for language changes from input source switch (Japanese/Chinese keyboard, no beep sound)
        let observerInputSource = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LanguageChangedFromObjC"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let language = notification.object as? NSNumber {
                Task { @MainActor in
                    self.isLoadingSettings = true
                    self.isEnabled = language.intValue == 1
                    self.isLoadingSettings = false
                    // No beep sound for input source auto-switch
                }
            }
        }
        notificationObservers.append(observerInputSource)

        // Listen for update check responses from backend
        let observer5 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CheckForUpdatesResponse"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let response = notification.object as? [String: Any] {
                // Extract values outside of MainActor to avoid data races
                let updateAvailable = (response["updateAvailable"] as? Bool) ?? false
                let message = response["message"] as? String ?? ""
                let latestVersion = response["latestVersion"] as? String ?? ""

                if updateAvailable && !message.isEmpty && !latestVersion.isEmpty {
                    Task { @MainActor in
                        // Show update banner on startup
                        self.updateAvailableMessage = message
                        self.latestVersion = latestVersion
                        self.showUpdateBanner = true
                    }
                }
            }
        }
        notificationObservers.append(observer5)

        // Sparkle custom update banner (only sent when auto-install is OFF)
        // Auto-install is now handled directly by PHSilentUserDriver
        let observer6 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SparkleShowUpdateBanner"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let info = notification.object as? [String: String] {
                Task { @MainActor in
                    let updateInfo = UpdateBannerInfo(
                        version: info["version"] ?? "",
                        releaseNotes: info["releaseNotes"] ?? "",
                        downloadURL: info["downloadURL"] ?? ""
                    )
                    self.customUpdateBannerInfo = updateInfo
                    // Show banner for user to choose (auto-install is OFF)
                    self.showCustomUpdateBanner = true
                    NSLog("[AppState] Showing update banner for version %@", updateInfo.version)
                }
            }
        }
        notificationObservers.append(observer6)

        // CRITICAL: Listen for Launch at Login changes from AppDelegate
        // This ensures UI syncs immediately when SMAppService status changes
        let observer7 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RunOnStartupChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let userInfo = notification.userInfo,
               let enabled = userInfo["enabled"] as? Bool {
                Task { @MainActor in
                    self.isUpdatingRunOnStartup = true
                    self.runOnStartup = enabled
                    self.isUpdatingRunOnStartup = false
                    print("[AppState] ✅ RunOnStartup synced from notification: \(enabled)")
                }
            }
        }
        notificationObservers.append(observer7)

        // SparkleNoUpdateFound is now handled by AppDelegate with NSAlert directly
        // This provides better UX as it doesn't require the settings window to be open

        // Start periodic check for login item status (every 5 seconds)
        // This detects when user disables it from System Settings
        startLoginItemStatusMonitoring()

        // Listen for app termination
        let terminateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ApplicationWillTerminate"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupObservers()
            }
        }
        notificationObservers.append(terminateObserver)
    }

    /// Cleanup notification observers (call on app termination if needed)
    @objc func cleanupObservers() {
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        // Stop login item monitoring timer
        loginItemCheckTimer?.invalidate()
        loginItemCheckTimer = nil
    }

    /// Start periodic monitoring of login item status
    /// This detects when macOS or user disables login item from System Settings
    private func startLoginItemStatusMonitoring() {
        guard #available(macOS 13.0, *) else { return }

        // Check every 5 seconds
        loginItemCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkLoginItemStatus()
            }
        }

        // Also check immediately
        Task { @MainActor in
            await checkLoginItemStatus()
        }

        NSLog("[LoginItem] Periodic status monitoring started (interval: 5s)")
    }

    /// Check if SMAppService status matches our UI state
    @available(macOS 13.0, *)
    @MainActor
    private func checkLoginItemStatus() async {
        guard !isUpdatingRunOnStartup else { return }

        // CRITICAL: Don't override user changes immediately
        // Give AppDelegate 10 seconds to complete SMAppService operation
        if let lastChange = lastRunOnStartupChangeTime {
            let timeSinceChange = Date().timeIntervalSince(lastChange)
            if timeSinceChange < 10.0 {
                NSLog("[LoginItem] Skipping check - user changed setting %.1fs ago (< 10s grace period)", timeSinceChange)
                return
            }
        }

        let appService = SMAppService.mainApp
        let actualStatus = (appService.status == .enabled)

        // Only log if there's a mismatch
        if actualStatus != runOnStartup {
            NSLog("[LoginItem] ⚠️ Status mismatch detected! UI: %@, SMAppService: %@",
                  runOnStartup ? "ON" : "OFF", actualStatus ? "ON" : "OFF")

            // Update UI to match reality
            isUpdatingRunOnStartup = true
            runOnStartup = actualStatus
            isUpdatingRunOnStartup = false

            // Update UserDefaults too
            let defaults = UserDefaults.standard
            defaults.set(actualStatus, forKey: "PHTV_RunOnStartup")
            defaults.set(actualStatus ? 1 : 0, forKey: "RunOnStartup")
            defaults.synchronize()

            NSLog("[LoginItem] ✅ UI synced to actual status: %@", actualStatus ? "ON" : "OFF")
        }
    }

    func checkAccessibilityPermission() {
        // CRITICAL: Use PHTVManager.canCreateEventTap() - the ONLY reliable method
        // AXIsProcessTrusted() is UNRELIABLE and can return wrong results!
        // This method uses test event tap creation (Apple recommended approach)
        Task { @MainActor in
            self.hasAccessibilityPermission = PHTVManager.canCreateEventTap()
        }
    }

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load language state (isEnabled)
        let inputMethod_saved = defaults.integer(forKey: "InputMethod")
        isEnabled = (inputMethod_saved == 1)

        // Load input method and code table
        let inputTypeIndex = defaults.integer(forKey: "InputType")
        inputMethod = InputMethod.from(index: inputTypeIndex)

        let codeTableIndex = defaults.integer(forKey: "CodeTable")
        codeTable = CodeTable.from(index: codeTableIndex)

        // Load system settings - check actual SMAppService status for runOnStartup
        if #available(macOS 13.0, *) {
            let appService = SMAppService.mainApp
            let status = (appService.status == .enabled)
            NSLog("[Settings] Loading runOnStartup from SMAppService: %@", status ? "enabled" : "disabled")
            isUpdatingRunOnStartup = true
            runOnStartup = status
            isUpdatingRunOnStartup = false
        } else {
            runOnStartup = defaults.bool(forKey: "PHTV_RunOnStartup")
        }
        performLayoutCompat = defaults.bool(forKey: "vPerformLayoutCompat")
        showIconOnDock = defaults.bool(forKey: "vShowIconOnDock")
        settingsWindowAlwaysOnTop = defaults.bool(forKey: "vSettingsWindowAlwaysOnTop")
        safeMode = defaults.bool(forKey: "SafeMode")
        enableLiquidGlassBackground = defaults.object(forKey: "vEnableLiquidGlassBackground") as? Bool ?? true
        settingsBackgroundOpacity = defaults.object(forKey: "vSettingsBackgroundOpacity") as? Double ?? 1.0
        // Text Replacement Fix is always enabled - no need to load from defaults

        // Load Claude Code patch setting - check actual patch status
        claudeCodePatchEnabled = ClaudeCodePatcher.shared.isPatched()

        // Load hotkey from SwitchKeyStatus (backend format)
        let switchKeyStatus = defaults.integer(forKey: "SwitchKeyStatus")
        if switchKeyStatus != 0 {
            decodeSwitchKeyStatus(switchKeyStatus)
        } else {
            // Default: Ctrl + Shift (0x9FE = Ctrl + Shift + no key)
            switchKeyCode = 0xFE  // No key (modifier only)
            switchKeyControl = true
            switchKeyOption = false
            switchKeyCommand = false
            switchKeyShift = true
            switchKeyName = "Không"
        }
        beepOnModeSwitch = defaults.bool(forKey: "vBeepOnModeSwitch")

        // Load input settings
        checkSpelling = defaults.bool(forKey: "Spelling")
        useModernOrthography = defaults.bool(forKey: "ModernOrthography")
        quickTelex = defaults.bool(forKey: "QuickTelex")
        restoreOnInvalidWord = defaults.bool(forKey: "RestoreIfInvalidWord")
        sendKeyStepByStep = defaults.bool(forKey: "SendKeyStepByStep")
        useMacro = defaults.bool(forKey: "UseMacro")
        useMacroInEnglishMode = defaults.bool(forKey: "UseMacroInEnglishMode")
        autoCapsMacro = defaults.bool(forKey: "vAutoCapsMacro")
        // Load macro categories (filter out default category if present)
        if let categoriesData = defaults.data(forKey: "macroCategories"),
           let categories = try? JSONDecoder().decode([MacroCategory].self, from: categoriesData) {
            macroCategories = categories.filter { $0.id != MacroCategory.defaultCategory.id }
        }
        useSmartSwitchKey = defaults.bool(forKey: "UseSmartSwitchKey")
        upperCaseFirstChar = defaults.bool(forKey: "UpperCaseFirstChar")
        allowConsonantZFWJ = defaults.bool(forKey: "vAllowConsonantZFWJ")
        quickStartConsonant = defaults.bool(forKey: "vQuickStartConsonant")
        quickEndConsonant = defaults.bool(forKey: "vQuickEndConsonant")
        rememberCode = defaults.bool(forKey: "vRememberCode")

        // Auto restore English words
        autoRestoreEnglishWord = defaults.bool(forKey: "vAutoRestoreEnglishWord")

        // Restore to raw keys (customizable key)
        restoreOnEscape = defaults.object(forKey: "vRestoreOnEscape") as? Bool ?? true
        let restoreKeyCode = defaults.integer(forKey: "vCustomEscapeKey")
        restoreKey = RestoreKey.from(keyCode: restoreKeyCode == 0 ? 53 : restoreKeyCode)

        // Pause Vietnamese input when holding a key
        pauseKeyEnabled = defaults.object(forKey: "vPauseKeyEnabled") as? Bool ?? false
        pauseKey = UInt16(defaults.integer(forKey: "vPauseKey"))
        if pauseKey == 0 {
            pauseKey = 58  // Default: Left Option
        }
        pauseKeyName = defaults.string(forKey: "vPauseKeyName") ?? "Option"

        // Load emoji hotkey settings (default true for first-time users)
        if defaults.object(forKey: "vEnableEmojiHotkey") != nil {
            enableEmojiHotkey = defaults.bool(forKey: "vEnableEmojiHotkey")
        } else {
            enableEmojiHotkey = true  // Default enabled for new users
        }
        emojiHotkeyModifiersRaw = defaults.integer(forKey: "vEmojiHotkeyModifiers")
        if emojiHotkeyModifiersRaw == 0 {
            emojiHotkeyModifiersRaw = Int(NSEvent.ModifierFlags.command.rawValue)  // Default: Command
        }
        let savedKeyCode = defaults.integer(forKey: "vEmojiHotkeyKeyCode")
        emojiHotkeyKeyCode = savedKeyCode > 0 ? UInt16(savedKeyCode) : 14  // Default: E key

        // Load audio and display settings
        beepVolume = defaults.double(forKey: "vBeepVolume")
        if beepVolume == 0 { beepVolume = 0.5 } // Default if not set
        print("[Settings] Loaded beepVolume: \(beepVolume)")

        // fontSize removed

        menuBarIconSize = defaults.double(forKey: "vMenuBarIconSize")
        if menuBarIconSize == 0 { menuBarIconSize = 18.0 } // Increased default if not set
        print("[Settings] Loaded menuBarIconSize: \(menuBarIconSize)")

        useVietnameseMenubarIcon = defaults.bool(forKey: "vUseVietnameseMenubarIcon")

        // Load excluded apps
        if let data = defaults.data(forKey: "ExcludedApps"),
            let apps = try? JSONDecoder().decode([ExcludedApp].self, from: data)
        {
            excludedApps = apps
        }

        // Load send key step by step apps
        if let data = defaults.data(forKey: "SendKeyStepByStepApps"),
            let apps = try? JSONDecoder().decode([SendKeyStepByStepApp].self, from: data)
        {
            sendKeyStepByStepApps = apps
        }

        // Load Sparkle settings
        let updateInterval = defaults.integer(forKey: "SUScheduledCheckInterval")
        updateCheckFrequency = UpdateCheckFrequency.from(interval: updateInterval == 0 ? 86400 : updateInterval)
        betaChannelEnabled = defaults.bool(forKey: "SUEnableBetaChannel")
        // Auto install updates - default to true if not set
        if defaults.object(forKey: "vAutoInstallUpdates") == nil {
            autoInstallUpdates = true
        } else {
            autoInstallUpdates = defaults.bool(forKey: "vAutoInstallUpdates")
        }

        // Note: EmojiHotkeyManager is initialized in AppDelegate.applicationDidFinishLaunching
        // via EmojiHotkeyBridge.initializeEmojiHotkeyManager()
    }

    // MARK: - Hotkey Encoding/Decoding

    /// Decode vSwitchKeyStatus from backend format
    /// Format: first 8 bits = keycode, bit 8 = Control, bit 9 = Option, bit 10 = Command, bit 11 = Shift, bit 12 = Fn, bit 15 = Beep
    private func decodeSwitchKeyStatus(_ status: Int) {
        switchKeyCode = UInt16(status & 0xFF)
        switchKeyControl = (status & 0x100) != 0
        switchKeyOption = (status & 0x200) != 0
        switchKeyCommand = (status & 0x400) != 0
        switchKeyShift = (status & 0x800) != 0
        switchKeyFn = (status & 0x1000) != 0
        beepOnModeSwitch = (status & 0x8000) != 0
        switchKeyName = keyCodeToName(switchKeyCode)
    }

    /// Encode hotkey settings to backend vSwitchKeyStatus format
    func encodeSwitchKeyStatus() -> Int {
        var status = Int(switchKeyCode)
        if switchKeyControl { status |= 0x100 }
        if switchKeyOption { status |= 0x200 }
        if switchKeyCommand { status |= 0x400 }
        if switchKeyShift { status |= 0x800 }
        if switchKeyFn { status |= 0x1000 }
        if beepOnModeSwitch { status |= 0x8000 }
        return status
    }

    /// Convert key code to display name
    private func keyCodeToName(_ keyCode: UInt16) -> String {
        // Special case: 0xFE means no key (modifier only mode)
        if keyCode == 0xFE {
            return "Không"
        }

        let keyNames: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x31: "Space", 0x32: "`",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return keyNames[keyCode] ?? "Key \(keyCode)"
    }

    func saveSettings() {
        let defaults = UserDefaults.standard

        // Save input method and code table
        defaults.set(inputMethod.toIndex(), forKey: "InputType")
        defaults.set(codeTable.toIndex(), forKey: "CodeTable")

        // Save system settings
        defaults.set(runOnStartup, forKey: "PHTV_RunOnStartup")
        defaults.set(performLayoutCompat, forKey: "vPerformLayoutCompat")
        defaults.set(showIconOnDock, forKey: "vShowIconOnDock")
        defaults.set(settingsWindowAlwaysOnTop, forKey: "vSettingsWindowAlwaysOnTop")
        defaults.set(enableLiquidGlassBackground, forKey: "vEnableLiquidGlassBackground")
        defaults.set(settingsBackgroundOpacity, forKey: "vSettingsBackgroundOpacity")

        // Save safe mode and sync with backend
        defaults.set(safeMode, forKey: "SafeMode")
        PHTVManager.setSafeModeEnabled(safeMode)

        // Text Replacement Fix is always enabled - no need to save

        // Save hotkey in backend format (SwitchKeyStatus)
        let switchKeyStatus = encodeSwitchKeyStatus()
        defaults.set(switchKeyStatus, forKey: "SwitchKeyStatus")
        defaults.set(beepOnModeSwitch, forKey: "vBeepOnModeSwitch")

        // Save input settings
        defaults.set(checkSpelling, forKey: "Spelling")
        defaults.set(useModernOrthography, forKey: "ModernOrthography")
        defaults.set(quickTelex, forKey: "QuickTelex")
        defaults.set(restoreOnInvalidWord, forKey: "RestoreIfInvalidWord")
        defaults.set(sendKeyStepByStep, forKey: "SendKeyStepByStep")
        defaults.set(useMacro, forKey: "UseMacro")
        defaults.set(useMacroInEnglishMode, forKey: "UseMacroInEnglishMode")
        defaults.set(autoCapsMacro, forKey: "vAutoCapsMacro")
        // Save macro categories (exclude default category)
        let categoriesToSave = macroCategories.filter { $0.id != MacroCategory.defaultCategory.id }
        if let categoriesData = try? JSONEncoder().encode(categoriesToSave) {
            defaults.set(categoriesData, forKey: "macroCategories")
        }
        defaults.set(useSmartSwitchKey, forKey: "UseSmartSwitchKey")
        defaults.set(upperCaseFirstChar, forKey: "UpperCaseFirstChar")
        defaults.set(allowConsonantZFWJ, forKey: "vAllowConsonantZFWJ")
        defaults.set(quickStartConsonant, forKey: "vQuickStartConsonant")
        defaults.set(quickEndConsonant, forKey: "vQuickEndConsonant")
        defaults.set(rememberCode, forKey: "vRememberCode")

        // Auto restore English words
        defaults.set(autoRestoreEnglishWord, forKey: "vAutoRestoreEnglishWord")

        // Restore to raw keys (customizable key)
        defaults.set(restoreOnEscape, forKey: "vRestoreOnEscape")
        defaults.set(restoreKey.rawValue, forKey: "vCustomEscapeKey")

        // Pause Vietnamese input when holding a key
        defaults.set(pauseKeyEnabled, forKey: "vPauseKeyEnabled")
        defaults.set(Int(pauseKey), forKey: "vPauseKey")
        defaults.set(pauseKeyName, forKey: "vPauseKeyName")

        // Save emoji hotkey settings
        defaults.set(enableEmojiHotkey, forKey: "vEnableEmojiHotkey")
        defaults.set(emojiHotkeyModifiersRaw, forKey: "vEmojiHotkeyModifiers")
        defaults.set(Int(emojiHotkeyKeyCode), forKey: "vEmojiHotkeyKeyCode")

        // Save audio and display settings
        defaults.set(beepVolume, forKey: "vBeepVolume")
        // fontSize removed
        defaults.set(menuBarIconSize, forKey: "vMenuBarIconSize")
        defaults.set(useVietnameseMenubarIcon, forKey: "vUseVietnameseMenubarIcon")

        // Save excluded apps
        if let data = try? JSONEncoder().encode(excludedApps) {
            defaults.set(data, forKey: "ExcludedApps")
        }

        // Save send key step by step apps
        if let data = try? JSONEncoder().encode(sendKeyStepByStepApps) {
            defaults.set(data, forKey: "SendKeyStepByStepApps")
        }

        // Save Sparkle settings
        defaults.set(updateCheckFrequency.rawValue, forKey: "SUScheduledCheckInterval")
        defaults.set(betaChannelEnabled, forKey: "SUEnableBetaChannel")
        defaults.set(autoInstallUpdates, forKey: "vAutoInstallUpdates")

        defaults.synchronize()

        // Notify Objective-C backend
        liveLog("posting PHTVSettingsChanged")
        NotificationCenter.default.post(
            name: NSNotification.Name("PHTVSettingsChanged"), object: nil)
    }

    // MARK: - Excluded Apps Management

    func addExcludedApp(_ app: ExcludedApp) {
        if !excludedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            excludedApps.append(app)
            saveExcludedApps()
        }
    }

    func removeExcludedApp(_ app: ExcludedApp) {
        excludedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        saveExcludedApps()
    }

    func isAppExcluded(bundleIdentifier: String) -> Bool {
        return excludedApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    private func saveExcludedApps() {
        if let data = try? JSONEncoder().encode(excludedApps) {
            UserDefaults.standard.set(data, forKey: "ExcludedApps")
            UserDefaults.standard.synchronize()

            // Notify backend with hot reload
            liveLog("posting ExcludedAppsChanged")
            NotificationCenter.default.post(
                name: NSNotification.Name("ExcludedAppsChanged"), object: excludedApps)

            // Also post legacy notification for backward compatibility
            liveLog("posting ExcludedAppsChanged (legacy)")
            NotificationCenter.default.post(
                name: NSNotification.Name("ExcludedAppsChanged"), object: nil)
        }
    }

    // MARK: - Send Key Step By Step Apps Management

    func addSendKeyStepByStepApp(_ app: SendKeyStepByStepApp) {
        if !sendKeyStepByStepApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            sendKeyStepByStepApps.append(app)
            saveSendKeyStepByStepApps()
        }
    }

    func removeSendKeyStepByStepApp(_ app: SendKeyStepByStepApp) {
        sendKeyStepByStepApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        saveSendKeyStepByStepApps()
    }

    func isAppInSendKeyStepByStepList(bundleIdentifier: String) -> Bool {
        return sendKeyStepByStepApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    private func saveSendKeyStepByStepApps() {
        if let data = try? JSONEncoder().encode(sendKeyStepByStepApps) {
            UserDefaults.standard.set(data, forKey: "SendKeyStepByStepApps")
            UserDefaults.standard.synchronize()

            // Notify backend with hot reload
            liveLog("posting SendKeyStepByStepAppsChanged")
            NotificationCenter.default.post(
                name: NSNotification.Name("SendKeyStepByStepAppsChanged"), object: sendKeyStepByStepApps)
        }
    }

    private func setupObservers() {
        // Note: EmojiHotkeyManager is initialized in AppDelegate via EmojiHotkeyBridge

        // Observer for isEnabled (language toggle)
        $isEnabled.sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            let language = value ? 1 : 0
            defaults.set(language, forKey: "InputMethod")
            defaults.synchronize()
            
            // Play beep if enabled (volume adjusted)
            if self.beepOnModeSwitch && self.beepVolume > 0.0 {
                BeepManager.shared.play(volume: self.beepVolume)
            }
            
            // Notify backend about language change from SwiftUI
            NotificationCenter.default.post(
                name: NSNotification.Name("LanguageChangedFromSwiftUI"),
                object: NSNumber(value: language))
        }.store(in: &cancellables)

        // Observer for runOnStartup - update immediately and verify status
        $runOnStartup.sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings, !self.isUpdatingRunOnStartup else {
                NSLog("[AppState] runOnStartup observer skipped (isLoading=%@, isUpdating=%@)",
                      self?.isLoadingSettings == true ? "YES" : "NO",
                      self?.isUpdatingRunOnStartup == true ? "YES" : "NO")
                return
            }

            NSLog("[AppState] 🔄 runOnStartup observer triggered: value=%@", value ? "ON" : "OFF")

            // Record timestamp to prevent periodic monitor from immediately overriding
            self.lastRunOnStartupChangeTime = Date()

            // Use C function GetAppDelegateInstance() to access global appDelegate
            // This bypasses Swift's concurrency checks and works during app launch
            guard let appDelegate = self.getAppDelegate() else {
                NSLog("[AppState] ❌ GetAppDelegateInstance() returned nil - app still initializing")
                NSLog("[AppState] ⚠️ Will retry when AppDelegate is fully initialized")
                return
            }

            NSLog("[AppState] ✅ Calling AppDelegate.setRunOnStartup(%@)", value ? "YES" : "NO")
            appDelegate.setRunOnStartup(value)

            // Note: setRunOnStartup will:
            // 1. Call SMAppService.register/unregister
            // 2. Save to UserDefaults ONLY if successful
            // 3. Send RunOnStartupChanged notification to sync UI
            // 4. Revert toggle if operation failed
        }.store(in: &cancellables)

        // Observer for input method
        $inputMethod.sink { [weak self] newMethod in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(newMethod.toIndex(), forKey: "InputType")
            defaults.synchronize()
            NotificationCenter.default.post(
                name: NSNotification.Name("InputMethodChanged"),
                object: NSNumber(value: newMethod.toIndex()))
        }.store(in: &cancellables)

        // Observer for code table
        $codeTable.sink { [weak self] newTable in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(newTable.toIndex(), forKey: "CodeTable")
            defaults.synchronize()
            NotificationCenter.default.post(
                name: NSNotification.Name("CodeTableChanged"),
                object: NSNumber(value: newTable.toIndex()))
        }.store(in: &cancellables)

        // Uppercase first character: apply immediately (no debounce) so
        // toggling takes effect right away while typing.
        $upperCaseFirstChar
        .removeDuplicates()
        .sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(value, forKey: "UpperCaseFirstChar")
            defaults.synchronize()
            self.liveLog("posting PHTVSettingsChanged (upperCaseFirstChar=\(value))")
            NotificationCenter.default.post(
                name: NSNotification.Name("PHTVSettingsChanged"), object: nil
            )
        }.store(in: &cancellables)

        // Observer for other settings that need to save and notify backend
        // Combine settings into single publisher for efficient batching
        Publishers.Merge7(
            $checkSpelling,
            $useModernOrthography,
            $quickTelex,
            $useMacro,
            $useMacroInEnglishMode,
            $autoCapsMacro,
            $useSmartSwitchKey
        )
        .merge(
            with:
                Publishers.Merge6(
                    $allowConsonantZFWJ,
                    $quickStartConsonant,
                    $quickEndConsonant,
                    $rememberCode,
                    $restoreOnInvalidWord,
                    $sendKeyStepByStep
                )
        )
        .map { _ in () }
        .merge(with: $autoRestoreEnglishWord.map { _ in () })
        .merge(with: $restoreOnEscape.map { _ in () })
        .merge(with: $restoreKey.map { _ in () })
        .merge(with: $pauseKeyEnabled.map { _ in () })
        .merge(with: $pauseKey.map { _ in () })
        .merge(with: $pauseKeyName.map { _ in () })
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
        }.store(in: &cancellables)

        // Observer for showIconOnDock - save to defaults only
        // Dock icon is controlled by SettingsView onAppear/onDisappear
        $showIconOnDock.sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(value, forKey: "vShowIconOnDock")
            // Notify backend so vShowIconOnDock stays in sync without restart
            NotificationCenter.default.post(
                name: NSNotification.Name("PHTVSettingsChanged"), object: nil)
        }.store(in: &cancellables)

        // Observer for emoji hotkey settings - post notification for EmojiHotkeyManager
        // Note: EmojiHotkeyManager observes "EmojiHotkeySettingsChanged" and syncs automatically
        Publishers.Merge3(
            $enableEmojiHotkey.map { _ in () },
            $emojiHotkeyModifiersRaw.map { _ in () },
            $emojiHotkeyKeyCode.map { _ in () }
        )
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self = self, !self.isLoadingSettings else { return }
            // Save settings when emoji hotkey changes
            self.saveSettings()
            // Post notification to trigger sync in EmojiHotkeyManager
            #if DEBUG
            print("[AppState] Posting EmojiHotkeySettingsChanged notification")
            #endif
            NotificationCenter.default.post(name: NSNotification.Name("EmojiHotkeySettingsChanged"), object: nil)
        }.store(in: &cancellables)

        // Observer for Claude Code patch - apply/remove patch when toggled
        $claudeCodePatchEnabled.sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let patcher = ClaudeCodePatcher.shared
                let currentlyPatched = patcher.isPatched()

                if value && !currentlyPatched {
                    // User wants to enable, apply patch
                    _ = patcher.applyPatch()
                } else if !value && currentlyPatched {
                    // User wants to disable, remove patch
                    _ = patcher.removePatch()
                }
            }
        }.store(in: &cancellables)

        Publishers.MergeMany([
            $performLayoutCompat.map { _ in () }.eraseToAnyPublisher(),
            $safeMode.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            self.saveSettings()
        }.store(in: &cancellables)

        // Observer for hotkey settings - notify backend efficiently
        let hotkeyChanges = Publishers.MergeMany([
            $switchKeyCode.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyCommand.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyOption.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyControl.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyShift.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyFn.map { _ in () }.eraseToAnyPublisher(),
            $beepOnModeSwitch.map { _ in () }.eraseToAnyPublisher()
        ])

        hotkeyChanges
        .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            let switchKeyStatus = self.encodeSwitchKeyStatus()
            UserDefaults.standard.set(switchKeyStatus, forKey: "SwitchKeyStatus")
            UserDefaults.standard.set(self.beepOnModeSwitch, forKey: "vBeepOnModeSwitch")
            UserDefaults.standard.synchronize()
            // Notify backend about hotkey change
            self.liveLog("posting HotkeyChanged (0x\(String(switchKeyStatus, radix: 16)))")
            NotificationCenter.default.post(
                name: NSNotification.Name("HotkeyChanged"), object: NSNumber(value: switchKeyStatus)
            )
        }.store(in: &cancellables)

        // Observer for audio and display settings - immediate UI + debounced persistence
        // Immediate UI update for menu bar icon size
        $menuBarIconSize
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                NotificationCenter.default.post(
                    name: NSNotification.Name("MenuBarIconSizeChanged"),
                    object: NSNumber(value: value)
                )
            }.store(in: &cancellables)

        // Immediate UI update for Vietnamese menubar icon preference
        $useVietnameseMenubarIcon
            .sink { [weak self] _ in
                guard let self = self, !self.isLoadingSettings else { return }
                NotificationCenter.default.post(
                    name: NSNotification.Name("MenuBarIconPreferenceChanged"),
                    object: nil
                )
            }.store(in: &cancellables)

        // Debounced persistence for these sliders
        $beepVolume
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                let defaults = UserDefaults.standard
                defaults.set(value, forKey: "vBeepVolume")
                // Avoid synchronous disk flush for smoother slider interaction
            }.store(in: &cancellables)

        // fontSize observer removed

        $menuBarIconSize
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                let defaults = UserDefaults.standard
                defaults.set(value, forKey: "vMenuBarIconSize")
                defaults.synchronize()
                print("[Settings] Saved menuBarIconSize: \(value)")
            }.store(in: &cancellables)

        $useVietnameseMenubarIcon
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self = self, !self.isLoadingSettings else { return }
                let defaults = UserDefaults.standard
                defaults.set(value, forKey: "vUseVietnameseMenubarIcon")
                defaults.synchronize()
                print("[Settings] Saved useVietnameseMenubarIcon: \(value)")
            }.store(in: &cancellables)

        // Update frequency observer
        $updateCheckFrequency.sink { [weak self] frequency in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(frequency.rawValue, forKey: "SUScheduledCheckInterval")
            defaults.synchronize()

            NotificationCenter.default.post(
                name: NSNotification.Name("UpdateCheckFrequencyChanged"),
                object: NSNumber(value: frequency.rawValue)
            )
        }.store(in: &cancellables)

        // Beta channel observer
        $betaChannelEnabled.sink { [weak self] enabled in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(enabled, forKey: "SUEnableBetaChannel")
            defaults.synchronize()

            NotificationCenter.default.post(
                name: NSNotification.Name("BetaChannelChanged"),
                object: NSNumber(value: enabled)
            )
        }.store(in: &cancellables)

        // Auto install updates observer
        $autoInstallUpdates.sink { [weak self] enabled in
            guard let self = self, !self.isLoadingSettings else { return }
            let defaults = UserDefaults.standard
            defaults.set(enabled, forKey: "vAutoInstallUpdates")
            defaults.synchronize()
        }.store(in: &cancellables)
    }

    // MARK: - Reset to Defaults

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        // Reset all settings to defaults
        inputMethod = .telex
        codeTable = .unicode

        isEnabled = true
        checkSpelling = true
        useModernOrthography = true
        quickTelex = false
        restoreOnInvalidWord = false
        sendKeyStepByStep = false
        useMacro = true
        useMacroInEnglishMode = false
        autoCapsMacro = false
        useSmartSwitchKey = true
        upperCaseFirstChar = false
        allowConsonantZFWJ = false
        quickStartConsonant = false
        quickEndConsonant = false
        rememberCode = true
        autoRestoreEnglishWord = true  // Default: ON for new users

        runOnStartup = false
        performLayoutCompat = false
        showIconOnDock = false
        safeMode = false

        switchKeyCommand = false
        switchKeyOption = false
        switchKeyControl = true
        switchKeyShift = true
        switchKeyFn = false
        switchKeyCode = 0xFE
        switchKeyName = "Không"

        beepVolume = 0.5
        menuBarIconSize = 18.0
        useVietnameseMenubarIcon = false

        excludedApps = []
        sendKeyStepByStepApps = []

        // Save to defaults
        saveSettings()

        // Notify backend about reset
        NotificationCenter.default.post(
            name: NSNotification.Name("SettingsResetToDefaults"),
            object: nil
        )
    }
}












// MARK: - Emoji Categories View

struct EmojiCategoriesView: View {
    var onEmojiSelected: (String) -> Void

    private let database = EmojiDatabase.shared
    @State private var selectedSubCategory: Int
    @State private var searchText = ""
    @State private var searchResults: [EmojiItem] = []
    @State private var searchTask: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool
    @Namespace private var subCategoryNamespace

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    
    // Key for saving last selected emoji sub-category
    private static let lastSubCategoryKey = "PHTVPickerLastEmojiSubCategory"
    
    init(onEmojiSelected: @escaping (String) -> Void) {
        self.onEmojiSelected = onEmojiSelected
        // Load last selected sub-category, default to 0 if not set or invalid
        let savedSubCategory = UserDefaults.standard.integer(forKey: EmojiCategoriesView.lastSubCategoryKey)
        // Validate saved value is within valid range
        if savedSubCategory >= 0 && savedSubCategory < EmojiDatabase.shared.categories.count {
            _selectedSubCategory = State(initialValue: savedSubCategory)
        } else {
            _selectedSubCategory = State(initialValue: 0)
        }
    }

    // Display emojis - from search results or current category
    private var displayedEmojis: [EmojiItem] {
        if searchText.isEmpty {
            return database.categories[selectedSubCategory].emojis
        }
        return searchResults
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                TextField("Tìm emoji...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        // Cancel previous search
                        searchTask?.cancel()

                        if newValue.isEmpty {
                            searchResults = []
                        } else {
                            // Debounce search
                            let task = DispatchWorkItem {
                                searchResults = database.search(newValue)
                            }
                            searchTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchTask?.cancel()
                        searchText = ""
                        searchResults = []
                        isSearchFocused = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(isSearchFocused ? 0.3 : 0), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Sub-category tabs (hidden when searching)
            if searchText.isEmpty {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 8) {
                            ForEach(0..<database.categories.count, id: \.self) { index in
                                Button(action: {
                                    withAnimation {
                                        selectedSubCategory = index
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Text(database.categories[index].icon)
                                            .font(.system(size: 16))
                                        Text(database.categories[index].name)
                                            .font(.system(size: 11, weight: selectedSubCategory == index ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedSubCategory == index ?
                                            Color.accentColor.opacity(0.15) : Color.clear
                                    )
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .id(index)  // ID for scrolling
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        // Scroll to saved/selected sub-category when view appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollProxy.scrollTo(selectedSubCategory, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Emoji grid for selected category or search results
            ScrollView {
                if displayedEmojis.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Không tìm thấy emoji")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(displayedEmojis, id: \.id) { emojiItem in
                            Button(action: {
                                onEmojiSelected(emojiItem.emoji)
                            }) {
                                Text(emojiItem.emoji)
                                    .font(.system(size: 30))
                            }
                            .buttonStyle(.plain)
                            .frame(height: 40)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: selectedSubCategory) { newValue in
            // Save selected sub-category to UserDefaults
            UserDefaults.standard.set(newValue, forKey: EmojiCategoriesView.lastSubCategoryKey)
        }
    }
}


// MARK: - GIF Only View

struct GIFOnlyView: View {
    var onClose: (() -> Void)?

    @StateObject private var klipyClient = KlipyAPIClient.shared
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12)
    ]

    var displayedGIFs: [KlipyGIF] {
        searchText.isEmpty ? klipyClient.trendingGIFs : klipyClient.searchResults
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                TextField("Tìm GIFs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        if newValue.isEmpty {
                            klipyClient.searchResults = []
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if searchText == newValue {
                                    klipyClient.search(query: newValue)
                                }
                            }
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearchFocused = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(isSearchFocused ? 0.3 : 0), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // GIF Grid
            ScrollView {
                if klipyClient.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                } else if displayedGIFs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: searchText.isEmpty ? "photo.on.rectangle.angled" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(searchText.isEmpty ? "Đang tải GIFs..." : "Không tìm thấy GIF")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(displayedGIFs) { gif in
                            GIFThumbnailView(gif: gif) {
                                copyGIF(gif)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
            if klipyClient.trendingGIFs.isEmpty {
                klipyClient.fetchTrending()
            }
        }
    }

    private func copyGIF(_ gif: KlipyGIF) {
        klipyClient.recordGIFUsage(gif)
        guard let url = URL(string: gif.fullURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data {
                    NSLog("[PHTPPicker] GIF downloaded: %@", gif.slug)

                    let phtpDir = getPHTPMediaDirectory()
                    let gifURL = phtpDir.appendingPathComponent("\(gif.slug).gif")
                    try? data.write(to: gifURL)

                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([gifURL as NSPasteboardWriting])
                    _ = pasteboard.setData(data, forType: .fileURL)

                    // Close panel first
                    onClose?()

                    // Small delay to allow panel to close and frontmost app to regain focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NSLog("[PHTPPicker] Pasting GIF...")

                        let source = CGEventSource(stateID: .hidSystemState)

                        // Press Command
                        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
                            cmdDown.flags = .maskCommand
                            cmdDown.post(tap: .cghidEventTap)
                        }

                        // Press V
                        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
                            vDown.flags = .maskCommand
                            vDown.post(tap: .cghidEventTap)
                        }

                        // Release V
                        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
                            vUp.flags = .maskCommand
                            vUp.post(tap: .cghidEventTap)
                        }

                        // Release Command
                        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) {
                            cmdUp.post(tap: .cghidEventTap)
                        }

                        NSLog("[PHTPPicker] Paste command sent")

                        // Clean up file after paste
                        deleteFileAfterDelay(gifURL)
                    }
                }
            }
        }.resume()
    }
}

// MARK: - Sticker Only View

struct StickerOnlyView: View {
    var onClose: (() -> Void)?

    @StateObject private var klipyClient = KlipyAPIClient.shared
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12)
    ]

    var displayedStickers: [KlipyGIF] {
        searchText.isEmpty ? klipyClient.trendingStickers : klipyClient.stickerSearchResults
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                TextField("Tìm Stickers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        if newValue.isEmpty {
                            klipyClient.stickerSearchResults = []
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if searchText == newValue {
                                    klipyClient.searchStickers(query: newValue)
                                }
                            }
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearchFocused = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(isSearchFocused ? 0.3 : 0), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Sticker Grid
            ScrollView {
                if klipyClient.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                } else if displayedStickers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: searchText.isEmpty ? "sparkle" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(searchText.isEmpty ? "Đang tải Stickers..." : "Không tìm thấy Sticker")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(displayedStickers) { sticker in
                            GIFThumbnailView(gif: sticker, onTap: {
                                copySticker(sticker)
                            }, contentType: "Sticker")
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
            if klipyClient.trendingStickers.isEmpty {
                klipyClient.fetchTrendingStickers()
            }
        }
    }

    private func copySticker(_ sticker: KlipyGIF) {
        klipyClient.recordStickerUsage(sticker)
        guard let url = URL(string: sticker.fullURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data {
                    NSLog("[PHTPPicker] Sticker downloaded: %@", sticker.slug)

                    let phtpDir = getPHTPMediaDirectory()
                    let stickerURL = phtpDir.appendingPathComponent("\(sticker.slug).png")
                    try? data.write(to: stickerURL)

                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([stickerURL as NSPasteboardWriting])

                    // Close panel first
                    onClose?()

                    // Small delay to allow panel to close and frontmost app to regain focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NSLog("[PHTPPicker] Pasting Sticker...")

                        let source = CGEventSource(stateID: .hidSystemState)

                        // Press Command
                        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
                            cmdDown.flags = .maskCommand
                            cmdDown.post(tap: .cghidEventTap)
                        }

                        // Press V
                        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
                            vDown.flags = .maskCommand
                            vDown.post(tap: .cghidEventTap)
                        }

                        // Release V
                        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
                            vUp.flags = .maskCommand
                            vUp.post(tap: .cghidEventTap)
                        }

                        // Release Command
                        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) {
                            cmdUp.post(tap: .cghidEventTap)
                        }

                        NSLog("[PHTPPicker] Paste command sent")

                        // Clean up file after paste
                        deleteFileAfterDelay(stickerURL)
                    }
                }
            }
        }.resume()
    }
}

// MARK: - Unified Content View

struct UnifiedContentView: View {
    var onEmojiSelected: (String) -> Void
    var onClose: (() -> Void)?

    @StateObject private var klipyClient = KlipyAPIClient.shared
    private let database = EmojiDatabase.shared

    @State private var searchText = ""
    @State private var emojiSearchResults: [EmojiItem] = []
    @State private var searchTask: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    private let mediaColumns = [
        GridItem(.fixed(70), spacing: 12),
        GridItem(.fixed(70), spacing: 12),
        GridItem(.fixed(70), spacing: 12),
        GridItem(.fixed(70), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                TextField("Tìm icons, GIFs, stickers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        // Cancel previous search task
                        searchTask?.cancel()

                        if newValue.isEmpty {
                            // Clear results immediately
                            emojiSearchResults = []
                            klipyClient.searchResults = []
                            klipyClient.stickerSearchResults = []
                        } else {
                            // Debounce search - wait for user to stop typing
                            let task = DispatchWorkItem { [self] in
                                performSearch(query: newValue)
                            }
                            searchTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchTask?.cancel()
                        searchText = ""
                        emojiSearchResults = []
                        isSearchFocused = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(isSearchFocused ? 0.3 : 0), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

            Divider()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Emojis Section
                if !searchText.isEmpty {
                    // Search results for emojis (cached)
                    if !emojiSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("Emojis")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 4)

                            LazyVGrid(columns: iconColumns, spacing: 12) {
                                ForEach(emojiSearchResults.prefix(14), id: \.id) { emojiItem in
                                    Button(action: {
                                        onEmojiSelected(emojiItem.emoji)
                                    }) {
                                        Text(emojiItem.emoji)
                                            .font(.system(size: 30))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(height: 40)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(10)
                    }
                } else if !database.getFrequentlyUsedEmojis(limit: 14).isEmpty {
                    // Recent emojis
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("Emojis")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(columns: iconColumns, spacing: 12) {
                            ForEach(database.getFrequentlyUsedEmojis(limit: 14), id: \.self) { emoji in
                                if let emojiItem = database.getEmojiItem(for: emoji) {
                                    Button(action: {
                                        onEmojiSelected(emojiItem.emoji)
                                    }) {
                                        Text(emojiItem.emoji)
                                            .font(.system(size: 30))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(height: 40)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(10)
                }

                // GIFs Section
                if !searchText.isEmpty {
                    // Search results for GIFs
                    if !klipyClient.searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("GIFs")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 4)

                            LazyVGrid(columns: mediaColumns, spacing: 12) {
                                ForEach(klipyClient.searchResults.prefix(8), id: \.id) { gif in
                                    GIFThumbnailView(gif: gif) {
                                        copyGIFURL(gif)
                                    }
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(10)
                    }
                } else if !klipyClient.getRecentGIFIDs().isEmpty {
                    // Recent GIFs
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("GIFs")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(columns: mediaColumns, spacing: 12) {
                            ForEach(klipyClient.getRecentGIFs().prefix(8), id: \.id) { gif in
                                GIFThumbnailView(gif: gif) {
                                    copyGIFURL(gif)
                                }
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(10)
                }

                // Stickers Section
                if !searchText.isEmpty {
                    // Search results for Stickers
                    if !klipyClient.stickerSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("Stickers")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 4)

                            LazyVGrid(columns: mediaColumns, spacing: 12) {
                                ForEach(klipyClient.stickerSearchResults.prefix(8), id: \.id) { sticker in
                                    GIFThumbnailView(gif: sticker, onTap: {
                                        copyStickerURL(sticker)
                                    }, contentType: "Sticker")
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(10)
                    }
                } else if !klipyClient.getRecentStickerIDs().isEmpty {
                    // Recent Stickers
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("Stickers")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(columns: mediaColumns, spacing: 12) {
                            ForEach(klipyClient.getRecentStickers().prefix(8), id: \.id) { sticker in
                                GIFThumbnailView(gif: sticker, onTap: {
                                    copyStickerURL(sticker)
                                }, contentType: "Sticker")
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(10)
                }

                // Empty state
                if !searchText.isEmpty {
                    // Search empty state
                    let hasAnyResults = !emojiSearchResults.isEmpty ||
                                       !klipyClient.searchResults.isEmpty ||
                                       !klipyClient.stickerSearchResults.isEmpty
                    if !hasAnyResults {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 56))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Không tìm thấy kết quả")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Thử tìm kiếm với từ khóa khác")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                } else if database.getFrequentlyUsedEmojis(limit: 1).isEmpty &&
                   klipyClient.getRecentGIFIDs().isEmpty &&
                   klipyClient.getRecentStickerIDs().isEmpty {
                    // Recent items empty state
                    VStack(spacing: 12) {
                        Image(systemName: "flame")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Chưa có nội dung thường dùng")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Emojis, GIFs và Stickers\nbạn dùng nhiều nhất sẽ hiển thị ở đây")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        }
        .onAppear {
            isSearchFocused = true
            // Fetch content if empty
            if klipyClient.trendingGIFs.isEmpty {
                klipyClient.fetchTrending()
            }
            if klipyClient.trendingStickers.isEmpty {
                klipyClient.fetchTrendingStickers()
            }
        }
    }

    // Perform search across all content types
    private func performSearch(query: String) {
        // Search Emojis (cached to avoid repeated computation)
        emojiSearchResults = database.search(query)
        // Search GIFs
        klipyClient.search(query: query)
        // Search Stickers
        klipyClient.searchStickers(query: query)
    }

    // Helper functions to copy media
    private func copyGIFURL(_ gif: KlipyGIF) {
        klipyClient.recordGIFUsage(gif)
        guard let url = URL(string: gif.fullURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let tempURL = saveTempGIF(data: data, filename: gif.slug) {
                    NSLog("[PHTPPicker] GIF downloaded: %@", gif.slug)

                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([tempURL as NSPasteboardWriting])
                    _ = pasteboard.setData(data, forType: .fileURL)

                    // Close panel first
                    onClose?()

                    // Small delay to allow panel to close and frontmost app to regain focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NSLog("[PHTPPicker] Pasting GIF...")
                        simulatePaste()

                        // Clean up file after paste
                        deleteFileAfterDelay(tempURL)
                    }
                }
            }
        }.resume()
    }

    private func copyStickerURL(_ sticker: KlipyGIF) {
        klipyClient.recordStickerUsage(sticker)
        guard let url = URL(string: sticker.fullURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let tempURL = saveTempSticker(data: data, filename: sticker.slug) {
                    NSLog("[PHTPPicker] Sticker downloaded: %@", sticker.slug)

                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([tempURL as NSPasteboardWriting])

                    // Close panel first
                    onClose?()

                    // Small delay to allow panel to close and frontmost app to regain focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NSLog("[PHTPPicker] Pasting Sticker...")
                        simulatePaste()

                        // Clean up file after paste
                        deleteFileAfterDelay(tempURL)
                    }
                }
            }
        }.resume()
    }

    private func getPHTPMediaDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let phtpDir = tempDir.appendingPathComponent("PHTPMedia", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: phtpDir.path) {
            try? FileManager.default.createDirectory(at: phtpDir, withIntermediateDirectories: true)
        }

        return phtpDir
    }

    private func saveTempGIF(data: Data, filename: String) -> URL? {
        let phtpDir = getPHTPMediaDirectory()
        let gifURL = phtpDir.appendingPathComponent("\(filename).gif")
        do {
            try data.write(to: gifURL)
            return gifURL
        } catch {
            NSLog("[PHTPPicker] Error saving GIF: %@", error.localizedDescription)
            return nil
        }
    }

    private func saveTempSticker(data: Data, filename: String) -> URL? {
        let phtpDir = getPHTPMediaDirectory()
        let stickerURL = phtpDir.appendingPathComponent("\(filename).png")
        do {
            try data.write(to: stickerURL)
            return stickerURL
        } catch {
            NSLog("[PHTPPicker] Error saving Sticker: %@", error.localizedDescription)
            return nil
        }
    }

    private func deleteFileAfterDelay(_ fileURL: URL, delay: TimeInterval = 5.0) {
        // Delete file after a delay to ensure paste is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            try? FileManager.default.removeItem(at: fileURL)
            NSLog("[PHTPPicker] Cleaned up file: %@", fileURL.lastPathComponent)
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Press Command
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cghidEventTap)
        }

        // Press V (0x09 = kVK_ANSI_V)
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
        }

        // Release V
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cghidEventTap)
        }

        // Release Command
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) {
            cmdUp.post(tap: .cghidEventTap)
        }

        NSLog("[PHTPPicker] Paste command sent")
    }
}

struct GIFThumbnailView: View {
    let gif: KlipyGIF
    let onTap: () -> Void
    var contentType: String = "GIF"  // "GIF" or "Sticker"

    @State private var isHovered = false
    @State private var hasTrackedImpression = false

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.05)

            // GIF content
            AnimatedGIFView(url: URL(string: gif.previewURL))
                .frame(width: 120, height: 120)
                .clipped()

            // Ad badge (nếu là ad)
            if gif.isAd {
                VStack {
                    HStack {
                        Spacer()
                        Text("Ad")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(8)
                .allowsHitTesting(false)
            }
        }
        .frame(width: 120, height: 120)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHovered ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .help(gif.isAd ? "Quảng cáo - Click để xem" : "Click để tải và gửi \(contentType)")
        .onAppear {
            if gif.isAd && !hasTrackedImpression {
                KlipyAPIClient.shared.trackImpression(for: gif)
                hasTrackedImpression = true
            }
        }
    }
}

// MARK: - API Key Setup View

struct APIKeySetupView: View {
    @ObservedObject var klipyClient: KlipyAPIClient

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Cần Klipy App Key")
                .font(.headline)

            Text("Để sử dụng tính năng GIF, bạn cần lấy app key miễn phí từ Klipy (không giới hạn request).")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.vertical, 8)

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Cách lấy app key miễn phí (< 60 giây):")
                    .font(.caption)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Mở Klipy Partner Portal")
                        .font(.caption2)
                    Text("2. Đăng nhập hoặc tạo account")
                        .font(.caption2)
                    Text("3. Vào API Keys section")
                        .font(.caption2)
                    Text("4. Copy app key")
                        .font(.caption2)
                    Text("5. Paste vào PHTVApp.swift (dòng 1694)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                Button("Mở Klipy Partner Portal") {
                    if let url = URL(string: "https://partner.klipy.com/api-keys") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)

                Text("Sau khi có app key, mở file PHTVApp.swift và thay 'YOUR_KLIPY_APP_KEY_HERE' bằng key của bạn.")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Animated GIF View

/// SwiftUI wrapper for NSImageView to display animated GIFs
struct AnimatedGIFView: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true // Enable GIF animation
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        guard let url = url else { return }

        // Load GIF data asynchronously
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                nsView.image = image
            }
        }.resume()
    }
}


/// Floating panel that stays on top of other windows
class FloatingPanel<Content: View>: NSPanel, NSWindowDelegate {

    init(view: Content, contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .closable, .borderless],
            backing: .buffered,
            defer: false
        )

        // Panel behavior
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Visual styling
        self.isMovableByWindowBackground = true  // Enable window dragging
        self.backgroundColor = .clear

        // Performance
        self.isOpaque = false
        self.hasShadow = false  // Shadow handled by SwiftUI layer

        // Disable resizing completely
        self.minSize = contentRect.size
        self.maxSize = contentRect.size

        // Set content view
        self.contentView = NSHostingView(rootView: view)

        // Set delegate to handle close button
        self.delegate = self

        // Center on screen
        self.center()
    }

    // Handle close button click
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSLog("[FloatingPanel] windowShouldClose called")
        return true
    }

    // Override performClose to handle close button for nonactivating panels
    override func performClose(_ sender: Any?) {
        NSLog("[FloatingPanel] performClose called - closing panel")
        self.close()
    }

    /// Shows the panel at current mouse position
    func showAtMousePosition() {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero

        // Position panel near mouse, but ensure it stays on screen
        var origin = mouseLocation
        origin.x = min(max(origin.x, screenFrame.minX), screenFrame.maxX - self.frame.width)
        origin.y = min(max(origin.y - self.frame.height, screenFrame.minY), screenFrame.maxY - self.frame.height)

        self.setFrameOrigin(origin)
        self.orderFrontRegardless()
    }

    /// Key event handling - close on Escape
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape key
            close()
        default:
            super.keyDown(with: event)
        }
    }

    // Override canBecomeKey to allow keyboard input
    override var canBecomeKey: Bool {
        return true
    }
}


/// PHTV Picker view with enhanced UX
struct EmojiPickerView: View {
    var onEmojiSelected: (String) -> Void
    var onClose: (() -> Void)?

    // Remember last selected tab using UserDefaults
    @State private var selectedCategory: Int
    @Namespace private var categoryNamespace
    
    private static let lastTabKey = "PHTVPickerLastTab"
    
    init(onEmojiSelected: @escaping (String) -> Void, onClose: (() -> Void)? = nil) {
        self.onEmojiSelected = onEmojiSelected
        self.onClose = onClose
        // Load last selected tab, default to -2 ("Tất cả") if not set
        let savedTab = UserDefaults.standard.integer(forKey: EmojiPickerView.lastTabKey)
        // Validate saved tab is valid (-2, -3, -4, -5)
        if [-2, -3, -4, -5].contains(savedTab) {
            _selectedCategory = State(initialValue: savedTab)
        } else {
            _selectedCategory = State(initialValue: -2)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button and drag handle
            HStack(spacing: 8) {
                // Drag handle icon (left side)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 20)
                    .background(WindowDragHandle())
                    .help("Kéo để di chuyển")

                Text("PHTV Picker")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    onClose?()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
                .help("Đóng (ESC)")
                .onHover { hovering in
                    NSCursor.pointingHand.set()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)


            // Category tabs
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // All Content tab
                        CategoryTab(
                            isSelected: selectedCategory == -2,
                            icon: "sparkles",
                            label: "Tất cả",
                            namespace: categoryNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = -2
                            }
                        }
                        .id(-2)
                        .onAppear {
                            // Scroll to saved/selected category when view appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollProxy.scrollTo(selectedCategory, anchor: .center)
                            }
                        }

                        // Emoji tab
                        CategoryTab(
                            isSelected: selectedCategory == -3,
                            icon: "face.smiling.fill",
                            label: "Emoji",
                            namespace: categoryNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = -3
                            }
                        }
                        .id(-3)

                        // GIF tab
                        CategoryTab(
                            isSelected: selectedCategory == -4,
                            icon: "photo.on.rectangle.angled",
                            label: "GIF",
                            namespace: categoryNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = -4
                            }
                        }
                        .id(-4)

                        // Sticker tab
                        CategoryTab(
                            isSelected: selectedCategory == -5,
                            icon: "sparkle",
                            label: "Sticker",
                            namespace: categoryNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = -5
                            }
                        }
                        .id(-5)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 10)
            }

            Divider()
                .opacity(0.5)

            // Content area - show different tabs based on selectedCategory
            if selectedCategory == -2 {
                // All Content tab with search (Emojis, GIFs, Stickers)
                UnifiedContentView(onEmojiSelected: onEmojiSelected, onClose: onClose)
                    .frame(height: 320)
            } else if selectedCategory == -3 {
                // Emoji tab - show all emoji categories
                EmojiCategoriesView(onEmojiSelected: onEmojiSelected)
                    .frame(height: 320)
            } else if selectedCategory == -4 {
                // GIF tab
                GIFOnlyView(onClose: onClose)
                    .frame(height: 320)
            } else if selectedCategory == -5 {
                // Sticker tab
                StickerOnlyView(onClose: onClose)
                    .frame(height: 320)
            }
        }
        .frame(width: 380)
        .onChange(of: selectedCategory) { newValue in
            // Save selected tab to UserDefaults
            UserDefaults.standard.set(newValue, forKey: EmojiPickerView.lastTabKey)
        }
        .background {
            if #available(macOS 26.0, *) {
                // Liquid Glass design for macOS 26+ (regular for better visibility)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.3))
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
            } else {
                // Fallback glassmorphism for older macOS
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            }
        }
    }
}

// MARK: - Category Tab Components

struct CategoryTab: View {
    let isSelected: Bool
    let icon: String
    let label: String
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 8)
            .frame(minWidth: 60)
            .frame(height: 40)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15))
                            .matchedGeometryEffect(id: "categoryBackground", in: namespace)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Emoji Button Component

struct EmojiButton: View {
    let emoji: EmojiItem
    let size: CGFloat
    let isHovered: Bool
    let frequencyCount: Int?
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            ZStack(alignment: .topTrailing) {
                Text(emoji.emoji)
                    .font(.system(size: size * 0.65))
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHovered ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor).opacity(0.3))
                    )
                    .scaleEffect(isHovered ? 1.15 : (isPressed ? 0.95 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressed)

                // Frequency badge
                if let count = frequencyCount, count > 3 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(emoji.name)
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Window Drag Handle

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        return DragHandleView()
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

class DragHandleView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        return true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}


/// Manager for PHTV Picker floating panel
@MainActor
class EmojiPickerManager {
    static let shared = EmojiPickerManager()

    private var panel: FloatingPanel<EmojiPickerView>?
    private var previousApp: NSRunningApplication?

    private init() {}

    /// Shows the PHTV Picker at current mouse position
    func show() {
        NSLog("[PHTPPicker] Showing PHTV Picker at mouse position")

        // Save the currently active app so we can restore focus later
        previousApp = NSWorkspace.shared.frontmostApplication
        if let appName = previousApp?.localizedName {
            NSLog("[PHTPPicker] Saved previous app: %@", appName)
        }

        // Close existing panel if any
        panel?.close()

        // Create new panel with PHTV Picker view
        let emojiPickerView = EmojiPickerView(
            onEmojiSelected: { [weak self] emoji in
                self?.handleEmojiSelected(emoji)
            },
            onClose: { [weak self] in
                self?.hide()
            }
        )

        let contentRect = NSRect(x: 0, y: 0, width: 380, height: 480)
        panel = FloatingPanel(view: emojiPickerView, contentRect: contentRect)

        // Hide system close button since we have our own
        panel?.standardWindowButton(.closeButton)?.isHidden = true
        panel?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel?.standardWindowButton(.zoomButton)?.isHidden = true

        // Show at mouse position
        panel?.showAtMousePosition()

        // Make panel key to receive keyboard input
        panel?.makeKey()

        NSLog("[EmojiPicker] Panel shown")
    }

    /// Hides the PHTV Picker and restores focus to previous app
    func hide() {
        NSLog("[PHTPPicker] Hiding PHTV Picker")
        panel?.close()
        panel = nil

        // Restore focus to the previous app with a small delay
        // to ensure panel is fully closed first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            if let app = self?.previousApp {
                NSLog("[PHTPPicker] Restoring focus to: %@", app.localizedName ?? "Unknown")
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }

    /// Handles emoji selection - pastes emoji to frontmost app
    private func handleEmojiSelected(_ emoji: String) {
        NSLog("[EmojiPicker] Emoji selected: %@", emoji)

        // Record emoji usage for recent & frequency tracking
        EmojiDatabase.shared.recordUsage(emoji)

        // Close panel
        hide()

        // Small delay to allow panel to close and frontmost app to regain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteEmoji(emoji)
        }
    }

    /// Pastes emoji using CGEvent to simulate typing
    private func pasteEmoji(_ emoji: String) {
        NSLog("[EmojiPicker] Pasting emoji: %@", emoji)

        // Method 1: Use pasteboard (most reliable)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(emoji, forType: .string)

        // Simulate Command+V to paste
        let source = CGEventSource(stateID: .hidSystemState)

        // Press Command
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cghidEventTap)
        }

        // Press V
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
        }

        // Release V
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cghidEventTap)
        }

        // Release Command
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) {
            cmdUp.post(tap: .cghidEventTap)
        }

        NSLog("[EmojiPicker] Paste command sent")
    }
}
