//
//  ConvertToolView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

#if canImport(FoundationModels)
import FoundationModels
#endif

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
    case manual = "Chuyển văn bản"
    case clipboard = "Chuyển Clipboard"

    var id: String { rawValue }
}

struct ConvertToolView: View {
    @Environment(\.dismiss) private var dismiss

    @SceneStorage("ConvertToolInputMode") private var storedInputMode = ConvertInputMode.manual.rawValue
    @AppStorage(UserDefaultsKey.convertToolFromCode) private var storedSourceCodeTable = Defaults.convertToolFromCode
    @AppStorage(UserDefaultsKey.convertToolToCode) private var storedTargetCodeTable = Defaults.convertToolToCode
    
    // Additional options stored in UserDefaults
    @AppStorage("convertToolToAllCaps") private var toAllCaps = false
    @AppStorage("convertToolToAllNonCaps") private var toAllNonCaps = false
    @AppStorage("convertToolToCapsFirstLetter") private var toCapsFirstLetter = false
    @AppStorage("convertToolToCapsEachWord") private var toCapsEachWord = false
    @AppStorage("convertToolRemoveMark") private var removeMark = false
    @AppStorage("convertToolLiveConvert") private var liveConvert = true

    @State private var inputText: String = ""
    @State private var clipboardContent: String = ""
    @State private var convertedContent: String = ""
    @State private var isConverting = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    @State private var showCopiedMessage = false
    
    // macOS 27 On-Device AI State
    @State private var isAIAvailable = false
    @State private var isDetectingAI = false

    private enum CaseTransformationMode: String, CaseIterable, Identifiable {
        case none = "Không đổi chữ"
        case allCaps = "CHỮ HOA"
        case allNonCaps = "chữ thường"
        case capsFirstLetter = "Hoa đầu câu"
        case capsEachWord = "Hoa mỗi từ"

        var id: String { rawValue }
    }

    private var caseTransformation: CaseTransformationMode {
        get {
            if toAllCaps { return .allCaps }
            if toAllNonCaps { return .allNonCaps }
            if toCapsFirstLetter { return .capsFirstLetter }
            if toCapsEachWord { return .capsEachWord }
            return .none
        }
        nonmutating set {
            toAllCaps = newValue == .allCaps
            toAllNonCaps = newValue == .allNonCaps
            toCapsFirstLetter = newValue == .capsFirstLetter
            toCapsEachWord = newValue == .capsEachWord
        }
    }

    private var inputMode: ConvertInputMode {
        get { ConvertInputMode(rawValue: storedInputMode) ?? .manual }
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
            .padding(.bottom, 8)

            Divider()

            // Pickers and Quick Presets Toolbar
            toolbarView
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
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
            .padding(16)

            Divider()

            // Footer
            footerView
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
        .settingsBackground()
        .frame(width: 680, height: 480)
        .task {
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                isAIAvailable = SystemLanguageModel.default.isAvailable
            }
            #endif
        }
        .task(id: inputMode) {
            guard inputMode == .clipboard else { return }
            loadClipboardContent()
        }
        .onChange(of: inputText) { _, _ in
            if liveConvert && inputMode == .manual {
                performLiveConversion()
            }
        }
        .onChange(of: sourceCodeTable) { _, _ in
            if liveConvert && inputMode == .manual {
                performLiveConversion()
            }
        }
        .onChange(of: targetCodeTable) { _, _ in
            if liveConvert && inputMode == .manual {
                performLiveConversion()
            }
        }
        .onChange(of: toAllCaps) { _, _ in
            if liveConvert && inputMode == .manual {
                performLiveConversion()
            }
        }
        .onChange(of: toAllNonCaps) { _, _ in
            if liveConvert && inputMode == .manual {
                performLiveConversion()
            }
        }
        .onChange(of: toCapsFirstLetter) { _, _ in
            if liveConvert && inputMode == .manual {
                performLiveConversion()
            }
        }
        .onChange(of: toCapsEachWord) { _, _ in
            if liveConvert && inputMode == .manual {
                performLiveConversion()
            }
        }
        .onChange(of: removeMark) { _, _ in
            if liveConvert && inputMode == .manual {
                performLiveConversion()
            }
        }
        .onChange(of: liveConvert) { _, newValue in
            if newValue && inputMode == .manual {
                performLiveConversion()
            }
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

                Text("Chuyển đổi văn bản giữa các bảng mã tiếng Việt")
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
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Toolbar View (Pickers & Presets)
    private var toolbarView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                // Source Picker
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Từ bảng mã")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if isAIAvailable {
                            Button(action: detectSourceEncodingWithAI) {
                                HStack(spacing: 3) {
                                    if isDetectingAI {
                                        ProgressView()
                                            .controlSize(.small)
                                            .scaleEffect(0.6)
                                            .frame(width: 10, height: 10)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text("Nhận diện (AI)")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDetectingAI)
                        }
                    }
                    
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

    // MARK: - Clipboard View (Dashboard Layout)
    private var clipboardView: some View {
        VStack(spacing: 12) {
            // Dashboard Card
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    // Clipboard Icon with background glow
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bảng tạm hệ thống")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if isClipboardEmpty {
                            Text("Clipboard hiện tại đang trống hoặc không có chữ")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Chứa \(clipboardContent.count) ký tự (khoảng \(clipboardContent.split(separator: " ").count) từ)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Refresh Button
                    Button(action: loadClipboardContent) {
                        Label("Làm mới", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                
                Divider()
                
                // Preview box
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nội dung xem trước:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if isClipboardEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundStyle(.tertiary)
                            Text("Không có dữ liệu văn bản. Hãy sao chép văn bản cần chuyển mã trước.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(6)
                    } else {
                        ScrollView {
                            Text(clipboardContent)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(6)
                    }
                }
                .frame(height: 64)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(NSColor.separatorColor), lineWidth: 1))
            .settingsGlassEffect(cornerRadius: 12)
            
            // Clipboard Options Strip
            HStack(spacing: 20) {
                // Dropdown for Case transformation
                HStack(spacing: 6) {
                    Text("Chuyển chữ:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { caseTransformation },
                        set: { caseTransformation = $0; showResult = false }
                    )) {
                        ForEach(CaseTransformationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                
                // Checkbox for Accents Removal
                Toggle("Bỏ dấu", isOn: Binding(
                    get: { removeMark },
                    set: { removeMark = $0; showResult = false }
                ))
                .toggleStyle(.checkbox)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Action Banner
            if showResult {
                HStack(spacing: 8) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isSuccess ? .green : .red)
                    Text(resultMessage)
                        .font(.caption)
                        .foregroundStyle(isSuccess ? .green : .red)
                    Spacer()
                }
                .padding(8)
                .background(isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
    }

    // MARK: - Manual Input View
    private var manualInputView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Left Column (Source Editor)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Văn bản gốc", systemImage: "doc.text")
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
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .roundedTextArea()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                        
                        if inputText.isEmpty {
                            Text("Nhập hoặc dán văn bản tại đây...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Text("\(inputText.count) ký tự")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Right Column (Target/Output View)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Văn bản sau chuyển", systemImage: "doc.plaintext")
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
                                Image(systemName: showCopiedMessage ? "checkmark.circle.fill" : "doc.on.doc")
                                Text(showCopiedMessage ? "Đã copy" : "Sao chép")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(showCopiedMessage ? .green : Color.accentColor)
                        .disabled(convertedContent.isEmpty)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: .constant(convertedContent))
                            .font(.system(.body, design: .monospaced))
                            .roundedTextArea()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .opacity(0.9)
                        
                        if convertedContent.isEmpty {
                            Text("Kết quả chuyển đổi sẽ hiển thị tại đây...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Text("\(convertedContent.count) ký tự")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Options strip
            HStack(spacing: 20) {
                // Dropdown for Case transformation
                HStack(spacing: 6) {
                    Text("Chuyển chữ:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { caseTransformation },
                        set: { caseTransformation = $0; if liveConvert { performLiveConversion() } }
                    )) {
                        ForEach(CaseTransformationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                
                // Checkbox for Accents Removal
                Toggle("Bỏ dấu", isOn: Binding(
                    get: { removeMark },
                    set: { removeMark = $0; if liveConvert { performLiveConversion() } }
                ))
                .toggleStyle(.checkbox)
                
                Spacer()
                
                // Toggle for Live convert
                Toggle(isOn: $liveConvert) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                        Text("Chuyển đổi trực tiếp")
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.top, 4)
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
            } else if !isConverting && inputMode == .manual {
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                if inputMode == .clipboard {
                    performClipboardConversion()
                } else {
                    performManualConversion()
                }
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
        if liveConvert {
            performLiveConversion()
        }
    }

    private func performLiveConversion() {
        guard !inputText.isEmpty else {
            convertedContent = ""
            showResult = false
            return
        }
        
        let sourceCode = sourceCodeTable
        let targetCode = targetCodeTable
        guard sourceCode != targetCode else {
            convertedContent = ""
            return
        }
        
        let defaults = UserDefaults.standard
        let originalFromCode = defaults.integer(forKey: UserDefaultsKey.convertToolFromCode)
        let originalToCode = defaults.integer(forKey: UserDefaultsKey.convertToolToCode)
        let originalAllCaps = defaults.bool(forKey: "convertToolToAllCaps")
        let originalAllNonCaps = defaults.bool(forKey: "convertToolToAllNonCaps")
        let originalCapsFirst = defaults.bool(forKey: "convertToolToCapsFirstLetter")
        let originalCapsEach = defaults.bool(forKey: "convertToolToCapsEachWord")
        let originalRemoveMark = defaults.bool(forKey: "convertToolRemoveMark")
        
        defaults.set(sourceCode.rawValue, forKey: UserDefaultsKey.convertToolFromCode)
        defaults.set(targetCode.rawValue, forKey: UserDefaultsKey.convertToolToCode)
        defaults.set(toAllCaps, forKey: "convertToolToAllCaps")
        defaults.set(toAllNonCaps, forKey: "convertToolToAllNonCaps")
        defaults.set(toCapsFirstLetter, forKey: "convertToolToCapsFirstLetter")
        defaults.set(toCapsEachWord, forKey: "convertToolToCapsEachWord")
        defaults.set(removeMark, forKey: "convertToolRemoveMark")
        
        let result = PHTVConvertToolTextConversionService.convertText(inputText)
        
        defaults.set(originalFromCode, forKey: UserDefaultsKey.convertToolFromCode)
        defaults.set(originalToCode, forKey: UserDefaultsKey.convertToolToCode)
        defaults.set(originalAllCaps, forKey: "convertToolToAllCaps")
        defaults.set(originalAllNonCaps, forKey: "convertToolToAllNonCaps")
        defaults.set(originalCapsFirst, forKey: "convertToolToCapsFirstLetter")
        defaults.set(originalCapsEach, forKey: "convertToolToCapsEachWord")
        defaults.set(originalRemoveMark, forKey: "convertToolRemoveMark")
        
        convertedContent = result
        isSuccess = true
        showResult = true
        resultMessage = "Đã tự động chuyển đổi \(inputText.count) ký tự"
    }

    private func performManualConversion() {
        guard !inputText.isEmpty else { return }
        
        isConverting = true
        showResult = false
        
        let sourceCode = sourceCodeTable
        let targetCode = targetCodeTable
        
        Task { @MainActor in
            let defaults = UserDefaults.standard
            let originalFromCode = defaults.integer(forKey: UserDefaultsKey.convertToolFromCode)
            let originalToCode = defaults.integer(forKey: UserDefaultsKey.convertToolToCode)
            let originalAllCaps = defaults.bool(forKey: "convertToolToAllCaps")
            let originalAllNonCaps = defaults.bool(forKey: "convertToolToAllNonCaps")
            let originalCapsFirst = defaults.bool(forKey: "convertToolToCapsFirstLetter")
            let originalCapsEach = defaults.bool(forKey: "convertToolToCapsEachWord")
            let originalRemoveMark = defaults.bool(forKey: "convertToolRemoveMark")
            
            defaults.set(sourceCode.rawValue, forKey: UserDefaultsKey.convertToolFromCode)
            defaults.set(targetCode.rawValue, forKey: UserDefaultsKey.convertToolToCode)
            defaults.set(toAllCaps, forKey: "convertToolToAllCaps")
            defaults.set(toAllNonCaps, forKey: "convertToolToAllNonCaps")
            defaults.set(toCapsFirstLetter, forKey: "convertToolToCapsFirstLetter")
            defaults.set(toCapsEachWord, forKey: "convertToolToCapsEachWord")
            defaults.set(removeMark, forKey: "convertToolRemoveMark")
            
            let result = PHTVConvertToolTextConversionService.convertText(inputText)
            
            defaults.set(originalFromCode, forKey: UserDefaultsKey.convertToolFromCode)
            defaults.set(originalToCode, forKey: UserDefaultsKey.convertToolToCode)
            defaults.set(originalAllCaps, forKey: "convertToolToAllCaps")
            defaults.set(originalAllNonCaps, forKey: "convertToolToAllNonCaps")
            defaults.set(originalCapsFirst, forKey: "convertToolToCapsFirstLetter")
            defaults.set(originalCapsEach, forKey: "convertToolToCapsEachWord")
            defaults.set(originalRemoveMark, forKey: "convertToolRemoveMark")
            
            isConverting = false
            showResult = true
            
            if !result.isEmpty && result != inputText {
                isSuccess = true
                convertedContent = result
                resultMessage = "Đã chuyển đổi \(inputText.count) ký tự từ \(sourceCode.displayName) sang \(targetCode.displayName)"
                NSSound.beep()
            } else if result == inputText {
                isSuccess = false
                resultMessage = "Văn bản không thay đổi hoặc không chứa ký tự tiếng Việt."
            } else {
                isSuccess = false
                resultMessage = "Không thể chuyển đổi."
            }
        }
    }

    private func performClipboardConversion() {
        let textToConvert = clipboardContent
        guard !textToConvert.isEmpty else { return }
        
        isConverting = true
        showResult = false
        
        let sourceCode = sourceCodeTable
        let targetCode = targetCodeTable
        
        // Capture choices into defaults for the service
        let defaults = UserDefaults.standard
        let originalAllCaps = defaults.bool(forKey: "convertToolToAllCaps")
        let originalAllNonCaps = defaults.bool(forKey: "convertToolToAllNonCaps")
        let originalCapsFirst = defaults.bool(forKey: "convertToolToCapsFirstLetter")
        let originalCapsEach = defaults.bool(forKey: "convertToolToCapsEachWord")
        let originalRemoveMark = defaults.bool(forKey: "convertToolRemoveMark")
        
        defaults.set(toAllCaps, forKey: "convertToolToAllCaps")
        defaults.set(toAllNonCaps, forKey: "convertToolToAllNonCaps")
        defaults.set(toCapsFirstLetter, forKey: "convertToolToCapsFirstLetter")
        defaults.set(toCapsEachWord, forKey: "convertToolToCapsEachWord")
        defaults.set(removeMark, forKey: "convertToolRemoveMark")
        
        Task { @MainActor in
            let success = PHTVConvertToolTextConversionService.quickConvertClipboard(
                fromCode: Int32(sourceCode.rawValue),
                toCode: Int32(targetCode.rawValue)
            )
            
            // Restore defaults
            defaults.set(originalAllCaps, forKey: "convertToolToAllCaps")
            defaults.set(originalAllNonCaps, forKey: "convertToolToAllNonCaps")
            defaults.set(originalCapsFirst, forKey: "convertToolToCapsFirstLetter")
            defaults.set(originalCapsEach, forKey: "convertToolToCapsEachWord")
            defaults.set(originalRemoveMark, forKey: "convertToolRemoveMark")
            
            let pasteboard = NSPasteboard.general
            let newContent = pasteboard.string(forType: .string) ?? ""
            
            isConverting = false
            showResult = true
            
            if success && !newContent.isEmpty && newContent != textToConvert {
                isSuccess = true
                clipboardContent = newContent
                resultMessage = "Đã chuyển đổi thành công clipboard (\(newContent.count) ký tự)"
                NSSound.beep()
            } else if newContent == textToConvert {
                isSuccess = false
                resultMessage = "Không đổi hoặc không chứa ký tự tiếng Việt cần chuyển."
            } else {
                isSuccess = false
                resultMessage = "Lỗi khi chuyển đổi clipboard."
            }
        }
    }

    private func copyResultToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(convertedContent, forType: .string)
        resultMessage = "Đã copy kết quả vào clipboard!"
    }
    
    // MARK: - macOS 27 On-Device AI Detection Logic
    private func detectSourceEncodingWithAI() {
        let text = inputText
        guard !text.isEmpty else { return }
        
        isDetectingAI = true
        showResult = false
        
        Task { @MainActor in
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                do {
                    let session = LanguageModelSession()
                    let prompt = """
                    Analyze this Vietnamese text snippet and determine its encoding format. Answer with ONLY one of these exact names: 'Unicode', 'TCVN3', 'VNI Windows', 'Unicode Compound', or 'CP 1258'. Do not include any other text, explanation, or conversational filler.
                    
                    Text snippet:
                    "\(text.prefix(150))"
                    """
                    
                    let response = try await session.respond(to: prompt)
                    let responseText = response.content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    
                    isDetectingAI = false
                    
                    if responseText.contains("tcvn3") || responseText.contains("abc") {
                        sourceCodeTable = .tcvn3
                        showAIDetectionSuccess(detected: .tcvn3)
                    } else if responseText.contains("vni") {
                        sourceCodeTable = .vniWindows
                        showAIDetectionSuccess(detected: .vniWindows)
                    } else if responseText.contains("compound") || responseText.contains("tổ hợp") {
                        sourceCodeTable = .unicodeCompound
                        showAIDetectionSuccess(detected: .unicodeCompound)
                    } else if responseText.contains("1258") {
                        sourceCodeTable = .cp1258
                        showAIDetectionSuccess(detected: .cp1258)
                    } else if responseText.contains("unicode") {
                        sourceCodeTable = .unicode
                        showAIDetectionSuccess(detected: .unicode)
                    } else {
                        isSuccess = false
                        showResult = true
                        resultMessage = "AI phản hồi không xác định: \(response.content)"
                    }
                } catch {
                    isDetectingAI = false
                    isSuccess = false
                    showResult = true
                    resultMessage = "Lỗi AI nhận diện: \(error.localizedDescription)"
                }
            } else {
                isDetectingAI = false
            }
            #else
            isDetectingAI = false
            #endif
        }
    }
    
    private func showAIDetectionSuccess(detected: ConvertCodeTable) {
        isSuccess = true
        showResult = true
        resultMessage = "AI nhận diện thành công bảng mã nguồn: \(detected.displayName)"
        NSSound.beep()
        if liveConvert {
            performLiveConversion()
        }
    }
}

#Preview {
    ConvertToolView()
}
