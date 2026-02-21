//
//  ConvertToolView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

/// Các bảng mã tiếng Việt hỗ trợ chuyển đổi
enum ConvertCodeTable: Int, CaseIterable, Identifiable {
    case unicode = 0
    case tcvn3 = 1
    case vniWindows = 2
    case unicodeCompound = 3
    case cp1258 = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .unicode: return "Unicode"
        case .tcvn3: return "TCVN3 (ABC)"
        case .vniWindows: return "VNI Windows"
        case .unicodeCompound: return "Unicode tổ hợp"
        case .cp1258: return "CP 1258"
        }
    }

    var shortName: String {
        switch self {
        case .unicode: return "Unicode"
        case .tcvn3: return "TCVN3"
        case .vniWindows: return "VNI"
        case .unicodeCompound: return "Tổ hợp"
        case .cp1258: return "CP1258"
        }
    }

    var description: String {
        switch self {
        case .unicode: return "Bảng mã chuẩn quốc tế, phổ biến nhất hiện nay"
        case .tcvn3: return "Bảng mã cũ, dùng trong các tài liệu cũ"
        case .vniWindows: return "Bảng mã VNI, dùng trong Windows cũ"
        case .unicodeCompound: return "Unicode dạng tổ hợp (combining marks)"
        case .cp1258: return "Code Page 1258 của Windows"
        }
    }
}

/// Chế độ nhập liệu
enum ConvertInputMode: String, CaseIterable, Identifiable {
    case clipboard = "Clipboard"
    case manual = "Nhập văn bản"

    var id: String { rawValue }
}

struct ConvertToolView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var inputMode: ConvertInputMode = .clipboard
    @State private var inputText: String = ""
    @State private var clipboardContent: String = ""
    @State private var convertedContent: String = ""
    @State private var sourceCodeTable: ConvertCodeTable = .tcvn3
    @State private var targetCodeTable: ConvertCodeTable = .unicode
    @State private var isConverting = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    private let presetColumns = [GridItem(.adaptive(minimum: 140), spacing: 8, alignment: .leading)]

    // Current text to convert based on mode
    private var currentText: String {
        inputMode == .clipboard ? clipboardContent : inputText
    }

    private var canConvert: Bool {
        !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isConverting
            && sourceCodeTable != targetCodeTable
    }

    private var conversionSummary: String {
        "\(sourceCodeTable.displayName) → \(targetCodeTable.displayName)"
    }

    private var isClipboardEmpty: Bool {
        clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: 16) {
                    // Input Area (Clipboard or Manual)
                    inputAreaCard

                    // Code Table Selection
                    codeTableSelectionCard

                    // Result Preview (if converted)
                    if showResult {
                        resultPreviewCard
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer with buttons
            footerView
        }
        .settingsBackground()
        .frame(width: 560, height: 680)
        .onAppear {
            loadClipboardContent()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                PHTVRoundedRect(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.14))
                    .settingsGlassEffect(cornerRadius: 12)
                PHTVRoundedRect(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Chuyển đổi bảng mã")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Chuyển văn bản giữa Unicode, TCVN3, VNI...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .adaptiveBorderedButtonStyle()
            .controlSize(.small)
            .help("Đóng")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Input Mode Picker

    private var inputModePicker: some View {
        Picker("", selection: $inputMode) {
            ForEach(ConvertInputMode.allCases) { mode in
                switch mode {
                case .clipboard:
                    Label("Clipboard", systemImage: "doc.on.clipboard").tag(mode)
                case .manual:
                    Label("Nhập tay", systemImage: "keyboard").tag(mode)
                }
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .onChange(of: inputMode) { _ in
            loadClipboardContent()
        }
    }

    // MARK: - Input Area Card

    private var inputAreaCard: some View {
        SettingsCard(
            title: "Bước 1 · Nguồn dữ liệu",
            subtitle: "Chọn clipboard hoặc nhập văn bản",
            icon: "1.circle.fill"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                inputModePicker

                HStack(spacing: 10) {
                    Label(
                        inputMode == .clipboard ? "Nội dung Clipboard" : "Văn bản cần chuyển đổi",
                        systemImage: inputMode == .clipboard ? "clipboard.fill" : "text.cursor"
                    )
                    .font(.subheadline.weight(.semibold))

                    Spacer()

                    if inputMode == .clipboard {
                        Button {
                            loadClipboardContent()
                        } label: {
                            Label("Làm mới", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)

                        Button {
                            pasteClipboardToInput()
                        } label: {
                            Label("Dán vào ô nhập", systemImage: "arrow.down.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .opacity(isClipboardEmpty ? 0.5 : 1)
                        .disabled(isClipboardEmpty)
                    } else {
                        Button {
                            pasteClipboardToInput()
                        } label: {
                            Label("Dán", systemImage: "doc.on.clipboard")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .opacity(isClipboardEmpty ? 0.5 : 1)
                        .disabled(isClipboardEmpty)

                        Button {
                            inputText = ""
                            showResult = false
                        } label: {
                            Label("Xóa", systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .opacity(inputText.isEmpty ? 0.5 : 1)
                        .disabled(inputText.isEmpty)
                    }
                }

                if inputMode == .clipboard {
                    if isClipboardEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Clipboard trống. Hãy copy văn bản cần chuyển đổi.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(inputPanelBackground)
                    } else {
                        Text(clipboardContent)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(6)
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                            .background(inputPanelBackground)
                    }
                } else {
                    TextEditor(text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 140)
                        .roundedTextArea()
                        .overlay {
                            if inputText.isEmpty {
                                Text("Nhập hoặc dán văn bản cần chuyển đổi vào đây…")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                HStack {
                    if currentText.isEmpty {
                        Text("Sẵn sàng chuyển đổi khi có nội dung.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(currentText.count) ký tự")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Code Table Selection Card

    private var codeTableSelectionCard: some View {
        SettingsCard(
            title: "Bước 2 · Bảng mã",
            subtitle: "Chọn nguồn và đích để chuyển đổi",
            icon: "2.circle.fill"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits {
                    HStack(spacing: 12) {
                        codeTablePicker(title: "Từ bảng mã", icon: "tray.and.arrow.down.fill", selection: $sourceCodeTable)
                        swapButtonCompact
                        codeTablePicker(title: "Sang bảng mã", icon: "tray.and.arrow.up.fill", selection: $targetCodeTable)
                    }

                    VStack(spacing: 12) {
                        codeTablePicker(title: "Từ bảng mã", icon: "tray.and.arrow.down.fill", selection: $sourceCodeTable)
                        swapButtonWide
                        codeTablePicker(title: "Sang bảng mã", icon: "tray.and.arrow.up.fill", selection: $targetCodeTable)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(conversionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Quick presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nhanh")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: presetColumns, alignment: .leading, spacing: 8) {
                        presetButton(from: .tcvn3, to: .unicode)
                        presetButton(from: .vniWindows, to: .unicode)
                        presetButton(from: .unicode, to: .tcvn3)
                        presetButton(from: .unicodeCompound, to: .unicode)
                    }
                }
            }
        }
    }

    private func presetButton(from source: ConvertCodeTable, to target: ConvertCodeTable) -> some View {
        let isSelected = sourceCodeTable == source && targetCodeTable == target
        return Button("\(source.shortName) → \(target.shortName)") {
            sourceCodeTable = source
            targetCodeTable = target
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.15))
                .settingsGlassEffect(cornerRadius: 999)
        )
        .foregroundStyle(isSelected ? .white : Color.accentColor)
    }

    private var swapButtonCompact: some View {
        Button {
            let temp = sourceCodeTable
            sourceCodeTable = targetCodeTable
            targetCodeTable = temp
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))
                .frame(width: 28, height: 28)
        }
        .adaptiveBorderedButtonStyle()
        .foregroundStyle(Color.accentColor)
        .help("Hoán đổi bảng mã")
        .accessibilityLabel("Hoán đổi bảng mã")
    }

    private var swapButtonWide: some View {
        Button {
            let temp = sourceCodeTable
            sourceCodeTable = targetCodeTable
            targetCodeTable = temp
        } label: {
            Label("Hoán đổi", systemImage: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))
        }
        .adaptiveBorderedButtonStyle()
        .foregroundStyle(Color.accentColor)
        .help("Hoán đổi bảng mã")
        .frame(maxWidth: .infinity)
    }

    private func codeTablePicker(
        title: String,
        icon: String,
        selection: Binding<ConvertCodeTable>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: selection) {
                ForEach(ConvertCodeTable.allCases) { table in
                    Text(table.displayName).tag(table)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .glassMenuPickerStyle()
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(selection.wrappedValue.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PHTVRoundedRect(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .settingsGlassEffect(cornerRadius: 12)
        )
        .overlay(
            PHTVRoundedRect(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Result Preview Card

    private var resultPreviewCard: some View {
        SettingsCard(
            title: isSuccess ? "Kết quả chuyển đổi" : "Không thể chuyển đổi",
            subtitle: isSuccess ? resultMessage : "Hãy kiểm tra lại bảng mã và nội dung",
            icon: isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
            trailing: {
                if isSuccess {
                    Button {
                        copyResultToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
        ) {
            if isSuccess {
                Text(convertedContent)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(6)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        PHTVRoundedRect(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                            .settingsGlassEffect(cornerRadius: 8)
                    }
            } else {
                Text(resultMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        PHTVRoundedRect(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .settingsGlassEffect(cornerRadius: 8)
                    }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Đóng") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            .adaptiveBorderedButtonStyle()

            Spacer()

            if !isConverting {
                if currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Chưa có nội dung để chuyển đổi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if sourceCodeTable == targetCodeTable {
                    Text("Bảng mã nguồn và đích phải khác nhau")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Button {
                performConversion()
            } label: {
                if isConverting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Label("Chuyển đổi", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .keyboardShortcut(.return)
            .disabled(!canConvert)
            .adaptiveProminentButtonStyle()
        }
        .padding()
    }

    private var inputPanelBackground: some View {
        PHTVRoundedRect(cornerRadius: 8)
            .fill(Color(NSColor.controlBackgroundColor))
            .settingsGlassEffect(cornerRadius: 8)
    }

    // MARK: - Actions

    private func loadClipboardContent() {
        let pasteboard = NSPasteboard.general
        clipboardContent = pasteboard.string(forType: .string) ?? ""
        showResult = false
    }

    private func pasteClipboardToInput() {
        let pasteboard = NSPasteboard.general
        let content = pasteboard.string(forType: .string) ?? ""
        clipboardContent = content
        inputText = content
        showResult = false

        if inputMode == .clipboard {
            inputMode = .manual
        }
    }

    private func performConversion() {
        let textToConvert = currentText
        guard !textToConvert.isEmpty else { return }

        isConverting = true
        showResult = false

        // Capture values for use in async closure
        let sourceCode = sourceCodeTable
        let targetCode = targetCodeTable
        let mode = inputMode

        // If manual mode, first copy text to clipboard
        if mode == .manual {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(textToConvert, forType: .string)
        }

        // Perform conversion in background
        DispatchQueue.global(qos: .userInitiated).async {
            // Save current code table
            let originalCodeTable = UserDefaults.standard.integer(forKey: UserDefaultsKey.codeTable)

            // Set source code table for conversion
            UserDefaults.standard.set(sourceCode.rawValue, forKey: UserDefaultsKey.codeTable)

            // Perform the conversion
            let success = PHTVManager.quickConvert()

            // Restore original code table
            UserDefaults.standard.set(originalCodeTable, forKey: UserDefaultsKey.codeTable)

            // Get the converted content
            let pasteboard = NSPasteboard.general
            let newContent = pasteboard.string(forType: .string) ?? ""

            DispatchQueue.main.async {
                isConverting = false
                showResult = true

                if success && !newContent.isEmpty && newContent != textToConvert {
                    isSuccess = true
                    convertedContent = newContent
                    resultMessage = "Đã chuyển đổi \(textToConvert.count) ký tự từ \(sourceCode.displayName) sang \(targetCode.displayName)"
                    NSSound.beep()
                } else if newContent == textToConvert {
                    isSuccess = false
                    resultMessage = "Văn bản không thay đổi. Có thể văn bản đã ở định dạng \(targetCode.displayName) hoặc không chứa ký tự tiếng Việt."
                } else {
                    isSuccess = false
                    resultMessage = "Không thể chuyển đổi. Văn bản có thể không đúng định dạng \(sourceCode.displayName)."
                }
            }
        }
    }

    private func copyResultToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(convertedContent, forType: .string)
        resultMessage = "Đã copy kết quả vào clipboard!"
    }
}

#Preview {
    ConvertToolView()
}
