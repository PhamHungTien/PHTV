import SwiftUI
import AppKit

// MARK: - Settings Window Controller

final class PHTVSettingsWindowController: NSWindowController {
    static let shared = PHTVSettingsWindowController()

    private var settingsWindow: NSWindow?

    init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func displayWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: PHTVSettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 520, height: 430))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "Cài đặt PHTV"
        window.subtitle = "Vietnamese Input Method"
        window.isReleasedWhenClosed = false
        window.center()

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    @objc private func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}

// MARK: - Settings View

struct PHTVSettingsView: View {
    @State private var inputStyle: PHTVInputStyle = .telex
    @State private var outputEncoding: PHTVOutputEncoding = .unicode
    @State private var autoRestoreEnglishWord = true
    @State private var upperCaseFirstChar = false
    @State private var showsSavedStatus = false

    private var inputStyleBinding: Binding<PHTVInputStyle> {
        Binding(
            get: { inputStyle },
            set: { newValue in
                inputStyle = newValue
                save()
            }
        )
    }

    private var outputEncodingBinding: Binding<PHTVOutputEncoding> {
        Binding(
            get: { outputEncoding },
            set: { newValue in
                outputEncoding = newValue
                save()
            }
        )
    }

    private var autoRestoreBinding: Binding<Bool> {
        Binding(
            get: { autoRestoreEnglishWord },
            set: { newValue in
                autoRestoreEnglishWord = newValue
                save()
            }
        )
    }

    private var upperCaseBinding: Binding<Bool> {
        Binding(
            get: { upperCaseFirstChar },
            set: { newValue in
                upperCaseFirstChar = newValue
                save()
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Kiểu gõ", selection: inputStyleBinding) {
                        ForEach(PHTVInputStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .help("Chọn quy tắc gõ tiếng Việt.")

                    Picker("Bảng mã", selection: outputEncodingBinding) {
                        ForEach(PHTVOutputEncoding.allCases, id: \.self) { encoding in
                            Text(encoding.displayName).tag(encoding)
                        }
                    }
                    .help("Chọn bảng mã đầu ra cho văn bản tiếng Việt.")
                } header: {
                    SettingsSectionHeader(
                        systemImage: "keyboard",
                        title: "Bộ gõ",
                        subtitle: "Thiết lập phương pháp gõ và bảng mã mặc định."
                    )
                }

                Section {
                    Toggle("Viết hoa đầu câu", isOn: upperCaseBinding)
                        .help("Tự động viết hoa chữ cái đầu sau dấu kết thúc câu.")

                    Toggle("Khôi phục từ tiếng Anh", isOn: autoRestoreBinding)
                        .help("Khi một chuỗi giống từ tiếng Anh, PHTV tự trả về dạng không dấu.")
                } header: {
                    SettingsSectionHeader(
                        systemImage: "arrow.uturn.backward.circle",
                        title: "Tự động",
                        subtitle: "Giữ trải nghiệm gõ tự nhiên khi xen kẽ tiếng Việt và tiếng Anh."
                    )
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Divider()

            HStack(spacing: 8) {
                if showsSavedStatus {
                    Label("Đã áp dụng", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                } else {
                    Text("Thay đổi được lưu tự động.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Đóng") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .frame(width: 520, height: 430)
        .onAppear(perform: loadConfiguration)
    }

    private func loadConfiguration() {
        let config = PHTVInputMethodPreferences.currentConfiguration()
        inputStyle = config.inputStyle
        outputEncoding = config.outputEncoding
        autoRestoreEnglishWord = config.autoRestoreEnglishWord
        upperCaseFirstChar = config.upperCaseFirstChar
    }

    private func save() {
        let config = PHTVInputMethodConfiguration(
            inputStyle: inputStyle,
            outputEncoding: outputEncoding,
            autoRestoreEnglishWord: autoRestoreEnglishWord,
            upperCaseFirstChar: upperCaseFirstChar
        )
        PHTVInputMethodPreferences.saveConfiguration(config)

        withAnimation(.easeInOut(duration: 0.15)) {
            showsSavedStatus = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showsSavedStatus = false
            }
        }
    }
}

private struct SettingsSectionHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .textCase(nil)
        .padding(.bottom, 4)
    }
}
