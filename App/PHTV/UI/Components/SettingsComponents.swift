//
//  SettingsComponents.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

enum SettingsLayout {
    static let contentMaxWidth: CGFloat = 680
    static let contentPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let cardContentHorizontalPadding: CGFloat = 12
    static let cardContentVerticalPadding: CGFloat = 8
    static let cardCornerRadius: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 7
    static let rowControlColumnWidth: CGFloat = 168
    static let toggleControlWidth: CGFloat = 54
    static let defaultPickerWidth: CGFloat = 148
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 300
    static let detailMinWidth: CGFloat = 500
    static let detailMinHeight: CGFloat = 500
    static let windowMinSize = CGSize(width: 780, height: 550)
    static let windowIdealSize = CGSize(width: 900, height: 620)
}

// MARK: - Settings Page

extension View {
    func settingsPageFrame() -> some View {
        self
            .frame(maxWidth: SettingsLayout.contentMaxWidth, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(SettingsLayout.contentPadding)
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing
    let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        _ = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader

            content
                .padding(.horizontal, SettingsLayout.cardContentHorizontalPadding)
                .padding(.vertical, SettingsLayout.cardContentVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsCardGlassSurface(reduceTransparency: reduceTransparency)
        }
        .frame(maxWidth: SettingsLayout.contentMaxWidth, alignment: .leading)
    }

    private var cardHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 12)

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }
}

private struct SettingsCardGlassSurface: ViewModifier {
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *),
           SettingsVisualEffects.enableGlassEffects,
           !reduceTransparency {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: SettingsLayout.cardCornerRadius))
        } else {
            content
                .background {
                    PHTVRoundedRect(cornerRadius: SettingsLayout.cardCornerRadius)
                        .fill(Color(NSColor.controlBackgroundColor))
                }
        }
    }
}

private extension View {
    func settingsCardGlassSurface(reduceTransparency: Bool) -> some View {
        modifier(SettingsCardGlassSurface(reduceTransparency: reduceTransparency))
    }
}

// MARK: - Settings Picker Row

struct SettingsPickerRow<SelectionValue: Hashable, PickerContent: View>: View {
    let title: String
    let subtitle: String?
    let controlWidth: CGFloat
    @Binding var selection: SelectionValue
    let pickerContent: PickerContent

    init(
        title: String,
        subtitle: String? = nil,
        selection: Binding<SelectionValue>,
        controlWidth: CGFloat = SettingsLayout.defaultPickerWidth,
        @ViewBuilder content: () -> PickerContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.controlWidth = controlWidth
        self._selection = selection
        self.pickerContent = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            rowLabel
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
        .accessibilityElement(children: .combine)
    }

    private var rowLabel: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            rowLabel
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
        .accessibilityElement(children: .combine)
    }

    private var rowLabel: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}

// MARK: - Settings Selection Row

struct SettingsSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .settingsControlButtonStyle(isProminent: isSelected)
        .controlSize(.small)
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let runtimeHealth: PHTVTypingRuntimeHealthSnapshot
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 12)

            if shouldShowPermissionButton {
                Button(permissionButtonTitle) {
                    AppDelegate.current()?.continuePermissionGuidanceIfNeeded(
                        forceOpenSystemSettings: true
                    )
                }
                .controlSize(.small)
                .adaptiveProminentButtonStyle()
                .tint(.orange)
            }
        }
        .padding(.horizontal, SettingsLayout.cardContentHorizontalPadding)
        .padding(.vertical, SettingsLayout.cardContentVerticalPadding)
        .settingsCardGlassSurface(reduceTransparency: reduceTransparency)
        .frame(maxWidth: SettingsLayout.contentMaxWidth)
    }

    private var statusColor: Color {
        switch runtimeHealth.phase {
        case .ready:
            return .green
        case .accessibilityRequired:
            return .orange
        case .inputMonitoringRequired:
            return .orange
        case .relaunchPending:
            return .blue
        case .waitingForEventTap:
            return .yellow
        }
    }

    private var statusIcon: String {
        switch runtimeHealth.phase {
        case .ready:
            return "checkmark.shield.fill"
        case .accessibilityRequired:
            return "exclamationmark.triangle.fill"
        case .inputMonitoringRequired:
            return "eye.fill"
        case .relaunchPending:
            return "arrow.clockwise.circle.fill"
        case .waitingForEventTap:
            return "clock.badge.exclamationmark.fill"
        }
    }

    private var statusTitle: String {
        switch runtimeHealth.phase {
        case .ready:
            return "Sẵn sàng"
        case .accessibilityRequired:
            return "Thiếu quyền Trợ năng"
        case .inputMonitoringRequired:
            return "Thiếu quyền Giám sát đầu vào"
        case .relaunchPending:
            return "Đang tự khởi động lại"
        case .waitingForEventTap:
            return "Đang hoàn tất khởi tạo"
        }
    }

    private var shouldShowPermissionButton: Bool {
        switch runtimeHealth.phase {
        case .ready, .relaunchPending:
            return false
        case .accessibilityRequired, .inputMonitoringRequired, .waitingForEventTap:
            return true
        }
    }

    private var permissionButtonTitle: String {
        if runtimeHealth.phase == .accessibilityRequired {
            return "Mở Trợ năng"
        }
        if runtimeHealth.phase == .inputMonitoringRequired {
            return "Mở Giám sát đầu vào"
        }
        return "Thử lại ngay"
    }
}

// MARK: - Restore Key Button

struct RestoreKeyButton: View {
    let key: RestoreKey
    @Binding var selection: RestoreKey
    let themeColor: Color

    private var isSelected: Bool { selection == key }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = key
            }
        }) {
            HStack(spacing: 4) {
                Text(key.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if key != .esc {
                    Text(shortDisplayName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .settingsControlButtonStyle(isProminent: isSelected)
        .controlSize(.small)
        .tint(themeColor)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var shortDisplayName: String {
        switch key {
        case .esc: return "ESC"
        case .option: return "Option"
        case .control: return "Control"
        }
    }
}

// MARK: - Shared Hotkey Recorder Button & Label

struct SettingsShortcutRecorderLabel: View {
    let text: String
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isRecording ? Color.accentColor : .secondary)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isRecording ? Color.accentColor : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
    }
}

struct SettingsShortcutRecorderButtonStyle: ButtonStyle {
    let isRecording: Bool
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .frame(width: SettingsLayout.rowControlColumnWidth, height: 32, alignment: .leading)
            .background {
                PHTVRoundedRect(cornerRadius: 7)
                    .fill(backgroundColor)
                    .overlay {
                        PHTVRoundedRect(cornerRadius: 7)
                            .stroke(borderColor, lineWidth: isRecording ? 1.5 : 1)
                    }
            }
            .contentShape(PHTVRoundedRect(cornerRadius: 7))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }

    private var backgroundColor: Color {
        if isRecording {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12)
        }
        return Color(NSColor.controlBackgroundColor)
    }

    private var borderColor: Color {
        if isRecording {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.8 : 0.65)
        }
        return Color(NSColor.separatorColor).opacity(colorScheme == .dark ? 0.9 : 0.65)
    }
}

// MARK: - Unified Hotkey Capture Services

private final class SettingsHotkeyLocalEventMonitor: @unchecked Sendable {
    let value: Any

    init(value: Any) {
        self.value = value
    }

    deinit {
        NSEvent.removeMonitor(value)
    }
}

final class UnifiedHotkeyCaptureView: NSView {
    var onKeyPress: ((UInt16, NSEvent.ModifierFlags, UInt64) -> Void)?
    var onCancel: (() -> Void)?
    private var localMonitor: SettingsHotkeyLocalEventMonitor?
    private var maxModifiers: NSEvent.ModifierFlags = []
    private var maxRawFlags: UInt64 = 0
    private var keyDownHappened = false

    var isRecording = false {
        didSet {
            isRecording ? startRecording() : stopRecording()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isRecording {
            focusForCapture()
        }
    }

    private func startRecording() {
        focusForCapture()
        guard localMonitor == nil else { return }
        maxModifiers = []
        maxRawFlags = 0
        keyDownHappened = false

        guard let monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] event in
            guard let self, self.isRecording else { return event }

            if event.type == .flagsChanged {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let raw = UInt64(event.modifierFlags.rawValue)
                let keyCode = event.keyCode
                
                if !flags.isEmpty {
                    self.maxModifiers = self.maxModifiers.union(flags)
                    self.maxRawFlags |= raw
                } else if !self.maxModifiers.isEmpty && !self.keyDownHappened {
                    if self.maxModifiersMatchKey(keyCode: keyCode, maxMods: self.maxModifiers) {
                        self.capture(keyCode: keyCode, modifiers: [], rawFlags: self.maxRawFlags)
                    } else {
                        self.capture(keyCode: KeyCode.noKey, modifiers: self.maxModifiers, rawFlags: self.maxRawFlags)
                    }
                    return nil
                }
            } else if event.type == .keyDown {
                self.keyDownHappened = true
                let keyCode = event.keyCode
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let raw = UInt64(event.modifierFlags.rawValue) | self.maxRawFlags
                
                if keyCode == KeyCode.escape && flags.isEmpty {
                    self.cancel()
                    return nil
                }
                
                self.capture(keyCode: keyCode, modifiers: flags, rawFlags: raw)
                return nil
            }

            return event
        }) else { return }
        localMonitor = SettingsHotkeyLocalEventMonitor(value: monitor)
    }

    private func stopRecording() {
        self.localMonitor = nil
    }

    private func focusForCapture() {
        window?.makeFirstResponder(self)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRecording else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    private func capture(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, rawFlags: UInt64) {
        isRecording = false
        Task { @MainActor [weak self] in
            self?.onKeyPress?(keyCode, modifiers, rawFlags)
        }
    }

    private func cancel() {
        isRecording = false
        Task { @MainActor [weak self] in
            self?.onCancel?()
        }
    }

    private func maxModifiersMatchKey(keyCode: UInt16, maxMods: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 58, 61: return maxMods == [.option]
        case 59, 62: return maxMods == [.control]
        case 56, 60: return maxMods == [.shift]
        case 55, 54: return maxMods == [.command]
        case 63: return maxMods == [.function]
        default: return false
        }
    }
}

struct UnifiedHotkeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCaptured: (UInt16, NSEvent.ModifierFlags, UInt64) -> Void
    var onCancelled: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = UnifiedHotkeyCaptureView()
        view.onKeyPress = { keyCode, modifiers, rawFlags in
            onCaptured(keyCode, modifiers, rawFlags)
        }
        view.onCancel = {
            onCancelled()
        }
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let captureView = nsView as? UnifiedHotkeyCaptureView {
            captureView.isRecording = isRecording
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var view: UnifiedHotkeyCaptureView?
    }
}
