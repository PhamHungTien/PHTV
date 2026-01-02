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
enum ConvertInputMode: String, CaseIterable {
    case clipboard = "Clipboard"
    case manual = "Nhập văn bản"
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

    // Current text to convert based on mode
    private var currentText: String {
        inputMode == .clipboard ? clipboardContent : inputText
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Input Mode Picker
                    inputModePicker

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
        .frame(width: 550, height: 650)
        .onAppear {
            loadClipboardContent()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chuyển đổi bảng mã")
                    .font(.headline)

                Text("Chuyển văn bản giữa Unicode, TCVN3, VNI...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Input Mode Picker

    private var inputModePicker: some View {
        Picker("", selection: $inputMode) {
            ForEach(ConvertInputMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: inputMode) { newValue in
            showResult = false
            if newValue == .clipboard {
                loadClipboardContent()
            }
        }
    }

    // MARK: - Input Area Card

    private var inputAreaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    inputMode == .clipboard ? "Nội dung Clipboard" : "Nhập văn bản cần chuyển đổi",
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
                } else {
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
                // Clipboard mode
                if clipboardContent.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Clipboard trống. Hãy copy văn bản cần chuyển đổi.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    }
                } else {
                    Text(clipboardContent)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(6)
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        }
                }
            } else {
                // Manual input mode
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    }
                    .overlay {
                        if inputText.isEmpty {
                            Text("Nhập hoặc dán văn bản cần chuyển đổi vào đây...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(12)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
            }

            if !currentText.isEmpty {
                Text("\(currentText.count) ký tự")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }

    // MARK: - Code Table Selection Card

    private var codeTableSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Chọn bảng mã", systemImage: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 16) {
                // Source
                VStack(alignment: .leading, spacing: 8) {
                    Text("Từ bảng mã")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $sourceCodeTable) {
                        ForEach(ConvertCodeTable.allCases) { table in
                            Text(table.displayName).tag(table)
                        }
                    }
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity)

                // Swap button
                Button {
                    let temp = sourceCodeTable
                    sourceCodeTable = targetCodeTable
                    targetCodeTable = temp
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Hoán đổi bảng mã")

                // Target
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sang bảng mã")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $targetCodeTable) {
                        ForEach(ConvertCodeTable.allCases) { table in
                            Text(table.displayName).tag(table)
                        }
                    }
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity)
            }

            // Quick presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Nhanh:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    presetButton(from: .tcvn3, to: .unicode)
                    presetButton(from: .vniWindows, to: .unicode)
                    presetButton(from: .unicode, to: .tcvn3)
                    presetButton(from: .unicodeCompound, to: .unicode)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }

    private func presetButton(from source: ConvertCodeTable, to target: ConvertCodeTable) -> some View {
        let isSelected = sourceCodeTable == source && targetCodeTable == target
        return Button("\(source.shortName) → \(target.shortName)") {
            sourceCodeTable = source
            targetCodeTable = target
        }
        .buttonStyle(.plain)
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.15)))
        .foregroundStyle(isSelected ? .white : Color.accentColor)
    }

    // MARK: - Result Preview Card

    private var resultPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(isSuccess ? "Kết quả chuyển đổi" : "Lỗi", systemImage: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSuccess ? .green : .red)

                Spacer()

                if isSuccess {
                    Button {
                        copyResultToClipboard()
                    } label: {
                        Label("Copy kết quả", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }

            if isSuccess {
                Text(convertedContent)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(6)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    }

                Text(resultMessage)
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Text(resultMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSuccess ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSuccess ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
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

            Spacer()

            if sourceCodeTable == targetCodeTable {
                Text("Bảng mã nguồn và đích phải khác nhau")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
            .disabled(currentText.isEmpty || isConverting || sourceCodeTable == targetCodeTable)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadClipboardContent() {
        let pasteboard = NSPasteboard.general
        clipboardContent = pasteboard.string(forType: .string) ?? ""
        showResult = false
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
            let originalCodeTable = UserDefaults.standard.integer(forKey: "CodeTable")

            // Set source code table for conversion
            UserDefaults.standard.set(sourceCode.rawValue, forKey: "CodeTable")

            // Perform the conversion
            let success = PHTVManager.quickConvert()

            // Restore original code table
            UserDefaults.standard.set(originalCodeTable, forKey: "CodeTable")

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
