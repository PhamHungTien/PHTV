import SwiftUI
import AppKit

// MARK: - Settings Window Controller
final class PHTVSettingsWindowController: NSWindowController {
    static let shared = PHTVSettingsWindowController()
    
    private var myWindow: NSWindow?
    
    init() {
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func displayWindow() {
        if let window = myWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = PHTVSettingsView()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Cấu hình PHTV"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Premium translucent behind-window blur (Vibrancy)
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        
        window.contentView = visualEffect
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffect.addSubview(hostingView)
        
        myWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Listen to window closing to clean up reference
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        myWindow = nil
    }
}

// MARK: - Settings Layout Tokens
enum SettingsLayout {
    static let sectionSpacing: CGFloat = 16
    static let cardContentHorizontalPadding: CGFloat = 12
    static let cardContentVerticalPadding: CGFloat = 8
    static let cardCornerRadius: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 7
    static let rowControlColumnWidth: CGFloat = 168
    static let toggleControlWidth: CGFloat = 54
}

// MARK: - Settings Card Component
struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader

            content
                .padding(.horizontal, SettingsLayout.cardContentHorizontalPadding)
                .padding(.vertical, SettingsLayout.cardContentVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: SettingsLayout.cardCornerRadius, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsLayout.cardCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }
}

// MARK: - Settings Picker Row Component
struct SettingsPickerRow<SelectionValue: Hashable, PickerContent: View>: View {
    let title: String
    let subtitle: String?
    @Binding var selection: SelectionValue
    let pickerContent: PickerContent

    init(
        title: String,
        subtitle: String? = nil,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> PickerContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.pickerContent = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Picker("", selection: $selection) {
                pickerContent
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: SettingsLayout.rowControlColumnWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }
}

// MARK: - Settings Toggle Row Component
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
                    .frame(width: 22, height: 22)
                    .background(iconColor.opacity(0.12))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .frame(width: SettingsLayout.toggleControlWidth, alignment: .trailing)
                .frame(width: SettingsLayout.rowControlColumnWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }
}

// MARK: - Settings Divider Component
struct SettingsDivider: View {
    var body: some View {
        Divider()
            .opacity(0.15)
            .padding(.vertical, 2)
    }
}

// MARK: - SwiftUI Settings View
struct PHTVSettingsView: View {
    @State private var inputStyle: PHTVInputStyle = .telex
    @State private var outputEncoding: PHTVOutputEncoding = .unicode
    @State private var autoRestoreEnglishWord = true
    @State private var showSavedAlert = false
    
    private var inputStyleBinding: Binding<PHTVInputStyle> {
        Binding(
            get: { self.inputStyle },
            set: { newValue in
                self.inputStyle = newValue
                self.save()
            }
        )
    }
    
    private var outputEncodingBinding: Binding<PHTVOutputEncoding> {
        Binding(
            get: { self.outputEncoding },
            set: { newValue in
                self.outputEncoding = newValue
                self.save()
            }
        )
    }
    
    private var autoRestoreBinding: Binding<Bool> {
        Binding(
            get: { self.autoRestoreEnglishWord },
            set: { newValue in
                self.autoRestoreEnglishWord = newValue
                self.save()
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Premium Header acting as Custom Title Bar
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bộ gõ PHTV")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Cấu hình bộ gõ độc lập")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Preferences Content Pane
            ScrollView {
                VStack(spacing: SettingsLayout.sectionSpacing) {
                    // Card 1: Thiết lập bộ gõ
                    SettingsCard(
                        title: "Thiết lập bộ gõ",
                        subtitle: "Chọn phương pháp gõ và bảng mã phù hợp",
                        icon: "keyboard.fill"
                    ) {
                        VStack(spacing: 0) {
                            SettingsPickerRow(
                                title: "Phương pháp gõ",
                                selection: inputStyleBinding
                            ) {
                                ForEach(PHTVInputStyle.allCases, id: \.self) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            
                            SettingsDivider()
                            
                            SettingsPickerRow(
                                title: "Bảng mã",
                                selection: outputEncodingBinding
                            ) {
                                ForEach(PHTVOutputEncoding.allCases, id: \.self) { encoding in
                                    Text(encoding.displayName).tag(encoding)
                                }
                            }
                        }
                    }
                    
                    // Card 2: Tối ưu gõ
                    SettingsCard(
                        title: "Tối ưu gõ",
                        subtitle: "Tăng tốc và cải thiện trải nghiệm",
                        icon: "wand.and.stars"
                    ) {
                        SettingsToggleRow(
                            icon: "text.magnifyingglass",
                            iconColor: .accentColor,
                            title: "Tự động khôi phục tiếng Anh",
                            subtitle: "Khôi phục từ được nhận diện là tiếng Anh",
                            isOn: autoRestoreBinding
                        )
                    }
                }
                .padding(24)
            }
            .frame(maxHeight: .infinity)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Premium Footer & Auto-save Alert
            HStack {
                if showSavedAlert {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12, weight: .bold))
                        Text("Đã tự động áp dụng")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                Button("Đóng") {
                    if let window = NSApp.windows.first(where: { $0.title == "Cấu hình PHTV" }) {
                        window.close()
                    }
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.08))
        }
        .frame(width: 500, height: 450)
        .onAppear {
            let config = PHTVInputMethodPreferences.currentConfiguration()
            self.inputStyle = config.inputStyle
            self.outputEncoding = config.outputEncoding
            self.autoRestoreEnglishWord = config.autoRestoreEnglishWord
        }
    }
    
    // MARK: - Save Settings
    private func save() {
        let config = PHTVInputMethodConfiguration(
            inputStyle: inputStyle,
            outputEncoding: outputEncoding,
            autoRestoreEnglishWord: autoRestoreEnglishWord
        )
        PHTVInputMethodPreferences.saveConfiguration(config)
        
        withAnimation(.easeInOut(duration: 0.15)) {
            showSavedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showSavedAlert = false
            }
        }
    }
}
