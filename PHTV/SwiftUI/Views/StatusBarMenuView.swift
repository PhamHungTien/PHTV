//
//  StatusBarMenuView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct StatusBarMenuView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    // Helper to open settings window using SwiftUI's Window scene
    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }

    // Get current hotkey string
    private var hotkeyString: String {
        var parts: [String] = []
        if appState.switchKeyControl { parts.append("⌃") }
        if appState.switchKeyOption { parts.append("⌥") }
        if appState.switchKeyShift { parts.append("⇧") }
        if appState.switchKeyCommand { parts.append("⌘") }
        if appState.switchKeyCode != 0xFE {
            parts.append(appState.switchKeyName)
        }
        return parts.isEmpty ? "Chưa đặt" : parts.joined()
    }

    // Get app version
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // Quick convert with specific code tables
    private func quickConvert(from source: Int, to target: Int) {
        // Save current code table
        let originalCodeTable = UserDefaults.standard.integer(forKey: "CodeTable")

        // Set source code table for conversion
        UserDefaults.standard.set(source, forKey: "CodeTable")

        // Perform the conversion
        let success = PHTVManager.quickConvert()

        // Restore original code table
        UserDefaults.standard.set(originalCodeTable, forKey: "CodeTable")

        // Play sound to indicate result
        if success {
            NSSound.beep()
        }
    }

    var body: some View {
        // ═══════════════════════════════════════════
        // MARK: - Chuyển đổi ngôn ngữ
        // ═══════════════════════════════════════════
        Button {
            appState.isEnabled = true
        } label: {
            HStack {
                Text("Tiếng Việt")
                if appState.isEnabled {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }

        Button {
            appState.isEnabled = false
        } label: {
            HStack {
                Text("Tiếng Anh")
                if !appState.isEnabled {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }

        Divider()

        // ═══════════════════════════════════════════
        // MARK: - Bộ gõ (Input Configuration)
        // ═══════════════════════════════════════════
        Menu {
            // Input Method submenu
            Section("Phương pháp gõ") {
                ForEach(InputMethod.allCases) { method in
                    Button {
                        appState.inputMethod = method
                    } label: {
                        HStack {
                            Text(method.rawValue)
                            if appState.inputMethod == method {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            // Code Table submenu
            Section("Bảng mã") {
                ForEach(CodeTable.allCases) { table in
                    Button {
                        appState.codeTable = table
                    } label: {
                        HStack {
                            Text(table.displayName)
                            if appState.codeTable == table {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            // Quick options
            Toggle(isOn: $appState.quickTelex) {
                Label("Gõ nhanh (Quick Telex)", systemImage: "hare")
            }

            Toggle(isOn: $appState.useModernOrthography) {
                Label("Chính tả mới (oà, uý)", systemImage: "textformat.abc")
            }
        } label: {
            Label("Bộ gõ", systemImage: "keyboard.fill")
        }

        // ═══════════════════════════════════════════
        // MARK: - Tính năng (Features)
        // ═══════════════════════════════════════════
        Menu {
            Section("Kiểm tra & Sửa lỗi") {
                Toggle(isOn: $appState.checkSpelling) {
                    Label("Kiểm tra chính tả", systemImage: "text.badge.checkmark")
                }

                Toggle(isOn: $appState.restoreOnInvalidWord) {
                    Label("Khôi phục từ sai", systemImage: "arrow.uturn.backward")
                }

                Toggle(isOn: $appState.autoRestoreEnglishWord) {
                    Label("Tự động khôi phục từ tiếng Anh", systemImage: "character.bubble")
                }
            }

            Divider()

            Section("Gõ tắt & Macro") {
                Toggle(isOn: $appState.useMacro) {
                    Label("Bật gõ tắt", systemImage: "text.badge.plus")
                }

                Toggle(isOn: $appState.useMacroInEnglishMode) {
                    Label("Gõ tắt khi ở chế độ Anh", systemImage: "character.book.closed")
                }

                Toggle(isOn: $appState.autoCapsMacro) {
                    Label("Tự động viết hoa macro", systemImage: "textformat.size")
                }
            }

            Divider()

            Section("Chuyển đổi thông minh") {
                Toggle(isOn: $appState.useSmartSwitchKey) {
                    Label("Chuyển thông minh theo ứng dụng", systemImage: "brain")
                }

                Toggle(isOn: $appState.rememberCode) {
                    Label("Nhớ bảng mã theo ứng dụng", systemImage: "memories")
                }
            }
        } label: {
            Label("Tính năng", systemImage: "star.fill")
        }

        // ═══════════════════════════════════════════
        // MARK: - Nâng cao (Advanced)
        // ═══════════════════════════════════════════
        Menu {
            Section("Tùy chọn nhập") {
                Toggle(isOn: $appState.upperCaseFirstChar) {
                    Label("Viết hoa đầu câu", systemImage: "textformat.size.larger")
                }

                Toggle(isOn: $appState.allowConsonantZFWJ) {
                    Label("Cho phép ghép phụ âm", systemImage: "character.cursor.ibeam")
                }

                Toggle(isOn: $appState.quickStartConsonant) {
                    Label("Phụ âm đầu nhanh", systemImage: "arrow.right.to.line")
                }

                Toggle(isOn: $appState.quickEndConsonant) {
                    Label("Phụ âm cuối nhanh", systemImage: "arrow.left.to.line")
                }
            }

            Divider()

            Section("Tương thích") {
                Toggle(isOn: $appState.sendKeyStepByStep) {
                    Label("Gửi phím từng bước", systemImage: "arrow.down.to.line.compact")
                }

                Toggle(isOn: $appState.fixChromiumBrowser) {
                    Label("Sửa lỗi Chromium", systemImage: "globe")
                }

                Toggle(isOn: $appState.performLayoutCompat) {
                    Label("Tương thích layout", systemImage: "keyboard.badge.ellipsis")
                }
            }

            Divider()

            Section("Khôi phục") {
                Toggle(isOn: $appState.restoreOnEscape) {
                    Label("Khôi phục khi nhấn \(appState.restoreKey.symbol)", systemImage: "escape")
                }

                Toggle(isOn: $appState.pauseKeyEnabled) {
                    Label("Tạm dừng khi giữ \(appState.pauseKeyName)", systemImage: "pause.circle")
                }
            }
        } label: {
            Label("Nâng cao", systemImage: "gearshape.2.fill")
        }

        // ═══════════════════════════════════════════
        // MARK: - Hệ thống (System)
        // ═══════════════════════════════════════════
        Menu {
            Toggle(isOn: $appState.runOnStartup) {
                Label("Khởi động cùng máy", systemImage: "power.circle")
            }

            Toggle(isOn: $appState.showIconOnDock) {
                Label("Hiện icon trên Dock", systemImage: "dock.rectangle")
            }

            Toggle(isOn: $appState.beepOnModeSwitch) {
                Label("Âm thanh khi chuyển chế độ", systemImage: "speaker.wave.2")
            }

            Divider()

            // Accessibility status
            if appState.hasAccessibilityPermission {
                Label("✓ Đã cấp quyền Accessibility", systemImage: "checkmark.shield")
            } else {
                Button {
                    // Open System Preferences
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("⚠ Cần cấp quyền Accessibility", systemImage: "exclamationmark.shield")
                }
            }
        } label: {
            Label("Hệ thống", systemImage: "gearshape.fill")
        }

        Divider()

        // ═══════════════════════════════════════════
        // MARK: - Công cụ & Cài đặt
        // ═══════════════════════════════════════════
        Menu {
            Section("Chuyển nhanh Clipboard") {
                Button {
                    quickConvert(from: 1, to: 0) // TCVN3 → Unicode
                } label: {
                    Label("TCVN3 → Unicode", systemImage: "arrow.right")
                }

                Button {
                    quickConvert(from: 2, to: 0) // VNI → Unicode
                } label: {
                    Label("VNI → Unicode", systemImage: "arrow.right")
                }

                Button {
                    quickConvert(from: 0, to: 1) // Unicode → TCVN3
                } label: {
                    Label("Unicode → TCVN3", systemImage: "arrow.right")
                }

                Button {
                    quickConvert(from: 3, to: 0) // Unicode tổ hợp → Unicode
                } label: {
                    Label("Tổ hợp → Unicode", systemImage: "arrow.right")
                }
            }

            Divider()

            Button {
                NotificationCenter.default.post(name: NSNotification.Name("OpenConvertTool"), object: nil)
            } label: {
                Label("Mở công cụ đầy đủ...", systemImage: "arrow.triangle.2.circlepath")
            }
        } label: {
            Label("Chuyển đổi bảng mã", systemImage: "arrow.triangle.2.circlepath")
        }

        Button {
            openSettingsWindow()
        } label: {
            Label("Mở Cài đặt đầy đủ...", systemImage: "slider.horizontal.3")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        // ═══════════════════════════════════════════
        // MARK: - Thông tin & Thoát
        // ═══════════════════════════════════════════
        Button {
            openSettingsWindow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("ShowAboutTab"), object: nil)
            }
        } label: {
            Label("Về PHTV v\(appVersion)", systemImage: "info.circle")
        }

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Thoát PHTV", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

#Preview {
    StatusBarMenuView()
        .environmentObject(AppState.shared)
}
