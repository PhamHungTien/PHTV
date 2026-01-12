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

    @StateObject private var klipyClient = KlipyAPIClient.shared
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
                    .onChange(of: searchText) { newValue in
                        if newValue.isEmpty {
                            klipyClient.searchResults = []
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if searchText == newValue {
                                    klipyClient.search(query: newValue)
                                }
                            }
                        }
                    }
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
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
            if klipyClient.trendingGIFs.isEmpty {
                klipyClient.fetchTrending()
            }
        }
    }

    private func copyGIF(_ gif: KlipyGIF) {
        klipyClient.recordGIFUsage(gif)
        guard let url = URL(string: gif.fullURL) else {
            NSLog("[GIFPicker] Invalid GIF URL: %@", gif.fullURL)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            // Check for network errors
            if let error = error {
                NSLog("[GIFPicker] GIF download error: %@", error.localizedDescription)
                return
            }

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                guard 200...299 ~= httpResponse.statusCode else {
                    NSLog("[GIFPicker] GIF download HTTP error: %d", httpResponse.statusCode)
                    return
                }
            }

            // Ensure we have data
            guard let data = data else {
                NSLog("[GIFPicker] No data received for GIF: %@", gif.slug)
                return
            }

            DispatchQueue.main.async {
                NSLog("[GIFPicker] GIF downloaded: %@", gif.slug)

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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
        }.resume()
    }
}

