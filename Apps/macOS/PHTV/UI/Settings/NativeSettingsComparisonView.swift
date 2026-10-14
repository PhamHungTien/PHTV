#if DEBUG
import SwiftUI

/// A separate system-managed window for comparing Form layout with existing pages.
/// Both modes read and edit the same settings; no copies or migration are involved.
struct NativeSettingsComparisonView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: Page = .typing
    @State private var useNativeForm = true

    private enum Page: String, CaseIterable, Identifiable {
        case typing = "Bộ gõ"
        case clipboard = "Clipboard"
        var id: Self { self }
        var symbol: String { self == .typing ? "keyboard" : "doc.on.clipboard" }
    }

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $selection) { page in
                Label(page.rawValue, systemImage: page.symbol).tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            Group {
                if useNativeForm {
                    nativeForm
                } else if selection == .typing {
                    TypingSettingsView()
                } else {
                    ClipboardHistorySettingsView()
                }
            }
            .navigationTitle(selection.rawValue)
            .frame(minWidth: 500, minHeight: 500)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Bố cục so sánh", selection: $useNativeForm) {
                    Text("Form hệ thống").tag(true)
                    Text("Nội dung hiện tại").tag(false)
                }
                .pickerStyle(.segmented)
                .help("Hai bố cục dùng chung cài đặt thật của PHTV")
            }
        }
    }

    private var nativeForm: some View {
        @Bindable var settings = appState
        return Form {
            if selection == .typing {
                Section("Thiết lập bộ gõ") {
                    Picker("Phương pháp gõ", selection: $settings.inputMethod) {
                        ForEach(InputMethod.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Bảng mã", selection: $settings.codeTable) {
                        ForEach(CodeTable.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Tối ưu gõ") {
                    Toggle("Kiểm tra chính tả", isOn: $settings.checkSpelling)
                    Toggle("Gõ nhanh Telex", isOn: $settings.quickTelex)
                    Toggle("Viết hoa đầu câu", isOn: $settings.upperCaseFirstChar)
                }
            } else {
                Section("Lịch sử Clipboard") {
                    Toggle("Bật lịch sử Clipboard", isOn: $settings.enableClipboardHistory)
                    Toggle("Bỏ qua nội dung nhạy cảm", isOn: $settings.skipSensitiveClipboardContent)
                }
            }
        }
        .formStyle(.grouped)
    }
}
#endif
