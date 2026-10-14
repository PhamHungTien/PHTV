import SwiftUI

/// App menus use the responder chain for standard editing and window commands.
@MainActor
struct PHTVCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Bindable private var appState = AppState.shared

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("Giới thiệu PHTV") {
                SettingsWindowOpener.requestOpenWindow(tab: .about)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Cài đặt PHTV...") { openWindow(id: "settings-main") }
                .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .appSettings) {
            Button("Kiểm tra cập nhật...") {
                NotificationCenter.default.post(name: NotificationName.sparkleManualCheck, object: nil)
            }
        }

        CommandGroup(after: .sidebar) {
            Menu("Các mục cài đặt") {
                ForEach(SettingsTabSection.allCases) { section in
                    Section(section.title) {
                        ForEach(section.tabs) { tab in
                            Button(tab.title + "...") {
                                SettingsWindowOpener.requestOpenWindow(tab: tab)
                            }
                        }
                    }
                }
            }
        }

        CommandMenu("Bộ gõ") {
            Toggle("Gõ tiếng Việt", isOn: Binding(
                get: { appState.isEnabled },
                set: { enabled in
                    guard !enabled || !PHTVManager.isEnglishLanguageLocked() else { return }
                    AppDelegate.current()?.rememberExplicitLanguageChoiceDuringNonLatinInput(enabled ? 1 : 0)
                    appState.isEnabled = enabled
                }
            ))
            Divider()
            Picker("Phương pháp gõ", selection: $appState.inputMethod) {
                ForEach(InputMethod.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }
            Picker("Bảng mã", selection: $appState.codeTable) {
                ForEach(CodeTable.allCases) { table in
                    Text(table.displayName).tag(table)
                }
            }
            Divider()
            Toggle("Kiểm tra chính tả", isOn: $appState.checkSpelling)
            Toggle("Gõ nhanh Telex", isOn: $appState.quickTelex)
            Toggle("Bật gõ tắt", isOn: $appState.useMacro)
        }

        CommandMenu("Công cụ") {
            Button("Mở PHTV Picker") { EmojiHotkeyBridge.openEmojiPicker() }
            Button("Mở Clipboard") { ClipboardHistoryManager.shared.show() }
            Divider()
            Button("Chuyển đổi bảng mã...") { SettingsWindowOpener.requestConvertTool() }
            Button("Quản lý gõ tắt...") { SettingsWindowOpener.requestOpenWindow(tab: .macro) }
            Button("Lau bàn phím...") { SettingsWindowOpener.requestOpenWindow(tab: .keyboardCleaning) }
            if PHTVKeyboardCleaningService.isCleaningActive() {
                Button("Dừng lau bàn phím") { PHTVKeyboardCleaningService.stopCleaning() }
            }
        }

        CommandGroup(replacing: .help) {
            Link("Hướng dẫn sử dụng PHTV", destination: URL(string: "https://phamhungtien.com/PHTV/")!)
            Button("Báo lỗi...") { SettingsWindowOpener.requestOpenWindow(tab: .bugReport) }
            Button("Ủng hộ PHTV...") { SettingsWindowOpener.requestDonatePopover() }
        }
    }
}
