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
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var windowOpener = SettingsWindowOpener.shared

    init() {
        NSLog("PHTV-APP-INIT-START")

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
                .tint(themeManager.themeColor)
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
                .environmentObject(themeManager)
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
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack(alignment: .top) {
            SettingsView()
                .tint(themeManager.themeColor)

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
                window.makeKeyAndOrderFront(nil)
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
    @Published var emojiHotkeyKeyCode: UInt16 = 41  // ; key (semicolon) default

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
        setupObservers()
        setupNotificationObservers()
        setupExternalSettingsObserver()
        checkAccessibilityPermission()
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
        emojiHotkeyKeyCode = savedKeyCode > 0 ? UInt16(savedKeyCode) : 41  // Default: semicolon

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
            let appDelegate = NSApp.delegate as? AppDelegate
            // Update immediately without debounce
            appDelegate?.setRunOnStartup(value)
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

/// Singleton manager for emoji picker hotkey
/// Monitors global keyboard events and triggers Character Palette when hotkey is pressed
final class EmojiHotkeyManager: ObservableObject, @unchecked Sendable {

    static let shared = EmojiHotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isEnabled: Bool = false
    private var modifiers: NSEvent.ModifierFlags = .command
    private var keyCode: UInt16 = 41  // ; key (semicolon) default

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
            NSLog("LOCAL-MONITOR-FIRED")
            if let consumed = self?.handleKeyEvent(event), consumed {
                return nil
            }
            return event
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

        NSLog("HANDLE-KEY-MATCH! Opening emoji picker")
        openEmojiPicker()
        return true
    }
    
    private func openEmojiPicker() {
        NSLog("[EmojiHotkey] Opening custom emoji picker...")

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


// MARK: - Custom Emoji Picker

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
        ]

        // Hands & Body
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
        ]

        // Hearts
        let hearts: [EmojiItem] = [
            EmojiItem(emoji: "❤️", name: "Red Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "🧡", name: "Orange Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "💛", name: "Yellow Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "💚", name: "Green Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "💙", name: "Blue Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "💜", name: "Purple Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "🖤", name: "Black Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "🤍", name: "White Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "🤎", name: "Brown Heart", keywords: ["love", "heart", "yêu", "tim"], category: "Hearts"),
            EmojiItem(emoji: "💔", name: "Broken Heart", keywords: ["broken", "heart", "heartbreak", "tan vỡ"], category: "Hearts"),
            EmojiItem(emoji: "❤️‍🔥", name: "Heart on Fire", keywords: ["love", "fire", "yêu", "lửa"], category: "Hearts"),
            EmojiItem(emoji: "❤️‍🩹", name: "Mending Heart", keywords: ["healing", "heart", "lành"], category: "Hearts"),
            EmojiItem(emoji: "💕", name: "Two Hearts", keywords: ["love", "hearts", "yêu"], category: "Hearts"),
            EmojiItem(emoji: "💞", name: "Revolving Hearts", keywords: ["love", "hearts", "yêu"], category: "Hearts"),
            EmojiItem(emoji: "💓", name: "Beating Heart", keywords: ["love", "heartbeat", "yêu", "đập"], category: "Hearts"),
            EmojiItem(emoji: "💗", name: "Growing Heart", keywords: ["love", "growing", "yêu"], category: "Hearts"),
            EmojiItem(emoji: "💖", name: "Sparkling Heart", keywords: ["love", "sparkle", "yêu", "lấp lánh"], category: "Hearts"),
            EmojiItem(emoji: "💘", name: "Heart with Arrow", keywords: ["love", "cupid", "yêu"], category: "Hearts"),
            EmojiItem(emoji: "💝", name: "Heart with Ribbon", keywords: ["love", "gift", "yêu", "quà"], category: "Hearts"),
            EmojiItem(emoji: "💟", name: "Heart Decoration", keywords: ["love", "heart", "yêu"], category: "Hearts"),
        ]

        // Animals
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
        ]

        self.categories = [
            ("Smileys", "😀", smileys),
            ("Hands", "👋", hands),
            ("Hearts", "❤️", hearts),
            ("Animals", "🐶", animals),
            ("Food", "🍎", food),
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
            styleMask: [.nonactivatingPanel, .titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        // Panel behavior
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Visual styling
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
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


/// Emoji picker view with grid layout
struct EmojiPickerView: View {
    var onEmojiSelected: (String) -> Void
    var onClose: (() -> Void)?

    @State private var selectedCategory = 0 // Start with first category (Smileys) instead of Recent
    @State private var searchText = ""

    // Access emoji database
    private let database = EmojiDatabase.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Emoji Picker")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    onClose?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Đóng (ESC)")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Tìm emoji...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Recent tab
                    Button(action: { selectedCategory = -1 }) {
                        VStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 16))
                            Text("Gần đây")
                                .font(.system(size: 8))
                        }
                        .frame(width: 52, height: 32)
                        .background(selectedCategory == -1 ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Emoji gần đây")

                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 4)

                    // Category tabs
                    ForEach(0..<database.categories.count, id: \.self) { index in
                        Button(action: { selectedCategory = index }) {
                            Text(database.categories[index].icon)
                                .font(.system(size: 20))
                                .frame(width: 32, height: 32)
                                .background(selectedCategory == index ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help(database.categories[index].name)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 8)

            Divider()

            // Emoji grid
            ScrollView {
                let emojis = filteredEmojis
                if emojis.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: selectedCategory == -1 ? "clock" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(selectedCategory == -1 ? "Chưa có emoji gần đây" : "Không tìm thấy")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if selectedCategory == -1 {
                            Text("Emoji bạn sử dụng sẽ hiển thị ở đây")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                        ForEach(emojis) { emojiItem in
                            Button(action: {
                                onEmojiSelected(emojiItem.emoji)
                            }) {
                                Text(emojiItem.emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 36, height: 36)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help(emojiItem.name)
                        }
                    }
                    .padding(12)
                }
            }
            .frame(height: 280)
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }

    private var filteredEmojis: [EmojiItem] {
        if !searchText.isEmpty {
            // Search with keywords
            return database.search(searchText)
        } else if selectedCategory == -1 {
            // Recent tab - show recently used emojis
            let recentEmojis = database.getRecentEmojis()
            return recentEmojis.compactMap { database.getEmojiItem(for: $0) }
        } else if selectedCategory >= 0 && selectedCategory < database.categories.count {
            // Show current category (with bounds check)
            return database.categories[selectedCategory].emojis
        } else {
            // Invalid category - return empty (shouldn't happen)
            NSLog("[EmojiPicker] WARNING: Invalid selectedCategory: \(selectedCategory)")
            return []
        }
    }
}


/// Manager for emoji picker floating panel
@MainActor
class EmojiPickerManager {
    static let shared = EmojiPickerManager()

    private var panel: FloatingPanel<EmojiPickerView>?

    private init() {}

    /// Shows the emoji picker at current mouse position
    func show() {
        NSLog("[EmojiPicker] Showing emoji picker at mouse position")

        // Close existing panel if any
        panel?.close()

        // Create new panel with emoji picker view
        let emojiPickerView = EmojiPickerView(
            onEmojiSelected: { [weak self] emoji in
                self?.handleEmojiSelected(emoji)
            },
            onClose: { [weak self] in
                self?.hide()
            }
        )

        let contentRect = NSRect(x: 0, y: 0, width: 320, height: 420)
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

    /// Hides the emoji picker
    func hide() {
        NSLog("[EmojiPicker] Hiding emoji picker")
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
