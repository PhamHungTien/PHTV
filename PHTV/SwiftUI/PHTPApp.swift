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
import Combine
import ServiceManagement
import SwiftUI

@main
struct PHTVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Menu bar extra - using native menu style
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(appState)
                .tint(themeManager.themeColor)
        } label: {
            // Use app icon (template); add slash when in English mode
            let size = CGFloat(appState.menuBarIconSize)
            Image(nsImage: makeMenuBarIconImage(size: size, slashed: !appState.isEnabled))
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: appState.isEnabled) { _, _ in
            // Force menu bar refresh when language changes
        }

        // Settings window with hidden title bar
        Window("Cài đặt", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .tint(themeManager.themeColor)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 650)
        .windowResizability(.contentSize)
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
private func makeMenuBarIconImage(size: CGFloat, slashed: Bool) -> NSImage {
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
        let useVietnameseIcon = AppState.shared.useVietnameseMenubarIcon
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

@MainActor
func openSettingsWindow(with appState: AppState) {
    // Check if settings window already exists
    for window in NSApp.windows {
        if window.identifier?.rawValue == "settings" || window.title == "Cài đặt" {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
    }

    // Open using SwiftUI Window Scene
    if let url = URL(string: "phtv://settings") {
        NSWorkspace.shared.open(url)
    } else {
        // Fallback: Create window manually with hidden title bar
        let settingsView = SettingsView().environmentObject(appState)
        let hostingController = NSHostingController(rootView: settingsView)

        let settingsWindow = NSWindow(contentViewController: hostingController)
        settingsWindow.identifier = NSUserInterfaceItemIdentifier("settings")
        settingsWindow.styleMask = [
            .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
        ]
        settingsWindow.titlebarAppearsTransparent = true
        settingsWindow.titleVisibility = .hidden
        settingsWindow.isMovableByWindowBackground = true
        settingsWindow.title = "Cài đặt"
        settingsWindow.setContentSize(NSSize(width: 850, height: 600))
        settingsWindow.minSize = NSSize(width: 700, height: 500)
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
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
    @Published var useSmartSwitchKey: Bool = true
    @Published var upperCaseFirstChar: Bool = false
    @Published var allowConsonantZFWJ: Bool = false
    @Published var quickStartConsonant: Bool = false
    @Published var quickEndConsonant: Bool = false
    @Published var rememberCode: Bool = true

    // System settings
    @Published var runOnStartup: Bool = false
    @Published var fixChromiumBrowser: Bool = false
    @Published var performLayoutCompat: Bool = false
    @Published var showIconOnDock: Bool = false

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

        // Listen for language changes from backend (e.g., hotkey)
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

                    // Play beep when hotkey changes mode (if enabled)
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
        useSmartSwitchKey = defaults.bool(forKey: "UseSmartSwitchKey")
        upperCaseFirstChar = defaults.bool(forKey: "UpperCaseFirstChar")
        allowConsonantZFWJ = defaults.bool(forKey: "vAllowConsonantZFWJ")
        quickStartConsonant = defaults.bool(forKey: "vQuickStartConsonant")
        quickEndConsonant = defaults.bool(forKey: "vQuickEndConsonant")
        rememberCode = defaults.bool(forKey: "vRememberCode")

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
        defaults.set(useSmartSwitchKey, forKey: "UseSmartSwitchKey")
        defaults.set(upperCaseFirstChar, forKey: "UpperCaseFirstChar")
        defaults.set(allowConsonantZFWJ, forKey: "vAllowConsonantZFWJ")
        defaults.set(quickStartConsonant, forKey: "vQuickStartConsonant")
        defaults.set(quickEndConsonant, forKey: "vQuickEndConsonant")
        defaults.set(rememberCode, forKey: "vRememberCode")

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
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in
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

        Publishers.Merge(
            $fixChromiumBrowser,
            $performLayoutCompat
        )
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

        runOnStartup = false
        fixChromiumBrowser = false
        performLayoutCompat = false
        showIconOnDock = false

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

