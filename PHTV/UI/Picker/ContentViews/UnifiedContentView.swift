//
//  UnifiedContentView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Carbon

// MARK: - Unified Content View

struct UnifiedContentView: View {
    var onEmojiSelected: (String) -> Void
    var onClose: (() -> Void)?

    @StateObject private var klipyClient = KlipyAPIClient.shared
    private let database = EmojiDatabase.shared

    @State private var searchText = ""
    @State private var emojiSearchResults: [EmojiItem] = []
    @State private var searchTask: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    private let mediaColumns = [
        GridItem(.fixed(70), spacing: 12),
        GridItem(.fixed(70), spacing: 12),
        GridItem(.fixed(70), spacing: 12),
        GridItem(.fixed(70), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                TextField("Tìm icons, GIFs, stickers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        // Cancel previous search task
                        searchTask?.cancel()

                        if newValue.isEmpty {
                            // Clear results immediately
                            emojiSearchResults = []
                            klipyClient.searchResults = []
                            klipyClient.stickerSearchResults = []
                        } else {
                            // Debounce search - wait for user to stop typing
                            let task = DispatchWorkItem { [self] in
                                performSearch(query: newValue)
                            }
                            searchTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchTask?.cancel()
                        searchText = ""
                        emojiSearchResults = []
                        isSearchFocused = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(isSearchFocused ? 0.3 : 0), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

            Divider()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Emojis Section
                if !searchText.isEmpty {
                    // Search results for emojis (cached)
                    if !emojiSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("Emojis")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 4)

                            LazyVGrid(columns: iconColumns, spacing: 12) {
                                ForEach(emojiSearchResults.prefix(14), id: \.id) { emojiItem in
                                    Button(action: {
                                        onEmojiSelected(emojiItem.emoji)
                                    }) {
                                        Text(emojiItem.emoji)
                                            .font(.system(size: 30))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(height: 40)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(10)
                    }
                } else if !database.getFrequentlyUsedEmojis(limit: 14).isEmpty {
                    // Recent emojis
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("Emojis")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(columns: iconColumns, spacing: 12) {
                            ForEach(database.getFrequentlyUsedEmojis(limit: 14), id: \.self) { emoji in
                                if let emojiItem = database.getEmojiItem(for: emoji) {
                                    Button(action: {
                                        onEmojiSelected(emojiItem.emoji)
                                    }) {
                                        Text(emojiItem.emoji)
                                            .font(.system(size: 30))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(height: 40)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(10)
                }

                // GIFs Section
                if !searchText.isEmpty {
                    // Search results for GIFs
                    if !klipyClient.searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("GIFs")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 4)

                            LazyVGrid(columns: mediaColumns, spacing: 12) {
                                ForEach(klipyClient.searchResults.prefix(8), id: \.id) { gif in
                                    GIFThumbnailView(gif: gif) {
                                        copyGIFURL(gif)
                                    }
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(10)
                    }
                } else if !klipyClient.getRecentGIFIDs().isEmpty {
                    // Recent GIFs
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("GIFs")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(columns: mediaColumns, spacing: 12) {
                            ForEach(klipyClient.getRecentGIFs().prefix(8), id: \.id) { gif in
                                GIFThumbnailView(gif: gif) {
                                    copyGIFURL(gif)
                                }
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(10)
                }

                // Stickers Section
                if !searchText.isEmpty {
                    // Search results for Stickers
                    if !klipyClient.stickerSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("Stickers")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 4)

                            LazyVGrid(columns: mediaColumns, spacing: 12) {
                                ForEach(klipyClient.stickerSearchResults.prefix(8), id: \.id) { sticker in
                                    GIFThumbnailView(gif: sticker, onTap: {
                                        copyStickerURL(sticker)
                                    }, contentType: "Sticker")
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(10)
                    }
                } else if !klipyClient.getRecentStickerIDs().isEmpty {
                    // Recent Stickers
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("Stickers")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(columns: mediaColumns, spacing: 12) {
                            ForEach(klipyClient.getRecentStickers().prefix(8), id: \.id) { sticker in
                                GIFThumbnailView(gif: sticker, onTap: {
                                    copyStickerURL(sticker)
                                }, contentType: "Sticker")
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(10)
                }

                // Empty state
                if !searchText.isEmpty {
                    // Search empty state
                    let hasAnyResults = !emojiSearchResults.isEmpty ||
                                       !klipyClient.searchResults.isEmpty ||
                                       !klipyClient.stickerSearchResults.isEmpty
                    if !hasAnyResults {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 56))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Không tìm thấy kết quả")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Thử tìm kiếm với từ khóa khác")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                } else if database.getFrequentlyUsedEmojis(limit: 1).isEmpty &&
                   klipyClient.getRecentGIFIDs().isEmpty &&
                   klipyClient.getRecentStickerIDs().isEmpty {
                    // Recent items empty state
                    VStack(spacing: 12) {
                        Image(systemName: "flame")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Chưa có nội dung thường dùng")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Emojis, GIFs và Stickers\nbạn dùng nhiều nhất sẽ hiển thị ở đây")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        }
        .onAppear {
            isSearchFocused = true
            // Fetch content if empty
            if klipyClient.trendingGIFs.isEmpty {
                klipyClient.fetchTrending()
            }
            if klipyClient.trendingStickers.isEmpty {
                klipyClient.fetchTrendingStickers()
            }
        }
    }

    // Perform search across all content types
    private func performSearch(query: String) {
        // Search Emojis (cached to avoid repeated computation)
        emojiSearchResults = database.search(query)
        // Search GIFs
        klipyClient.search(query: query)
        // Search Stickers
        klipyClient.searchStickers(query: query)
    }

    // Helper functions to copy media
    private func copyGIFURL(_ gif: KlipyGIF) {
        klipyClient.recordGIFUsage(gif)
        guard let url = URL(string: gif.fullURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let tempURL = saveTempGIF(data: data, filename: gif.slug) {
                    NSLog("[PHTPPicker] GIF downloaded: %@", gif.slug)

                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([tempURL as NSPasteboardWriting])
                    _ = pasteboard.setData(data, forType: .fileURL)

                    // Close panel first
                    onClose?()

                    // Small delay to allow panel to close and frontmost app to regain focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NSLog("[PHTPPicker] Pasting GIF...")
                        simulatePaste()

                        // Clean up file after paste
                        deleteFileAfterDelay(tempURL)
                    }
                }
            }
        }.resume()
    }

    private func copyStickerURL(_ sticker: KlipyGIF) {
        klipyClient.recordStickerUsage(sticker)
        guard let url = URL(string: sticker.fullURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let tempURL = saveTempSticker(data: data, filename: sticker.slug) {
                    NSLog("[PHTPPicker] Sticker downloaded: %@", sticker.slug)

                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([tempURL as NSPasteboardWriting])

                    // Close panel first
                    onClose?()

                    // Small delay to allow panel to close and frontmost app to regain focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NSLog("[PHTPPicker] Pasting Sticker...")
                        simulatePaste()

                        // Clean up file after paste
                        deleteFileAfterDelay(tempURL)
                    }
                }
            }
        }.resume()
    }

    private func getPHTPMediaDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let phtpDir = tempDir.appendingPathComponent("PHTPMedia", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: phtpDir.path) {
            try? FileManager.default.createDirectory(at: phtpDir, withIntermediateDirectories: true)
        }

        return phtpDir
    }

    private func saveTempGIF(data: Data, filename: String) -> URL? {
        let phtpDir = getPHTPMediaDirectory()
        let gifURL = phtpDir.appendingPathComponent("\(filename).gif")
        do {
            try data.write(to: gifURL)
            return gifURL
        } catch {
            NSLog("[PHTPPicker] Error saving GIF: %@", error.localizedDescription)
            return nil
        }
    }

    private func saveTempSticker(data: Data, filename: String) -> URL? {
        let phtpDir = getPHTPMediaDirectory()
        let stickerURL = phtpDir.appendingPathComponent("\(filename).png")
        do {
            try data.write(to: stickerURL)
            return stickerURL
        } catch {
            NSLog("[PHTPPicker] Error saving Sticker: %@", error.localizedDescription)
            return nil
        }
    }

    private func deleteFileAfterDelay(_ fileURL: URL, delay: TimeInterval = 5.0) {
        // Delete file after a delay to ensure paste is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            try? FileManager.default.removeItem(at: fileURL)
            NSLog("[PHTPPicker] Cleaned up file: %@", fileURL.lastPathComponent)
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Press Command
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cghidEventTap)
        }

        // Press V (0x09 = kVK_ANSI_V)
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
        }

        // Release V
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cghidEventTap)
        }

        // Release Command
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) {
            cmdUp.post(tap: .cghidEventTap)
        }

        NSLog("[PHTPPicker] Paste command sent")
    }
}

