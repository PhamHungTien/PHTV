//
//  PHTPApp.swift
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
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 950, height: 680)
        .windowResizability(.contentMinSize)
    }
}

/// Wrapper view for settings window content
/// This helps with proper lifecycle management
struct SettingsWindowContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .top) {
            SettingsView()

            // Update banner overlay
            UpdateBannerView()
                .zIndex(1000)
        }
    }
}

// MARK: - Beep Manager (inline for target visibility)
@MainActor
final class BeepManager {
    static let shared = BeepManager()

    private let popSound: NSSound?

    private init() {
        self.popSound = NSSound(named: NSSound.Name("Pop"))
        self.popSound?.loops = false
    }

    func play(volume: Double) {
        let v = max(0.0, min(1.0, volume))
        guard v > 0.0 else { return }
        if let sound = self.popSound {
            sound.stop()
            sound.volume = Float(v)
            sound.play()
            return
        }
        NSSound.beep()
    }
}

// MARK: - Menu Bar Icon Drawing
@MainActor
private func makeMenuBarIconImage(size: CGFloat, slashed: Bool, useVietnameseIcon: Bool) -> NSImage {
    let targetSize = NSSize(width: size, height: size)
    let img = NSImage(size: targetSize)
    img.lockFocus()
    defer { img.unlockFocus() }

    let rect = NSRect(origin: .zero, size: targetSize)

    // Use different icons based on language mode
    let baseIcon: NSImage? = {
        if slashed {
            // English mode - use menubar_english.png
            if let englishIcon = NSImage(named: "menubar_english") {
                return englishIcon
            }
        }
        // Vietnamese mode - use menubar_vietnamese.png or menubar_icon.png based on preference
        if useVietnameseIcon, let vietnameseIcon = NSImage(named: "menubar_vietnamese") {
            return vietnameseIcon
        }
        if let img = NSImage(named: "menubar_icon") {
            return img
        }
        return NSApplication.shared.applicationIconImage
    }()

    if let baseIcon {
        baseIcon.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    img.isTemplate = true
    img.size = targetSize
    return img
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

                // FIX: Set window level to ensure it appears above other apps
                window.level = .floating

                // FIX: Use orderFrontRegardless to force window to front
                window.orderFrontRegardless()
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

    // Auto restore English words
    @Published var autoRestoreEnglishWord: Bool = false

    // Typing statistics
    @Published var typingStatsEnabled: Bool = false

    // Restore to raw keys (customizable key)
    @Published var restoreOnEscape: Bool = true
    @Published var restoreKey: RestoreKey = .esc

    // Pause Vietnamese input when holding a key
    @Published var pauseKeyEnabled: Bool = false
    @Published var pauseKey: UInt16 = 58  // Default: Left Option (same as RestoreKey.option)
    @Published var pauseKeyName: String = "Option"

    // Emoji Hotkey Settings
    @Published var enableEmojiHotkey: Bool = false
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
    @Published var fixChromiumBrowser: Bool = false
    @Published var performLayoutCompat: Bool = false
    @Published var showIconOnDock: Bool = false
    @Published var safeMode: Bool = false  // Safe mode disables Accessibility API for OCLP Macs
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
    @Published var showCustomUpdateBanner: Bool = false
    @Published var customUpdateBannerInfo: UpdateBannerInfo? = nil

    private var cancellables = Set<AnyCancellable>()
    private var isLoadingSettings = false

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
        NotificationCenter.default.addObserver(
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

        // Listen for language changes from manual actions (hotkey, UI, input type change)
        NotificationCenter.default.addObserver(
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

        // Listen for language changes from excluded apps (no beep sound)
        NotificationCenter.default.addObserver(
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

        // Listen for language changes from smart switch (no beep sound)
        NotificationCenter.default.addObserver(
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

        // Listen for update check responses from backend
        NotificationCenter.default.addObserver(
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

        // Sparkle custom update banner
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SparkleShowUpdateBanner"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let info = notification.object as? [String: String] {
                Task { @MainActor in
                    self.customUpdateBannerInfo = UpdateBannerInfo(
                        version: info["version"] ?? "",
                        releaseNotes: info["releaseNotes"] ?? "",
                        downloadURL: info["downloadURL"] ?? ""
                    )
                    self.showCustomUpdateBanner = true
                }
            }
        }
    }

    func checkAccessibilityPermission() {
        // Check using AXIsProcessTrusted
        Task { @MainActor in
            self.hasAccessibilityPermission = AXIsProcessTrusted()
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
            runOnStartup = (appService.status == .enabled)
        } else {
            runOnStartup = defaults.bool(forKey: "PHTV_RunOnStartup")
        }
        fixChromiumBrowser = defaults.bool(forKey: "vFixChromiumBrowser")
        performLayoutCompat = defaults.bool(forKey: "vPerformLayoutCompat")
        showIconOnDock = defaults.bool(forKey: "vShowIconOnDock")
        safeMode = defaults.bool(forKey: "SafeMode")
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

        // Typing statistics
        typingStatsEnabled = defaults.bool(forKey: "vTypingStatsEnabled")

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

        // Load emoji hotkey settings
        enableEmojiHotkey = defaults.bool(forKey: "vEnableEmojiHotkey")
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
        defaults.set(fixChromiumBrowser, forKey: "vFixChromiumBrowser")
        defaults.set(performLayoutCompat, forKey: "vPerformLayoutCompat")
        defaults.set(showIconOnDock, forKey: "vShowIconOnDock")

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

        // Typing statistics
        defaults.set(typingStatsEnabled, forKey: "vTypingStatsEnabled")

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

        // Observer for runOnStartup - update immediately
        $runOnStartup.sink { [weak self] value in
            guard let self = self, !self.isLoadingSettings else { return }
            // Safe unwrap AppDelegate
            guard let appDelegate = NSApp.delegate as? AppDelegate else {
                print("[AppState] AppDelegate not available yet, skipping runOnStartup update")
                return
            }
            // Update immediately without debounce
            appDelegate.setRunOnStartup(value)
            let defaults = UserDefaults.standard
            defaults.set(value, forKey: "PHTV_RunOnStartup")
            defaults.synchronize()
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
        .merge(with: $typingStatsEnabled.map { _ in () })
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
            $fixChromiumBrowser.map { _ in () }.eraseToAnyPublisher(),
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
        autoRestoreEnglishWord = false
        typingStatsEnabled = false

        runOnStartup = false
        fixChromiumBrowser = false
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

// MARK: - Enums
enum InputMethod: String, CaseIterable, Identifiable, Sendable {
    case telex = "Telex"
    case vni = "VNI"
    case simpleTelex1 = "Simple Telex 1"
    case simpleTelex2 = "Simple Telex 2"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String { rawValue }

    func toIndex() -> Int {
        switch self {
        case .telex: return 0
        case .vni: return 1
        case .simpleTelex1: return 2
        case .simpleTelex2: return 3
        }
    }

    static func from(index: Int) -> InputMethod {
        switch index {
        case 0: return .telex
        case 1: return .vni
        case 2: return .simpleTelex1
        case 3: return .simpleTelex2
        default: return .telex
        }
    }
}

enum CodeTable: String, CaseIterable, Identifiable, Sendable {
    case unicode = "Unicode"
    case tcvn = "TCVN3"
    case vniWindows = "VNI Windows"
    case unicodeComposite = "Unicode Composite"
    case cp1258 = "Vietnamese Locale (CP1258)"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String { rawValue }

    func toIndex() -> Int {
        switch self {
        case .unicode: return 0
        case .tcvn: return 1
        case .vniWindows: return 2
        case .unicodeComposite: return 3
        case .cp1258: return 4
        }
    }

    static func from(index: Int) -> CodeTable {
        switch index {
        case 0: return .unicode
        case 1: return .tcvn
        case 2: return .vniWindows
        case 3: return .unicodeComposite
        case 4: return .cp1258
        default: return .unicode
        }
    }
}

// MARK: - Restore Key
enum RestoreKey: Int, CaseIterable, Identifiable, Sendable {
    case esc = 53
    case option = 58         // Left Option (represents both L/R)
    case control = 59        // Left Control (represents both L/R)

    nonisolated var id: Int { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .esc: return "ESC"
        case .option: return "Option"
        case .control: return "Control"
        }
    }

    nonisolated var symbol: String {
        switch self {
        case .esc: return "esc"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }

    // Get all possible key codes for this restore key (for modifiers, includes both left and right)
    nonisolated var keyCodes: [Int] {
        switch self {
        case .esc: return [53]
        case .option: return [58, 61]       // Left and Right Option
        case .control: return [59, 62]      // Left and Right Control
        }
    }

    static func from(keyCode: Int) -> RestoreKey {
        // SAFETY: Only allow valid restore keys to prevent conflicts with typing
        // Any invalid value defaults to ESC for safety
        switch keyCode {
        case 53: return .esc
        case 58, 61: return .option      // Left or Right Option
        case 59, 62: return .control     // Left or Right Control
        default:
            // Invalid key code - log warning and default to ESC
            print("[WARNING] Invalid restore key code: \(keyCode), defaulting to ESC")
            return .esc
        }
    }
}

// MARK: - Update Check Frequency
enum UpdateCheckFrequency: Int, CaseIterable, Identifiable, Sendable {
    case never = 0
    case daily = 86400        // 24 hours
    case weekly = 604800      // 7 days
    case monthly = 2592000    // 30 days

    nonisolated var id: Int { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .never: return "Không bao giờ"
        case .daily: return "Hàng ngày"
        case .weekly: return "Hàng tuần"
        case .monthly: return "Hàng tháng"
        }
    }

    static func from(interval: Int) -> UpdateCheckFrequency {
        switch interval {
        case 0: return .never
        case 86400: return .daily
        case 604800: return .weekly
        case 2592000: return .monthly
        default: return .daily
        }
    }
}

// MARK: - Update Banner Info
struct UpdateBannerInfo: Equatable {
    let version: String
    let releaseNotes: String
    let downloadURL: String
}

// MARK: - Excluded App Model
struct ExcludedApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String

    init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }

    init?(from url: URL) {
        guard let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier,
            let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?[
                "CFBundleDisplayName"] as? String
        else { return nil }

        self.bundleIdentifier = bundleId
        self.name = name
        self.path = url.path
    }
}

// MARK: - Send Key Step By Step App Model
struct SendKeyStepByStepApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String

    init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }

    init?(from url: URL) {
        guard let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier,
            let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?[
                "CFBundleDisplayName"] as? String
        else { return nil }

        self.bundleIdentifier = bundleId
        self.name = name
        self.path = url.path
    }
}


// MARK: - Emoji Hotkey Manager

/// Singleton manager for PHTV Picker hotkey
/// Monitors global keyboard events and triggers PHTV Picker when hotkey is pressed
final class EmojiHotkeyManager: ObservableObject, @unchecked Sendable {

    static let shared = EmojiHotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isEnabled: Bool = false
    private var modifiers: NSEvent.ModifierFlags = .command
    private var keyCode: UInt16 = 14  // E key default

    private init() {
        NSLog("[EmojiHotkey] EmojiHotkeyManager initialized")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: NSNotification.Name("EmojiHotkeySettingsChanged"),
            object: nil
        )

        // CRITICAL: Delay sync to avoid circular dependency during AppState.shared initialization
        // Use asyncAfter with minimal delay to break the dispatch_once recursion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.syncFromAppState(AppState.shared)
            }
        }
    }

    @objc private func handleSettingsChanged() {
        NSLog("[EmojiHotkey] Settings changed notification received")
        // Delay to avoid circular dependency if called during AppState.shared initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.syncFromAppState(AppState.shared)
            }
        }
    }
    
    @MainActor
    func syncFromAppState(_ appState: AppState) {
        NSLog("SYNC-START: enabled=%d, modifiers=%lu, keyCode=%d", appState.enableEmojiHotkey ? 1 : 0, UInt(appState.emojiHotkeyModifiers.rawValue), appState.emojiHotkeyKeyCode)

        let wasEnabled = isEnabled
        let oldModifiers = modifiers
        let oldKeyCode = keyCode

        isEnabled = appState.enableEmojiHotkey
        modifiers = appState.emojiHotkeyModifiers
        keyCode = appState.emojiHotkeyKeyCode

        NSLog("SYNC-CHANGE-CHECK: wasEnabled=%d, isEnabled=%d", wasEnabled ? 1 : 0, isEnabled ? 1 : 0)

        if wasEnabled != isEnabled || oldModifiers != modifiers || oldKeyCode != keyCode {
            NSLog("SYNC-WILL-UPDATE")
            // CRITICAL: Save desired state BEFORE unregisterHotkey() modifies isEnabled
            let shouldEnable = isEnabled
            unregisterHotkey()

            if shouldEnable {
                NSLog("SYNC-WILL-REGISTER")
                registerHotkey(modifiers: modifiers, keyCode: keyCode)
            }

            if shouldEnable {
                NSLog("[EmojiHotkey] Registered: %@%@", modifierSymbols(modifiers), keyCodeSymbol(keyCode))
            } else {
                NSLog("[EmojiHotkey] Disabled")
            }
        } else {
            NSLog("SYNC-NO-CHANGE")
        }
    }
    
    func registerHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        NSLog("REGISTER-START: modifiers=%lu, keyCode=%d", UInt(modifiers.rawValue), keyCode)
        unregisterHotkey()

        self.modifiers = modifiers
        self.keyCode = keyCode
        self.isEnabled = true

        NSLog("REGISTER-ADDING-MONITORS")
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            NSLog("GLOBAL-MONITOR-FIRED")
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Quick check to consume event IMMEDIATELY if it matches hotkey
            // This prevents system beep sound
            guard event.keyCode == self.keyCode else {
                return event
            }

            let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

            guard eventModifiers == self.modifiers else {
                return event
            }

            // Match! Consume event immediately to prevent beep
            NSLog("[EmojiHotkey] Hotkey matched, opening picker")
            DispatchQueue.main.async {
                self.openEmojiPicker()
            }

            // Return nil to consume the event and prevent system beep
            return nil
        }

        NSLog("REGISTER-COMPLETE: globalMonitor=%@, localMonitor=%@", globalMonitor != nil ? "YES" : "NO", localMonitor != nil ? "YES" : "NO")
        NSLog("[EmojiHotkey] Hotkey registered: %@%@", modifierSymbols(modifiers), keyCodeSymbol(keyCode))
    }
    
    func unregisterHotkey() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        isEnabled = false

        NSLog("[EmojiHotkey] Hotkey unregistered")
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        NSLog("HANDLE-KEY: keyCode=%d (expecting %d)", event.keyCode, keyCode)

        guard event.keyCode == keyCode else {
            return false
        }

        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

        NSLog("HANDLE-KEY-MODIFIERS: event=%lu, expected=%lu", UInt(eventModifiers.rawValue), UInt(modifiers.rawValue))

        guard eventModifiers == modifiers else {
            return false
        }

        NSLog("HANDLE-KEY-MATCH! Opening PHTV Picker")

        openEmojiPicker()
        return true
    }
    
    private func openEmojiPicker() {
        NSLog("[EmojiHotkey] Opening PHTV Picker...")

        DispatchQueue.main.async {
            EmojiPickerManager.shared.show()
        }
    }
    
    private func modifierSymbols(_ modifiers: NSEvent.ModifierFlags) -> String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols
    }
    
    private func keyCodeSymbol(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 41: return ";"
        case 14: return "E"
        case 49: return "Space"
        case 44: return "/"
        case 39: return "'"
        case 43: return ","
        case 47: return "."
        default:
            if let char = keyCodeToCharacter(keyCode) {
                return String(char)
            }
            return "Key\(keyCode)"
        }
    }
    
    private func keyCodeToCharacter(_ keyCode: UInt16) -> Character? {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)
        var length = 0
        event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: nil)
        
        if length > 0 {
            var chars: [UniChar] = Array(repeating: 0, count: length)
            event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
            if let scalar = UnicodeScalar(chars[0]) {
                return Character(scalar)
            }
        }
        
        return nil
    }
}

// MARK: - Emoji Hotkey Bridge for Objective-C

/// Bridge to initialize EmojiHotkeyManager from Objective-C AppDelegate
@objc class EmojiHotkeyBridge: NSObject {
    @objc static func initializeEmojiHotkeyManager() {
        NSLog("BRIDGE-START")
        print("BRIDGE-START-PRINT")

        // Force initialization - this will trigger the singleton's init()
        let manager = EmojiHotkeyManager.shared

        NSLog("BRIDGE-AFTER-SHARED")
        print("BRIDGE-AFTER-SHARED-PRINT")

        NSLog("[EmojiHotkeyBridge] Manager object: %@", String(describing: manager))
    }
}


// MARK: - PHTV Picker

// MARK: - Klipy GIF API

/// Klipy API client for fetching GIFs - Free unlimited API
@MainActor
class KlipyAPIClient: ObservableObject {
    static let shared = KlipyAPIClient()

    // KLIPY API - Free unlimited (không giới hạn request)
    // App key cho PHTV từ https://partner.klipy.com/api-keys
    private let appKey = "OvUIlmqoLrdwmY1YvnF9gVp7ScFDgx30TMGgDWDHqIdPb8CHyQWgYmr3byyhBFPZ"
    private let baseURL = "https://api.klipy.com/api/v1"

    // Domain where app-ads.txt is hosted (required for monetization)
    private let domain = "phamhungtien.github.io"

    // Customer ID - unique user identifier (có thể dùng UUID)
    private let customerId: String = {
        if let saved = UserDefaults.standard.string(forKey: "KlipyCustomerID") {
            return saved
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "KlipyCustomerID")
        return newId
    }()

    @Published var trendingGIFs: [KlipyGIF] = []
    @Published var searchResults: [KlipyGIF] = []
    @Published var trendingStickers: [KlipyGIF] = []
    @Published var stickerSearchResults: [KlipyGIF] = []
    @Published var isLoading = false
    @Published var needsAPIKey: Bool = false

    // Recent items tracking
    private let maxRecentItems = 20
    private let recentGIFsKey = "RecentGIFs"
    private let recentStickersKey = "RecentStickers"

    // Callback to close picker window
    var onCloseCallback: (() -> Void)?

    private init() {
        needsAPIKey = appKey == "YOUR_KLIPY_APP_KEY_HERE"

        // Clean old cache on init
        cleanOldCache()
    }

    func saveAPIKey(_ key: String) {
        print("[Klipy] Please hardcode your app key in PHTPApp.swift")
    }

    /// Fetch trending GIFs
    func fetchTrending(limit: Int = 24) {
        guard appKey != "YOUR_KLIPY_APP_KEY_HERE" else {
            print("[Klipy] Please set your app key")
            needsAPIKey = true
            return
        }

        isLoading = true

        // Klipy API: GET /api/v1/{app_key}/gifs/trending
        let urlString = "\(baseURL)/\(appKey)/gifs/trending?customer_id=\(customerId)&per_page=\(limit)&domain=\(domain)"
        print("[Klipy] Fetching trending from: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[Klipy] Invalid URL")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse {
                print("[Klipy] Response status: \(httpResponse.statusCode)")
            }

            guard let data = data, error == nil else {
                print("[Klipy] Error fetching trending: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(KlipyResponse.self, from: data)
                print("[Klipy] Successfully decoded \(result.data.data.count) GIFs")
                DispatchQueue.main.async {
                    self.trendingGIFs = result.data.data
                    self.isLoading = false
                }
            } catch {
                print("[Klipy] Decode error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    /// Search GIFs
    func search(query: String, limit: Int = 24) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        guard appKey != "YOUR_KLIPY_APP_KEY_HERE" else {
            print("[Klipy] Please set your app key for search")
            needsAPIKey = true
            return
        }

        isLoading = true

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Klipy API: GET /api/v1/{app_key}/gifs/search
        let urlString = "\(baseURL)/\(appKey)/gifs/search?q=\(encodedQuery)&customer_id=\(customerId)&per_page=\(limit)&domain=\(domain)"
        print("[Klipy] Searching for: \(query)")
        guard let url = URL(string: urlString) else {
            print("[Klipy] Invalid search URL")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data, error == nil else {
                print("[Klipy] Error searching: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(KlipyResponse.self, from: data)
                print("[Klipy] Search found \(result.data.data.count) GIFs")
                DispatchQueue.main.async {
                    self.searchResults = result.data.data
                    self.isLoading = false
                }
            } catch {
                print("[Klipy] Decode error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    // MARK: - Stickers API

    /// Fetch trending Stickers
    func fetchTrendingStickers(limit: Int = 24) {
        guard appKey != "YOUR_KLIPY_APP_KEY_HERE" else {
            print("[Klipy] Please set your app key")
            needsAPIKey = true
            return
        }

        isLoading = true

        // Klipy API: GET /api/v1/{app_key}/stickers/trending
        let urlString = "\(baseURL)/\(appKey)/stickers/trending?customer_id=\(customerId)&per_page=\(limit)&domain=\(domain)"
        print("[Klipy Stickers] Fetching trending from: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[Klipy Stickers] Invalid URL")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse {
                print("[Klipy Stickers] Response status: \(httpResponse.statusCode)")
            }

            guard let data = data, error == nil else {
                print("[Klipy Stickers] Error fetching trending: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(KlipyResponse.self, from: data)
                print("[Klipy Stickers] Successfully decoded \(result.data.data.count) Stickers")
                DispatchQueue.main.async {
                    self.trendingStickers = result.data.data
                    self.isLoading = false
                }
            } catch {
                print("[Klipy Stickers] Decode error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    /// Search Stickers
    func searchStickers(query: String, limit: Int = 24) {
        guard !query.isEmpty else {
            stickerSearchResults = []
            return
        }

        guard appKey != "YOUR_KLIPY_APP_KEY_HERE" else {
            print("[Klipy Stickers] Please set your app key for search")
            needsAPIKey = true
            return
        }

        isLoading = true

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Klipy API: GET /api/v1/{app_key}/stickers/search
        let urlString = "\(baseURL)/\(appKey)/stickers/search?q=\(encodedQuery)&customer_id=\(customerId)&per_page=\(limit)&domain=\(domain)"
        print("[Klipy Stickers] Searching for: \(query)")
        guard let url = URL(string: urlString) else {
            print("[Klipy Stickers] Invalid search URL")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data, error == nil else {
                print("[Klipy Stickers] Error searching: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(KlipyResponse.self, from: data)
                print("[Klipy Stickers] Search found \(result.data.data.count) Stickers")
                DispatchQueue.main.async {
                    self.stickerSearchResults = result.data.data
                    self.isLoading = false
                }
            } catch {
                print("[Klipy Stickers] Decode error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    // MARK: - Recent Items Tracking

    /// Record GIF usage
    func recordGIFUsage(_ gif: KlipyGIF) {
        var recent = getRecentGIFIDs()
        recent.removeAll { $0 == gif.id }
        recent.insert(gif.id, at: 0)
        if recent.count > maxRecentItems {
            recent = Array(recent.prefix(maxRecentItems))
        }
        UserDefaults.standard.set(Array(recent), forKey: recentGIFsKey)
    }

    /// Record Sticker usage
    func recordStickerUsage(_ sticker: KlipyGIF) {
        var recent = getRecentStickerIDs()
        recent.removeAll { $0 == sticker.id }
        recent.insert(sticker.id, at: 0)
        if recent.count > maxRecentItems {
            recent = Array(recent.prefix(maxRecentItems))
        }
        UserDefaults.standard.set(Array(recent), forKey: recentStickersKey)
    }

    /// Get recent GIF IDs
    func getRecentGIFIDs() -> [Int64] {
        return (UserDefaults.standard.array(forKey: recentGIFsKey) as? [Int64]) ?? []
    }

    /// Get recent Sticker IDs
    func getRecentStickerIDs() -> [Int64] {
        return (UserDefaults.standard.array(forKey: recentStickersKey) as? [Int64]) ?? []
    }

    /// Get recent GIFs (from all sources)
    func getRecentGIFs() -> [KlipyGIF] {
        let ids = getRecentGIFIDs()
        let allGIFs = trendingGIFs + searchResults
        return ids.compactMap { id in allGIFs.first { $0.id == id } }
    }

    /// Get recent Stickers (from all sources)
    func getRecentStickers() -> [KlipyGIF] {
        let ids = getRecentStickerIDs()
        let allStickers = trendingStickers + stickerSearchResults
        return ids.compactMap { id in allStickers.first { $0.id == id } }
    }

    // MARK: - Cache Management

    /// Clean old cached GIFs/Stickers (older than 7 days or if cache exceeds 100MB)
    func cleanOldCache() {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

            guard let files = try? fileManager.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            ) else {
                return
            }

            var totalSize: Int64 = 0
            var oldFiles: [URL] = []

            // Collect old files and calculate total size
            for fileURL in files {
                // Only process GIF and PNG files (our cached media)
                let ext = fileURL.pathExtension.lowercased()
                guard ext == "gif" || ext == "png" else { continue }

                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   let fileSize = attributes[.size] as? Int64 {

                    totalSize += fileSize

                    // Mark files older than 7 days for deletion
                    if creationDate < sevenDaysAgo {
                        oldFiles.append(fileURL)
                    }
                }
            }

            // Delete old files
            for fileURL in oldFiles {
                try? fileManager.removeItem(at: fileURL)
            }

            // If total cache size > 100MB, delete oldest files until under 50MB
            let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
            let targetCacheSize: Int64 = 50 * 1024 * 1024 // 50MB

            if totalSize > maxCacheSize {
                // Sort files by creation date (oldest first)
                let sortedFiles = files
                    .filter { url in
                        let ext = url.pathExtension.lowercased()
                        return ext == "gif" || ext == "png"
                    }
                    .compactMap { url -> (URL, Date)? in
                        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                              let creationDate = attributes[.creationDate] as? Date else {
                            return nil
                        }
                        return (url, creationDate)
                    }
                    .sorted { $0.1 < $1.1 }

                var currentSize = totalSize
                for (fileURL, _) in sortedFiles {
                    if currentSize <= targetCacheSize {
                        break
                    }

                    if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        try? fileManager.removeItem(at: fileURL)
                        currentSize -= fileSize
                    }
                }

                print("[Klipy Cache] Cleaned cache from \(totalSize / 1024 / 1024)MB to \(currentSize / 1024 / 1024)MB")
            }
        }
    }

    // MARK: - Ad Tracking

    /// Track ad impression (when ad is displayed)
    func trackImpression(for gif: KlipyGIF) {
        guard gif.isAd, let impressionURL = gif.impression_url, let url = URL(string: impressionURL) else {
            return
        }

        print("[Klipy Ads] Tracking impression for ad: \(gif.id)")

        // Fire impression tracking pixel
        URLSession.shared.dataTask(with: url) { _, _, error in
            if let error = error {
                print("[Klipy Ads] Impression tracking error: \(error.localizedDescription)")
            } else {
                print("[Klipy Ads] Impression tracked successfully")
            }
        }.resume()
    }

    /// Track ad click (when ad is clicked)
    func trackClick(for gif: KlipyGIF) {
        guard gif.isAd, let clickURL = gif.click_url, let url = URL(string: clickURL) else {
            return
        }

        print("[Klipy Ads] Tracking click for ad: \(gif.id)")

        // Fire click tracking pixel
        URLSession.shared.dataTask(with: url) { _, _, error in
            if let error = error {
                print("[Klipy Ads] Click tracking error: \(error.localizedDescription)")
            } else {
                print("[Klipy Ads] Click tracked successfully")
            }
        }.resume()
    }

    /// Open ad target URL in browser (optional, if user clicks ad)
    func openAdTarget(for gif: KlipyGIF) {
        guard gif.isAd, let targetURL = gif.target_url, let url = URL(string: targetURL) else {
            return
        }

        print("[Klipy Ads] Opening ad target: \(targetURL)")
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Klipy Models

struct KlipyResponse: Codable {
    let result: Bool
    let data: KlipyData
}

struct KlipyData: Codable {
    let data: [KlipyGIF]
    let current_page: Int
    let per_page: Int
    let has_next: Bool
}

struct KlipyGIF: Codable, Identifiable {
    let id: Int64
    let slug: String
    let title: String
    let file: KlipyFile
    let tags: [String]?  // Optional - API có thể trả về null
    let type: String

    // Ad-specific fields (optional, only present when type == "ad")
    let impression_url: String?
    let click_url: String?
    let target_url: String?
    let advertiser: String?

    var isAd: Bool {
        type == "ad"
    }

    var previewURL: String {
        // Use small size for preview, fallback to any available size
        file.sm?.gif?.url ?? file.xs?.gif?.url ?? file.hd?.gif?.url ?? ""
    }

    var fullURL: String {
        // Use HD GIF for full quality, fallback to smaller sizes
        file.hd?.gif?.url ?? file.sm?.gif?.url ?? file.xs?.gif?.url ?? ""
    }

    // Safe check for empty URLs
    var hasValidURL: Bool {
        !previewURL.isEmpty && !fullURL.isEmpty
    }
}

struct KlipyFile: Codable {
    let hd: KlipyFileSize?  // Optional - API có thể không trả về hd
    let sm: KlipyFileSize?
    let xs: KlipyFileSize?
}

struct KlipyFileSize: Codable {
    let gif: KlipyMedia?
    let webp: KlipyMedia?
    let mp4: KlipyMedia?
}

struct KlipyMedia: Codable {
    let url: String
    let width: Int?
    let height: Int?
    let size: Int?
}

// MARK: - Emoji Categories View

struct EmojiCategoriesView: View {
    var onEmojiSelected: (String) -> Void

    private let database = EmojiDatabase.shared
    @State private var selectedSubCategory = 0
    @Namespace private var subCategoryNamespace

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // Sub-category tabs
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
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            // Emoji grid for selected category
            ScrollView {
                LazyVGrid(columns: iconColumns, spacing: 12) {
                    ForEach(database.categories[selectedSubCategory].emojis, id: \.id) { emojiItem in
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
                    let tempDir = FileManager.default.temporaryDirectory
                    let gifURL = tempDir.appendingPathComponent("\(gif.slug).gif")
                    try? data.write(to: gifURL)

                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([gifURL as NSPasteboardWriting])
                    _ = pasteboard.setData(data, forType: .fileURL)
                    onClose?()

                    let source = CGEventSource(stateID: .hidSystemState)
                    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                    keyDown?.flags = .maskCommand
                    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                    keyUp?.flags = .maskCommand
                    keyDown?.post(tap: .cghidEventTap)
                    keyUp?.post(tap: .cghidEventTap)
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
                    let tempDir = FileManager.default.temporaryDirectory
                    let stickerURL = tempDir.appendingPathComponent("\(sticker.slug).png")
                    try? data.write(to: stickerURL)

                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([stickerURL as NSPasteboardWriting])
                    onClose?()

                    let source = CGEventSource(stateID: .hidSystemState)
                    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                    keyDown?.flags = .maskCommand
                    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                    keyUp?.flags = .maskCommand
                    keyDown?.post(tap: .cghidEventTap)
                    keyUp?.post(tap: .cghidEventTap)
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
                        if !newValue.isEmpty {
                            // Debounce search
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if searchText == newValue {
                                    performSearch(query: newValue)
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
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

            Divider()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Emojis Section
                if !searchText.isEmpty {
                    // Search results for emojis
                    let emojiResults = database.search(searchText)
                    if !emojiResults.isEmpty {
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
                                ForEach(emojiResults.prefix(14), id: \.id) { emojiItem in
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
                    let hasAnyResults = !database.search(searchText).isEmpty ||
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
        // Search GIFs
        klipyClient.search(query: query)
        // Search Stickers
        klipyClient.searchStickers(query: query)
        // Emoji search is done via database.search() in the view
    }

    // Helper functions to copy media
    private func copyGIFURL(_ gif: KlipyGIF) {
        klipyClient.recordGIFUsage(gif)
        guard let url = URL(string: gif.fullURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let tempURL = saveTempGIF(data: data, filename: gif.slug) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([tempURL as NSPasteboardWriting])
                    _ = pasteboard.setData(data, forType: .fileURL)
                    onClose?()
                    simulatePaste()
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
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([tempURL as NSPasteboardWriting])
                    onClose?()
                    simulatePaste()
                }
            }
        }.resume()
    }

    private func saveTempGIF(data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let gifURL = tempDir.appendingPathComponent("\(filename).gif")
        do {
            try data.write(to: gifURL)
            return gifURL
        } catch {
            return nil
        }
    }

    private func saveTempSticker(data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let stickerURL = tempDir.appendingPathComponent("\(filename).png")
        do {
            try data.write(to: stickerURL)
            return stickerURL
        } catch {
            return nil
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
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
                    Text("5. Paste vào PHTPApp.swift (dòng 1694)")
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

                Text("Sau khi có app key, mở file PHTPApp.swift và thay 'YOUR_KLIPY_APP_KEY_HERE' bằng key của bạn.")
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

// MARK: - Emoji Database

/// Represents an emoji with metadata for search
struct EmojiItem: Identifiable, Codable, Equatable {
    let id = UUID()
    let emoji: String
    let name: String // English name
    let keywords: [String] // English + Vietnamese keywords
    let category: String

    enum CodingKeys: String, CodingKey {
        case emoji, name, keywords, category
    }
}

/// Comprehensive emoji database with search support
final class EmojiDatabase: @unchecked Sendable {
    static let shared = EmojiDatabase()

    let categories: [(name: String, icon: String, emojis: [EmojiItem])]

    private init() {
        // Smileys & People
        let smileys: [EmojiItem] = [
            EmojiItem(emoji: "😀", name: "Grinning Face", keywords: ["grinning", "smile", "happy", "cười", "vui"], category: "Smileys"),
            EmojiItem(emoji: "😃", name: "Grinning Face with Big Eyes", keywords: ["grinning", "smile", "happy", "cười", "vui", "mắt to"], category: "Smileys"),
            EmojiItem(emoji: "😄", name: "Grinning Face with Smiling Eyes", keywords: ["smile", "happy", "joy", "cười", "vui vẻ"], category: "Smileys"),
            EmojiItem(emoji: "😁", name: "Beaming Face with Smiling Eyes", keywords: ["smile", "happy", "cười toe toét"], category: "Smileys"),
            EmojiItem(emoji: "😆", name: "Grinning Squinting Face", keywords: ["laugh", "happy", "cười", "vui"], category: "Smileys"),
            EmojiItem(emoji: "😅", name: "Grinning Face with Sweat", keywords: ["smile", "sweat", "cười", "mồ hôi"], category: "Smileys"),
            EmojiItem(emoji: "🤣", name: "Rolling on the Floor Laughing", keywords: ["laugh", "lol", "rofl", "cười lăn"], category: "Smileys"),
            EmojiItem(emoji: "😂", name: "Face with Tears of Joy", keywords: ["laugh", "cry", "tears", "cười", "nước mắt"], category: "Smileys"),
            EmojiItem(emoji: "🙂", name: "Slightly Smiling Face", keywords: ["smile", "cười nhẹ"], category: "Smileys"),
            EmojiItem(emoji: "🙃", name: "Upside-Down Face", keywords: ["upside down", "sarcasm", "ngược"], category: "Smileys"),
            EmojiItem(emoji: "😉", name: "Winking Face", keywords: ["wink", "flirt", "nháy mắt"], category: "Smileys"),
            EmojiItem(emoji: "😊", name: "Smiling Face with Smiling Eyes", keywords: ["smile", "blush", "cười", "hạnh phúc"], category: "Smileys"),
            EmojiItem(emoji: "😇", name: "Smiling Face with Halo", keywords: ["angel", "halo", "thiên thần"], category: "Smileys"),
            EmojiItem(emoji: "🥰", name: "Smiling Face with Hearts", keywords: ["love", "hearts", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "😍", name: "Smiling Face with Heart-Eyes", keywords: ["love", "hearts", "yêu", "mắt tim"], category: "Smileys"),
            EmojiItem(emoji: "🤩", name: "Star-Struck", keywords: ["star", "eyes", "wow", "ngôi sao"], category: "Smileys"),
            EmojiItem(emoji: "😘", name: "Face Blowing a Kiss", keywords: ["kiss", "love", "hôn"], category: "Smileys"),
            EmojiItem(emoji: "😗", name: "Kissing Face", keywords: ["kiss", "hôn"], category: "Smileys"),
            EmojiItem(emoji: "😚", name: "Kissing Face with Closed Eyes", keywords: ["kiss", "hôn"], category: "Smileys"),
            EmojiItem(emoji: "😙", name: "Kissing Face with Smiling Eyes", keywords: ["kiss", "smile", "hôn"], category: "Smileys"),
            EmojiItem(emoji: "🥲", name: "Smiling Face with Tear", keywords: ["smile", "tear", "cười", "nước mắt"], category: "Smileys"),
            EmojiItem(emoji: "😋", name: "Face Savoring Food", keywords: ["yum", "delicious", "ngon"], category: "Smileys"),
            EmojiItem(emoji: "😛", name: "Face with Tongue", keywords: ["tongue", "lưỡi"], category: "Smileys"),
            EmojiItem(emoji: "😜", name: "Winking Face with Tongue", keywords: ["wink", "tongue", "nháy mắt"], category: "Smileys"),
            EmojiItem(emoji: "🤪", name: "Zany Face", keywords: ["crazy", "wild", "điên"], category: "Smileys"),
            EmojiItem(emoji: "😝", name: "Squinting Face with Tongue", keywords: ["tongue", "lưỡi"], category: "Smileys"),
            EmojiItem(emoji: "🤑", name: "Money-Mouth Face", keywords: ["money", "rich", "tiền"], category: "Smileys"),
            EmojiItem(emoji: "🤗", name: "Hugging Face", keywords: ["hug", "ôm"], category: "Smileys"),
            EmojiItem(emoji: "🤭", name: "Face with Hand Over Mouth", keywords: ["oops", "surprise", "che miệng"], category: "Smileys"),
            EmojiItem(emoji: "🤫", name: "Shushing Face", keywords: ["shh", "quiet", "im lặng"], category: "Smileys"),
            EmojiItem(emoji: "🤔", name: "Thinking Face", keywords: ["think", "hmm", "suy nghĩ"], category: "Smileys"),
            EmojiItem(emoji: "🤐", name: "Zipper-Mouth Face", keywords: ["silence", "secret", "im lặng"], category: "Smileys"),
            EmojiItem(emoji: "🤨", name: "Face with Raised Eyebrow", keywords: ["skeptical", "suspicious", "nghi ngờ"], category: "Smileys"),
            EmojiItem(emoji: "😐", name: "Neutral Face", keywords: ["neutral", "trung lập"], category: "Smileys"),
            EmojiItem(emoji: "😑", name: "Expressionless Face", keywords: ["blank", "vô cảm"], category: "Smileys"),
            EmojiItem(emoji: "😶", name: "Face Without Mouth", keywords: ["silence", "im lặng"], category: "Smileys"),
            EmojiItem(emoji: "😏", name: "Smirking Face", keywords: ["smirk", "cười khẩy"], category: "Smileys"),
            EmojiItem(emoji: "😒", name: "Unamused Face", keywords: ["unimpressed", "không vui"], category: "Smileys"),
            EmojiItem(emoji: "🙄", name: "Face with Rolling Eyes", keywords: ["eyeroll", "lăn mắt"], category: "Smileys"),
            EmojiItem(emoji: "😬", name: "Grimacing Face", keywords: ["grimace", "nhăn mặt"], category: "Smileys"),
            EmojiItem(emoji: "🤥", name: "Lying Face", keywords: ["lie", "pinocchio", "nói dối"], category: "Smileys"),
            EmojiItem(emoji: "😌", name: "Relieved Face", keywords: ["relieved", "calm", "nhẹ nhõm"], category: "Smileys"),
            EmojiItem(emoji: "😔", name: "Pensive Face", keywords: ["sad", "pensive", "buồn"], category: "Smileys"),
            EmojiItem(emoji: "😪", name: "Sleepy Face", keywords: ["tired", "sleepy", "buồn ngủ"], category: "Smileys"),
            EmojiItem(emoji: "🤤", name: "Drooling Face", keywords: ["drool", "chảy nước miếng"], category: "Smileys"),
            EmojiItem(emoji: "😴", name: "Sleeping Face", keywords: ["sleep", "ngủ"], category: "Smileys"),
            EmojiItem(emoji: "😷", name: "Face with Medical Mask", keywords: ["mask", "sick", "khẩu trang"], category: "Smileys"),
            EmojiItem(emoji: "🤒", name: "Face with Thermometer", keywords: ["sick", "fever", "ốm"], category: "Smileys"),
            EmojiItem(emoji: "🤕", name: "Face with Head-Bandage", keywords: ["hurt", "injured", "bị thương"], category: "Smileys"),
            EmojiItem(emoji: "🤢", name: "Nauseated Face", keywords: ["sick", "nausea", "buồn nôn"], category: "Smileys"),
            EmojiItem(emoji: "🤮", name: "Face Vomiting", keywords: ["vomit", "sick", "nôn"], category: "Smileys"),
            EmojiItem(emoji: "🤧", name: "Sneezing Face", keywords: ["sneeze", "sick", "hắt hơi"], category: "Smileys"),
            EmojiItem(emoji: "🥵", name: "Hot Face", keywords: ["hot", "heat", "nóng"], category: "Smileys"),
            EmojiItem(emoji: "🥶", name: "Cold Face", keywords: ["cold", "freeze", "lạnh"], category: "Smileys"),
            EmojiItem(emoji: "😵", name: "Dizzy Face", keywords: ["dizzy", "confused", "chóng mặt"], category: "Smileys"),
            EmojiItem(emoji: "🤯", name: "Exploding Head", keywords: ["mind blown", "shocked", "sốc"], category: "Smileys"),
            EmojiItem(emoji: "🥳", name: "Partying Face", keywords: ["party", "celebrate", "tiệc tung"], category: "Smileys"),
            EmojiItem(emoji: "😎", name: "Smiling Face with Sunglasses", keywords: ["cool", "sunglasses", "ngầu"], category: "Smileys"),
            EmojiItem(emoji: "🤓", name: "Nerd Face", keywords: ["nerd", "geek", "mọt sách"], category: "Smileys"),
            EmojiItem(emoji: "🧐", name: "Face with Monocle", keywords: ["monocle", "fancy", "lịch lãm"], category: "Smileys"),
            EmojiItem(emoji: "😕", name: "Confused Face", keywords: ["confused", "bối rối"], category: "Smileys"),
            EmojiItem(emoji: "😟", name: "Worried Face", keywords: ["worried", "lo lắng"], category: "Smileys"),
            EmojiItem(emoji: "🙁", name: "Slightly Frowning Face", keywords: ["sad", "buồn"], category: "Smileys"),
            EmojiItem(emoji: "☹️", name: "Frowning Face", keywords: ["sad", "unhappy", "buồn"], category: "Smileys"),
            EmojiItem(emoji: "😮", name: "Face with Open Mouth", keywords: ["surprise", "wow", "ngạc nhiên"], category: "Smileys"),
            EmojiItem(emoji: "😯", name: "Hushed Face", keywords: ["quiet", "surprise", "im lặng"], category: "Smileys"),
            EmojiItem(emoji: "😲", name: "Astonished Face", keywords: ["shocked", "surprise", "sốc"], category: "Smileys"),
            EmojiItem(emoji: "😳", name: "Flushed Face", keywords: ["blush", "embarrassed", "xấu hổ"], category: "Smileys"),
            EmojiItem(emoji: "🥺", name: "Pleading Face", keywords: ["puppy eyes", "please", "cầu xin"], category: "Smileys"),
            EmojiItem(emoji: "😦", name: "Frowning Face with Open Mouth", keywords: ["sad", "frown", "buồn"], category: "Smileys"),
            EmojiItem(emoji: "😧", name: "Anguished Face", keywords: ["anguish", "worry", "đau khổ"], category: "Smileys"),
            EmojiItem(emoji: "😨", name: "Fearful Face", keywords: ["fear", "scared", "sợ hãi"], category: "Smileys"),
            EmojiItem(emoji: "😰", name: "Anxious Face with Sweat", keywords: ["anxious", "nervous", "lo lắng"], category: "Smileys"),
            EmojiItem(emoji: "😥", name: "Sad but Relieved Face", keywords: ["sad", "relieved", "buồn"], category: "Smileys"),
            EmojiItem(emoji: "😢", name: "Crying Face", keywords: ["cry", "sad", "tears", "khóc"], category: "Smileys"),
            EmojiItem(emoji: "😭", name: "Loudly Crying Face", keywords: ["cry", "sob", "tears", "khóc"], category: "Smileys"),
            EmojiItem(emoji: "😱", name: "Face Screaming in Fear", keywords: ["scream", "fear", "hét"], category: "Smileys"),
            EmojiItem(emoji: "😖", name: "Confounded Face", keywords: ["confused", "frustrated", "bối rối"], category: "Smileys"),
            EmojiItem(emoji: "😣", name: "Persevering Face", keywords: ["struggle", "persevere", "kiên trì"], category: "Smileys"),
            EmojiItem(emoji: "😞", name: "Disappointed Face", keywords: ["disappointed", "sad", "thất vọng"], category: "Smileys"),
            EmojiItem(emoji: "😓", name: "Downcast Face with Sweat", keywords: ["sad", "sweat", "buồn"], category: "Smileys"),
            EmojiItem(emoji: "😩", name: "Weary Face", keywords: ["tired", "weary", "mệt mỏi"], category: "Smileys"),
            EmojiItem(emoji: "😫", name: "Tired Face", keywords: ["tired", "exhausted", "kiệt sức"], category: "Smileys"),
            EmojiItem(emoji: "🥱", name: "Yawning Face", keywords: ["yawn", "tired", "ngáp"], category: "Smileys"),
            EmojiItem(emoji: "😤", name: "Face with Steam From Nose", keywords: ["angry", "triumph", "tức giận"], category: "Smileys"),
            EmojiItem(emoji: "😡", name: "Pouting Face", keywords: ["angry", "mad", "tức"], category: "Smileys"),
            EmojiItem(emoji: "😠", name: "Angry Face", keywords: ["angry", "mad", "giận"], category: "Smileys"),
            EmojiItem(emoji: "🤬", name: "Face with Symbols on Mouth", keywords: ["swearing", "cursing", "chửi"], category: "Smileys"),
            EmojiItem(emoji: "😈", name: "Smiling Face with Horns", keywords: ["devil", "evil", "ma quỷ"], category: "Smileys"),
            EmojiItem(emoji: "👿", name: "Angry Face with Horns", keywords: ["devil", "angry", "quỷ"], category: "Smileys"),
            EmojiItem(emoji: "💀", name: "Skull", keywords: ["skull", "death", "dead", "đầu lâu"], category: "Smileys"),
            EmojiItem(emoji: "☠️", name: "Skull and Crossbones", keywords: ["skull", "danger", "nguy hiểm"], category: "Smileys"),
            EmojiItem(emoji: "💩", name: "Pile of Poo", keywords: ["poop", "shit", "phân"], category: "Smileys"),
            EmojiItem(emoji: "🤡", name: "Clown Face", keywords: ["clown", "hề"], category: "Smileys"),
            EmojiItem(emoji: "👹", name: "Ogre", keywords: ["ogre", "monster", "quỷ"], category: "Smileys"),
            EmojiItem(emoji: "👺", name: "Goblin", keywords: ["goblin", "monster", "quỷ"], category: "Smileys"),
            EmojiItem(emoji: "👻", name: "Ghost", keywords: ["ghost", "boo", "ma"], category: "Smileys"),
            EmojiItem(emoji: "👽", name: "Alien", keywords: ["alien", "ufo", "người ngoài hành tinh"], category: "Smileys"),
            EmojiItem(emoji: "👾", name: "Alien Monster", keywords: ["alien", "game", "quái vật"], category: "Smileys"),
            EmojiItem(emoji: "🤖", name: "Robot", keywords: ["robot", "rô bốt"], category: "Smileys"),
            EmojiItem(emoji: "😺", name: "Grinning Cat", keywords: ["cat", "smile", "mèo"], category: "Smileys"),
            EmojiItem(emoji: "😸", name: "Grinning Cat with Smiling Eyes", keywords: ["cat", "happy", "mèo"], category: "Smileys"),
            EmojiItem(emoji: "😹", name: "Cat with Tears of Joy", keywords: ["cat", "laugh", "mèo"], category: "Smileys"),
            EmojiItem(emoji: "😻", name: "Smiling Cat with Heart-Eyes", keywords: ["cat", "love", "mèo"], category: "Smileys"),
            EmojiItem(emoji: "😼", name: "Cat with Wry Smile", keywords: ["cat", "smirk", "mèo"], category: "Smileys"),
            EmojiItem(emoji: "😽", name: "Kissing Cat", keywords: ["cat", "kiss", "mèo"], category: "Smileys"),
            EmojiItem(emoji: "🙀", name: "Weary Cat", keywords: ["cat", "scared", "mèo"], category: "Smileys"),
            EmojiItem(emoji: "😿", name: "Crying Cat", keywords: ["cat", "cry", "mèo"], category: "Smileys"),
            EmojiItem(emoji: "😾", name: "Pouting Cat", keywords: ["cat", "angry", "mèo"], category: "Smileys"),
            // Hearts & Emotion
            EmojiItem(emoji: "❤️", name: "Red Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "🧡", name: "Orange Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "💛", name: "Yellow Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "💚", name: "Green Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "💙", name: "Blue Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "💜", name: "Purple Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "🖤", name: "Black Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "🤍", name: "White Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "🤎", name: "Brown Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Smileys"),
            EmojiItem(emoji: "💔", name: "Broken Heart", keywords: ["broken", "heart", "heartbreak", "tan vỡ"], category: "Smileys"),
            EmojiItem(emoji: "❤️‍🔥", name: "Heart on Fire", keywords: ["love", "fire", "yêu", "lửa"], category: "Smileys"),
            EmojiItem(emoji: "❤️‍🩹", name: "Mending Heart", keywords: ["healing", "heart", "lành"], category: "Smileys"),
            EmojiItem(emoji: "💕", name: "Two Hearts", keywords: ["love", "hearts", "yêu"], category: "Smileys"),
            EmojiItem(emoji: "💞", name: "Revolving Hearts", keywords: ["love", "hearts", "yêu"], category: "Smileys"),
            EmojiItem(emoji: "💓", name: "Beating Heart", keywords: ["love", "heartbeat", "yêu", "đập"], category: "Smileys"),
            EmojiItem(emoji: "💗", name: "Growing Heart", keywords: ["love", "growing", "yêu"], category: "Smileys"),
            EmojiItem(emoji: "💖", name: "Sparkling Heart", keywords: ["love", "sparkle", "yêu", "lấp lánh"], category: "Smileys"),
            EmojiItem(emoji: "💘", name: "Heart with Arrow", keywords: ["love", "cupid", "yêu"], category: "Smileys"),
            EmojiItem(emoji: "💝", name: "Heart with Ribbon", keywords: ["love", "gift", "yêu", "quà"], category: "Smileys"),
            EmojiItem(emoji: "💟", name: "Heart Decoration", keywords: ["love", "heart", "yêu"], category: "Smileys"),
        ]

        // People & Body
        let hands: [EmojiItem] = [
            EmojiItem(emoji: "👋", name: "Waving Hand", keywords: ["wave", "hello", "vẫy tay", "chào"], category: "Hands"),
            EmojiItem(emoji: "🤚", name: "Raised Back of Hand", keywords: ["hand", "raised", "tay"], category: "Hands"),
            EmojiItem(emoji: "🖐", name: "Hand with Fingers Splayed", keywords: ["hand", "five", "tay"], category: "Hands"),
            EmojiItem(emoji: "✋", name: "Raised Hand", keywords: ["hand", "stop", "tay", "dừng"], category: "Hands"),
            EmojiItem(emoji: "🖖", name: "Vulcan Salute", keywords: ["spock", "star trek", "tay"], category: "Hands"),
            EmojiItem(emoji: "👌", name: "OK Hand", keywords: ["ok", "okay", "good", "được"], category: "Hands"),
            EmojiItem(emoji: "🤏", name: "Pinching Hand", keywords: ["small", "tiny", "nhỏ"], category: "Hands"),
            EmojiItem(emoji: "✌️", name: "Victory Hand", keywords: ["peace", "victory", "chiến thắng"], category: "Hands"),
            EmojiItem(emoji: "🤞", name: "Crossed Fingers", keywords: ["fingers crossed", "luck", "may mắn"], category: "Hands"),
            EmojiItem(emoji: "🤟", name: "Love-You Gesture", keywords: ["love", "yêu"], category: "Hands"),
            EmojiItem(emoji: "🤘", name: "Sign of the Horns", keywords: ["rock", "metal", "nhạc rock"], category: "Hands"),
            EmojiItem(emoji: "🤙", name: "Call Me Hand", keywords: ["phone", "call", "gọi điện"], category: "Hands"),
            EmojiItem(emoji: "👈", name: "Backhand Index Pointing Left", keywords: ["point", "left", "trái"], category: "Hands"),
            EmojiItem(emoji: "👉", name: "Backhand Index Pointing Right", keywords: ["point", "right", "phải"], category: "Hands"),
            EmojiItem(emoji: "👆", name: "Backhand Index Pointing Up", keywords: ["point", "up", "lên"], category: "Hands"),
            EmojiItem(emoji: "👇", name: "Backhand Index Pointing Down", keywords: ["point", "down", "xuống"], category: "Hands"),
            EmojiItem(emoji: "☝️", name: "Index Pointing Up", keywords: ["point", "up", "lên", "một"], category: "Hands"),
            EmojiItem(emoji: "🖕", name: "Middle Finger", keywords: ["middle finger", "rude", "ngón giữa"], category: "Hands"),
            EmojiItem(emoji: "👍", name: "Thumbs Up", keywords: ["like", "good", "yes", "thích", "tốt"], category: "Hands"),
            EmojiItem(emoji: "👎", name: "Thumbs Down", keywords: ["dislike", "bad", "no", "không thích"], category: "Hands"),
            EmojiItem(emoji: "✊", name: "Raised Fist", keywords: ["fist", "punch", "đấm"], category: "Hands"),
            EmojiItem(emoji: "👊", name: "Oncoming Fist", keywords: ["punch", "đấm"], category: "Hands"),
            EmojiItem(emoji: "🤛", name: "Left-Facing Fist", keywords: ["fist", "đấm"], category: "Hands"),
            EmojiItem(emoji: "🤜", name: "Right-Facing Fist", keywords: ["fist", "đấm"], category: "Hands"),
            EmojiItem(emoji: "👏", name: "Clapping Hands", keywords: ["clap", "applause", "vỗ tay"], category: "Hands"),
            EmojiItem(emoji: "🙌", name: "Raising Hands", keywords: ["hands", "celebrate", "ăn mừng"], category: "Hands"),
            EmojiItem(emoji: "👐", name: "Open Hands", keywords: ["hands", "open", "mở"], category: "Hands"),
            EmojiItem(emoji: "🤲", name: "Palms Up Together", keywords: ["pray", "hands", "cầu nguyện"], category: "Hands"),
            EmojiItem(emoji: "🤝", name: "Handshake", keywords: ["shake", "deal", "bắt tay"], category: "Hands"),
            EmojiItem(emoji: "🙏", name: "Folded Hands", keywords: ["pray", "thanks", "cầu nguyện", "cảm ơn"], category: "Hands"),
            EmojiItem(emoji: "✍️", name: "Writing Hand", keywords: ["write", "pen", "viết"], category: "Hands"),
            EmojiItem(emoji: "💅", name: "Nail Polish", keywords: ["nail", "polish", "manicure", "sơn móng"], category: "Hands"),
            EmojiItem(emoji: "🤳", name: "Selfie", keywords: ["selfie", "camera", "phone", "chụp ảnh"], category: "Hands"),
            EmojiItem(emoji: "💪", name: "Flexed Biceps", keywords: ["muscle", "strong", "cơ bắp", "mạnh"], category: "Hands"),
            EmojiItem(emoji: "🦵", name: "Leg", keywords: ["leg", "kick", "chân"], category: "Hands"),
            EmojiItem(emoji: "🦶", name: "Foot", keywords: ["foot", "kick", "bàn chân"], category: "Hands"),
            EmojiItem(emoji: "👂", name: "Ear", keywords: ["ear", "hear", "tai"], category: "Hands"),
            EmojiItem(emoji: "🦻", name: "Ear with Hearing Aid", keywords: ["ear", "hearing aid", "tai nghe"], category: "Hands"),
            EmojiItem(emoji: "👃", name: "Nose", keywords: ["nose", "smell", "mũi"], category: "Hands"),
            EmojiItem(emoji: "🧠", name: "Brain", keywords: ["brain", "smart", "não"], category: "Hands"),
            EmojiItem(emoji: "🫀", name: "Anatomical Heart", keywords: ["heart", "organ", "tim"], category: "Hands"),
            EmojiItem(emoji: "🫁", name: "Lungs", keywords: ["lungs", "breath", "phổi"], category: "Hands"),
            EmojiItem(emoji: "🦷", name: "Tooth", keywords: ["tooth", "dental", "răng"], category: "Hands"),
            EmojiItem(emoji: "🦴", name: "Bone", keywords: ["bone", "skeleton", "xương"], category: "Hands"),
            EmojiItem(emoji: "👀", name: "Eyes", keywords: ["eyes", "look", "watch", "mắt"], category: "Hands"),
            EmojiItem(emoji: "👁️", name: "Eye", keywords: ["eye", "look", "mắt"], category: "Hands"),
            EmojiItem(emoji: "👅", name: "Tongue", keywords: ["tongue", "lick", "lưỡi"], category: "Hands"),
            EmojiItem(emoji: "👄", name: "Mouth", keywords: ["mouth", "lips", "miệng", "môi"], category: "Hands"),
            EmojiItem(emoji: "🫦", name: "Biting Lip", keywords: ["lip", "bite", "cắn môi"], category: "Hands"),
            EmojiItem(emoji: "💋", name: "Kiss Mark", keywords: ["kiss", "lipstick", "hôn"], category: "Hands"),
            EmojiItem(emoji: "🦾", name: "Mechanical Arm", keywords: ["robot", "arm", "cánh tay robot"], category: "Hands"),
            EmojiItem(emoji: "🦿", name: "Mechanical Leg", keywords: ["robot", "leg", "chân robot"], category: "Hands"),
            // People
            EmojiItem(emoji: "👶", name: "Baby", keywords: ["baby", "infant", "em bé"], category: "Hands"),
            EmojiItem(emoji: "🧒", name: "Child", keywords: ["child", "kid", "trẻ em"], category: "Hands"),
            EmojiItem(emoji: "👦", name: "Boy", keywords: ["boy", "bé trai"], category: "Hands"),
            EmojiItem(emoji: "👧", name: "Girl", keywords: ["girl", "bé gái"], category: "Hands"),
            EmojiItem(emoji: "🧑", name: "Person", keywords: ["person", "người"], category: "Hands"),
            EmojiItem(emoji: "👨", name: "Man", keywords: ["man", "đàn ông"], category: "Hands"),
            EmojiItem(emoji: "👩", name: "Woman", keywords: ["woman", "phụ nữ"], category: "Hands"),
            EmojiItem(emoji: "🧓", name: "Older Person", keywords: ["old", "elderly", "người già"], category: "Hands"),
            EmojiItem(emoji: "👴", name: "Old Man", keywords: ["old man", "ông"], category: "Hands"),
            EmojiItem(emoji: "👵", name: "Old Woman", keywords: ["old woman", "bà"], category: "Hands"),
            EmojiItem(emoji: "👨‍⚕️", name: "Man Health Worker", keywords: ["doctor", "bác sĩ"], category: "Hands"),
            EmojiItem(emoji: "👩‍⚕️", name: "Woman Health Worker", keywords: ["doctor", "bác sĩ"], category: "Hands"),
            EmojiItem(emoji: "👨‍🎓", name: "Man Student", keywords: ["student", "học sinh"], category: "Hands"),
            EmojiItem(emoji: "👩‍🎓", name: "Woman Student", keywords: ["student", "học sinh"], category: "Hands"),
            EmojiItem(emoji: "👨‍🏫", name: "Man Teacher", keywords: ["teacher", "giáo viên"], category: "Hands"),
            EmojiItem(emoji: "👩‍🏫", name: "Woman Teacher", keywords: ["teacher", "giáo viên"], category: "Hands"),
            EmojiItem(emoji: "👨‍💻", name: "Man Technologist", keywords: ["developer", "programmer", "lập trình viên"], category: "Hands"),
            EmojiItem(emoji: "👩‍💻", name: "Woman Technologist", keywords: ["developer", "programmer", "lập trình viên"], category: "Hands"),
            EmojiItem(emoji: "👨‍🎨", name: "Man Artist", keywords: ["artist", "nghệ sĩ"], category: "Hands"),
            EmojiItem(emoji: "👩‍🎨", name: "Woman Artist", keywords: ["artist", "nghệ sĩ"], category: "Hands"),
            EmojiItem(emoji: "👮", name: "Police Officer", keywords: ["police", "cảnh sát"], category: "Hands"),
            EmojiItem(emoji: "🕵️", name: "Detective", keywords: ["detective", "thám tử"], category: "Hands"),
            EmojiItem(emoji: "💂", name: "Guard", keywords: ["guard", "lính gác"], category: "Hands"),
            EmojiItem(emoji: "👷", name: "Construction Worker", keywords: ["construction", "công nhân"], category: "Hands"),
            EmojiItem(emoji: "🤴", name: "Prince", keywords: ["prince", "hoàng tử"], category: "Hands"),
            EmojiItem(emoji: "👸", name: "Princess", keywords: ["princess", "công chúa"], category: "Hands"),
            EmojiItem(emoji: "👳", name: "Person Wearing Turban", keywords: ["turban", "khăn"], category: "Hands"),
            EmojiItem(emoji: "👲", name: "Person with Skullcap", keywords: ["hat", "mũ"], category: "Hands"),
            EmojiItem(emoji: "🧕", name: "Woman with Headscarf", keywords: ["headscarf", "khăn trùm"], category: "Hands"),
            EmojiItem(emoji: "🤵", name: "Person in Tuxedo", keywords: ["tuxedo", "suit", "vest"], category: "Hands"),
            EmojiItem(emoji: "👰", name: "Person with Veil", keywords: ["bride", "wedding", "cô dâu"], category: "Hands"),
            EmojiItem(emoji: "🤰", name: "Pregnant Woman", keywords: ["pregnant", "mang thai"], category: "Hands"),
            EmojiItem(emoji: "🤱", name: "Breast-Feeding", keywords: ["baby", "feeding", "cho con bú"], category: "Hands"),
            EmojiItem(emoji: "👼", name: "Baby Angel", keywords: ["angel", "thiên thần"], category: "Hands"),
            EmojiItem(emoji: "🎅", name: "Santa Claus", keywords: ["santa", "christmas", "ông già noel"], category: "Hands"),
            EmojiItem(emoji: "🤶", name: "Mrs. Claus", keywords: ["santa", "christmas", "bà noel"], category: "Hands"),
            EmojiItem(emoji: "🦸", name: "Superhero", keywords: ["superhero", "siêu anh hùng"], category: "Hands"),
            EmojiItem(emoji: "🦹", name: "Supervillain", keywords: ["villain", "phản diện"], category: "Hands"),
            EmojiItem(emoji: "🧙", name: "Mage", keywords: ["wizard", "phù thủy"], category: "Hands"),
            EmojiItem(emoji: "🧚", name: "Fairy", keywords: ["fairy", "tiên"], category: "Hands"),
            EmojiItem(emoji: "🧛", name: "Vampire", keywords: ["vampire", "ma cà rồng"], category: "Hands"),
            EmojiItem(emoji: "🧜", name: "Merperson", keywords: ["mermaid", "nàng tiên cá"], category: "Hands"),
            EmojiItem(emoji: "🧝", name: "Elf", keywords: ["elf", "yêu tinh"], category: "Hands"),
            EmojiItem(emoji: "🧞", name: "Genie", keywords: ["genie", "thần đèn"], category: "Hands"),
            EmojiItem(emoji: "🧟", name: "Zombie", keywords: ["zombie", "xác sống"], category: "Hands"),
            EmojiItem(emoji: "💆", name: "Person Getting Massage", keywords: ["massage", "spa", "mát-xa"], category: "Hands"),
            EmojiItem(emoji: "💇", name: "Person Getting Haircut", keywords: ["haircut", "cắt tóc"], category: "Hands"),
            EmojiItem(emoji: "🚶", name: "Person Walking", keywords: ["walk", "đi bộ"], category: "Hands"),
            EmojiItem(emoji: "🏃", name: "Person Running", keywords: ["run", "chạy"], category: "Hands"),
            EmojiItem(emoji: "💃", name: "Woman Dancing", keywords: ["dance", "nhảy"], category: "Hands"),
            EmojiItem(emoji: "🕺", name: "Man Dancing", keywords: ["dance", "nhảy"], category: "Hands"),
            EmojiItem(emoji: "🧖", name: "Person in Steamy Room", keywords: ["sauna", "steam", "xông hơi"], category: "Hands"),
            EmojiItem(emoji: "🧗", name: "Person Climbing", keywords: ["climb", "leo núi"], category: "Hands"),
            EmojiItem(emoji: "🏇", name: "Horse Racing", keywords: ["horse", "racing", "đua ngựa"], category: "Hands"),
            EmojiItem(emoji: "🏂", name: "Snowboarder", keywords: ["snowboard", "trượt tuyết"], category: "Hands"),
            EmojiItem(emoji: "🏄", name: "Person Surfing", keywords: ["surf", "lướt sóng"], category: "Hands"),
            EmojiItem(emoji: "🚣", name: "Person Rowing Boat", keywords: ["boat", "rowing", "chèo thuyền"], category: "Hands"),
            EmojiItem(emoji: "🏊", name: "Person Swimming", keywords: ["swim", "bơi"], category: "Hands"),
            EmojiItem(emoji: "🤽", name: "Person Playing Water Polo", keywords: ["water polo", "bóng nước"], category: "Hands"),
            EmojiItem(emoji: "🤾", name: "Person Playing Handball", keywords: ["handball", "bóng ném"], category: "Hands"),
            EmojiItem(emoji: "🤺", name: "Person Fencing", keywords: ["fencing", "đấu kiếm"], category: "Hands"),
            EmojiItem(emoji: "🏌️", name: "Person Golfing", keywords: ["golf", "đánh golf"], category: "Hands"),
            EmojiItem(emoji: "🧘", name: "Person in Lotus Position", keywords: ["yoga", "meditation", "thiền"], category: "Hands"),
            EmojiItem(emoji: "🛀", name: "Person Taking Bath", keywords: ["bath", "tắm"], category: "Hands"),
            EmojiItem(emoji: "🛌", name: "Person in Bed", keywords: ["sleep", "bed", "ngủ"], category: "Hands"),
        ]

        // Animals & Nature
        let animals: [EmojiItem] = [
            EmojiItem(emoji: "🐶", name: "Dog Face", keywords: ["dog", "puppy", "chó"], category: "Animals"),
            EmojiItem(emoji: "🐱", name: "Cat Face", keywords: ["cat", "kitten", "mèo"], category: "Animals"),
            EmojiItem(emoji: "🐭", name: "Mouse Face", keywords: ["mouse", "chuột"], category: "Animals"),
            EmojiItem(emoji: "🐹", name: "Hamster", keywords: ["hamster", "chuột"], category: "Animals"),
            EmojiItem(emoji: "🐰", name: "Rabbit Face", keywords: ["rabbit", "bunny", "thỏ"], category: "Animals"),
            EmojiItem(emoji: "🦊", name: "Fox", keywords: ["fox", "cáo"], category: "Animals"),
            EmojiItem(emoji: "🐻", name: "Bear", keywords: ["bear", "gấu"], category: "Animals"),
            EmojiItem(emoji: "🐼", name: "Panda", keywords: ["panda", "bear", "gấu trúc"], category: "Animals"),
            EmojiItem(emoji: "🐨", name: "Koala", keywords: ["koala", "gấu túi"], category: "Animals"),
            EmojiItem(emoji: "🐯", name: "Tiger Face", keywords: ["tiger", "hổ"], category: "Animals"),
            EmojiItem(emoji: "🦁", name: "Lion", keywords: ["lion", "sư tử"], category: "Animals"),
            EmojiItem(emoji: "🐮", name: "Cow Face", keywords: ["cow", "bò"], category: "Animals"),
            EmojiItem(emoji: "🐷", name: "Pig Face", keywords: ["pig", "lợn"], category: "Animals"),
            EmojiItem(emoji: "🐸", name: "Frog", keywords: ["frog", "ếch"], category: "Animals"),
            EmojiItem(emoji: "🐵", name: "Monkey Face", keywords: ["monkey", "khỉ"], category: "Animals"),
            EmojiItem(emoji: "🐔", name: "Chicken", keywords: ["chicken", "gà"], category: "Animals"),
            EmojiItem(emoji: "🐧", name: "Penguin", keywords: ["penguin", "chim cánh cụt"], category: "Animals"),
            EmojiItem(emoji: "🐦", name: "Bird", keywords: ["bird", "chim"], category: "Animals"),
            EmojiItem(emoji: "🐤", name: "Baby Chick", keywords: ["chick", "baby", "gà con"], category: "Animals"),
            EmojiItem(emoji: "🦆", name: "Duck", keywords: ["duck", "vịt"], category: "Animals"),
            EmojiItem(emoji: "🦅", name: "Eagle", keywords: ["eagle", "bird", "đại bàng"], category: "Animals"),
            EmojiItem(emoji: "🦉", name: "Owl", keywords: ["owl", "bird", "cú"], category: "Animals"),
            EmojiItem(emoji: "🦇", name: "Bat", keywords: ["bat", "dơi"], category: "Animals"),
            EmojiItem(emoji: "🐺", name: "Wolf", keywords: ["wolf", "sói"], category: "Animals"),
            EmojiItem(emoji: "🐗", name: "Boar", keywords: ["boar", "lợn rừng"], category: "Animals"),
            EmojiItem(emoji: "🐴", name: "Horse Face", keywords: ["horse", "ngựa"], category: "Animals"),
            EmojiItem(emoji: "🦄", name: "Unicorn", keywords: ["unicorn", "kỳ lân"], category: "Animals"),
            EmojiItem(emoji: "🐝", name: "Honeybee", keywords: ["bee", "ong"], category: "Animals"),
            EmojiItem(emoji: "🐛", name: "Bug", keywords: ["bug", "worm", "sâu"], category: "Animals"),
            EmojiItem(emoji: "🦋", name: "Butterfly", keywords: ["butterfly", "bướm"], category: "Animals"),
            EmojiItem(emoji: "🐌", name: "Snail", keywords: ["snail", "ốc sên"], category: "Animals"),
            EmojiItem(emoji: "🐞", name: "Lady Beetle", keywords: ["ladybug", "bọ rùa"], category: "Animals"),
            EmojiItem(emoji: "🐜", name: "Ant", keywords: ["ant", "kiến"], category: "Animals"),
            EmojiItem(emoji: "🦗", name: "Cricket", keywords: ["cricket", "dế"], category: "Animals"),
            EmojiItem(emoji: "🕷️", name: "Spider", keywords: ["spider", "nhện"], category: "Animals"),
            EmojiItem(emoji: "🦂", name: "Scorpion", keywords: ["scorpion", "bọ cạp"], category: "Animals"),
            EmojiItem(emoji: "🐢", name: "Turtle", keywords: ["turtle", "rùa"], category: "Animals"),
            EmojiItem(emoji: "🐍", name: "Snake", keywords: ["snake", "rắn"], category: "Animals"),
            EmojiItem(emoji: "🦎", name: "Lizard", keywords: ["lizard", "thằn lằn"], category: "Animals"),
            EmojiItem(emoji: "🐙", name: "Octopus", keywords: ["octopus", "bạch tuộc"], category: "Animals"),
            EmojiItem(emoji: "🦑", name: "Squid", keywords: ["squid", "mực"], category: "Animals"),
            EmojiItem(emoji: "🦐", name: "Shrimp", keywords: ["shrimp", "tôm"], category: "Animals"),
            EmojiItem(emoji: "🦞", name: "Lobster", keywords: ["lobster", "tôm hùm"], category: "Animals"),
            EmojiItem(emoji: "🦀", name: "Crab", keywords: ["crab", "cua"], category: "Animals"),
            EmojiItem(emoji: "🐡", name: "Blowfish", keywords: ["fish", "puffer", "cá nóc"], category: "Animals"),
            EmojiItem(emoji: "🐠", name: "Tropical Fish", keywords: ["fish", "cá"], category: "Animals"),
            EmojiItem(emoji: "🐟", name: "Fish", keywords: ["fish", "cá"], category: "Animals"),
            EmojiItem(emoji: "🐬", name: "Dolphin", keywords: ["dolphin", "cá heo"], category: "Animals"),
            EmojiItem(emoji: "🐳", name: "Spouting Whale", keywords: ["whale", "cá voi"], category: "Animals"),
            EmojiItem(emoji: "🐋", name: "Whale", keywords: ["whale", "cá voi"], category: "Animals"),
            EmojiItem(emoji: "🦈", name: "Shark", keywords: ["shark", "cá mập"], category: "Animals"),
            EmojiItem(emoji: "🐊", name: "Crocodile", keywords: ["crocodile", "cá sấu"], category: "Animals"),
            EmojiItem(emoji: "🐅", name: "Tiger", keywords: ["tiger", "hổ"], category: "Animals"),
            EmojiItem(emoji: "🐆", name: "Leopard", keywords: ["leopard", "báo"], category: "Animals"),
            EmojiItem(emoji: "🦓", name: "Zebra", keywords: ["zebra", "ngựa vằn"], category: "Animals"),
            EmojiItem(emoji: "🦍", name: "Gorilla", keywords: ["gorilla", "khỉ đột"], category: "Animals"),
            EmojiItem(emoji: "🦧", name: "Orangutan", keywords: ["orangutan", "đười ươi"], category: "Animals"),
            EmojiItem(emoji: "🐘", name: "Elephant", keywords: ["elephant", "voi"], category: "Animals"),
            EmojiItem(emoji: "🦛", name: "Hippopotamus", keywords: ["hippo", "hà mã"], category: "Animals"),
            EmojiItem(emoji: "🦏", name: "Rhinoceros", keywords: ["rhino", "tê giác"], category: "Animals"),
            EmojiItem(emoji: "🐪", name: "Camel", keywords: ["camel", "lạc đà"], category: "Animals"),
            EmojiItem(emoji: "🐫", name: "Two-Hump Camel", keywords: ["camel", "lạc đà"], category: "Animals"),
            EmojiItem(emoji: "🦒", name: "Giraffe", keywords: ["giraffe", "hươu cao cổ"], category: "Animals"),
            EmojiItem(emoji: "🦘", name: "Kangaroo", keywords: ["kangaroo", "chuột túi"], category: "Animals"),
            EmojiItem(emoji: "🐃", name: "Water Buffalo", keywords: ["buffalo", "trâu"], category: "Animals"),
            EmojiItem(emoji: "🐂", name: "Ox", keywords: ["ox", "bò"], category: "Animals"),
            EmojiItem(emoji: "🐄", name: "Cow", keywords: ["cow", "bò"], category: "Animals"),
            EmojiItem(emoji: "🐎", name: "Horse", keywords: ["horse", "ngựa"], category: "Animals"),
            EmojiItem(emoji: "🐖", name: "Pig", keywords: ["pig", "lợn"], category: "Animals"),
            EmojiItem(emoji: "🐏", name: "Ram", keywords: ["ram", "cừu đực"], category: "Animals"),
            EmojiItem(emoji: "🐑", name: "Ewe", keywords: ["sheep", "cừu"], category: "Animals"),
            EmojiItem(emoji: "🐐", name: "Goat", keywords: ["goat", "dê"], category: "Animals"),
            EmojiItem(emoji: "🦌", name: "Deer", keywords: ["deer", "hươu"], category: "Animals"),
            EmojiItem(emoji: "🐕", name: "Dog", keywords: ["dog", "chó"], category: "Animals"),
            EmojiItem(emoji: "🐩", name: "Poodle", keywords: ["poodle", "dog", "chó poodle"], category: "Animals"),
            EmojiItem(emoji: "🦮", name: "Guide Dog", keywords: ["dog", "guide", "chó dẫn đường"], category: "Animals"),
            EmojiItem(emoji: "🐕‍🦺", name: "Service Dog", keywords: ["dog", "service", "chó nghiệp vụ"], category: "Animals"),
            EmojiItem(emoji: "🐈", name: "Cat", keywords: ["cat", "mèo"], category: "Animals"),
            EmojiItem(emoji: "🐈‍⬛", name: "Black Cat", keywords: ["cat", "black", "mèo đen"], category: "Animals"),
            EmojiItem(emoji: "🐓", name: "Rooster", keywords: ["rooster", "gà trống"], category: "Animals"),
            EmojiItem(emoji: "🦃", name: "Turkey", keywords: ["turkey", "gà tây"], category: "Animals"),
            EmojiItem(emoji: "🦚", name: "Peacock", keywords: ["peacock", "công"], category: "Animals"),
            EmojiItem(emoji: "🦜", name: "Parrot", keywords: ["parrot", "vẹt"], category: "Animals"),
            EmojiItem(emoji: "🦢", name: "Swan", keywords: ["swan", "thiên nga"], category: "Animals"),
            EmojiItem(emoji: "🦩", name: "Flamingo", keywords: ["flamingo", "hồng hạc"], category: "Animals"),
            EmojiItem(emoji: "🐁", name: "Mouse", keywords: ["mouse", "chuột"], category: "Animals"),
            EmojiItem(emoji: "🐀", name: "Rat", keywords: ["rat", "chuột"], category: "Animals"),
            EmojiItem(emoji: "🐿️", name: "Chipmunk", keywords: ["chipmunk", "sóc"], category: "Animals"),
            EmojiItem(emoji: "🦔", name: "Hedgehog", keywords: ["hedgehog", "nhím"], category: "Animals"),
            EmojiItem(emoji: "🦇", name: "Bat", keywords: ["bat", "dơi"], category: "Animals"),
            EmojiItem(emoji: "🐻‍❄️", name: "Polar Bear", keywords: ["bear", "polar", "gấu bắc cực"], category: "Animals"),
            EmojiItem(emoji: "🐨", name: "Koala", keywords: ["koala", "gấu túi"], category: "Animals"),
            EmojiItem(emoji: "🐼", name: "Panda", keywords: ["panda", "gấu trúc"], category: "Animals"),
            EmojiItem(emoji: "🦥", name: "Sloth", keywords: ["sloth", "lười"], category: "Animals"),
            EmojiItem(emoji: "🦦", name: "Otter", keywords: ["otter", "rái cá"], category: "Animals"),
            EmojiItem(emoji: "🦨", name: "Skunk", keywords: ["skunk", "chồn hôi"], category: "Animals"),
            EmojiItem(emoji: "🦡", name: "Badger", keywords: ["badger", "lửng"], category: "Animals"),
        ]

        // Food
        let food: [EmojiItem] = [
            EmojiItem(emoji: "🍎", name: "Red Apple", keywords: ["apple", "fruit", "táo"], category: "Food"),
            EmojiItem(emoji: "🍐", name: "Pear", keywords: ["pear", "fruit", "lê"], category: "Food"),
            EmojiItem(emoji: "🍊", name: "Tangerine", keywords: ["orange", "fruit", "cam"], category: "Food"),
            EmojiItem(emoji: "🍋", name: "Lemon", keywords: ["lemon", "fruit", "chanh"], category: "Food"),
            EmojiItem(emoji: "🍌", name: "Banana", keywords: ["banana", "fruit", "chuối"], category: "Food"),
            EmojiItem(emoji: "🍉", name: "Watermelon", keywords: ["watermelon", "fruit", "dưa hấu"], category: "Food"),
            EmojiItem(emoji: "🍇", name: "Grapes", keywords: ["grapes", "fruit", "nho"], category: "Food"),
            EmojiItem(emoji: "🍓", name: "Strawberry", keywords: ["strawberry", "fruit", "dâu"], category: "Food"),
            EmojiItem(emoji: "🫐", name: "Blueberries", keywords: ["blueberry", "fruit", "việt quất"], category: "Food"),
            EmojiItem(emoji: "🍒", name: "Cherries", keywords: ["cherry", "fruit", "anh đào"], category: "Food"),
            EmojiItem(emoji: "🍑", name: "Peach", keywords: ["peach", "fruit", "đào"], category: "Food"),
            EmojiItem(emoji: "🥭", name: "Mango", keywords: ["mango", "fruit", "xoài"], category: "Food"),
            EmojiItem(emoji: "🍍", name: "Pineapple", keywords: ["pineapple", "fruit", "dứa"], category: "Food"),
            EmojiItem(emoji: "🥥", name: "Coconut", keywords: ["coconut", "fruit", "dừa"], category: "Food"),
            EmojiItem(emoji: "🥝", name: "Kiwi Fruit", keywords: ["kiwi", "fruit", "kiwi"], category: "Food"),
            EmojiItem(emoji: "🍅", name: "Tomato", keywords: ["tomato", "vegetable", "cà chua"], category: "Food"),
            EmojiItem(emoji: "🥑", name: "Avocado", keywords: ["avocado", "fruit", "bơ"], category: "Food"),
            EmojiItem(emoji: "🍔", name: "Hamburger", keywords: ["burger", "hamburger", "fast food", "bánh hamburger"], category: "Food"),
            EmojiItem(emoji: "🍕", name: "Pizza", keywords: ["pizza", "italian", "bánh pizza"], category: "Food"),
            EmojiItem(emoji: "🍝", name: "Spaghetti", keywords: ["pasta", "spaghetti", "italian", "mì ý"], category: "Food"),
            EmojiItem(emoji: "🍜", name: "Steaming Bowl", keywords: ["noodles", "ramen", "phở", "mì"], category: "Food"),
            EmojiItem(emoji: "🍲", name: "Pot of Food", keywords: ["stew", "pot", "nấu ăn"], category: "Food"),
            EmojiItem(emoji: "🍛", name: "Curry Rice", keywords: ["curry", "rice", "cơm"], category: "Food"),
            EmojiItem(emoji: "🍣", name: "Sushi", keywords: ["sushi", "japanese", "sushi"], category: "Food"),
            EmojiItem(emoji: "🍱", name: "Bento Box", keywords: ["bento", "japanese", "hộp cơm"], category: "Food"),
            EmojiItem(emoji: "🥟", name: "Dumpling", keywords: ["dumpling", "gyoza", "há cảo"], category: "Food"),
            EmojiItem(emoji: "🍤", name: "Fried Shrimp", keywords: ["shrimp", "tempura", "tôm"], category: "Food"),
            EmojiItem(emoji: "🍙", name: "Rice Ball", keywords: ["onigiri", "rice", "cơm nắm"], category: "Food"),
            EmojiItem(emoji: "🍚", name: "Cooked Rice", keywords: ["rice", "cơm"], category: "Food"),
            EmojiItem(emoji: "🍘", name: "Rice Cracker", keywords: ["cracker", "rice", "bánh gạo"], category: "Food"),
            EmojiItem(emoji: "🍥", name: "Fish Cake", keywords: ["fish cake", "japanese", "chả cá"], category: "Food"),
            EmojiItem(emoji: "🥮", name: "Moon Cake", keywords: ["moon cake", "mid autumn", "bánh trung thu"], category: "Food"),
            EmojiItem(emoji: "🍰", name: "Shortcake", keywords: ["cake", "dessert", "bánh"], category: "Food"),
            EmojiItem(emoji: "🎂", name: "Birthday Cake", keywords: ["birthday", "cake", "sinh nhật"], category: "Food"),
            EmojiItem(emoji: "🧁", name: "Cupcake", keywords: ["cupcake", "muffin", "bánh"], category: "Food"),
            EmojiItem(emoji: "🥧", name: "Pie", keywords: ["pie", "dessert", "bánh pie"], category: "Food"),
            EmojiItem(emoji: "🍫", name: "Chocolate Bar", keywords: ["chocolate", "sweet", "sôcôla"], category: "Food"),
            EmojiItem(emoji: "🍬", name: "Candy", keywords: ["candy", "sweet", "kẹo"], category: "Food"),
            EmojiItem(emoji: "🍭", name: "Lollipop", keywords: ["lollipop", "candy", "kẹo mút"], category: "Food"),
            EmojiItem(emoji: "🍮", name: "Custard", keywords: ["custard", "pudding", "bánh flan"], category: "Food"),
            EmojiItem(emoji: "🍯", name: "Honey Pot", keywords: ["honey", "sweet", "mật ong"], category: "Food"),
            EmojiItem(emoji: "🍼", name: "Baby Bottle", keywords: ["milk", "baby", "sữa"], category: "Food"),
            EmojiItem(emoji: "🥛", name: "Glass of Milk", keywords: ["milk", "drink", "sữa"], category: "Food"),
            EmojiItem(emoji: "☕", name: "Hot Beverage", keywords: ["coffee", "tea", "cà phê", "trà"], category: "Food"),
            EmojiItem(emoji: "🍵", name: "Teacup Without Handle", keywords: ["tea", "green tea", "trà"], category: "Food"),
            EmojiItem(emoji: "🧃", name: "Beverage Box", keywords: ["juice", "drink", "nước ép"], category: "Food"),
            EmojiItem(emoji: "🥤", name: "Cup with Straw", keywords: ["drink", "soda", "nước"], category: "Food"),
            EmojiItem(emoji: "🧋", name: "Bubble Tea", keywords: ["bubble tea", "boba", "trà sữa"], category: "Food"),
            EmojiItem(emoji: "🍺", name: "Beer Mug", keywords: ["beer", "drink", "bia"], category: "Food"),
            EmojiItem(emoji: "🍻", name: "Clinking Beer Mugs", keywords: ["beer", "cheers", "bia"], category: "Food"),
            EmojiItem(emoji: "🍷", name: "Wine Glass", keywords: ["wine", "drink", "rượu vang"], category: "Food"),
            EmojiItem(emoji: "🥂", name: "Clinking Glasses", keywords: ["champagne", "cheers", "chúc mừng"], category: "Food"),
            EmojiItem(emoji: "🍾", name: "Bottle with Popping Cork", keywords: ["champagne", "celebration", "rượu"], category: "Food"),
            EmojiItem(emoji: "🍩", name: "Doughnut", keywords: ["donut", "doughnut", "sweet", "bánh donut"], category: "Food"),
            EmojiItem(emoji: "🍪", name: "Cookie", keywords: ["cookie", "sweet", "bánh quy"], category: "Food"),
            EmojiItem(emoji: "🌰", name: "Chestnut", keywords: ["chestnut", "nut", "hạt dẻ"], category: "Food"),
            EmojiItem(emoji: "🥜", name: "Peanuts", keywords: ["peanut", "nut", "đậu phộng"], category: "Food"),
            EmojiItem(emoji: "🍿", name: "Popcorn", keywords: ["popcorn", "bắp rang"], category: "Food"),
            EmojiItem(emoji: "🥨", name: "Pretzel", keywords: ["pretzel", "bánh quy xoắn"], category: "Food"),
            EmojiItem(emoji: "🥖", name: "Baguette Bread", keywords: ["bread", "baguette", "bánh mì"], category: "Food"),
            EmojiItem(emoji: "🥐", name: "Croissant", keywords: ["croissant", "bread", "bánh sừng bò"], category: "Food"),
            EmojiItem(emoji: "🧀", name: "Cheese Wedge", keywords: ["cheese", "phô mai"], category: "Food"),
            EmojiItem(emoji: "🥚", name: "Egg", keywords: ["egg", "trứng"], category: "Food"),
            EmojiItem(emoji: "🍳", name: "Cooking", keywords: ["egg", "frying", "nấu ăn"], category: "Food"),
            EmojiItem(emoji: "🥓", name: "Bacon", keywords: ["bacon", "thịt xông khói"], category: "Food"),
            EmojiItem(emoji: "🥩", name: "Cut of Meat", keywords: ["meat", "steak", "thịt"], category: "Food"),
            EmojiItem(emoji: "🍗", name: "Poultry Leg", keywords: ["chicken", "leg", "đùi gà"], category: "Food"),
            EmojiItem(emoji: "🍖", name: "Meat on Bone", keywords: ["meat", "bone", "thịt"], category: "Food"),
            EmojiItem(emoji: "🌭", name: "Hot Dog", keywords: ["hotdog", "sausage", "xúc xích"], category: "Food"),
            EmojiItem(emoji: "🥪", name: "Sandwich", keywords: ["sandwich", "bánh sandwich"], category: "Food"),
            EmojiItem(emoji: "🌮", name: "Taco", keywords: ["taco", "mexican", "taco"], category: "Food"),
            EmojiItem(emoji: "🌯", name: "Burrito", keywords: ["burrito", "mexican", "burrito"], category: "Food"),
            EmojiItem(emoji: "🥙", name: "Stuffed Flatbread", keywords: ["falafel", "gyro", "bánh kebab"], category: "Food"),
            EmojiItem(emoji: "🧆", name: "Falafel", keywords: ["falafel", "chickpea", "bánh đậu"], category: "Food"),
            EmojiItem(emoji: "🥗", name: "Green Salad", keywords: ["salad", "healthy", "rau trộn"], category: "Food"),
            EmojiItem(emoji: "🥘", name: "Shallow Pan of Food", keywords: ["paella", "pan", "chảo"], category: "Food"),
            EmojiItem(emoji: "🍿", name: "Popcorn", keywords: ["popcorn", "snack", "bắp rang"], category: "Food"),
            EmojiItem(emoji: "🧈", name: "Butter", keywords: ["butter", "bơ"], category: "Food"),
            EmojiItem(emoji: "🧂", name: "Salt", keywords: ["salt", "muối"], category: "Food"),
            EmojiItem(emoji: "🥫", name: "Canned Food", keywords: ["can", "food", "đồ hộp"], category: "Food"),
            EmojiItem(emoji: "🍱", name: "Bento Box", keywords: ["bento", "japanese", "hộp cơm"], category: "Food"),
            EmojiItem(emoji: "🍿", name: "Popcorn", keywords: ["popcorn", "movie", "bắp rang"], category: "Food"),
            EmojiItem(emoji: "🧊", name: "Ice", keywords: ["ice", "cold", "đá"], category: "Food"),
            EmojiItem(emoji: "🥡", name: "Takeout Box", keywords: ["takeout", "chinese", "hộp đựng"], category: "Food"),
            EmojiItem(emoji: "🥢", name: "Chopsticks", keywords: ["chopsticks", "đũa"], category: "Food"),
            EmojiItem(emoji: "🍽️", name: "Fork and Knife with Plate", keywords: ["plate", "dinner", "đĩa"], category: "Food"),
            EmojiItem(emoji: "🍴", name: "Fork and Knife", keywords: ["fork", "knife", "dao nĩa"], category: "Food"),
            EmojiItem(emoji: "🥄", name: "Spoon", keywords: ["spoon", "thìa"], category: "Food"),
            EmojiItem(emoji: "🔪", name: "Kitchen Knife", keywords: ["knife", "cook", "dao"], category: "Food"),
        ]

        // Nature & Weather
        let nature: [EmojiItem] = [
            EmojiItem(emoji: "🌸", name: "Cherry Blossom", keywords: ["flower", "spring", "hoa anh đào"], category: "Nature"),
            EmojiItem(emoji: "💐", name: "Bouquet", keywords: ["flowers", "bó hoa"], category: "Nature"),
            EmojiItem(emoji: "🌹", name: "Rose", keywords: ["rose", "flower", "hoa hồng"], category: "Nature"),
            EmojiItem(emoji: "🥀", name: "Wilted Flower", keywords: ["wilted", "flower", "hoa úa"], category: "Nature"),
            EmojiItem(emoji: "🌺", name: "Hibiscus", keywords: ["flower", "hibiscus", "hoa dâm bụt"], category: "Nature"),
            EmojiItem(emoji: "🌻", name: "Sunflower", keywords: ["sunflower", "hoa hướng dương"], category: "Nature"),
            EmojiItem(emoji: "🌼", name: "Blossom", keywords: ["flower", "blossom", "hoa"], category: "Nature"),
            EmojiItem(emoji: "🌷", name: "Tulip", keywords: ["tulip", "flower", "hoa tulip"], category: "Nature"),
            EmojiItem(emoji: "🌱", name: "Seedling", keywords: ["plant", "seedling", "mầm"], category: "Nature"),
            EmojiItem(emoji: "🌲", name: "Evergreen Tree", keywords: ["tree", "pine", "cây thông"], category: "Nature"),
            EmojiItem(emoji: "🌳", name: "Deciduous Tree", keywords: ["tree", "cây"], category: "Nature"),
            EmojiItem(emoji: "🌴", name: "Palm Tree", keywords: ["palm", "tree", "cây dừa"], category: "Nature"),
            EmojiItem(emoji: "🌵", name: "Cactus", keywords: ["cactus", "desert", "xương rồng"], category: "Nature"),
            EmojiItem(emoji: "🌾", name: "Sheaf of Rice", keywords: ["rice", "grain", "lúa"], category: "Nature"),
            EmojiItem(emoji: "🌿", name: "Herb", keywords: ["herb", "plant", "cỏ"], category: "Nature"),
            EmojiItem(emoji: "☘️", name: "Shamrock", keywords: ["shamrock", "clover", "cỏ ba lá"], category: "Nature"),
            EmojiItem(emoji: "🍀", name: "Four Leaf Clover", keywords: ["clover", "lucky", "cỏ bốn lá"], category: "Nature"),
            EmojiItem(emoji: "🍁", name: "Maple Leaf", keywords: ["maple", "leaf", "lá phong"], category: "Nature"),
            EmojiItem(emoji: "🍂", name: "Fallen Leaf", keywords: ["leaf", "autumn", "lá rụng"], category: "Nature"),
            EmojiItem(emoji: "🍃", name: "Leaf Fluttering in Wind", keywords: ["leaf", "wind", "lá bay"], category: "Nature"),
            EmojiItem(emoji: "🌍", name: "Globe Showing Europe-Africa", keywords: ["world", "earth", "trái đất"], category: "Nature"),
            EmojiItem(emoji: "🌎", name: "Globe Showing Americas", keywords: ["world", "earth", "trái đất"], category: "Nature"),
            EmojiItem(emoji: "🌏", name: "Globe Showing Asia-Australia", keywords: ["world", "earth", "trái đất"], category: "Nature"),
            EmojiItem(emoji: "🌐", name: "Globe with Meridians", keywords: ["world", "internet", "địa cầu"], category: "Nature"),
            EmojiItem(emoji: "🌑", name: "New Moon", keywords: ["moon", "trăng non"], category: "Nature"),
            EmojiItem(emoji: "🌒", name: "Waxing Crescent Moon", keywords: ["moon", "trăng lưỡi liềm"], category: "Nature"),
            EmojiItem(emoji: "🌓", name: "First Quarter Moon", keywords: ["moon", "trăng"], category: "Nature"),
            EmojiItem(emoji: "🌔", name: "Waxing Gibbous Moon", keywords: ["moon", "trăng"], category: "Nature"),
            EmojiItem(emoji: "🌕", name: "Full Moon", keywords: ["moon", "trăng tròn"], category: "Nature"),
            EmojiItem(emoji: "🌖", name: "Waning Gibbous Moon", keywords: ["moon", "trăng"], category: "Nature"),
            EmojiItem(emoji: "🌗", name: "Last Quarter Moon", keywords: ["moon", "trăng"], category: "Nature"),
            EmojiItem(emoji: "🌘", name: "Waning Crescent Moon", keywords: ["moon", "trăng"], category: "Nature"),
            EmojiItem(emoji: "🌙", name: "Crescent Moon", keywords: ["moon", "night", "trăng khuyết"], category: "Nature"),
            EmojiItem(emoji: "🌚", name: "New Moon Face", keywords: ["moon", "face", "mặt trăng"], category: "Nature"),
            EmojiItem(emoji: "🌛", name: "First Quarter Moon Face", keywords: ["moon", "mặt trăng"], category: "Nature"),
            EmojiItem(emoji: "🌜", name: "Last Quarter Moon Face", keywords: ["moon", "mặt trăng"], category: "Nature"),
            EmojiItem(emoji: "☀️", name: "Sun", keywords: ["sun", "sunny", "mặt trời"], category: "Nature"),
            EmojiItem(emoji: "🌝", name: "Full Moon Face", keywords: ["moon", "mặt trăng"], category: "Nature"),
            EmojiItem(emoji: "🌞", name: "Sun with Face", keywords: ["sun", "mặt trời"], category: "Nature"),
            EmojiItem(emoji: "⭐", name: "Star", keywords: ["star", "ngôi sao"], category: "Nature"),
            EmojiItem(emoji: "🌟", name: "Glowing Star", keywords: ["star", "ngôi sao"], category: "Nature"),
            EmojiItem(emoji: "🌠", name: "Shooting Star", keywords: ["star", "shooting", "sao băng"], category: "Nature"),
            EmojiItem(emoji: "☁️", name: "Cloud", keywords: ["cloud", "đám mây"], category: "Nature"),
            EmojiItem(emoji: "⛅", name: "Sun Behind Cloud", keywords: ["cloud", "sun", "mây"], category: "Nature"),
            EmojiItem(emoji: "⛈️", name: "Cloud with Lightning and Rain", keywords: ["storm", "thunder", "giông"], category: "Nature"),
            EmojiItem(emoji: "🌤️", name: "Sun Behind Small Cloud", keywords: ["sun", "cloud", "nắng"], category: "Nature"),
            EmojiItem(emoji: "🌥️", name: "Sun Behind Large Cloud", keywords: ["cloud", "mây"], category: "Nature"),
            EmojiItem(emoji: "🌦️", name: "Sun Behind Rain Cloud", keywords: ["rain", "sun", "mưa"], category: "Nature"),
            EmojiItem(emoji: "🌧️", name: "Cloud with Rain", keywords: ["rain", "mưa"], category: "Nature"),
            EmojiItem(emoji: "🌨️", name: "Cloud with Snow", keywords: ["snow", "tuyết"], category: "Nature"),
            EmojiItem(emoji: "🌩️", name: "Cloud with Lightning", keywords: ["lightning", "sét"], category: "Nature"),
            EmojiItem(emoji: "🌪️", name: "Tornado", keywords: ["tornado", "lốc xoáy"], category: "Nature"),
            EmojiItem(emoji: "🌫️", name: "Fog", keywords: ["fog", "sương mù"], category: "Nature"),
            EmojiItem(emoji: "🌬️", name: "Wind Face", keywords: ["wind", "gió"], category: "Nature"),
            EmojiItem(emoji: "🌀", name: "Cyclone", keywords: ["cyclone", "hurricane", "bão"], category: "Nature"),
            EmojiItem(emoji: "🌈", name: "Rainbow", keywords: ["rainbow", "cầu vồng"], category: "Nature"),
            EmojiItem(emoji: "⚡", name: "High Voltage", keywords: ["lightning", "sét"], category: "Nature"),
            EmojiItem(emoji: "❄️", name: "Snowflake", keywords: ["snow", "cold", "tuyết"], category: "Nature"),
            EmojiItem(emoji: "☃️", name: "Snowman", keywords: ["snowman", "snow", "người tuyết"], category: "Nature"),
            EmojiItem(emoji: "⛄", name: "Snowman Without Snow", keywords: ["snowman", "người tuyết"], category: "Nature"),
            EmojiItem(emoji: "☄️", name: "Comet", keywords: ["comet", "space", "sao chổi"], category: "Nature"),
            EmojiItem(emoji: "🔥", name: "Fire", keywords: ["fire", "lửa"], category: "Nature"),
            EmojiItem(emoji: "💧", name: "Droplet", keywords: ["water", "drop", "nước"], category: "Nature"),
            EmojiItem(emoji: "🌊", name: "Water Wave", keywords: ["wave", "ocean", "sóng"], category: "Nature"),
        ]

        // Activities
        let activities: [EmojiItem] = [
            EmojiItem(emoji: "⚽", name: "Soccer Ball", keywords: ["soccer", "football", "bóng đá"], category: "Activities"),
            EmojiItem(emoji: "🏀", name: "Basketball", keywords: ["basketball", "bóng rổ"], category: "Activities"),
            EmojiItem(emoji: "🏈", name: "American Football", keywords: ["football", "bóng bầu dục"], category: "Activities"),
            EmojiItem(emoji: "⚾", name: "Baseball", keywords: ["baseball", "bóng chày"], category: "Activities"),
            EmojiItem(emoji: "🥎", name: "Softball", keywords: ["softball", "bóng mềm"], category: "Activities"),
            EmojiItem(emoji: "🎾", name: "Tennis", keywords: ["tennis", "quần vợt"], category: "Activities"),
            EmojiItem(emoji: "🏐", name: "Volleyball", keywords: ["volleyball", "bóng chuyền"], category: "Activities"),
            EmojiItem(emoji: "🏉", name: "Rugby Football", keywords: ["rugby", "bóng bầu dục"], category: "Activities"),
            EmojiItem(emoji: "🥏", name: "Flying Disc", keywords: ["frisbee", "disc", "đĩa bay"], category: "Activities"),
            EmojiItem(emoji: "🎱", name: "Pool 8 Ball", keywords: ["pool", "billiards", "bi-a"], category: "Activities"),
            EmojiItem(emoji: "🏓", name: "Ping Pong", keywords: ["ping pong", "table tennis", "bóng bàn"], category: "Activities"),
            EmojiItem(emoji: "🏸", name: "Badminton", keywords: ["badminton", "cầu lông"], category: "Activities"),
            EmojiItem(emoji: "🏒", name: "Ice Hockey", keywords: ["hockey", "ice", "khúc côn cầu"], category: "Activities"),
            EmojiItem(emoji: "🏑", name: "Field Hockey", keywords: ["hockey", "field", "khúc côn cầu"], category: "Activities"),
            EmojiItem(emoji: "🥅", name: "Goal Net", keywords: ["goal", "net", "khung thành"], category: "Activities"),
            EmojiItem(emoji: "🏹", name: "Bow and Arrow", keywords: ["archery", "bow", "cung tên"], category: "Activities"),
            EmojiItem(emoji: "🎣", name: "Fishing Pole", keywords: ["fishing", "câu cá"], category: "Activities"),
            EmojiItem(emoji: "🥊", name: "Boxing Glove", keywords: ["boxing", "quyền anh"], category: "Activities"),
            EmojiItem(emoji: "🥋", name: "Martial Arts Uniform", keywords: ["judo", "karate", "võ thuật"], category: "Activities"),
            EmojiItem(emoji: "🎯", name: "Direct Hit", keywords: ["target", "bullseye", "bia"], category: "Activities"),
            EmojiItem(emoji: "🎮", name: "Video Game", keywords: ["game", "gaming", "trò chơi"], category: "Activities"),
            EmojiItem(emoji: "🕹️", name: "Joystick", keywords: ["game", "gaming", "tay cầm"], category: "Activities"),
            EmojiItem(emoji: "🎲", name: "Game Die", keywords: ["dice", "game", "xúc xắc"], category: "Activities"),
            EmojiItem(emoji: "🎰", name: "Slot Machine", keywords: ["slot", "casino", "máy đánh bạc"], category: "Activities"),
            EmojiItem(emoji: "🎭", name: "Performing Arts", keywords: ["theater", "drama", "kịch"], category: "Activities"),
            EmojiItem(emoji: "🎨", name: "Artist Palette", keywords: ["art", "paint", "vẽ"], category: "Activities"),
            EmojiItem(emoji: "🎬", name: "Clapper Board", keywords: ["movie", "film", "phim"], category: "Activities"),
            EmojiItem(emoji: "🎤", name: "Microphone", keywords: ["sing", "karaoke", "hát"], category: "Activities"),
            EmojiItem(emoji: "🎧", name: "Headphone", keywords: ["music", "audio", "tai nghe"], category: "Activities"),
            EmojiItem(emoji: "🎼", name: "Musical Score", keywords: ["music", "notes", "nhạc"], category: "Activities"),
            EmojiItem(emoji: "🎹", name: "Musical Keyboard", keywords: ["piano", "keyboard", "đàn"], category: "Activities"),
            EmojiItem(emoji: "🥁", name: "Drum", keywords: ["drum", "music", "trống"], category: "Activities"),
            EmojiItem(emoji: "🎷", name: "Saxophone", keywords: ["saxophone", "jazz", "kèn"], category: "Activities"),
            EmojiItem(emoji: "🎺", name: "Trumpet", keywords: ["trumpet", "music", "kèn"], category: "Activities"),
            EmojiItem(emoji: "🎸", name: "Guitar", keywords: ["guitar", "music", "đàn guitar"], category: "Activities"),
            EmojiItem(emoji: "🎻", name: "Violin", keywords: ["violin", "music", "đàn vĩ cầm"], category: "Activities"),
        ]

        // Travel & Places
        let travel: [EmojiItem] = [
            EmojiItem(emoji: "🚗", name: "Car", keywords: ["car", "automobile", "xe hơi"], category: "Travel"),
            EmojiItem(emoji: "🚕", name: "Taxi", keywords: ["taxi", "cab", "taxi"], category: "Travel"),
            EmojiItem(emoji: "🚙", name: "Sport Utility Vehicle", keywords: ["suv", "car", "xe"], category: "Travel"),
            EmojiItem(emoji: "🚌", name: "Bus", keywords: ["bus", "xe buýt"], category: "Travel"),
            EmojiItem(emoji: "🚎", name: "Trolleybus", keywords: ["trolleybus", "xe điện"], category: "Travel"),
            EmojiItem(emoji: "🏎️", name: "Racing Car", keywords: ["race", "car", "đua xe"], category: "Travel"),
            EmojiItem(emoji: "🚓", name: "Police Car", keywords: ["police", "cop", "cảnh sát"], category: "Travel"),
            EmojiItem(emoji: "🚑", name: "Ambulance", keywords: ["ambulance", "xe cứu thương"], category: "Travel"),
            EmojiItem(emoji: "🚒", name: "Fire Engine", keywords: ["fire", "truck", "cứu hỏa"], category: "Travel"),
            EmojiItem(emoji: "🚐", name: "Minibus", keywords: ["minibus", "van", "xe"], category: "Travel"),
            EmojiItem(emoji: "🚚", name: "Delivery Truck", keywords: ["truck", "delivery", "xe tải"], category: "Travel"),
            EmojiItem(emoji: "🚛", name: "Articulated Lorry", keywords: ["truck", "lorry", "xe container"], category: "Travel"),
            EmojiItem(emoji: "🚜", name: "Tractor", keywords: ["tractor", "farm", "máy cày"], category: "Travel"),
            EmojiItem(emoji: "🏍️", name: "Motorcycle", keywords: ["motorcycle", "bike", "xe máy"], category: "Travel"),
            EmojiItem(emoji: "🛵", name: "Motor Scooter", keywords: ["scooter", "vespa", "xe máy"], category: "Travel"),
            EmojiItem(emoji: "🚲", name: "Bicycle", keywords: ["bike", "bicycle", "xe đạp"], category: "Travel"),
            EmojiItem(emoji: "🛴", name: "Kick Scooter", keywords: ["scooter", "kick", "xe trượt"], category: "Travel"),
            EmojiItem(emoji: "✈️", name: "Airplane", keywords: ["plane", "flight", "máy bay"], category: "Travel"),
            EmojiItem(emoji: "🚁", name: "Helicopter", keywords: ["helicopter", "máy bay trực thăng"], category: "Travel"),
            EmojiItem(emoji: "🚂", name: "Locomotive", keywords: ["train", "tàu hỏa"], category: "Travel"),
            EmojiItem(emoji: "🚆", name: "Train", keywords: ["train", "tàu"], category: "Travel"),
            EmojiItem(emoji: "🚇", name: "Metro", keywords: ["metro", "subway", "tàu điện ngầm"], category: "Travel"),
            EmojiItem(emoji: "🚈", name: "Light Rail", keywords: ["train", "rail", "tàu"], category: "Travel"),
            EmojiItem(emoji: "🚝", name: "Monorail", keywords: ["monorail", "train", "tàu một ray"], category: "Travel"),
            EmojiItem(emoji: "🚅", name: "Bullet Train", keywords: ["bullet", "train", "fast", "tàu cao tốc"], category: "Travel"),
            EmojiItem(emoji: "🚄", name: "High-Speed Train", keywords: ["train", "fast", "tàu cao tốc"], category: "Travel"),
            EmojiItem(emoji: "🚢", name: "Ship", keywords: ["ship", "boat", "tàu thủy"], category: "Travel"),
            EmojiItem(emoji: "⛴️", name: "Ferry", keywords: ["ferry", "boat", "phà"], category: "Travel"),
            EmojiItem(emoji: "🛥️", name: "Motor Boat", keywords: ["boat", "motor", "thuyền máy"], category: "Travel"),
            EmojiItem(emoji: "🚤", name: "Speedboat", keywords: ["boat", "speed", "ca nô"], category: "Travel"),
            EmojiItem(emoji: "⛵", name: "Sailboat", keywords: ["sail", "boat", "thuyền buồm"], category: "Travel"),
            EmojiItem(emoji: "🚀", name: "Rocket", keywords: ["rocket", "space", "tên lửa"], category: "Travel"),
            EmojiItem(emoji: "🛸", name: "Flying Saucer", keywords: ["ufo", "alien", "đĩa bay"], category: "Travel"),
            EmojiItem(emoji: "🏠", name: "House", keywords: ["house", "home", "nhà"], category: "Travel"),
            EmojiItem(emoji: "🏡", name: "House with Garden", keywords: ["house", "garden", "nhà"], category: "Travel"),
            EmojiItem(emoji: "🏢", name: "Office Building", keywords: ["office", "building", "văn phòng"], category: "Travel"),
            EmojiItem(emoji: "🏣", name: "Japanese Post Office", keywords: ["post", "office", "bưu điện"], category: "Travel"),
            EmojiItem(emoji: "🏤", name: "Post Office", keywords: ["post", "office", "bưu điện"], category: "Travel"),
            EmojiItem(emoji: "🏥", name: "Hospital", keywords: ["hospital", "medical", "bệnh viện"], category: "Travel"),
            EmojiItem(emoji: "🏦", name: "Bank", keywords: ["bank", "money", "ngân hàng"], category: "Travel"),
            EmojiItem(emoji: "🏨", name: "Hotel", keywords: ["hotel", "khách sạn"], category: "Travel"),
            EmojiItem(emoji: "🏩", name: "Love Hotel", keywords: ["hotel", "love", "khách sạn"], category: "Travel"),
            EmojiItem(emoji: "🏪", name: "Convenience Store", keywords: ["store", "shop", "cửa hàng"], category: "Travel"),
            EmojiItem(emoji: "🏫", name: "School", keywords: ["school", "trường học"], category: "Travel"),
            EmojiItem(emoji: "🏬", name: "Department Store", keywords: ["store", "shopping", "trung tâm"], category: "Travel"),
            EmojiItem(emoji: "🏭", name: "Factory", keywords: ["factory", "industry", "nhà máy"], category: "Travel"),
            EmojiItem(emoji: "🏯", name: "Japanese Castle", keywords: ["castle", "japanese", "lâu đài"], category: "Travel"),
            EmojiItem(emoji: "🏰", name: "Castle", keywords: ["castle", "lâu đài"], category: "Travel"),
            EmojiItem(emoji: "⛪", name: "Church", keywords: ["church", "religion", "nhà thờ"], category: "Travel"),
            EmojiItem(emoji: "🕌", name: "Mosque", keywords: ["mosque", "islam", "nhà thờ hồi giáo"], category: "Travel"),
            EmojiItem(emoji: "🕍", name: "Synagogue", keywords: ["synagogue", "jewish", "giáo đường"], category: "Travel"),
            EmojiItem(emoji: "⛩️", name: "Shinto Shrine", keywords: ["shrine", "shinto", "đền thờ"], category: "Travel"),
        ]

        // Objects
        let objects: [EmojiItem] = [
            EmojiItem(emoji: "⌚", name: "Watch", keywords: ["watch", "time", "đồng hồ"], category: "Objects"),
            EmojiItem(emoji: "📱", name: "Mobile Phone", keywords: ["phone", "mobile", "điện thoại"], category: "Objects"),
            EmojiItem(emoji: "💻", name: "Laptop", keywords: ["computer", "laptop", "máy tính"], category: "Objects"),
            EmojiItem(emoji: "⌨️", name: "Keyboard", keywords: ["keyboard", "bàn phím"], category: "Objects"),
            EmojiItem(emoji: "🖥️", name: "Desktop Computer", keywords: ["computer", "desktop", "máy tính"], category: "Objects"),
            EmojiItem(emoji: "🖨️", name: "Printer", keywords: ["printer", "máy in"], category: "Objects"),
            EmojiItem(emoji: "🖱️", name: "Computer Mouse", keywords: ["mouse", "computer", "chuột"], category: "Objects"),
            EmojiItem(emoji: "🖲️", name: "Trackball", keywords: ["trackball", "mouse", "chuột"], category: "Objects"),
            EmojiItem(emoji: "💽", name: "Computer Disk", keywords: ["disk", "minidisc", "đĩa"], category: "Objects"),
            EmojiItem(emoji: "💾", name: "Floppy Disk", keywords: ["floppy", "disk", "save", "đĩa mềm"], category: "Objects"),
            EmojiItem(emoji: "💿", name: "Optical Disk", keywords: ["cd", "disk", "đĩa CD"], category: "Objects"),
            EmojiItem(emoji: "📀", name: "DVD", keywords: ["dvd", "disk", "đĩa DVD"], category: "Objects"),
            EmojiItem(emoji: "📷", name: "Camera", keywords: ["camera", "photo", "máy ảnh"], category: "Objects"),
            EmojiItem(emoji: "📹", name: "Video Camera", keywords: ["video", "camera", "máy quay"], category: "Objects"),
            EmojiItem(emoji: "📺", name: "Television", keywords: ["tv", "television", "tivi"], category: "Objects"),
            EmojiItem(emoji: "📻", name: "Radio", keywords: ["radio", "đài"], category: "Objects"),
            EmojiItem(emoji: "📞", name: "Telephone Receiver", keywords: ["phone", "telephone", "điện thoại"], category: "Objects"),
            EmojiItem(emoji: "☎️", name: "Telephone", keywords: ["phone", "telephone", "điện thoại"], category: "Objects"),
            EmojiItem(emoji: "📟", name: "Pager", keywords: ["pager", "máy nhắn tin"], category: "Objects"),
            EmojiItem(emoji: "📠", name: "Fax Machine", keywords: ["fax", "máy fax"], category: "Objects"),
            EmojiItem(emoji: "📡", name: "Satellite Antenna", keywords: ["satellite", "antenna", "vệ tinh"], category: "Objects"),
            EmojiItem(emoji: "🔋", name: "Battery", keywords: ["battery", "power", "pin"], category: "Objects"),
            EmojiItem(emoji: "🔌", name: "Electric Plug", keywords: ["plug", "electric", "phích cắm"], category: "Objects"),
            EmojiItem(emoji: "💡", name: "Light Bulb", keywords: ["light", "idea", "bóng đèn"], category: "Objects"),
            EmojiItem(emoji: "🔦", name: "Flashlight", keywords: ["flashlight", "torch", "đèn pin"], category: "Objects"),
            EmojiItem(emoji: "🕯️", name: "Candle", keywords: ["candle", "light", "nến"], category: "Objects"),
            EmojiItem(emoji: "📚", name: "Books", keywords: ["books", "library", "sách"], category: "Objects"),
            EmojiItem(emoji: "📖", name: "Open Book", keywords: ["book", "open", "sách"], category: "Objects"),
            EmojiItem(emoji: "📝", name: "Memo", keywords: ["memo", "note", "write", "ghi chú"], category: "Objects"),
            EmojiItem(emoji: "✏️", name: "Pencil", keywords: ["pencil", "write", "bút chì"], category: "Objects"),
            EmojiItem(emoji: "✒️", name: "Black Nib", keywords: ["pen", "write", "bút"], category: "Objects"),
            EmojiItem(emoji: "🖊️", name: "Pen", keywords: ["pen", "write", "bút"], category: "Objects"),
            EmojiItem(emoji: "🖋️", name: "Fountain Pen", keywords: ["pen", "fountain", "bút máy"], category: "Objects"),
            EmojiItem(emoji: "🖍️", name: "Crayon", keywords: ["crayon", "draw", "bút sáp"], category: "Objects"),
            EmojiItem(emoji: "📌", name: "Pushpin", keywords: ["pin", "pushpin", "ghim"], category: "Objects"),
            EmojiItem(emoji: "📍", name: "Round Pushpin", keywords: ["pin", "location", "ghim"], category: "Objects"),
            EmojiItem(emoji: "📎", name: "Paperclip", keywords: ["clip", "paperclip", "kẹp giấy"], category: "Objects"),
            EmojiItem(emoji: "🔗", name: "Link", keywords: ["link", "chain", "liên kết"], category: "Objects"),
            EmojiItem(emoji: "📏", name: "Straight Ruler", keywords: ["ruler", "measure", "thước"], category: "Objects"),
            EmojiItem(emoji: "📐", name: "Triangular Ruler", keywords: ["ruler", "triangle", "thước"], category: "Objects"),
            EmojiItem(emoji: "✂️", name: "Scissors", keywords: ["scissors", "cut", "kéo"], category: "Objects"),
            EmojiItem(emoji: "🔒", name: "Locked", keywords: ["lock", "locked", "khóa"], category: "Objects"),
            EmojiItem(emoji: "🔓", name: "Unlocked", keywords: ["unlock", "unlocked", "mở khóa"], category: "Objects"),
            EmojiItem(emoji: "🔑", name: "Key", keywords: ["key", "chìa khóa"], category: "Objects"),
            EmojiItem(emoji: "🔨", name: "Hammer", keywords: ["hammer", "tool", "búa"], category: "Objects"),
            EmojiItem(emoji: "🔧", name: "Wrench", keywords: ["wrench", "tool", "cờ lê"], category: "Objects"),
            EmojiItem(emoji: "🔩", name: "Nut and Bolt", keywords: ["bolt", "nut", "ốc vít"], category: "Objects"),
            EmojiItem(emoji: "⚙️", name: "Gear", keywords: ["gear", "settings", "bánh răng"], category: "Objects"),
            EmojiItem(emoji: "🛠️", name: "Hammer and Wrench", keywords: ["tools", "repair", "công cụ"], category: "Objects"),
            EmojiItem(emoji: "🔬", name: "Microscope", keywords: ["science", "lab", "kính hiển vi"], category: "Objects"),
            EmojiItem(emoji: "🔭", name: "Telescope", keywords: ["space", "astronomy", "kính thiên văn"], category: "Objects"),
            EmojiItem(emoji: "📡", name: "Satellite Antenna", keywords: ["satellite", "vệ tinh"], category: "Objects"),
            EmojiItem(emoji: "💊", name: "Pill", keywords: ["medicine", "drug", "thuốc"], category: "Objects"),
            EmojiItem(emoji: "💉", name: "Syringe", keywords: ["needle", "medicine", "kim tiêm"], category: "Objects"),
            EmojiItem(emoji: "🩹", name: "Adhesive Bandage", keywords: ["bandaid", "bandage", "băng"], category: "Objects"),
            EmojiItem(emoji: "🩺", name: "Stethoscope", keywords: ["doctor", "medical", "ống nghe"], category: "Objects"),
            EmojiItem(emoji: "🚪", name: "Door", keywords: ["door", "cửa"], category: "Objects"),
            EmojiItem(emoji: "🛏️", name: "Bed", keywords: ["bed", "sleep", "giường"], category: "Objects"),
            EmojiItem(emoji: "🛋️", name: "Couch and Lamp", keywords: ["couch", "sofa", "ghế sofa"], category: "Objects"),
            EmojiItem(emoji: "🚽", name: "Toilet", keywords: ["toilet", "bathroom", "nhà vệ sinh"], category: "Objects"),
            EmojiItem(emoji: "🚿", name: "Shower", keywords: ["shower", "bath", "vòi sen"], category: "Objects"),
            EmojiItem(emoji: "🛁", name: "Bathtub", keywords: ["bath", "tub", "bồn tắm"], category: "Objects"),
            EmojiItem(emoji: "🧴", name: "Lotion Bottle", keywords: ["lotion", "bottle", "chai"], category: "Objects"),
            EmojiItem(emoji: "🧷", name: "Safety Pin", keywords: ["pin", "ghim"], category: "Objects"),
            EmojiItem(emoji: "🧹", name: "Broom", keywords: ["broom", "sweep", "chổi"], category: "Objects"),
            EmojiItem(emoji: "🧺", name: "Basket", keywords: ["basket", "giỏ"], category: "Objects"),
            EmojiItem(emoji: "🧻", name: "Roll of Paper", keywords: ["paper", "toilet paper", "giấy"], category: "Objects"),
            EmojiItem(emoji: "🧼", name: "Soap", keywords: ["soap", "xà phòng"], category: "Objects"),
            EmojiItem(emoji: "🧽", name: "Sponge", keywords: ["sponge", "clean", "miếng rửa"], category: "Objects"),
            EmojiItem(emoji: "🧯", name: "Fire Extinguisher", keywords: ["fire", "extinguisher", "bình cứu hỏa"], category: "Objects"),
            EmojiItem(emoji: "🛒", name: "Shopping Cart", keywords: ["cart", "shopping", "xe đẩy"], category: "Objects"),
            EmojiItem(emoji: "🚬", name: "Cigarette", keywords: ["cigarette", "smoke", "thuốc lá"], category: "Objects"),
            EmojiItem(emoji: "⚰️", name: "Coffin", keywords: ["coffin", "death", "quan tài"], category: "Objects"),
            EmojiItem(emoji: "⚱️", name: "Funeral Urn", keywords: ["urn", "death", "bình tro"], category: "Objects"),
            EmojiItem(emoji: "🗿", name: "Moai", keywords: ["moai", "statue", "tượng"], category: "Objects"),
            EmojiItem(emoji: "🪧", name: "Placard", keywords: ["sign", "placard", "biển"], category: "Objects"),
        ]

        // Symbols
        let symbols: [EmojiItem] = [
            EmojiItem(emoji: "⭐", name: "Star", keywords: ["star", "favorite", "ngôi sao"], category: "Symbols"),
            EmojiItem(emoji: "🌟", name: "Glowing Star", keywords: ["star", "glow", "ngôi sao"], category: "Symbols"),
            EmojiItem(emoji: "✨", name: "Sparkles", keywords: ["sparkle", "star", "lấp lánh"], category: "Symbols"),
            EmojiItem(emoji: "⚡", name: "High Voltage", keywords: ["lightning", "fast", "sét"], category: "Symbols"),
            EmojiItem(emoji: "🔥", name: "Fire", keywords: ["fire", "hot", "lửa", "nóng"], category: "Symbols"),
            EmojiItem(emoji: "💥", name: "Collision", keywords: ["boom", "explosion", "nổ"], category: "Symbols"),
            EmojiItem(emoji: "💫", name: "Dizzy", keywords: ["dizzy", "star", "chóng mặt"], category: "Symbols"),
            EmojiItem(emoji: "💦", name: "Sweat Droplets", keywords: ["sweat", "water", "mồ hôi"], category: "Symbols"),
            EmojiItem(emoji: "💨", name: "Dashing Away", keywords: ["dash", "fast", "nhanh"], category: "Symbols"),
            EmojiItem(emoji: "✅", name: "Check Mark Button", keywords: ["check", "yes", "done", "xong"], category: "Symbols"),
            EmojiItem(emoji: "❌", name: "Cross Mark", keywords: ["no", "wrong", "sai"], category: "Symbols"),
            EmojiItem(emoji: "❓", name: "Question Mark", keywords: ["question", "hỏi"], category: "Symbols"),
            EmojiItem(emoji: "❗", name: "Exclamation Mark", keywords: ["exclamation", "warning", "cảnh báo"], category: "Symbols"),
            EmojiItem(emoji: "⚠️", name: "Warning", keywords: ["warning", "caution", "cảnh báo"], category: "Symbols"),
            EmojiItem(emoji: "🎉", name: "Party Popper", keywords: ["party", "celebrate", "tiệc tung"], category: "Symbols"),
            EmojiItem(emoji: "🎊", name: "Confetti Ball", keywords: ["confetti", "celebrate", "lễ hội"], category: "Symbols"),
            EmojiItem(emoji: "🎈", name: "Balloon", keywords: ["balloon", "party", "bóng bay"], category: "Symbols"),
            EmojiItem(emoji: "🎁", name: "Wrapped Gift", keywords: ["gift", "present", "quà"], category: "Symbols"),
            EmojiItem(emoji: "🏆", name: "Trophy", keywords: ["trophy", "win", "cup", "cúp"], category: "Symbols"),
            EmojiItem(emoji: "🥇", name: "1st Place Medal", keywords: ["gold", "first", "medal", "huy chương vàng"], category: "Symbols"),
            EmojiItem(emoji: "🥈", name: "2nd Place Medal", keywords: ["silver", "second", "medal", "huy chương bạc"], category: "Symbols"),
            EmojiItem(emoji: "🥉", name: "3rd Place Medal", keywords: ["bronze", "third", "medal", "huy chương đồng"], category: "Symbols"),
            EmojiItem(emoji: "🎖️", name: "Military Medal", keywords: ["military", "medal", "huy chương"], category: "Symbols"),
            EmojiItem(emoji: "🏅", name: "Sports Medal", keywords: ["sports", "medal", "huy chương"], category: "Symbols"),
            EmojiItem(emoji: "💯", name: "Hundred Points", keywords: ["100", "perfect", "hoàn hảo"], category: "Symbols"),
            EmojiItem(emoji: "🔔", name: "Bell", keywords: ["bell", "notification", "chuông"], category: "Symbols"),
            EmojiItem(emoji: "🔕", name: "Bell with Slash", keywords: ["mute", "silent", "im lặng"], category: "Symbols"),
            EmojiItem(emoji: "🎵", name: "Musical Note", keywords: ["music", "note", "nhạc"], category: "Symbols"),
            EmojiItem(emoji: "🎶", name: "Musical Notes", keywords: ["music", "notes", "nhạc"], category: "Symbols"),
            EmojiItem(emoji: "💬", name: "Speech Balloon", keywords: ["chat", "talk", "nói chuyện"], category: "Symbols"),
            EmojiItem(emoji: "💭", name: "Thought Balloon", keywords: ["think", "thought", "suy nghĩ"], category: "Symbols"),
            EmojiItem(emoji: "💤", name: "Zzz", keywords: ["sleep", "tired", "ngủ"], category: "Symbols"),
            EmojiItem(emoji: "🚫", name: "Prohibited", keywords: ["no", "forbidden", "cấm"], category: "Symbols"),
            EmojiItem(emoji: "♻️", name: "Recycling Symbol", keywords: ["recycle", "green", "tái chế"], category: "Symbols"),
            EmojiItem(emoji: "☮️", name: "Peace Symbol", keywords: ["peace", "hòa bình"], category: "Symbols"),
            EmojiItem(emoji: "☯️", name: "Yin Yang", keywords: ["yin yang", "balance", "âm dương"], category: "Symbols"),
            EmojiItem(emoji: "🆕", name: "NEW Button", keywords: ["new", "mới"], category: "Symbols"),
            EmojiItem(emoji: "🆓", name: "FREE Button", keywords: ["free", "miễn phí"], category: "Symbols"),
            EmojiItem(emoji: "🔝", name: "TOP Arrow", keywords: ["top", "up", "lên trên"], category: "Symbols"),
            EmojiItem(emoji: "🔜", name: "SOON Arrow", keywords: ["soon", "sắp tới"], category: "Symbols"),
            EmojiItem(emoji: "🆒", name: "COOL Button", keywords: ["cool", "ngầu"], category: "Symbols"),
            EmojiItem(emoji: "🆗", name: "OK Button", keywords: ["ok", "okay", "được"], category: "Symbols"),
            EmojiItem(emoji: "🆙", name: "UP! Button", keywords: ["up", "lên"], category: "Symbols"),
            EmojiItem(emoji: "🆚", name: "VS Button", keywords: ["versus", "vs", "đối đầu"], category: "Symbols"),
            EmojiItem(emoji: "🈁", name: "Japanese 'Here' Button", keywords: ["japanese", "here"], category: "Symbols"),
            EmojiItem(emoji: "🈯", name: "Japanese 'Reserved' Button", keywords: ["japanese", "reserved"], category: "Symbols"),
            EmojiItem(emoji: "🈳", name: "Japanese 'Vacancy' Button", keywords: ["japanese", "vacancy"], category: "Symbols"),
            EmojiItem(emoji: "🈵", name: "Japanese 'No Vacancy' Button", keywords: ["japanese", "full"], category: "Symbols"),
            EmojiItem(emoji: "🈴", name: "Japanese 'Passing Grade' Button", keywords: ["japanese", "pass"], category: "Symbols"),
            EmojiItem(emoji: "🈲", name: "Japanese 'Prohibited' Button", keywords: ["japanese", "prohibited"], category: "Symbols"),
            EmojiItem(emoji: "🉐", name: "Japanese 'Bargain' Button", keywords: ["japanese", "bargain"], category: "Symbols"),
            EmojiItem(emoji: "🈹", name: "Japanese 'Discount' Button", keywords: ["japanese", "discount"], category: "Symbols"),
            EmojiItem(emoji: "🈺", name: "Japanese 'Open for Business' Button", keywords: ["japanese", "open"], category: "Symbols"),
            EmojiItem(emoji: "🈶", name: "Japanese 'Not Free of Charge' Button", keywords: ["japanese", "not free"], category: "Symbols"),
            EmojiItem(emoji: "🈚", name: "Japanese 'Free of Charge' Button", keywords: ["japanese", "free"], category: "Symbols"),
            EmojiItem(emoji: "🚻", name: "Restroom", keywords: ["bathroom", "toilet", "restroom", "nhà vệ sinh"], category: "Symbols"),
            EmojiItem(emoji: "🚹", name: "Men's Room", keywords: ["men", "bathroom", "nam"], category: "Symbols"),
            EmojiItem(emoji: "🚺", name: "Women's Room", keywords: ["women", "bathroom", "nữ"], category: "Symbols"),
            EmojiItem(emoji: "🚼", name: "Baby Symbol", keywords: ["baby", "infant", "em bé"], category: "Symbols"),
            EmojiItem(emoji: "🚾", name: "Water Closet", keywords: ["wc", "toilet", "nhà vệ sinh"], category: "Symbols"),
            EmojiItem(emoji: "⚠️", name: "Warning", keywords: ["warning", "caution", "cảnh báo"], category: "Symbols"),
            EmojiItem(emoji: "🚸", name: "Children Crossing", keywords: ["children", "crossing", "trẻ em"], category: "Symbols"),
            EmojiItem(emoji: "⛔", name: "No Entry", keywords: ["no entry", "forbidden", "cấm"], category: "Symbols"),
            EmojiItem(emoji: "🚫", name: "Prohibited", keywords: ["no", "prohibited", "cấm"], category: "Symbols"),
            EmojiItem(emoji: "🚳", name: "No Bicycles", keywords: ["no bikes", "cấm xe đạp"], category: "Symbols"),
            EmojiItem(emoji: "🚭", name: "No Smoking", keywords: ["no smoking", "cấm hút thuốc"], category: "Symbols"),
            EmojiItem(emoji: "🚯", name: "No Littering", keywords: ["no litter", "cấm vứt rác"], category: "Symbols"),
            EmojiItem(emoji: "🚱", name: "Non-Potable Water", keywords: ["no water", "không uống được"], category: "Symbols"),
            EmojiItem(emoji: "🚷", name: "No Pedestrians", keywords: ["no walking", "cấm đi bộ"], category: "Symbols"),
            EmojiItem(emoji: "📵", name: "No Mobile Phones", keywords: ["no phones", "cấm điện thoại"], category: "Symbols"),
            EmojiItem(emoji: "🔞", name: "No One Under Eighteen", keywords: ["18+", "adult", "người lớn"], category: "Symbols"),
            EmojiItem(emoji: "☢️", name: "Radioactive", keywords: ["radioactive", "danger", "phóng xạ"], category: "Symbols"),
            EmojiItem(emoji: "☣️", name: "Biohazard", keywords: ["biohazard", "danger", "sinh học"], category: "Symbols"),
            EmojiItem(emoji: "⬆️", name: "Up Arrow", keywords: ["up", "arrow", "lên"], category: "Symbols"),
            EmojiItem(emoji: "↗️", name: "Up-Right Arrow", keywords: ["arrow", "northeast", "lên phải"], category: "Symbols"),
            EmojiItem(emoji: "➡️", name: "Right Arrow", keywords: ["right", "arrow", "phải"], category: "Symbols"),
            EmojiItem(emoji: "↘️", name: "Down-Right Arrow", keywords: ["arrow", "southeast", "xuống phải"], category: "Symbols"),
            EmojiItem(emoji: "⬇️", name: "Down Arrow", keywords: ["down", "arrow", "xuống"], category: "Symbols"),
            EmojiItem(emoji: "↙️", name: "Down-Left Arrow", keywords: ["arrow", "southwest", "xuống trái"], category: "Symbols"),
            EmojiItem(emoji: "⬅️", name: "Left Arrow", keywords: ["left", "arrow", "trái"], category: "Symbols"),
            EmojiItem(emoji: "↖️", name: "Up-Left Arrow", keywords: ["arrow", "northwest", "lên trái"], category: "Symbols"),
            EmojiItem(emoji: "↕️", name: "Up-Down Arrow", keywords: ["arrow", "vertical", "dọc"], category: "Symbols"),
            EmojiItem(emoji: "↔️", name: "Left-Right Arrow", keywords: ["arrow", "horizontal", "ngang"], category: "Symbols"),
            EmojiItem(emoji: "↩️", name: "Right Arrow Curving Left", keywords: ["arrow", "return", "quay lại"], category: "Symbols"),
            EmojiItem(emoji: "↪️", name: "Left Arrow Curving Right", keywords: ["arrow", "forward", "tiếp"], category: "Symbols"),
            EmojiItem(emoji: "⤴️", name: "Right Arrow Curving Up", keywords: ["arrow", "up", "lên"], category: "Symbols"),
            EmojiItem(emoji: "⤵️", name: "Right Arrow Curving Down", keywords: ["arrow", "down", "xuống"], category: "Symbols"),
            EmojiItem(emoji: "🔃", name: "Clockwise Vertical Arrows", keywords: ["reload", "refresh", "tải lại"], category: "Symbols"),
            EmojiItem(emoji: "🔄", name: "Counterclockwise Arrows Button", keywords: ["reload", "refresh", "tải lại"], category: "Symbols"),
            EmojiItem(emoji: "🔙", name: "BACK Arrow", keywords: ["back", "quay lại"], category: "Symbols"),
            EmojiItem(emoji: "🔚", name: "END Arrow", keywords: ["end", "kết thúc"], category: "Symbols"),
            EmojiItem(emoji: "🔛", name: "ON! Arrow", keywords: ["on", "bật"], category: "Symbols"),
            EmojiItem(emoji: "🔀", name: "Shuffle Tracks Button", keywords: ["shuffle", "random", "ngẫu nhiên"], category: "Symbols"),
            EmojiItem(emoji: "🔁", name: "Repeat Button", keywords: ["repeat", "loop", "lặp lại"], category: "Symbols"),
            EmojiItem(emoji: "🔂", name: "Repeat Single Button", keywords: ["repeat", "one", "lặp một"], category: "Symbols"),
            EmojiItem(emoji: "▶️", name: "Play Button", keywords: ["play", "phát"], category: "Symbols"),
            EmojiItem(emoji: "⏸️", name: "Pause Button", keywords: ["pause", "tạm dừng"], category: "Symbols"),
            EmojiItem(emoji: "⏯️", name: "Play or Pause Button", keywords: ["play", "pause", "phát"], category: "Symbols"),
            EmojiItem(emoji: "⏹️", name: "Stop Button", keywords: ["stop", "dừng"], category: "Symbols"),
            EmojiItem(emoji: "⏺️", name: "Record Button", keywords: ["record", "ghi"], category: "Symbols"),
            EmojiItem(emoji: "⏭️", name: "Next Track Button", keywords: ["next", "tiếp"], category: "Symbols"),
            EmojiItem(emoji: "⏮️", name: "Last Track Button", keywords: ["previous", "trước"], category: "Symbols"),
            EmojiItem(emoji: "⏩", name: "Fast-Forward Button", keywords: ["fast forward", "tua"], category: "Symbols"),
            EmojiItem(emoji: "⏪", name: "Fast Reverse Button", keywords: ["rewind", "tua lại"], category: "Symbols"),
            EmojiItem(emoji: "⏫", name: "Fast Up Button", keywords: ["fast up", "lên nhanh"], category: "Symbols"),
            EmojiItem(emoji: "⏬", name: "Fast Down Button", keywords: ["fast down", "xuống nhanh"], category: "Symbols"),
            EmojiItem(emoji: "◀️", name: "Reverse Button", keywords: ["reverse", "back", "lùi"], category: "Symbols"),
            EmojiItem(emoji: "🔼", name: "Upwards Button", keywords: ["up", "lên"], category: "Symbols"),
            EmojiItem(emoji: "🔽", name: "Downwards Button", keywords: ["down", "xuống"], category: "Symbols"),
            EmojiItem(emoji: "➕", name: "Plus", keywords: ["plus", "add", "cộng"], category: "Symbols"),
            EmojiItem(emoji: "➖", name: "Minus", keywords: ["minus", "subtract", "trừ"], category: "Symbols"),
            EmojiItem(emoji: "✖️", name: "Multiply", keywords: ["multiply", "times", "nhân"], category: "Symbols"),
            EmojiItem(emoji: "➗", name: "Divide", keywords: ["divide", "chia"], category: "Symbols"),
            EmojiItem(emoji: "♾️", name: "Infinity", keywords: ["infinity", "vô hạn"], category: "Symbols"),
            EmojiItem(emoji: "‼️", name: "Double Exclamation Mark", keywords: ["exclamation", "warning"], category: "Symbols"),
            EmojiItem(emoji: "⁉️", name: "Exclamation Question Mark", keywords: ["exclamation", "question"], category: "Symbols"),
            EmojiItem(emoji: "❔", name: "White Question Mark", keywords: ["question", "hỏi"], category: "Symbols"),
            EmojiItem(emoji: "❕", name: "White Exclamation Mark", keywords: ["exclamation", "cảnh báo"], category: "Symbols"),
            EmojiItem(emoji: "〰️", name: "Wavy Dash", keywords: ["wave", "dash"], category: "Symbols"),
            EmojiItem(emoji: "💱", name: "Currency Exchange", keywords: ["currency", "exchange", "tiền tệ"], category: "Symbols"),
            EmojiItem(emoji: "💲", name: "Heavy Dollar Sign", keywords: ["dollar", "money", "đô la"], category: "Symbols"),
            EmojiItem(emoji: "⚕️", name: "Medical Symbol", keywords: ["medical", "health", "y tế"], category: "Symbols"),
            EmojiItem(emoji: "♻️", name: "Recycling Symbol", keywords: ["recycle", "tái chế"], category: "Symbols"),
            EmojiItem(emoji: "⚜️", name: "Fleur-de-lis", keywords: ["fleur", "symbol"], category: "Symbols"),
            EmojiItem(emoji: "🔱", name: "Trident Emblem", keywords: ["trident", "weapon"], category: "Symbols"),
            EmojiItem(emoji: "📛", name: "Name Badge", keywords: ["name", "badge", "thẻ tên"], category: "Symbols"),
            EmojiItem(emoji: "🔰", name: "Japanese Symbol for Beginner", keywords: ["beginner", "japanese", "người mới"], category: "Symbols"),
            EmojiItem(emoji: "⭕", name: "Hollow Red Circle", keywords: ["circle", "o", "vòng tròn"], category: "Symbols"),
            EmojiItem(emoji: "✅", name: "Check Mark Button", keywords: ["check", "done", "xong"], category: "Symbols"),
            EmojiItem(emoji: "☑️", name: "Check Box with Check", keywords: ["checkbox", "checked", "chọn"], category: "Symbols"),
            EmojiItem(emoji: "✔️", name: "Check Mark", keywords: ["check", "done", "dấu tick"], category: "Symbols"),
            EmojiItem(emoji: "❎", name: "Cross Mark Button", keywords: ["x", "cross", "xóa"], category: "Symbols"),
            EmojiItem(emoji: "➰", name: "Curly Loop", keywords: ["loop", "vòng"], category: "Symbols"),
            EmojiItem(emoji: "➿", name: "Double Curly Loop", keywords: ["loop", "double", "vòng đôi"], category: "Symbols"),
            EmojiItem(emoji: "〽️", name: "Part Alternation Mark", keywords: ["mark", "symbol"], category: "Symbols"),
            EmojiItem(emoji: "✳️", name: "Eight-Spoked Asterisk", keywords: ["asterisk", "star", "dấu sao"], category: "Symbols"),
            EmojiItem(emoji: "✴️", name: "Eight-Pointed Star", keywords: ["star", "ngôi sao"], category: "Symbols"),
            EmojiItem(emoji: "❇️", name: "Sparkle", keywords: ["sparkle", "lấp lánh"], category: "Symbols"),
            EmojiItem(emoji: "©️", name: "Copyright", keywords: ["copyright", "bản quyền"], category: "Symbols"),
            EmojiItem(emoji: "®️", name: "Registered", keywords: ["registered", "trademark", "đăng ký"], category: "Symbols"),
            EmojiItem(emoji: "™️", name: "Trade Mark", keywords: ["trademark", "tm", "thương hiệu"], category: "Symbols"),
            EmojiItem(emoji: "#️⃣", name: "Keycap Number Sign", keywords: ["hashtag", "number"], category: "Symbols"),
            EmojiItem(emoji: "*️⃣", name: "Keycap Asterisk", keywords: ["asterisk", "star"], category: "Symbols"),
            EmojiItem(emoji: "0️⃣", name: "Keycap Digit Zero", keywords: ["0", "zero", "số 0"], category: "Symbols"),
            EmojiItem(emoji: "1️⃣", name: "Keycap Digit One", keywords: ["1", "one", "số 1"], category: "Symbols"),
            EmojiItem(emoji: "2️⃣", name: "Keycap Digit Two", keywords: ["2", "two", "số 2"], category: "Symbols"),
            EmojiItem(emoji: "3️⃣", name: "Keycap Digit Three", keywords: ["3", "three", "số 3"], category: "Symbols"),
            EmojiItem(emoji: "4️⃣", name: "Keycap Digit Four", keywords: ["4", "four", "số 4"], category: "Symbols"),
            EmojiItem(emoji: "5️⃣", name: "Keycap Digit Five", keywords: ["5", "five", "số 5"], category: "Symbols"),
            EmojiItem(emoji: "6️⃣", name: "Keycap Digit Six", keywords: ["6", "six", "số 6"], category: "Symbols"),
            EmojiItem(emoji: "7️⃣", name: "Keycap Digit Seven", keywords: ["7", "seven", "số 7"], category: "Symbols"),
            EmojiItem(emoji: "8️⃣", name: "Keycap Digit Eight", keywords: ["8", "eight", "số 8"], category: "Symbols"),
            EmojiItem(emoji: "9️⃣", name: "Keycap Digit Nine", keywords: ["9", "nine", "số 9"], category: "Symbols"),
            EmojiItem(emoji: "🔟", name: "Keycap 10", keywords: ["10", "ten", "số 10"], category: "Symbols"),
            EmojiItem(emoji: "🔠", name: "Input Latin Uppercase", keywords: ["letters", "uppercase", "chữ hoa"], category: "Symbols"),
            EmojiItem(emoji: "🔡", name: "Input Latin Lowercase", keywords: ["letters", "lowercase", "chữ thường"], category: "Symbols"),
            EmojiItem(emoji: "🔢", name: "Input Numbers", keywords: ["numbers", "số"], category: "Symbols"),
            EmojiItem(emoji: "🔣", name: "Input Symbols", keywords: ["symbols", "ký hiệu"], category: "Symbols"),
            EmojiItem(emoji: "🔤", name: "Input Latin Letters", keywords: ["letters", "abc", "chữ cái"], category: "Symbols"),
            EmojiItem(emoji: "🅰️", name: "A Button (Blood Type)", keywords: ["a", "blood type"], category: "Symbols"),
            EmojiItem(emoji: "🆎", name: "AB Button (Blood Type)", keywords: ["ab", "blood type"], category: "Symbols"),
            EmojiItem(emoji: "🅱️", name: "B Button (Blood Type)", keywords: ["b", "blood type"], category: "Symbols"),
            EmojiItem(emoji: "🆑", name: "CL Button", keywords: ["cl", "clear"], category: "Symbols"),
            EmojiItem(emoji: "🅾️", name: "O Button (Blood Type)", keywords: ["o", "blood type"], category: "Symbols"),
            EmojiItem(emoji: "🆘", name: "SOS Button", keywords: ["sos", "help", "cứu"], category: "Symbols"),
            EmojiItem(emoji: "🆔", name: "ID Button", keywords: ["id", "identity"], category: "Symbols"),
            EmojiItem(emoji: "ℹ️", name: "Information", keywords: ["info", "information", "thông tin"], category: "Symbols"),
            EmojiItem(emoji: "Ⓜ️", name: "Circled M", keywords: ["m", "metro"], category: "Symbols"),
            EmojiItem(emoji: "🅿️", name: "P Button", keywords: ["p", "parking", "đỗ xe"], category: "Symbols"),
            EmojiItem(emoji: "🈂️", name: "Japanese 'Service Charge' Button", keywords: ["japanese", "service"], category: "Symbols"),
            EmojiItem(emoji: "🈷️", name: "Japanese 'Monthly Amount' Button", keywords: ["japanese", "monthly"], category: "Symbols"),
            EmojiItem(emoji: "🔶", name: "Large Orange Diamond", keywords: ["diamond", "orange"], category: "Symbols"),
            EmojiItem(emoji: "🔷", name: "Large Blue Diamond", keywords: ["diamond", "blue"], category: "Symbols"),
            EmojiItem(emoji: "🔸", name: "Small Orange Diamond", keywords: ["diamond", "orange"], category: "Symbols"),
            EmojiItem(emoji: "🔹", name: "Small Blue Diamond", keywords: ["diamond", "blue"], category: "Symbols"),
            EmojiItem(emoji: "🔺", name: "Red Triangle Pointed Up", keywords: ["triangle", "red"], category: "Symbols"),
            EmojiItem(emoji: "🔻", name: "Red Triangle Pointed Down", keywords: ["triangle", "red"], category: "Symbols"),
            EmojiItem(emoji: "💠", name: "Diamond with a Dot", keywords: ["diamond", "dot"], category: "Symbols"),
            EmojiItem(emoji: "🔘", name: "Radio Button", keywords: ["radio", "button"], category: "Symbols"),
            EmojiItem(emoji: "🔳", name: "White Square Button", keywords: ["square", "white"], category: "Symbols"),
            EmojiItem(emoji: "🔲", name: "Black Square Button", keywords: ["square", "black"], category: "Symbols"),
        ]

        self.categories = [
            ("Smileys", "😀", smileys),
            ("People", "👋", hands),
            ("Animals", "🐶", animals),
            ("Food", "🍎", food),
            ("Nature", "🌸", nature),
            ("Activities", "⚽", activities),
            ("Travel", "🚗", travel),
            ("Objects", "💻", objects),
            ("Symbols", "⭐", symbols),
        ]
    }

    /// Search emojis by keyword
    func search(_ query: String) -> [EmojiItem] {
        guard !query.isEmpty else { return [] }

        let lowercaseQuery = query.lowercased()
        var results: [EmojiItem] = []

        for (_, _, emojis) in categories {
            for emoji in emojis {
                // Search in name
                if emoji.name.lowercased().contains(lowercaseQuery) {
                    results.append(emoji)
                    continue
                }

                // Search in keywords
                for keyword in emoji.keywords {
                    if keyword.lowercased().contains(lowercaseQuery) {
                        results.append(emoji)
                        break
                    }
                }
            }
        }

        return results
    }

    // MARK: - Recent & Frequently Used Tracking

    private let recentEmojisKey = "com.phtv.recentEmojis"
    private let emojiFrequencyKey = "com.phtv.emojiFrequency"
    private let maxRecentEmojis = 20

    /// Record emoji usage (adds to recent and increments frequency)
    func recordUsage(_ emoji: String) {
        DispatchQueue.main.async {
            // Update recent emojis
            var recent = self.getRecentEmojis()
            // Remove if already exists to avoid duplicates
            recent.removeAll { $0 == emoji }
            // Add to front
            recent.insert(emoji, at: 0)
            // Limit to maxRecentEmojis
            if recent.count > self.maxRecentEmojis {
                recent = Array(recent.prefix(self.maxRecentEmojis))
            }
            UserDefaults.standard.set(recent, forKey: self.recentEmojisKey)

            // Update frequency
            var frequency = self.getEmojiFrequency()
            frequency[emoji, default: 0] += 1
            UserDefaults.standard.set(frequency, forKey: self.emojiFrequencyKey)

            NSLog("[EmojiDatabase] Recorded usage: \(emoji), frequency: \(frequency[emoji] ?? 0)")
        }
    }

    /// Get recent emojis (most recent first) - must be called from main thread
    func getRecentEmojis() -> [String] {
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                return UserDefaults.standard.stringArray(forKey: recentEmojisKey) ?? []
            }
        }
        return UserDefaults.standard.stringArray(forKey: recentEmojisKey) ?? []
    }

    /// Get emoji frequency map - must be called from main thread
    func getEmojiFrequency() -> [String: Int] {
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                return UserDefaults.standard.dictionary(forKey: emojiFrequencyKey) as? [String: Int] ?? [:]
            }
        }
        return UserDefaults.standard.dictionary(forKey: emojiFrequencyKey) as? [String: Int] ?? [:]
    }

    /// Get frequently used emojis (sorted by count)
    func getFrequentlyUsedEmojis(limit: Int = 20) -> [String] {
        let frequency = getEmojiFrequency()
        return frequency.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    /// Get EmojiItem for a given emoji string
    func getEmojiItem(for emoji: String) -> EmojiItem? {
        for (_, _, emojis) in categories {
            if let found = emojis.first(where: { $0.emoji == emoji }) {
                return found
            }
        }
        return nil
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
        self.hasShadow = true

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

    @State private var selectedCategory = -2  // Default to "All" tab
    @Namespace private var categoryNamespace

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
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .opacity(0.7)
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
                            // Scroll to selected category when view appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if selectedCategory == -2 {
                                    scrollProxy.scrollTo(-2, anchor: .leading)
                                }
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
        .background(
            // Glassmorphism background
            ZStack {
                Color(NSColor.windowBackgroundColor)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
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

    private init() {}

    /// Shows the PHTV Picker at current mouse position
    func show() {
        NSLog("[PHTPPicker] Showing PHTV Picker at mouse position")

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

    /// Hides the PHTV Picker
    func hide() {
        NSLog("[PHTPPicker] Hiding PHTV Picker")
        panel?.close()
        panel = nil
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
