//
//  CustomDictionaryView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Custom Dictionary Word Model
struct CustomWord: Identifiable, Hashable, Codable {
    let id: UUID
    var word: String
    var type: WordType  // "en" for English, "vi" for Vietnamese

    enum WordType: String, Codable, CaseIterable {
        case english = "en"
        case vietnamese = "vi"

        var displayName: String {
            switch self {
            case .english: return "Tiếng Anh"
            case .vietnamese: return "Tiếng Việt"
            }
        }

        var shortName: String {
            switch self {
            case .english: return "EN"
            case .vietnamese: return "VI"
            }
        }

        var color: Color {
            switch self {
            case .english: return .blue
            case .vietnamese: return .green
            }
        }
    }

    init(word: String, type: WordType) {
        self.id = UUID()
        self.word = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        word = try container.decode(String.self, forKey: .word)
        type = try container.decode(WordType.self, forKey: .type)
    }
}

// MARK: - Custom Dictionary View
struct CustomDictionaryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    @State private var customWords: [CustomWord] = []
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var newWord = ""
    @State private var newWordType: CustomWord.WordType = .english
    @State private var showImportSheet = false
    @State private var showExportSheet = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var filteredWords: [CustomWord] {
        if searchText.isEmpty {
            return customWords.sorted { $0.word < $1.word }
        }
        return customWords.filter {
            $0.word.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.word < $1.word }
    }

    private var englishWords: [CustomWord] {
        filteredWords.filter { $0.type == .english }
    }

    private var vietnameseWords: [CustomWord] {
        filteredWords.filter { $0.type == .vietnamese }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Stats
                statsSection

                // Word list
                wordListSection
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "Tìm từ...")
        .onAppear {
            loadCustomWords()
        }
        .sheet(isPresented: $showAddSheet) {
            addWordSheet
        }
        .fileImporter(
            isPresented: $showImportSheet,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showExportSheet,
            document: CustomDictionaryDocument(words: customWords),
            contentType: .plainText,
            defaultFilename: "custom_dictionary.txt"
        ) { result in
            if case .failure(let error) = result {
                errorMessage = "Không thể xuất file: \(error.localizedDescription)"
                showError = true
            }
        }
        .alert("Lỗi", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Từ điển tùy chỉnh")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Thêm từ tiếng Anh hoặc tiếng Việt để cải thiện độ chính xác của tính năng tự động nhận diện.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "textformat.abc",
                title: "Tiếng Anh",
                value: "\(customWords.filter { $0.type == .english }.count)",
                color: .blue
            )

            StatCard(
                icon: "character.textbox",
                title: "Tiếng Việt",
                value: "\(customWords.filter { $0.type == .vietnamese }.count)",
                color: .green
            )

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Thêm", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.themeColor)

                Menu {
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Nhập từ file...", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        showExportSheet = true
                    } label: {
                        Label("Xuất ra file...", systemImage: "square.and.arrow.up")
                    }
                    .disabled(customWords.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Word List Section
    private var wordListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredWords.isEmpty {
                emptyStateView
            } else {
                // English words
                if !englishWords.isEmpty {
                    wordGroupSection(title: "Tiếng Anh", icon: "textformat.abc", words: englishWords, color: .blue)
                }

                // Vietnamese words
                if !vietnameseWords.isEmpty {
                    wordGroupSection(title: "Tiếng Việt", icon: "character.textbox", words: vietnameseWords, color: .green)
                }
            }
        }
    }

    private func wordGroupSection(title: String, icon: String, words: [CustomWord], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Text("(\(words.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 8)
            ], spacing: 8) {
                ForEach(words) { word in
                    wordChip(word)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func wordChip(_ word: CustomWord) -> some View {
        HStack(spacing: 6) {
            Text(word.word)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Button {
                deleteWord(word)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(word.type.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "Chưa có từ nào" : "Không tìm thấy '\(searchText)'")
                .font(.headline)

            if searchText.isEmpty {
                Text("Thêm từ tiếng Anh hoặc tiếng Việt để cải thiện tính năng tự động nhận diện.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Add Word Sheet
    private var addWordSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Thêm từ mới")
                    .font(.headline)
                Spacer()
                Button("Đóng") {
                    showAddSheet = false
                    newWord = ""
                }
            }

            Form {
                Section("Từ") {
                    TextField("Nhập từ (vd: vinfast, spotify)", text: $newWord)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Loại từ") {
                    Picker("Loại", selection: $newWordType) {
                        ForEach(CustomWord.WordType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(newWordType == .english
                         ? "Từ tiếng Anh sẽ được tự động khôi phục khi gõ nhầm tiếng Việt"
                         : "Từ tiếng Việt sẽ KHÔNG bị khôi phục thành tiếng Anh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Hủy") {
                    showAddSheet = false
                    newWord = ""
                }
                Button("Thêm") {
                    addWord()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.themeColor)
                .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 280)
    }

    // MARK: - Data Operations
    private func loadCustomWords() {
        if let data = UserDefaults.standard.data(forKey: "customDictionary"),
           let words = try? JSONDecoder().decode([CustomWord].self, from: data) {
            customWords = words
        }
    }

    private func saveCustomWords() {
        if let encoded = try? JSONEncoder().encode(customWords) {
            UserDefaults.standard.set(encoded, forKey: "customDictionary")
            UserDefaults.standard.synchronize()

            // Notify engine to reload
            NotificationCenter.default.post(name: NSNotification.Name("CustomDictionaryUpdated"), object: nil)
        }
    }

    private func addWord() {
        let trimmed = newWord.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check for duplicate
        if customWords.contains(where: { $0.word == trimmed }) {
            errorMessage = "Từ '\(trimmed)' đã tồn tại"
            showError = true
            return
        }

        let word = CustomWord(word: trimmed, type: newWordType)
        customWords.append(word)
        saveCustomWords()

        newWord = ""
        showAddSheet = false
    }

    private func deleteWord(_ word: CustomWord) {
        customWords.removeAll { $0.id == word.id }
        saveCustomWords()
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Không thể truy cập file"
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)

                var addedCount = 0
                for line in lines {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: ",")
                    let word = parts[0].lowercased().trimmingCharacters(in: .whitespaces)

                    guard !word.isEmpty else { continue }
                    guard !customWords.contains(where: { $0.word == word }) else { continue }

                    // Determine type: default to English, or use second column if present
                    var wordType: CustomWord.WordType = .english
                    if parts.count > 1 {
                        let typeStr = parts[1].lowercased().trimmingCharacters(in: .whitespaces)
                        if typeStr == "vi" || typeStr == "vietnamese" {
                            wordType = .vietnamese
                        }
                    }

                    customWords.append(CustomWord(word: word, type: wordType))
                    addedCount += 1
                }

                if addedCount > 0 {
                    saveCustomWords()
                }

                NSLog("[CustomDictionary] Imported \(addedCount) words")
            } catch {
                errorMessage = "Không thể đọc file: \(error.localizedDescription)"
                showError = true
            }

        case .failure(let error):
            errorMessage = "Không thể mở file: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Stat Card Component
private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Document for Export
struct CustomDictionaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var words: [CustomWord]

    init(words: [CustomWord]) {
        self.words = words
    }

    init(configuration: ReadConfiguration) throws {
        words = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let content = words.map { "\($0.word),\($0.type.rawValue)" }.joined(separator: "\n")
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview
struct CustomDictionaryView_Previews: PreviewProvider {
    static var previews: some View {
        CustomDictionaryView()
            .environmentObject(AppState.shared)
            .environmentObject(ThemeManager.shared)
            .frame(width: 600, height: 500)
    }
}
