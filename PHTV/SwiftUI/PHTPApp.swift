//
//  PHTPApp.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import SwiftUI

@main
struct PHTVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Menu bar extra - using native menu style
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(appState)
        } label: {
            // Use text label that changes based on language mode
            Text(appState.isEnabled ? "Vi" : "En")
                .fontWeight(.medium)
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: appState.isEnabled) { _, _ in
            // Force menu bar refresh when language changes
        }

        // Settings window with hidden title bar
        Window("Cài đặt", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
    }
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

    // Input method settings
    @Published var inputMethod: InputMethod = .telex
    @Published var codeTable: CodeTable = .unicode

    // Features
    @Published var isEnabled: Bool = true
    @Published var checkSpelling: Bool = true
    @Published var useModernOrthography: Bool = true
    @Published var quickTelex: Bool = false
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
    @Published var switchKeyCode: UInt16 = 0xFE  // 0xFE = modifier only mode
    @Published var switchKeyName: String = "Không"  // Display name for the key

    // Excluded apps - auto switch to English when these apps are active
    @Published var excludedApps: [ExcludedApp] = []

    // Accessibility
    @Published var hasAccessibilityPermission: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var isLoadingSettings = false

    private init() {
        isLoadingSettings = true
        loadSettings()
        isLoadingSettings = false
        setupObservers()
        setupNotificationObservers()
        checkAccessibilityPermission()
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

        // Listen for language changes from backend (e.g., excluded apps)
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

        // Load input settings
        checkSpelling = defaults.bool(forKey: "Spelling")
        useModernOrthography = defaults.bool(forKey: "ModernOrthography")
        quickTelex = defaults.bool(forKey: "QuickTelex")
        useMacro = defaults.bool(forKey: "UseMacro")
        useMacroInEnglishMode = defaults.bool(forKey: "UseMacroInEnglishMode")
        autoCapsMacro = defaults.bool(forKey: "vAutoCapsMacro")
        useSmartSwitchKey = defaults.bool(forKey: "UseSmartSwitchKey")
        upperCaseFirstChar = defaults.bool(forKey: "UpperCaseFirstChar")
        allowConsonantZFWJ = defaults.bool(forKey: "vAllowConsonantZFWJ")
        quickStartConsonant = defaults.bool(forKey: "vQuickStartConsonant")
        quickEndConsonant = defaults.bool(forKey: "vQuickEndConsonant")
        rememberCode = defaults.bool(forKey: "vRememberCode")

        // Load excluded apps
        if let data = defaults.data(forKey: "ExcludedApps"),
            let apps = try? JSONDecoder().decode([ExcludedApp].self, from: data)
        {
            excludedApps = apps
        }
    }

    // MARK: - Hotkey Encoding/Decoding

    /// Decode vSwitchKeyStatus from backend format
    /// Format: first 8 bits = keycode, bit 8 = Control, bit 9 = Option, bit 10 = Command
    private func decodeSwitchKeyStatus(_ status: Int) {
        switchKeyCode = UInt16(status & 0xFF)
        switchKeyControl = (status & 0x100) != 0
        switchKeyOption = (status & 0x200) != 0
        switchKeyCommand = (status & 0x400) != 0
        switchKeyShift = (status & 0x800) != 0
        switchKeyName = keyCodeToName(switchKeyCode)
    }

    /// Encode hotkey settings to backend vSwitchKeyStatus format
    func encodeSwitchKeyStatus() -> Int {
        var status = Int(switchKeyCode)
        if switchKeyControl { status |= 0x100 }
        if switchKeyOption { status |= 0x200 }
        if switchKeyCommand { status |= 0x400 }
        if switchKeyShift { status |= 0x800 }
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

        // Save input settings
        defaults.set(checkSpelling, forKey: "Spelling")
        defaults.set(useModernOrthography, forKey: "ModernOrthography")
        defaults.set(quickTelex, forKey: "QuickTelex")
        defaults.set(useMacro, forKey: "UseMacro")
        defaults.set(useMacroInEnglishMode, forKey: "UseMacroInEnglishMode")
        defaults.set(autoCapsMacro, forKey: "vAutoCapsMacro")
        defaults.set(useSmartSwitchKey, forKey: "UseSmartSwitchKey")
        defaults.set(upperCaseFirstChar, forKey: "UpperCaseFirstChar")
        defaults.set(allowConsonantZFWJ, forKey: "vAllowConsonantZFWJ")
        defaults.set(quickStartConsonant, forKey: "vQuickStartConsonant")
        defaults.set(quickEndConsonant, forKey: "vQuickEndConsonant")
        defaults.set(rememberCode, forKey: "vRememberCode")

        // Save excluded apps
        if let data = try? JSONEncoder().encode(excludedApps) {
            defaults.set(data, forKey: "ExcludedApps")
        }

        defaults.synchronize()

        // Notify Objective-C backend
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
            // Notify backend
            NotificationCenter.default.post(
                name: NSNotification.Name("ExcludedAppsChanged"), object: nil)
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

        // Observer for other settings that need to save
        // Combine all settings into single publisher for efficient batching
        Publishers.Merge8(
            $checkSpelling,
            $useModernOrthography,
            $quickTelex,
            $useMacro,
            $useMacroInEnglishMode,
            $autoCapsMacro,
            $useSmartSwitchKey,
            $upperCaseFirstChar
        )
        .merge(
            with:
                Publishers.Merge4(
                    $allowConsonantZFWJ,
                    $quickStartConsonant,
                    $quickEndConsonant,
                    $rememberCode
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
            // Let UserDefaults auto-save periodically instead of immediate sync
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
        Publishers.Merge5(
            $switchKeyCode.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyCommand.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyOption.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyControl.map { _ in () }.eraseToAnyPublisher(),
            $switchKeyShift.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self = self, !self.isLoadingSettings else { return }
            let switchKeyStatus = self.encodeSwitchKeyStatus()
            UserDefaults.standard.set(switchKeyStatus, forKey: "SwitchKeyStatus")
            // Notify backend about hotkey change
            NotificationCenter.default.post(
                name: NSNotification.Name("HotkeyChanged"), object: NSNumber(value: switchKeyStatus)
            )
        }.store(in: &cancellables)
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
