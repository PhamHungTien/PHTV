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












