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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowConvertToolSheet"))) { _ in
            // Switch to System tab first, then SystemSettingsView will show the sheet
            if selectedTab != .system {
                selectedTab = .system
                // Post notification for SystemSettingsView after it's mounted
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenConvertToolSheet"), object: nil)
                }
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .typing:
            TypingSettingsView()
        case .hotkeys:
            HotkeySettingsView()
        case .macro:
            MacroSettingsView()
        case .dictionary:
            CustomDictionaryView()
        case .apps:
            AppsSettingsView()
        case .compatibility:
            CompatibilitySettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .system:
            SystemSettingsView()
        case .stats:
            TypingStatsView()
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
        // ═══════════════════════════════════════════
        // MARK: - Bộ gõ (Typing)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Phương pháp gõ", iconName: "keyboard", tab: .typing,
            keywords: ["telex", "vni", "simple telex", "kiểu gõ", "input method", "cấu hình gõ"]),
        SettingsItem(
            title: "Bảng mã", iconName: "textformat", tab: .typing,
            keywords: ["unicode", "tcvn3", "vni windows", "code table", "codepoint"]),
        SettingsItem(
            title: "Kiểm tra chính tả", iconName: "text.badge.checkmark", tab: .typing,
            keywords: ["spell check", "spelling", "lỗi chính tả", "tính năng cơ bản"]),
        SettingsItem(
            title: "Khôi phục phím nếu từ sai", iconName: "arrow.uturn.left.circle.fill", tab: .typing,
            keywords: ["restore", "khôi phục", "ký tự", "từ sai", "invalid word"]),
        SettingsItem(
            title: "Tự động nhận diện từ tiếng Anh", iconName: "textformat.abc.dottedunderline", tab: .typing,
            keywords: ["auto restore english", "tiếng anh", "english word", "terminal", "tẻminal"]),
        SettingsItem(
            title: "Phím khôi phục ký tự gốc", iconName: "arrow.uturn.backward.circle.fill", tab: .typing,
            keywords: ["restore key", "esc", "escape", "option", "control", "khôi phục", "ký tự gốc"]),
        SettingsItem(
            title: "Viết hoa ký tự đầu", iconName: "textformat.abc", tab: .typing,
            keywords: ["capitalize", "uppercase", "hoa", "tự động", "cải thiện gõ"]),
        SettingsItem(
            title: "Đặt dấu oà, uý", iconName: "a.circle.fill", tab: .typing,
            keywords: ["modern orthography", "chính tả hiện đại", "dấu oà", "dấu uý", "quy tắc"]),
        SettingsItem(
            title: "Gõ nhanh (Quick Telex)", iconName: "hare.fill", tab: .typing,
            keywords: ["quick telex", "gõ nhanh", "cc", "gg", "kk", "nn", "qq", "pp", "tt"]),

        SettingsItem(
            title: "Phụ âm Z, F, W, J", iconName: "character", tab: .typing,
            keywords: ["consonant", "phụ âm", "ngoại lai", "z f w j", "phụ âm nâng cao"]),
        SettingsItem(
            title: "Phụ âm đầu nhanh", iconName: "arrow.right.circle.fill", tab: .typing,
            keywords: ["quick start consonant", "phụ âm đầu", "nhanh", "f", "j", "w", "ph", "gi", "qu"]),
        SettingsItem(
            title: "Phụ âm cuối nhanh", iconName: "arrow.left.circle.fill", tab: .typing,
            keywords: ["quick end consonant", "phụ âm cuối", "nhanh", "g", "h", "k", "ng", "nh", "ch"]),

        // ═══════════════════════════════════════════
        // MARK: - Gõ tắt (Macro)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Bật gõ tắt", iconName: "text.badge.plus", tab: .macro,
            keywords: ["macro", "shortcut", "expansion", "viết tắt", "gõ tắt", "enable", "bật"]),
        SettingsItem(
            title: "Gõ tắt trong chế độ tiếng Anh", iconName: "globe", tab: .macro,
            keywords: ["macro english", "tiếng anh", "gõ tắt", "mode", "chế độ"]),
        SettingsItem(
            title: "Tự động viết hoa macro", iconName: "textformat.abc", tab: .macro,
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
            title: "Import/Export gõ tắt", iconName: "square.and.arrow.down", tab: .macro,
            keywords: ["import macro", "export", "import", "nhập", "xuất", "tệp", "file"]),
        SettingsItem(
            title: "Danh mục gõ tắt", iconName: "folder.fill", tab: .macro,
            keywords: ["category", "danh mục", "nhóm", "phân loại", "folder"]),
        SettingsItem(
            title: "Text Snippets (Đoạn văn động)", iconName: "doc.text.fill", tab: .macro,
            keywords: ["snippet", "date", "time", "clipboard", "ngày", "giờ", "động", "tự động", "counter", "random"]),

        // ═══════════════════════════════════════════
        // MARK: - Từ điển (Dictionary)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Từ điển tùy chỉnh", iconName: "character.book.closed", tab: .dictionary,
            keywords: ["dictionary", "custom", "từ điển", "tùy chỉnh", "tiếng anh", "tiếng việt"]),
        SettingsItem(
            title: "Thêm từ tiếng Anh", iconName: "textformat.abc", tab: .dictionary,
            keywords: ["english", "tiếng anh", "thêm", "add", "từ", "word"]),
        SettingsItem(
            title: "Thêm từ tiếng Việt", iconName: "character.textbox", tab: .dictionary,
            keywords: ["vietnamese", "tiếng việt", "thêm", "add", "từ", "word"]),
        SettingsItem(
            title: "Import/Export từ điển", iconName: "square.and.arrow.down", tab: .dictionary,
            keywords: ["import", "export", "nhập", "xuất", "từ điển", "dictionary", "file"]),

        // ═══════════════════════════════════════════
        // MARK: - Thống kê (Stats)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Bật thống kê gõ phím", iconName: "chart.bar.fill", tab: .stats,
            keywords: ["enable", "bật", "tắt", "statistics", "thống kê", "gõ phím", "typing", "stats"]),
        SettingsItem(
            title: "Thống kê gõ phím", iconName: "chart.bar.fill", tab: .stats,
            keywords: ["statistics", "thống kê", "gõ phím", "typing", "stats", "biểu đồ"]),
        SettingsItem(
            title: "Số từ đã gõ", iconName: "text.word.spacing", tab: .stats,
            keywords: ["words", "từ", "đếm", "count", "tổng"]),
        SettingsItem(
            title: "Thời gian gõ", iconName: "clock.fill", tab: .stats,
            keywords: ["time", "thời gian", "duration", "phút", "giờ"]),
        SettingsItem(
            title: "Biểu đồ hoạt động", iconName: "chart.line.uptrend.xyaxis", tab: .stats,
            keywords: ["chart", "biểu đồ", "graph", "activity", "hoạt động"]),
        SettingsItem(
            title: "Phân bố ngôn ngữ", iconName: "globe", tab: .stats,
            keywords: ["language", "ngôn ngữ", "tiếng việt", "tiếng anh", "phân bố", "tỷ lệ"]),
        SettingsItem(
            title: "Xóa thống kê", iconName: "trash.fill", tab: .stats,
            keywords: ["reset", "xóa", "làm mới", "delete", "clear"]),

        // ═══════════════════════════════════════════
        // MARK: - Phím tắt (Hotkeys)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Phím tắt chuyển chế độ", iconName: "command.circle.fill", tab: .hotkeys,
            keywords: ["hotkey", "shortcut", "ctrl", "shift", "option", "command", "chuyển chế độ", "tiếng việt", "tiếng anh"]),
        SettingsItem(
            title: "Phím tạm dừng", iconName: "pause.circle.fill", tab: .hotkeys,
            keywords: ["pause", "tạm dừng", "giữ phím", "option", "control"]),

        // ═══════════════════════════════════════════
        // MARK: - Ứng dụng (Apps)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Phím chuyển thông minh", iconName: "arrow.left.arrow.right", tab: .apps,
            keywords: ["smart switch", "auto switch", "tự động chuyển", "ngữ thông minh"]),
        SettingsItem(
            title: "Nhớ bảng mã theo ứng dụng", iconName: "memorychip.fill", tab: .apps,
            keywords: ["remember code", "bảng mã", "lưu", "nhớ", "ứng dụng"]),
        SettingsItem(
            title: "Loại trừ ứng dụng", iconName: "app.badge.fill", tab: .apps,
            keywords: ["exclude", "blacklist", "app", "ứng dụng", "loại trừ", "không gõ"]),
        SettingsItem(
            title: "Gửi từng phím", iconName: "keyboard.badge.ellipsis", tab: .apps,
            keywords: ["send key step by step", "từng ký tự", "ổn định", "chậm"]),
        SettingsItem(
            title: "Ứng dụng gửi từng phím", iconName: "app.badge.fill", tab: .apps,
            keywords: ["send key apps", "ứng dụng", "từng phím", "app list"]),

        // ═══════════════════════════════════════════
        // MARK: - Giao diện (Appearance)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Màu chủ đạo", iconName: "paintpalette.fill", tab: .appearance,
            keywords: ["theme", "color", "màu sắc", "giao diện", "theme color", "accent", "xanh", "đỏ", "vàng", "tím", "cam", "hồng"]),
        SettingsItem(
            title: "Icon chữ V trên thanh menu", iconName: "flag.fill", tab: .appearance,
            keywords: ["menu bar", "icon", "chữ v", "vietnamese", "thanh menu"]),
        SettingsItem(
            title: "Kích cỡ icon thanh menu", iconName: "arrow.up.left.and.arrow.down.right", tab: .appearance,
            keywords: ["menu bar size", "kích cỡ", "icon", "thanh menu", "pixel"]),
        SettingsItem(
            title: "Hiển thị icon trên Dock", iconName: "app.fill", tab: .appearance,
            keywords: ["show icon dock", "icon", "dock", "hiển thị"]),

        // ═══════════════════════════════════════════
        // MARK: - Tương thích (Compatibility)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Sửa lỗi Chromium", iconName: "globe", tab: .compatibility,
            keywords: ["chrome", "edge", "brave", "arc", "browser", "trình duyệt", "chromium"]),
        SettingsItem(
            title: "Tương thích bố cục bàn phím", iconName: "keyboard.fill", tab: .compatibility,
            keywords: ["layout", "compatibility", "dvorak", "colemak", "bố cục", "đặc biệt"]),
        SettingsItem(
            title: "Hỗ trợ gõ tiếng Việt trong Claude Code", iconName: "terminal.fill", tab: .compatibility,
            keywords: ["claude", "claude code", "terminal", "cli", "anthropic", "ai", "tiếng việt", "patch", "sửa lỗi", "fix", "npm"]),
        SettingsItem(
            title: "Chế độ an toàn (Safe Mode)", iconName: "shield.fill", tab: .compatibility,
            keywords: ["safe mode", "an toàn", "oclp", "opencore", "legacy", "mac cũ", "accessibility", "crash", "khôi phục"]),

        // ═══════════════════════════════════════════
        // MARK: - Hệ thống (System)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Khởi động cùng hệ thống", iconName: "play.fill", tab: .system,
            keywords: ["startup", "login", "boot", "tự động mở", "khởi động"]),
        SettingsItem(
            title: "Tần suất kiểm tra cập nhật", iconName: "clock.fill", tab: .system,
            keywords: ["update frequency", "cập nhật", "tự động", "kiểm tra", "tần suất"]),
        SettingsItem(
            title: "Kênh Beta", iconName: "testtube.2", tab: .system,
            keywords: ["beta", "beta channel", "thử nghiệm", "không ổn định"]),
        SettingsItem(
            title: "Kiểm tra cập nhật", iconName: "arrow.clockwise.circle.fill", tab: .system,
            keywords: ["update", "cập nhật", "new version", "phiên bản mới", "kiểm tra"]),
        SettingsItem(
            title: "Chuyển đổi bảng mã", iconName: "doc.on.clipboard.fill", tab: .system,
            keywords: ["convert", "chuyển đổi", "bảng mã", "unicode", "tcvn3", "vni", "clipboard"]),
        SettingsItem(
            title: "Xuất cài đặt", iconName: "square.and.arrow.up.fill", tab: .system,
            keywords: ["export", "xuất", "backup", "sao lưu", "settings", "cài đặt", "file"]),
        SettingsItem(
            title: "Nhập cài đặt", iconName: "square.and.arrow.down.fill", tab: .system,
            keywords: ["import", "nhập", "restore", "khôi phục", "settings", "cài đặt", "file"]),
        SettingsItem(
            title: "Đặt lại cài đặt", iconName: "arrow.counterclockwise.circle.fill", tab: .system,
            keywords: ["reset", "đặt lại", "khôi phục", "mặc định", "quản lý dữ liệu"]),

        // ═══════════════════════════════════════════
        // MARK: - Báo lỗi (Bug Report)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Báo lỗi", iconName: "ladybug.fill", tab: .bugReport,
            keywords: ["bug", "report", "lỗi", "báo cáo", "feedback", "phản hồi"]),
        SettingsItem(
            title: "Debug logs", iconName: "doc.text.fill", tab: .bugReport,
            keywords: ["log", "debug", "nhật ký", "gỡ lỗi", "thông tin hệ thống"]),
        SettingsItem(
            title: "Gửi báo lỗi", iconName: "paperplane.fill", tab: .bugReport,
            keywords: ["send", "gửi", "email", "github", "issue"]),
        SettingsItem(
            title: "Quyền Accessibility", iconName: "checkmark.shield", tab: .bugReport,
            keywords: ["accessibility", "permission", "quyền", "trợ năng", "cấp quyền"]),

        // ═══════════════════════════════════════════
        // MARK: - Thông tin (About)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Thông tin ứng dụng", iconName: "info.circle", tab: .about,
            keywords: ["about", "version", "phiên bản", "info", "thông tin", "phtv"]),
        SettingsItem(
            title: "Ủng hộ phát triển", iconName: "heart.fill", tab: .about,
            keywords: ["donate", "ủng hộ", "support", "qr", "mã", "phát triển"]),
    ]
}

// MARK: - Settings Tabs
enum SettingsTab: String, CaseIterable, Identifiable {
    case typing = "Bộ gõ"
    case hotkeys = "Phím tắt"
    case macro = "Gõ tắt"
    case dictionary = "Từ điển"
    case apps = "Ứng dụng"
    case compatibility = "Tương thích"
    case appearance = "Giao diện"
    case system = "Hệ thống"
    case stats = "Thống kê"
    case bugReport = "Báo lỗi"
    case about = "Thông tin"

    nonisolated var id: String { rawValue }
    nonisolated var title: String { rawValue }

    nonisolated var iconName: String {
        switch self {
        case .typing: return "keyboard"
        case .hotkeys: return "command"
        case .macro: return "text.badge.checkmark"
        case .dictionary: return "character.book.closed"
        case .apps: return "square.stack.3d.up"
        case .compatibility: return "puzzlepiece.extension.fill"
        case .appearance: return "paintpalette.fill"
        case .system: return "gear"
        case .stats: return "chart.bar.fill"
        case .bugReport: return "ladybug.fill"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Data Models

/// Danh mục gõ tắt
struct MacroCategory: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var icon: String  // SF Symbol name
    var color: String // Hex color

    init(id: UUID = UUID(), name: String, icon: String = "folder.fill", color: String = "#007AFF") {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }

    /// Danh mục mặc định "Chung"
    static let defaultCategory = MacroCategory(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "Chung",
        icon: "folder.fill",
        color: "#007AFF"
    )

    /// Chuyển hex string sang Color
    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
}

enum SnippetType: String, Codable, CaseIterable {
    case `static` = "static"      // Fixed text (default)
    case date = "date"            // Current date
    case time = "time"            // Current time
    case datetime = "datetime"    // Date and time
    case clipboard = "clipboard"  // Clipboard content
    case random = "random"        // Random from list
    case counter = "counter"      // Auto-increment number

    var displayName: String {
        switch self {
        case .static: return "Văn bản tĩnh"
        case .date: return "Ngày hiện tại"
        case .time: return "Giờ hiện tại"
        case .datetime: return "Ngày và giờ"
        case .clipboard: return "Clipboard"
        case .random: return "Ngẫu nhiên"
        case .counter: return "Bộ đếm"
        }
    }

    var placeholder: String {
        switch self {
        case .static: return "Nội dung mở rộng..."
        case .date: return "dd/MM/yyyy"
        case .time: return "HH:mm:ss"
        case .datetime: return "dd/MM/yyyy HH:mm"
        case .clipboard: return "(Sẽ dán nội dung từ clipboard)"
        case .random: return "giá trị 1, giá trị 2, giá trị 3"
        case .counter: return "prefix"
        }
    }

    var helpText: String {
        switch self {
        case .static: return "Văn bản cố định sẽ được thay thế"
        case .date: return "Định dạng: d=ngày, M=tháng, y=năm. VD: dd/MM/yyyy"
        case .time: return "Định dạng: H=giờ, m=phút, s=giây. VD: HH:mm:ss"
        case .datetime: return "Kết hợp ngày và giờ. VD: dd/MM/yyyy HH:mm"
        case .clipboard: return "Dán nội dung hiện tại từ clipboard"
        case .random: return "Chọn ngẫu nhiên từ danh sách, phân cách bằng dấu phẩy"
        case .counter: return "Số tự động tăng. VD: prefix → prefix1, prefix2..."
        }
    }
}

struct MacroItem: Identifiable, Hashable, Codable {
    let id: UUID
    var shortcut: String
    var expansion: String
    var categoryId: UUID?  // nil = default category
    var snippetType: SnippetType = .static  // NEW: snippet type

    // MACRO INTELLIGENCE: Usage tracking for smart features
    var usageCount: Int = 0  // Number of times this macro was triggered
    var lastUsed: Date? = nil  // Last time this macro was used
    var createdDate: Date = Date()  // When this macro was created

    init(shortcut: String, expansion: String, categoryId: UUID? = nil, snippetType: SnippetType = .static) {
        self.id = UUID()
        self.shortcut = shortcut
        self.expansion = expansion
        self.categoryId = categoryId
        self.snippetType = snippetType
        self.usageCount = 0
        self.lastUsed = nil
        self.createdDate = Date()
    }

    // Backward compatible decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        shortcut = try container.decode(String.self, forKey: .shortcut)
        expansion = try container.decode(String.self, forKey: .expansion)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        snippetType = try container.decodeIfPresent(SnippetType.self, forKey: .snippetType) ?? .static

        // MACRO INTELLIGENCE: Backward compatible - default to 0/nil/now for old macros
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        lastUsed = try container.decodeIfPresent(Date.self, forKey: .lastUsed)
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id, shortcut, expansion, categoryId, snippetType
        case usageCount, lastUsed, createdDate  // MACRO INTELLIGENCE fields
    }
}

// MARK: - Macro Intelligence Extension

extension MacroItem {
    /// MACRO INTELLIGENCE: Find conflicts with other macros
    /// Returns array of conflicting macro IDs and conflict type
    func findConflicts(in macros: [MacroItem]) -> [(MacroItem, ConflictType)] {
        var conflicts: [(MacroItem, ConflictType)] = []

        for macro in macros {
            // Skip self
            if macro.id == self.id { continue }

            let thisShortcut = self.shortcut.lowercased()
            let otherShortcut = macro.shortcut.lowercased()

            // Exact duplicate
            if thisShortcut == otherShortcut {
                conflicts.append((macro, .exactDuplicate))
            }
            // This is prefix of other (e.g., "btw" is prefix of "btwn")
            else if otherShortcut.hasPrefix(thisShortcut) {
                conflicts.append((macro, .thisIsPrefix))
            }
            // Other is prefix of this (e.g., "btw" when checking "btwn")
            else if thisShortcut.hasPrefix(otherShortcut) {
                conflicts.append((macro, .otherIsPrefix))
            }
        }

        return conflicts
    }

    /// Check if this macro is rarely used (not used in last 30 days)
    var isRarelyUsed: Bool {
        guard let lastUsed = lastUsed else {
            // Never used - check if created more than 30 days ago
            return createdDate.timeIntervalSinceNow < -30 * 24 * 3600
        }
        return lastUsed.timeIntervalSinceNow < -30 * 24 * 3600
    }

    /// Check if this is a popular macro (used 10+ times)
    var isPopular: Bool {
        return usageCount >= 10
    }
}

enum ConflictType: String {
    case exactDuplicate = "Exact duplicate"
    case thisIsPrefix = "This shortcut is prefix of another"
    case otherIsPrefix = "Another shortcut is prefix of this"

    var icon: String {
        switch self {
        case .exactDuplicate: return "exclamationmark.triangle.fill"
        case .thisIsPrefix: return "exclamationmark.circle.fill"
        case .otherIsPrefix: return "info.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .exactDuplicate: return "red"
        case .thisIsPrefix: return "orange"
        case .otherIsPrefix: return "yellow"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
