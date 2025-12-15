//
//  SettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Main Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .typing
    @State private var searchText: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var initialSettingsHash: Int = 0

    private var filteredSettings: [SettingsItem] {
        if searchText.isEmpty {
            return []
        }
        return SettingsItem.allItems.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText)
                || item.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var searchSuggestions: [SettingsItem] {
        if searchText.isEmpty {
            // Show popular/recent searches when search is active but empty
            return Array(SettingsItem.allItems.prefix(5))
        }
        // Show top 5 matches as suggestions
        return Array(filteredSettings.prefix(5))
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                if searchText.isEmpty {
                    // Normal tab list
                    ForEach(SettingsTab.allCases) { tab in
                        NavigationLink(value: tab) {
                            Label(tab.title, systemImage: tab.iconName)
                        }
                    }
                } else {
                    // Search results
                    if filteredSettings.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(filteredSettings) { item in
                            Button {
                                selectedTab = item.tab
                                searchText = ""
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(item.title, systemImage: item.iconName)
                                    Text(item.tab.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: "Tìm kiếm cài đặt..."
            )
            .searchSuggestions {
                if !searchText.isEmpty {
                    ForEach(searchSuggestions) { item in
                        Button {
                            selectedTab = item.tab
                            searchText = ""
                        } label: {
                            HStack {
                                Image(systemName: item.iconName)
                                    .foregroundStyle(.blue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.body)
                                    Text(item.tab.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } detail: {
            detailView
                .environmentObject(appState)
                .frame(minWidth: 500)
                .toolbar {
                    // Flexible spacer to push items to trailing edge (macOS 26.0+)
                    if #available(macOS 26.0, *) {
                        ToolbarSpacer(.flexible)
                    } else {
                        ToolbarItem(placement: .automatic) {
                            Spacer()
                        }
                    }
                    
                    // Action items group
                    ToolbarItemGroup(placement: .automatic) {
                        if hasUnsavedChanges {
                            Button {
                                restartApp()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Lưu & Khởi động lại")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .help("Lưu thay đổi và khởi động lại ứng dụng")
                        }
                    }
                }
        }
        .navigationSplitViewStyle(.automatic)
        .onAppear {
            // When settings window opens, show dock icon only if setting is enabled
            let appDelegate = NSApp.delegate as? AppDelegate
            NSLog(
                "[SettingsView] onAppear - showIconOnDock: %@",
                appState.showIconOnDock ? "true" : "false")
            if appState.showIconOnDock {
                appDelegate?.showIcon(onDock: true)
            }
            // Capture initial settings state
            initialSettingsHash = calculateSettingsHash()
            hasUnsavedChanges = false
        }
        .onDisappear {
            // When settings window closes, always hide dock icon
            let appDelegate = NSApp.delegate as? AppDelegate
            NSLog("[SettingsView] onDisappear - hiding dock icon")
            appDelegate?.showIcon(onDock: false)
        }
        .onChange(of: appState.showIconOnDock) { oldValue, newValue in
            // When dock icon toggle is changed, update immediately
            let appDelegate = NSApp.delegate as? AppDelegate
            NSLog(
                "[SettingsView] onChange - showIconOnDock changed from %@ to %@",
                oldValue ? "true" : "false", newValue ? "true" : "false")
            appDelegate?.showIcon(onDock: newValue)
        }
        .onChange(of: calculateSettingsHash()) { oldValue, newValue in
            // Track any settings changes
            hasUnsavedChanges = (newValue != initialSettingsHash)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MacrosUpdated"))) { _ in
            // Recalculate hash when macros change
            let newHash = calculateSettingsHash()
            hasUnsavedChanges = (newHash != initialSettingsHash)
        }
    }
    
    private func calculateSettingsHash() -> Int {
        var hasher = Hasher()
        // Input settings
        hasher.combine(appState.inputMethod)
        hasher.combine(appState.codeTable)
        hasher.combine(appState.checkSpelling)
        hasher.combine(appState.useModernOrthography)
        hasher.combine(appState.quickTelex)
        
        // Macro settings
        hasher.combine(appState.useMacro)
        hasher.combine(appState.useMacroInEnglishMode)
        hasher.combine(appState.autoCapsMacro)
        
        // Typing enhancement settings
        hasher.combine(appState.useSmartSwitchKey)
        hasher.combine(appState.upperCaseFirstChar)
        hasher.combine(appState.allowConsonantZFWJ)
        hasher.combine(appState.quickStartConsonant)
        hasher.combine(appState.quickEndConsonant)
        hasher.combine(appState.rememberCode)
        
        // System settings
        hasher.combine(appState.runOnStartup)
        hasher.combine(appState.showIconOnDock)
        hasher.combine(appState.fixChromiumBrowser)
        hasher.combine(appState.performLayoutCompat)
        
        // Hotkey settings
        hasher.combine(appState.switchKeyCode)
        hasher.combine(appState.switchKeyControl)
        hasher.combine(appState.switchKeyOption)
        hasher.combine(appState.switchKeyCommand)
        hasher.combine(appState.switchKeyShift)
        hasher.combine(appState.beepOnModeSwitch)
        
        // Excluded apps
        hasher.combine(appState.excludedApps.map { $0.bundleIdentifier })
        
        // Macros list from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "macroList"),
           let macros = try? JSONDecoder().decode([MacroItem].self, from: data) {
            for macro in macros {
                hasher.combine(macro.shortcut)
                hasher.combine(macro.expansion)
            }
        }
        
        return hasher.finalize()
    }
    
    private func restartApp() {
        // Save all settings first
        appState.saveSettings()
        
        // Get app bundle path
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            NSLog("[Restart] Failed to get bundle path")
            return
        }
        
        // Create a shell script to wait and relaunch
        let script = """
        #!/bin/bash
        sleep 0.5
        open "\(bundlePath)"
        """
        
        // Write script to temporary file
        let tempDir = NSTemporaryDirectory()
        let scriptPath = tempDir + "restart_phtv.sh"
        
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            // Make script executable
            let process1 = Process()
            process1.launchPath = "/bin/chmod"
            process1.arguments = ["+x", scriptPath]
            process1.launch()
            process1.waitUntilExit()
            
            // Launch script in background
            let process2 = Process()
            process2.launchPath = "/bin/bash"
            process2.arguments = [scriptPath]
            process2.launch()
            
            // Terminate current instance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
        } catch {
            NSLog("[Restart] Failed to create restart script: \(error)")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .typing:
            TypingSettingsView()
        case .macro:
            MacroSettingsView()
        case .system:
            SystemSettingsView()
        case .about:
            AboutView()
        }
    }
}

// MARK: - Settings Search Item
struct SettingsItem: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let tab: SettingsTab
    let keywords: [String]

    static let allItems: [SettingsItem] = [
        // Typing settings
        SettingsItem(
            title: "Phương pháp gõ", iconName: "keyboard", tab: .typing,
            keywords: ["telex", "vni", "simple telex", "kiểu gõ", "input method"]),
        SettingsItem(
            title: "Bảng mã", iconName: "textformat", tab: .typing,
            keywords: ["unicode", "tcvn3", "vni windows", "code table"]),
        SettingsItem(
            title: "Kiểm tra chính tả", iconName: "text.badge.checkmark", tab: .typing,
            keywords: ["spell check", "spelling", "lỗi chính tả"]),
        SettingsItem(
            title: "Chính tả hiện đại", iconName: "book.closed.fill", tab: .typing,
            keywords: ["modern", "orthography", "quy tắc"]),
        SettingsItem(
            title: "Quick Telex", iconName: "bolt.fill", tab: .typing,
            keywords: ["quick", "nhanh", "tắt"]),
        SettingsItem(
            title: "Viết hoa ký tự đầu", iconName: "textformat.abc", tab: .typing,
            keywords: ["capitalize", "uppercase", "hoa"]),
        SettingsItem(
            title: "Phím chuyển thông minh", iconName: "arrow.left.arrow.right", tab: .typing,
            keywords: ["smart switch", "auto switch", "tự động"]),
        SettingsItem(
            title: "Phím tắt chuyển chế độ", iconName: "command.circle.fill", tab: .typing,
            keywords: ["hotkey", "shortcut", "ctrl", "shift", "option", "command"]),

        // Macro settings
        SettingsItem(
            title: "Gõ tắt", iconName: "text.badge.plus", tab: .macro,
            keywords: ["macro", "shortcut", "expansion", "viết tắt"]),
        SettingsItem(
            title: "Danh sách gõ tắt", iconName: "list.bullet", tab: .macro,
            keywords: ["macro list", "danh sách"]),

        // System settings
        SettingsItem(
            title: "Khởi động cùng hệ thống", iconName: "play.fill", tab: .system,
            keywords: ["startup", "login", "boot", "tự động mở"]),
        SettingsItem(
            title: "Loại trừ ứng dụng", iconName: "app.badge.fill", tab: .system,
            keywords: ["exclude", "blacklist", "app", "ứng dụng"]),
        SettingsItem(
            title: "Sửa lỗi Chromium", iconName: "globe", tab: .system,
            keywords: ["chrome", "edge", "brave", "browser", "trình duyệt"]),
        SettingsItem(
            title: "Tương thích bố cục bàn phím", iconName: "keyboard.fill", tab: .system,
            keywords: ["layout", "compatibility", "dvorak", "colemak"]),

        // About
        SettingsItem(
            title: "Thông tin ứng dụng", iconName: "info.circle", tab: .about,
            keywords: ["about", "version", "phiên bản", "info"]),
        SettingsItem(
            title: "Kiểm tra cập nhật", iconName: "arrow.clockwise", tab: .about,
            keywords: ["update", "cập nhật", "new version"]),
    ]
}

// MARK: - Settings Tabs
enum SettingsTab: String, CaseIterable, Identifiable {
    case typing = "Bộ gõ"
    case macro = "Gõ tắt"
    case system = "Hệ thống"
    case about = "Thông tin"

    nonisolated var id: String { rawValue }
    nonisolated var title: String { rawValue }

    nonisolated var iconName: String {
        switch self {
        case .typing: return "keyboard"
        case .macro: return "text.badge.checkmark"
        case .system: return "gear"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Data Models
struct MacroItem: Identifiable, Hashable, Codable {
    let id: UUID
    var shortcut: String
    var expansion: String

    init(shortcut: String, expansion: String) {
        self.id = UUID()
        self.shortcut = shortcut
        self.expansion = expansion
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
