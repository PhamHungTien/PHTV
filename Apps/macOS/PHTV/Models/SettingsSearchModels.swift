//
//  SettingsSearchModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Settings Search Item

struct SettingsItem: Identifiable {
    var id: String { "\(tab.id):\(title)" }
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
            title: "Tự động khôi phục từ", iconName: "textformat.abc.dottedunderline", tab: .typing,
            keywords: ["auto restore english", "tiếng anh", "english word", "tên riêng", "thuật ngữ", "terminal", "tẻminal", "khôi phục", "không phải tiếng việt", "chỉ tiếng anh"]),
        SettingsItem(
            title: "Kiểm tra chính tả", iconName: "textformat.abc.dottedunderline", tab: .typing,
            keywords: ["spell check", "chính tả", "kiểm tra", "đúng", "sai", "correction"]),
        SettingsItem(
            title: "Phím khôi phục ký tự gốc", iconName: "arrow.uturn.backward.circle.fill", tab: .hotkeys,
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
            title: "Phụ âm Z, F, W, J, DZ", iconName: "character.cursor.ibeam", tab: .typing,
            keywords: ["consonants", "z", "f", "w", "j", "dz", "phụ âm", "tiếng anh", "ngoại ngữ"]),
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
            title: "Loại trừ ứng dụng khỏi gõ tắt", iconName: "text.badge.minus", tab: .macro,
            keywords: ["macro", "loại trừ", "ứng dụng", "exclude", "bundle id"]),
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
        // MARK: - Phím tắt (Hotkeys)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Phím tắt chuyển chế độ", iconName: "command.circle.fill", tab: .hotkeys,
            keywords: ["hotkey", "shortcut", "ctrl", "shift", "option", "command", "chuyển chế độ", "tiếng việt", "tiếng anh"]),
        SettingsItem(
            title: "Phím tạm dừng", iconName: "pause.circle.fill", tab: .hotkeys,
            keywords: ["pause", "tạm dừng", "giữ phím", "option", "control"]),
        // ═══════════════════════════════════════════
        // MARK: - PHTV Picker
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "PHTV Picker", iconName: "smiley.fill", tab: .phtvPicker,
            keywords: ["emoji", "mặt cười", "biểu tượng cảm xúc", "phím tắt", "hotkey", "character viewer", "palette", "gif", "sticker", "😀", "😊", "🎉"]),

        // ═══════════════════════════════════════════
        // MARK: - Clipboard History
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Clipboard", iconName: "doc.on.clipboard.fill", tab: .clipboardHistory,
            keywords: ["clipboard", "pasteboard", "lịch sử", "mục đã lưu", "nhóm", "folder", "snippet", "sao chép", "copy", "paste", "dán", "phím tắt", "hotkey"]),
        SettingsItem(
            title: "Số mục Clipboard tối đa", iconName: "list.number", tab: .clipboardHistory,
            keywords: ["clipboard", "max items", "số mục", "lưu", "history", "100", "30"]),
        SettingsItem(
            title: "Mục đã lưu", iconName: "bookmark.fill", tab: .clipboardHistory,
            keywords: ["clipboard", "mục đã lưu", "nội dung thường dùng", "nhóm", "folder", "snippet", "văn bản", "dán nhanh"]),

        // ═══════════════════════════════════════════
        // MARK: - Lau bàn phím
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Lau bàn phím", iconName: "keyboard.badge.eye", tab: .keyboardCleaning,
            keywords: ["clean keyboard", "cleanmykeyboard", "lau bàn phím", "khóa phím", "vệ sinh", "keyboard lock"]),

        // ═══════════════════════════════════════════
        // MARK: - Ứng dụng (Apps)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Ghi nhớ theo ứng dụng", iconName: "arrow.left.arrow.right", tab: .apps,
            keywords: ["smart switch", "auto switch", "tự động chuyển", "ghi nhớ", "Việt Anh"]),
        SettingsItem(
            title: "Nhớ bảng mã theo ứng dụng", iconName: "memorychip.fill", tab: .apps,
            keywords: ["remember code", "bảng mã", "lưu", "nhớ", "ứng dụng"]),
        SettingsItem(
            title: "Tiếng Anh theo ứng dụng", iconName: "e.circle.fill", tab: .apps,
            keywords: [
                "English", "tiếng Anh", "luôn dùng tiếng Anh", "chỉ dùng tiếng Anh",
                "không gõ tiếng Việt", "tắt tiếng Việt", "khóa tiếng Việt",
                "khóa cứng", "tự chuyển",
                "ứng dụng", "app", "loại trừ", "exclude", "blacklist"
            ]),
        SettingsItem(
            title: "Gửi từng phím", iconName: "keyboard.badge.ellipsis", tab: .apps,
            keywords: ["send key step by step", "từng ký tự", "ổn định", "chậm"]),
        SettingsItem(
            title: "Tự động gửi từng phím theo ứng dụng", iconName: "app.badge.fill", tab: .apps,
            keywords: ["send key apps", "ứng dụng", "từng phím", "app list"]),
        SettingsItem(
            title: "Tương thích bố cục bàn phím", iconName: "keyboard.fill", tab: .apps,
            keywords: ["layout", "compatibility", "dvorak", "colemak", "bố cục", "đặc biệt", "tương thích"]),

        // ═══════════════════════════════════════════
        // MARK: - Hệ thống (System)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Khởi động cùng hệ thống", iconName: "play.fill", tab: .system,
            keywords: ["startup", "login", "boot", "tự động mở", "khởi động"]),
        SettingsItem(
            title: "Cửa sổ Cài đặt luôn ở trên", iconName: "pin.fill", tab: .system,
            keywords: ["always on top", "settings window", "cửa sổ", "luôn ở trên", "floating", "pin", "giao diện", "z-order", "mission control"]),
        SettingsItem(
            title: "Hiển thị icon chữ V", iconName: "flag.fill", tab: .system,
            keywords: ["vietnamese icon", "menubar icon", "thanh menu", "icon chữ V", "giao diện", "menu bar", "status bar"]),
        SettingsItem(
            title: "Kích cỡ icon thanh menu", iconName: "arrow.up.left.and.arrow.down.right", tab: .system,
            keywords: ["icon size", "menubar", "thanh menu", "kích thước", "giao diện", "resize", "menu bar"]),
        SettingsItem(
            title: "Hiển thị icon trên Dock", iconName: "app.fill", tab: .system,
            keywords: ["dock icon", "show icon", "hiển thị", "dock", "giao diện", "app icon"]),
        SettingsItem(
            title: "Tần suất kiểm tra cập nhật", iconName: "clock.fill", tab: .system,
            keywords: ["update frequency", "cập nhật", "tự động", "kiểm tra", "tần suất"]),
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
            title: "Quyền nhập liệu", iconName: "checkmark.shield", tab: .bugReport,
            keywords: ["accessibility", "input monitoring", "permission", "quyền", "trợ năng", "giám sát đầu vào", "cấp quyền"]),

        // ═══════════════════════════════════════════
        // MARK: - Thông tin (About)
        SettingsItem(
            title: "Fanpage", iconName: "link", tab: .about,
            keywords: ["facebook", "PHTVInput", "liên hệ", "contact"]),
        SettingsItem(
            title: "Email", iconName: "envelope", tab: .about,
            keywords: ["mail", "contact@phamhungtien.com", "liên hệ"]),
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Thông tin ứng dụng", iconName: "info.circle", tab: .about,
            keywords: ["about", "version", "phiên bản", "info", "thông tin", "phtv"]),
        SettingsItem(
            title: "Ủng hộ phát triển", iconName: "heart.fill", tab: .about,
            keywords: ["donate", "ủng hộ", "support", "qr", "mã", "phát triển"]),
        // Additional entries mirror labels exposed by the current settings pages.
        SettingsItem(title: "Thiết lập bộ gõ", iconName: SettingsTab.typing.iconName, tab: .typing, keywords: []),
        SettingsItem(title: "Tối ưu gõ", iconName: SettingsTab.typing.iconName, tab: .typing, keywords: []),
        SettingsItem(title: "Chính tả mới (oà, uý)", iconName: SettingsTab.typing.iconName, tab: .typing, keywords: []),
        SettingsItem(title: "Viết hoa đầu câu", iconName: SettingsTab.typing.iconName, tab: .typing, keywords: []),
        SettingsItem(title: "Thêm dấu chấm khi gõ 2 lần phím cách", iconName: SettingsTab.typing.iconName, tab: .typing, keywords: []),
        SettingsItem(title: "Gõ nhanh Telex", iconName: SettingsTab.typing.iconName, tab: .typing, keywords: []),
        SettingsItem(title: "Phụ âm nhanh", iconName: SettingsTab.typing.iconName, tab: .typing, keywords: []),
        SettingsItem(title: "Phụ âm tùy chỉnh", iconName: SettingsTab.typing.iconName, tab: .typing, keywords: []),
        SettingsItem(title: "Chế độ Việt/Anh", iconName: SettingsTab.apps.iconName, tab: .apps, keywords: []),
        SettingsItem(title: "Bật cho mọi ứng dụng", iconName: SettingsTab.apps.iconName, tab: .apps, keywords: []),
        SettingsItem(title: "Tương thích nâng cao", iconName: SettingsTab.apps.iconName, tab: .apps, keywords: []),
        SettingsItem(title: "Bố cục bàn phím đặc biệt", iconName: SettingsTab.apps.iconName, tab: .apps, keywords: []),
        SettingsItem(title: "Chuyển chế độ gõ", iconName: SettingsTab.hotkeys.iconName, tab: .hotkeys, keywords: []),
        SettingsItem(title: "Khôi phục ký tự", iconName: SettingsTab.hotkeys.iconName, tab: .hotkeys, keywords: []),
        SettingsItem(title: "Hoàn tác về ký tự gốc", iconName: SettingsTab.hotkeys.iconName, tab: .hotkeys, keywords: []),
        SettingsItem(title: "Tạm dừng gõ tiếng Việt", iconName: SettingsTab.hotkeys.iconName, tab: .hotkeys, keywords: []),
        SettingsItem(title: "Thiết lập gõ tắt", iconName: SettingsTab.macro.iconName, tab: .macro, keywords: []),
        SettingsItem(title: "Tự động viết hoa", iconName: SettingsTab.macro.iconName, tab: .macro, keywords: []),
        SettingsItem(title: "Dùng Text Replacements của macOS", iconName: SettingsTab.macro.iconName, tab: .macro, keywords: []),
        SettingsItem(title: "Danh mục", iconName: SettingsTab.macro.iconName, tab: .macro, keywords: []),
        SettingsItem(title: "Danh sách gõ tắt", iconName: SettingsTab.macro.iconName, tab: .macro, keywords: []),
        SettingsItem(title: "Loại trừ ứng dụng", iconName: SettingsTab.macro.iconName, tab: .macro, keywords: []),
        SettingsItem(title: "Quyền riêng tư GIF & Sticker", iconName: SettingsTab.phtvPicker.iconName, tab: .phtvPicker, keywords: []),
        SettingsItem(title: "Lịch sử Clipboard", iconName: SettingsTab.clipboardHistory.iconName, tab: .clipboardHistory, keywords: []),
        SettingsItem(title: "Khởi động", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Mở cùng hệ thống", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Tự động khởi động lại khi đóng Cài đặt", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Giao diện", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Cài đặt luôn ở trên", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Thanh menu", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Hiển thị biểu tượng chữ V", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Kích thước icon", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Dock", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Hiện icon trên Dock", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Cập nhật", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Tự động tải và cài đặt", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Kiểm tra ngay", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Tiện ích", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Dữ liệu & sao lưu", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Xem lại hướng dẫn", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Xuất cấu hình", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Nhập cấu hình", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Khôi phục mặc định", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Gỡ cài đặt PHTV", iconName: SettingsTab.system.iconName, tab: .system, keywords: []),
        SettingsItem(title: "Thời gian", iconName: SettingsTab.keyboardCleaning.iconName, tab: .keyboardCleaning, keywords: []),
        SettingsItem(title: "Thời lượng", iconName: SettingsTab.keyboardCleaning.iconName, tab: .keyboardCleaning, keywords: []),
        SettingsItem(title: "Bật lịch sử Clipboard", iconName: SettingsTab.clipboardHistory.iconName, tab: .clipboardHistory, keywords: []),
        SettingsItem(title: "Bỏ qua nội dung nhạy cảm", iconName: SettingsTab.clipboardHistory.iconName, tab: .clipboardHistory, keywords: []),
        SettingsItem(title: "Phát âm thanh khi chuyển chế độ", iconName: SettingsTab.hotkeys.iconName, tab: .hotkeys, keywords: []),
        SettingsItem(title: "Âm lượng beep", iconName: SettingsTab.hotkeys.iconName, tab: .hotkeys, keywords: []),
        SettingsItem(title: "Bật tính năng tạm dừng", iconName: SettingsTab.hotkeys.iconName, tab: .hotkeys, keywords: []),
        SettingsItem(title: "Bật phím tắt PHTV Picker", iconName: SettingsTab.hotkeys.iconName, tab: .hotkeys, keywords: []),
        SettingsItem(title: "Tự động xóa mục cũ hơn", iconName: SettingsTab.clipboardHistory.iconName, tab: .clipboardHistory, keywords: []),

    ]

    private static let searchIndex: [(item: SettingsItem, text: String)] = allItems.map { item in
        (item, normalized(([item.title, item.tab.title] + item.keywords).joined(separator: " ")))
    }

    static func search(_ query: String) -> [SettingsItem] {
        let terms = normalized(query).split(whereSeparator: { $0.isWhitespace })
        guard !terms.isEmpty else { return [] }
        return searchIndex.compactMap { entry in
            terms.allSatisfy { entry.text.contains($0) } ? entry.item : nil
        }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
    }

}

// MARK: - Settings Tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case typing = "Bộ gõ"
    case phtvPicker = "PHTV Picker"
    case clipboardHistory = "Clipboard"
    case keyboardCleaning = "Lau bàn phím"
    case hotkeys = "Phím tắt"
    case macro = "Gõ tắt"
    case apps = "Ứng dụng"
    case system = "Hệ thống"
    case bugReport = "Báo lỗi"
    case about = "Thông tin"

    nonisolated var id: String { rawValue }
    nonisolated var title: String { rawValue }

    nonisolated var iconName: String {
        switch self {
        case .typing: return "keyboard"
        case .phtvPicker: return "smiley"
        case .clipboardHistory: return "doc.on.clipboard"
        case .keyboardCleaning: return "keyboard.badge.eye"
        case .hotkeys: return "command"
        case .macro: return "text.badge.checkmark"
        case .apps: return "square.stack.3d.up"
        case .system: return "gear"
        case .bugReport: return "ladybug.fill"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Settings Sidebar Sections

enum SettingsTabSection: String, CaseIterable, Identifiable {
    case typing = "Nhập liệu"
    case system = "Hệ thống"
    case support = "Hỗ trợ"

    nonisolated var id: String { rawValue }
    nonisolated var title: String { rawValue }

    nonisolated var tabs: [SettingsTab] {
        switch self {
        case .typing:
            return [.typing, .hotkeys, .macro, .apps, .phtvPicker, .clipboardHistory]
        case .system:
            return [.keyboardCleaning, .system]
        case .support:
            return [.bugReport, .about]
        }
    }
}
