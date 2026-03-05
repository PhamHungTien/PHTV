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
            title: "Tự động khôi phục", iconName: "textformat.abc.dottedunderline", tab: .typing,
            keywords: ["auto restore english", "tiếng anh", "english word", "terminal", "tẻminal", "khôi phục", "không phải tiếng việt", "chỉ tiếng anh"]),
        SettingsItem(
            title: "Chỉ gõ đúng chính tả tiếng Việt", iconName: "textformat.abc.dottedunderline", tab: .typing,
            keywords: ["spell check", "chính tả", "kiểm tra", "đúng", "sai", "tiếng việt", "correction"]),
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
            title: "Phụ âm Z, F, W, J", iconName: "character.cursor.ibeam", tab: .typing,
            keywords: ["consonants", "z", "f", "w", "j", "phụ âm", "tiếng anh", "ngoại ngữ"]),
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
        // MARK: - Phím tắt (Hotkeys)
        // ═══════════════════════════════════════════
        SettingsItem(
            title: "Phím tắt chuyển chế độ", iconName: "command.circle.fill", tab: .hotkeys,
            keywords: ["hotkey", "shortcut", "ctrl", "shift", "option", "command", "chuyển chế độ", "tiếng việt", "tiếng anh"]),
        SettingsItem(
            title: "Phím tạm dừng", iconName: "pause.circle.fill", tab: .hotkeys,
            keywords: ["pause", "tạm dừng", "giữ phím", "option", "control"]),
        SettingsItem(
            title: "PHTV Picker", iconName: "smiley.fill", tab: .hotkeys,
            keywords: ["emoji", "mặt cười", "biểu tượng cảm xúc", "phím tắt", "hotkey", "character viewer", "palette", "😀", "😊", "🎉"]),

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
        SettingsItem(
            title: "Tương thích bố cục bàn phím", iconName: "keyboard.fill", tab: .apps,
            keywords: ["layout", "compatibility", "dvorak", "colemak", "bố cục", "đặc biệt", "tương thích"]),
        SettingsItem(
            title: "Chế độ an toàn (Safe Mode)", iconName: "shield.fill", tab: .apps,
            keywords: ["safe mode", "an toàn", "oclp", "opencore", "legacy", "mac cũ", "accessibility", "crash", "khôi phục", "tương thích"]),

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
    case apps = "Ứng dụng"
    case system = "Hệ thống"
    case bugReport = "Báo lỗi"
    case about = "Thông tin"

    nonisolated var id: String { rawValue }
    nonisolated var title: String { rawValue }

    nonisolated var iconName: String {
        switch self {
        case .typing: return "keyboard"
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
            return [.typing, .hotkeys, .macro, .apps]
        case .system:
            return [.system]
        case .support:
            return [.bugReport, .about]
        }
    }
}
