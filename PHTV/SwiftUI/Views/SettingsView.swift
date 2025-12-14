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

    private var filteredSettings: [SettingsItem] {
        if searchText.isEmpty {
            return []
        }
        return SettingsItem.allItems.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText)
                || item.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
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
            .searchable(text: $searchText, placement: .sidebar, prompt: "Tìm kiếm cài đặt")
        } detail: {
            detailView
                .environmentObject(appState)
                .frame(minWidth: 500)
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
