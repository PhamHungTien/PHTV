//
//  GIFOnlyView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Carbon

// MARK: - GIF Only View

struct GIFOnlyView: View {
    var onClose: (() -> Void)?

    @Environment(KlipyAPIClient.self) private var klipyClient
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12),
        GridItem(.fixed(80), spacing: 12)
    ]

    var displayedGIFs: [KlipyGIF] {
        searchText.isEmpty ? klipyClient.trendingGIFs : klipyClient.searchResults
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                TextField("Tìm GIFs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
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
                PHTVRoundedRect(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        PHTVRoundedRect(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(isSearchFocused ? 0.3 : 0), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // GIF Grid
            ScrollView {
                if klipyClient.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                } else if displayedGIFs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: searchText.isEmpty ? "photo.on.rectangle.angled" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(searchText.isEmpty ? "Đang tải GIFs..." : "Không tìm thấy GIF")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(displayedGIFs) { gif in
                            GIFThumbnailView(gif: gif) {
                                copyGIF(gif)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(PHTVRoundedRect(cornerRadius: 8))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            isSearchFocused = true
            if klipyClient.trendingGIFs.isEmpty {
                await klipyClient.fetchTrending()
            }
        }
        .task(id: searchText) {
            if searchText.isEmpty {
                klipyClient.searchResults = []
                return
            }

            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await klipyClient.search(query: searchText)
        }
    }

    private func copyGIF(_ gif: KlipyGIF) {
        klipyClient.recordGIFUsage(gif)
        guard let url = URL(string: gif.fullURL) else {
            NSLog("[GIFPicker] Invalid GIF URL: %@", gif.fullURL)
            return
        }

        Task { @MainActor in
            guard let data = await downloadRemoteData(
                from: url,
                logPrefix: "[GIFPicker]",
                itemDescription: "GIF",
                identifier: gif.slug
            ) else {
                return
            }

            let phtpDir = getPHTPMediaDirectory()
            let gifURL = phtpDir.appendingPathComponent("\(gif.slug).gif")

            do {
                try data.write(to: gifURL)
            } catch {
                NSLog("[GIFPicker] Failed to save GIF: %@", error.localizedDescription)
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([gifURL as NSPasteboardWriting])
            _ = pasteboard.setData(data, forType: .fileURL)

            // Close panel first
            onClose?()

            // Small delay to allow panel to close and frontmost app to regain focus
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            NSLog("[GIFPicker] Pasting GIF...")

            let source = CGEventSource(stateID: .hidSystemState)

            // Press Command
            if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true) {
                cmdDown.flags = .maskCommand
                cmdDown.post(tap: .cghidEventTap)
            }

            // Press V
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

            NSLog("[GIFPicker] Paste command sent")

            // Clean up file after paste
            deleteFileAfterDelay(gifURL)
        }
    }
}
