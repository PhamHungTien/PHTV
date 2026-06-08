//
//  ConvertToolView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

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
        case .unicode: return "Chuẩn quốc tế"
        case .tcvn3: return "Tiêu chuẩn cũ"
        case .vniWindows: return "Bảng mã VNI"
        case .unicodeCompound: return "Dạng tổ hợp"
        case .cp1258: return "Code Page 1258"
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

    @SceneStorage("ConvertToolInputMode") private var storedInputMode = ConvertInputMode.clipboard.rawValue
    @AppStorage(UserDefaultsKey.convertToolFromCode) private var storedSourceCodeTable = Defaults.convertToolFromCode
    @AppStorage(UserDefaultsKey.convertToolToCode) private var storedTargetCodeTable = Defaults.convertToolToCode
    
    @State private var inputText: String = ""
    @State private var clipboardContent: String = ""
    @State private var convertedContent: String = ""
    @State private var isConverting = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    @State private var showCopiedMessage = false

    private var inputMode: ConvertInputMode {
        get { ConvertInputMode(rawValue: storedInputMode) ?? .clipboard }
        nonmutating set { storedInputMode = newValue.rawValue }
    }

    private var sourceCodeTable: ConvertCodeTable {
        get { ConvertCodeTable(rawValue: storedSourceCodeTable) ?? .tcvn3 }
        nonmutating set { storedSourceCodeTable = newValue.rawValue }
    }

    private var targetCodeTable: ConvertCodeTable {
        get { ConvertCodeTable(rawValue: storedTargetCodeTable) ?? .unicode }
        nonmutating set { storedTargetCodeTable = newValue.rawValue }
    }

    private var currentText: String {
        inputMode == .clipboard ? clipboardContent : inputText
    }

    private var canConvert: Bool {
        !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isConverting
            && sourceCodeTable != targetCodeTable
    }

    private var isClipboardEmpty: Bool {
        clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Mode Selector
            Picker("", selection: Binding(
                get: { inputMode },
                set: { inputMode = $0; showResult = false }
            )) {
                ForEach(ConvertInputMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            // Pickers and Quick Presets Toolbar
            toolbarView
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.4))

            Divider()

            // Main Content Area
            Group {
                switch inputMode {
                case .clipboard:
                    clipboardView
                case .manual:
                    manualInputView
                }
            }
            .frame(maxHeight: .infinity)
            .padding(20)

            Divider()

            // Footer
            footerView
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .settingsBackground()
        .frame(width: 680, height: 520)
        .task(id: inputMode) {
            guard inputMode == .clipboard else { return }
            loadClipboardContent()
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chuyển đổi bảng mã")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Chuyển đổi nhanh văn bản giữa các bảng mã tiếng Việt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Toolbar View (Pickers & Presets)
    private var toolbarView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                // Source Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Từ bảng mã")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { sourceCodeTable },
                        set: { sourceCodeTable = $0; showResult = false }
                    )) {
                        ForEach(ConvertCodeTable.allCases) { table in
                            Text(table.displayName).tag(table)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
                
                // Swap Button
                Button {
                    let temp = sourceCodeTable
                    sourceCodeTable = targetCodeTable
                    targetCodeTable = temp
                    showResult = false
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(NSColor.separatorColor), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                
                // Target Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sang bảng mã")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { targetCodeTable },
                        set: { targetCodeTable = $0; showResult = false }
                    )) {
                        ForEach(ConvertCodeTable.allCases) { table in
                            Text(table.displayName).tag(table)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
            }

            // Quick Presets
            HStack(spacing: 8) {
                Text("Gợi ý nhanh:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                presetButton(from: .tcvn3, to: .unicode)
                presetButton(from: .vniWindows, to: .unicode)
                presetButton(from: .unicodeCompound, to: .unicode)

                Spacer()
            }
        }
    }

    private func presetButton(from source: ConvertCodeTable, to target: ConvertCodeTable) -> some View {
        let isSelected = sourceCodeTable == source && targetCodeTable == target
        return Button("\(source.shortName) → \(target.shortName)") {
            sourceCodeTable = source
            targetCodeTable = target
            showResult = false
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color(NSColor.separatorColor), lineWidth: 1)
        )
        .buttonStyle(.plain)
    }

    // MARK: - Clipboard View
    private var clipboardView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Nội dung Clipboard hiện tại", systemImage: "doc.on.clipboard.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        loadClipboardContent()
                    } label: {
                        Label("Làm mới", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }

                if isClipboardEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Clipboard trống hoặc không chứa văn bản.\nHãy sao chép văn bản cần chuyển đổi trước.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                } else {
                    ScrollView {
                        Text(clipboardContent)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                }
            }

            if showResult {
                HStack(spacing: 10) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isSuccess ? .green : .red)
                    Text(resultMessage)
                        .font(.caption)
                        .foregroundStyle(isSuccess ? .green : .red)
                    Spacer()
                }
                .padding(10)
                .background(isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Manual Input View
    private var manualInputView: some View {
        HStack(spacing: 16) {
            // Left Column (Source Editor)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Văn bản gốc")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: pasteClipboardToInput) {
                        Image(systemName: "doc.on.clipboard")
                            .help("Dán từ clipboard")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    
                    Button(action: { inputText = ""; convertedContent = ""; showResult = false }) {
                        Image(systemName: "trash")
                            .help("Xóa văn bản")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .disabled(inputText.isEmpty)
                }
                
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .overlay {
                        if inputText.isEmpty {
                            Text("Nhập hoặc dán văn bản tại đây...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
            }
            
            // Right Column (Target/Output View)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Văn bản sau chuyển")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        copyResultToClipboard()
                        showCopiedMessage = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            showCopiedMessage = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopiedMessage ? "checkmark" : "doc.on.doc")
                            Text(showCopiedMessage ? "Đã copy" : "Sao chép")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .disabled(convertedContent.isEmpty)
                }
                
                TextEditor(text: .constant(convertedContent))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(4)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .overlay {
                        if convertedContent.isEmpty {
                            Text("Kết quả chuyển đổi sẽ hiển thị tại đây...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Button("Đóng") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            .adaptiveBorderedButtonStyle()

            Spacer()

            if showResult && inputMode == .manual {
                Text(resultMessage)
                    .font(.caption)
                    .foregroundStyle(isSuccess ? Color.secondary : Color.red)
                    .lineLimit(1)
                    .frame(maxWidth: 320, alignment: .trailing)
            } else if !isConverting {
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
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Label(inputMode == .clipboard ? "Chuyển đổi Clipboard" : "Chuyển đổi", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .keyboardShortcut(.return)
            .disabled(!canConvert)
            .adaptiveProminentButtonStyle()
        }
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
    }

    private func performConversion() {
        let textToConvert = currentText
        guard !textToConvert.isEmpty else { return }

        isConverting = true
        showResult = false

        let sourceCode = sourceCodeTable
        let targetCode = targetCodeTable
        let mode = inputMode

        // If manual mode, first copy text to clipboard
        if mode == .manual {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(textToConvert, forType: .string)
        }

        Task { @MainActor in
            let success = PHTVConvertToolTextConversionService.quickConvertClipboard(
                fromCode: Int32(sourceCode.rawValue),
                toCode: Int32(targetCode.rawValue)
            )

            let pasteboard = NSPasteboard.general
            let newContent = pasteboard.string(forType: .string) ?? ""

            isConverting = false
            showResult = true

            if success && !newContent.isEmpty && newContent != textToConvert {
                isSuccess = true
                convertedContent = newContent
                resultMessage = "Đã chuyển đổi \(textToConvert.count) ký tự từ \(sourceCode.displayName) sang \(targetCode.displayName)"
                NSSound.beep()
            } else if newContent == textToConvert {
                isSuccess = false
                resultMessage = "Văn bản không thay đổi hoặc không chứa ký tự tiếng Việt."
            } else {
                isSuccess = false
                resultMessage = "Không thể chuyển đổi. Định dạng không khớp."
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
