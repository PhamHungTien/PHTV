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
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab: SettingsTab = .typing
    @State private var searchText: String = ""

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
                        HStack(spacing: 12) {
                            Image(systemName: tab.iconName)
                                .foregroundStyle(selectedTab == tab ? .white : themeManager.themeColor)
                                .frame(width: 20, alignment: .center)
                            Text(tab.title)
                                .foregroundStyle(selectedTab == tab ? .white : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(themeManager.themeColor.gradient)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTab = tab
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } else {
                    // Search results
                    if filteredSettings.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Không tìm thấy '\(searchText)'")
                                .font(.headline)
                            Text("Thử tìm kiếm với từ khóa khác")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
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
            .tint(themeManager.themeColor)
            .conditionalSearchable(text: $searchText, prompt: "Tìm kiếm cài đặt...")
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
        } detail: {
            detailView
                .environmentObject(appState)
                .environmentObject(themeManager)
                .frame(minWidth: 400, minHeight: 400)
                .modifier(BackgroundExtensionModifier())
        }
        .navigationSplitViewStyle(.balanced)
        .tint(themeManager.themeColor)
        .accentColor(themeManager.themeColor)
        .onAppear {
            // When settings window opens, show dock icon only if setting is enabled
            let appDelegate = NSApp.delegate as? AppDelegate
            NSLog(
                "[SettingsView] onAppear - showIconOnDock: %@",
                appState.showIconOnDock ? "true" : "false")
            if appState.showIconOnDock {
                appDelegate?.showIcon(onDock: true)
            }
        }
        .onDisappear {
            // When settings window closes, always hide dock icon
            let appDelegate = NSApp.delegate as? AppDelegate
            NSLog("[SettingsView] onDisappear - hiding dock icon")
            appDelegate?.showIcon(onDock: false)
        }
        .onChange(of: appState.showIconOnDock) { newValue in
            // When dock icon toggle is changed, update immediately
            let appDelegate = NSApp.delegate as? AppDelegate
            NSLog("[SettingsView] onChange - showIconOnDock changed to %@", newValue ? "true" : "false")
            appDelegate?.showIcon(onDock: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAboutTab"))) { _ in
            selectedTab = .about
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowMacroTab"))) { _ in
            selectedTab = .macro
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .typing:
            TypingSettingsView()
        case .advanced:
            AdvancedSettingsView()
        case .macro:
            MacroSettingsView()
        case .hotkeys:
            HotkeySettingsView()
        case .theme:
            ThemeSettingsView()
        case .system:
            SystemSettingsView()
        case .bugReport:
            BugReportView()
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
        // Typing settings - Input Configuration
        SettingsItem(
            title: "Phương pháp gõ", iconName: "keyboard", tab: .typing,
            keywords: ["telex", "vni", "simple telex", "kiểu gõ", "input method", "cấu hình gõ"]),
        SettingsItem(
            title: "Bảng mã", iconName: "textformat", tab: .typing,
            keywords: ["unicode", "tcvn3", "vni windows", "code table", "codepoint"]),

        // Typing settings - Basic Features
        SettingsItem(
            title: "Kiểm tra chính tả", iconName: "text.badge.checkmark", tab: .typing,
            keywords: ["spell check", "spelling", "lỗi chính tả", "tính năng cơ bản"]),
        SettingsItem(
            title: "Khôi phục phím nếu từ sai", iconName: "arrow.uturn.left.circle.fill", tab: .typing,
            keywords: ["restore", "khôi phục", "ký tự", "từ sai", "invalid word"]),

        // Typing settings - Enhancement Features
        SettingsItem(
            title: "Viết hoa ký tự đầu", iconName: "textformat.abc", tab: .typing,
            keywords: ["capitalize", "uppercase", "hoa", "tự động", "cải thiện gõ"]),
        SettingsItem(
            title: "Phím chuyển thông minh", iconName: "arrow.left.arrow.right", tab: .typing,
            keywords: ["smart switch", "auto switch", "tự động chuyển", "ngữ thông minh"]),
        SettingsItem(
            title: "Đặt dấu oà, uý", iconName: "a.circle.fill", tab: .typing,
            keywords: ["modern orthography", "chính tả hiện đại", "dấu oà", "dấu uý", "quy tắc"]),

        // Advanced settings - Advanced Options
        SettingsItem(
            title: "Phụ âm Z, F, W, J", iconName: "character", tab: .advanced,
            keywords: ["consonant", "phụ âm", "ngoại lai", "z f w j", "tùy chọn nâng cao"]),
        SettingsItem(
            title: "Phụ âm đầu nhanh", iconName: "arrow.right.circle.fill", tab: .advanced,
            keywords: ["quick start consonant", "phụ âm đầu", "nhanh", "gõ tắt"]),
        SettingsItem(
            title: "Phụ âm cuối nhanh", iconName: "arrow.left.circle.fill", tab: .advanced,
            keywords: ["quick end consonant", "phụ âm cuối", "nhanh", "gõ tắt"]),
        SettingsItem(
            title: "Nhớ bảng mã", iconName: "memorychip.fill", tab: .advanced,
            keywords: ["remember code", "bảng mã", "lưu", "nhớ", "khôi phục"]),
        SettingsItem(
            title: "Gửi từng phím", iconName: "keyboard.badge.ellipsis", tab: .advanced,
            keywords: ["send key step by step", "từng ký tự", "ổn định", "chậm"]),
        SettingsItem(
            title: "Ứng dụng gửi từng phím", iconName: "app.badge.fill", tab: .advanced,
            keywords: ["send key apps", "ứng dụng", "từng phím", "app list"]),

        // Advanced settings - Claude Code Fix
        SettingsItem(
            title: "Hỗ trợ gõ tiếng Việt trong Claude Code", iconName: "terminal.fill", tab: .advanced,
            keywords: ["claude", "claude code", "terminal", "cli", "anthropic", "ai", "tiếng việt", "patch", "sửa lỗi", "fix"]),

        // Hotkey settings
        SettingsItem(
            title: "Phím tắt chuyển chế độ", iconName: "command.circle.fill", tab: .hotkeys,
            keywords: ["hotkey", "shortcut", "ctrl", "shift", "option", "command", "chuyển chế độ"]),

        // Theme settings
        SettingsItem(
            title: "Màu chủ đạo", iconName: "paintpalette.fill", tab: .theme,
            keywords: ["theme", "color", "màu sắc", "giao diện", "theme color", "accent", "xanh", "đỏ", "vàng", "tím", "cam", "hồng"]),

        // Macro settings
        SettingsItem(
            title: "Gõ tắt", iconName: "text.badge.plus", tab: .macro,
            keywords: ["macro", "shortcut", "expansion", "viết tắt", "tắc gõ", "enable"]),
        SettingsItem(
            title: "Bật trong chế độ tiếng Anh", iconName: "globe", tab: .macro,
            keywords: ["macro english", "tiếng anh", "gõ tắt", "mode"]),
        SettingsItem(
            title: "Tự động viết hoa ký tự đầu macro", iconName: "textformat.abc", tab: .macro,
            keywords: ["auto caps macro", "viết hoa", "gõ tắt", "ký tự đầu"]),
        SettingsItem(
            title: "Thêm gõ tắt", iconName: "plus.circle.fill", tab: .macro,
            keywords: ["add macro", "thêm", "mới", "tạo"]),
        SettingsItem(
            title: "Xóa gõ tắt", iconName: "minus.circle.fill", tab: .macro,
            keywords: ["delete macro", "xóa", "danh sách"]),
        SettingsItem(
            title: "Chỉnh sửa gõ tắt", iconName: "pencil.circle.fill", tab: .macro,
            keywords: ["edit macro", "chỉnh sửa", "sửa"]),
        SettingsItem(
            title: "Import gõ tắt", iconName: "square.and.arrow.down", tab: .macro,
            keywords: ["import macro", "import", "nhập", "tệp"]),

        // System settings - Startup
        SettingsItem(
            title: "Khởi động cùng hệ thống", iconName: "play.fill", tab: .system,
            keywords: ["startup", "login", "boot", "tự động mở", "khởi động"]),
        SettingsItem(
            title: "Hiển thị icon trên Dock", iconName: "app.fill", tab: .system,
            keywords: ["show icon dock", "icon", "dock", "hiển thị"]),

        // System settings - Excluded Apps
        SettingsItem(
            title: "Loại trừ ứng dụng", iconName: "app.badge.fill", tab: .system,
            keywords: ["exclude", "blacklist", "app", "ứng dụng", "loại trừ"]),

        // System settings - Compatibility
        SettingsItem(
            title: "Sửa lỗi Chromium", iconName: "globe", tab: .system,
            keywords: ["chrome", "edge", "brave", "browser", "trình duyệt", "chromium"]),
        SettingsItem(
            title: "Tương thích bố cục bàn phím", iconName: "keyboard.fill", tab: .system,
            keywords: ["layout", "compatibility", "dvorak", "colemak", "bố cục"]),

        // System settings - Data Management
        SettingsItem(
            title: "Đặt lại cài đặt", iconName: "arrow.counterclockwise.circle.fill", tab: .system,
            keywords: ["reset", "đặt lại", "khôi phục", "mặc định", "quản lý dữ liệu"]),

        // Bug Report
        SettingsItem(
            title: "Báo lỗi", iconName: "ladybug.fill", tab: .bugReport,
            keywords: ["bug", "report", "lỗi", "báo cáo", "feedback", "phản hồi"]),
        SettingsItem(
            title: "Debug logs", iconName: "doc.text.fill", tab: .bugReport,
            keywords: ["log", "debug", "nhật ký", "gỡ lỗi", "thông tin hệ thống"]),
        SettingsItem(
            title: "Gửi báo lỗi", iconName: "paperplane.fill", tab: .bugReport,
            keywords: ["send", "gửi", "email", "github", "issue"]),

        // About
        SettingsItem(
            title: "Thông tin ứng dụng", iconName: "info.circle", tab: .about,
            keywords: ["about", "version", "phiên bản", "info", "thông tin"]),
        SettingsItem(
            title: "Kiểm tra cập nhật", iconName: "arrow.clockwise", tab: .about,
            keywords: ["update", "cập nhật", "new version", "phiên bản mới", "kiểm tra"]),
    ]
}

// MARK: - Settings Tabs
enum SettingsTab: String, CaseIterable, Identifiable {
    case typing = "Bộ gõ"
    case advanced = "Nâng cao"
    case macro = "Gõ tắt"
    case hotkeys = "Phím tắt"
    case theme = "Giao diện"
    case system = "Hệ thống"
    case bugReport = "Báo lỗi"
    case about = "Thông tin"

    nonisolated var id: String { rawValue }
    nonisolated var title: String { rawValue }

    nonisolated var iconName: String {
        switch self {
        case .typing: return "keyboard"
        case .advanced: return "gearshape.2"
        case .macro: return "text.badge.checkmark"
        case .hotkeys: return "command"
        case .theme: return "paintpalette.fill"
        case .system: return "gear"
        case .bugReport: return "ladybug.fill"
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
