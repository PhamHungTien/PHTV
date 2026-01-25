//
//  EmojiPickerView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct EmojiPickerView: View {
    var onEmojiSelected: (String) -> Void
    var onClose: (() -> Void)?

    // Remember last selected tab using UserDefaults
    @State private var selectedCategory: Int
    @Namespace private var categoryNamespace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private static let lastTabKey = "PHTVPickerLastTab"

    init(onEmojiSelected: @escaping (String) -> Void, onClose: (() -> Void)? = nil) {
        self.onEmojiSelected = onEmojiSelected
        self.onClose = onClose
        // Load last selected tab, default to -2 ("Tất cả") if not set
        let savedTab = UserDefaults.standard.integer(forKey: EmojiPickerView.lastTabKey)
        // Validate saved tab is valid (-2, -3, -4, -5)
        if [-2, -3, -4, -5].contains(savedTab) {
            _selectedCategory = State(initialValue: savedTab)
        } else {
            _selectedCategory = State(initialValue: -2)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button and drag handle
            headerView
                .contentShape(Rectangle())
                .background(WindowDragHandle())


            // Category tabs
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // All Content tab
                        CategoryTab(
                            isSelected: selectedCategory == -2,
                            icon: "sparkles",
                            label: "Tất cả",
                            namespace: categoryNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = -2
                            }
                        }
                        .id(-2)
                        .onAppear {
                            // Scroll to saved/selected category when view appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollProxy.scrollTo(selectedCategory, anchor: .center)
                            }
                        }

                        // Emoji tab
                        CategoryTab(
                            isSelected: selectedCategory == -3,
                            icon: "face.smiling.fill",
                            label: "Emoji",
                            namespace: categoryNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = -3
                            }
                        }
                        .id(-3)

                        // GIF tab
                        CategoryTab(
                            isSelected: selectedCategory == -4,
                            icon: "photo.on.rectangle.angled",
                            label: "GIF",
                            namespace: categoryNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = -4
                            }
                        }
                        .id(-4)

                        // Sticker tab
                        CategoryTab(
                            isSelected: selectedCategory == -5,
                            icon: "sparkle",
                            label: "Sticker",
                            namespace: categoryNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = -5
                            }
                        }
                        .id(-5)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 10)
            }

            Divider()
                .opacity(0.5)

            // Content area - show different tabs based on selectedCategory
            if selectedCategory == -2 {
                // All Content tab with search (Emojis, GIFs, Stickers)
                UnifiedContentView(onEmojiSelected: onEmojiSelected, onClose: onClose)
                    .frame(height: 320)
            } else if selectedCategory == -3 {
                // Emoji tab - show all emoji categories
                EmojiCategoriesView(onEmojiSelected: onEmojiSelected)
                    .frame(height: 320)
            } else if selectedCategory == -4 {
                // GIF tab
                GIFOnlyView(onClose: onClose)
                    .frame(height: 320)
            } else if selectedCategory == -5 {
                // Sticker tab
                StickerOnlyView(onClose: onClose)
                    .frame(height: 320)
            }
        }
        .frame(width: 380)
        .onChange(of: selectedCategory) { newValue in
            // Save selected tab to UserDefaults
            UserDefaults.standard.set(newValue, forKey: EmojiPickerView.lastTabKey)
        }
        .background {
            pickerBackground
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 8) {
            // Drag handle icon (left side) with Liquid Glass
            if #available(macOS 26.0, *), !reduceTransparency {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular, in: Circle())
                            .opacity(0.5)
                    }
                    .help("Kéo để di chuyển")
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 20)
                    .help("Kéo để di chuyển")
            }

            Text("PHTV Picker")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            // Close button with Liquid Glass
            GlassCloseButton {
                onClose?()
            }
            .help("Đóng (ESC)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Picker Background

    @ViewBuilder
    private var pickerBackground: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            // Enhanced Liquid Glass design for macOS 26+
            PHTVRoundedRect(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor).opacity(colorScheme == .dark ? 0.2 : 0.25))
                .glassEffect(
                    .regular,
                    in: .rect(corners: .fixed(16), isUniform: true)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 24, y: 10)
                .overlay(
                    PHTVRoundedRect(cornerRadius: 16)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), lineWidth: 1)
                )
        } else {
            // Fallback glassmorphism for older macOS
            ZStack {
                PHTVRoundedRect(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
            .clipShape(PHTVRoundedRect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        }
    }
}
