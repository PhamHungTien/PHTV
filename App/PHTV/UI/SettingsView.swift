//
//  SettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Main Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .typing
    @State private var lastTab: SettingsTab = .typing
    @State private var searchText: String = ""

    private var filteredSettings: [SettingsItem] {
        if searchText.isEmpty {
            return []
        }
        return SettingsItem.allItems.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText)
                || item.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
                .environmentObject(appState)
                .frame(minWidth: 400, minHeight: 400)
                .modifier(DetailViewGlassModifier())
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: appState.showIconOnDock) { newValue in
            // When dock icon toggle is changed, update immediately and save
            let appDelegate = NSApp.delegate as? AppDelegate
            NSLog("[SettingsView] onChange - showIconOnDock changed to %@", newValue ? "true" : "false")
            appDelegate?.showIcon(newValue)  // This one saves to UserDefaults
        }
        .onChange(of: selectedTab) { newValue in
            // Release cached app icons when leaving icon-heavy tabs.
            if lastTab == .apps || lastTab == .typing {
                AppIconCache.shared.clear()
            }
            lastTab = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationName.showAboutTab)) { _ in
            selectedTab = .about
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationName.showMacroTab)) { _ in
            selectedTab = .macro
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationName.showConvertToolSheet)) { _ in
            // Switch to System tab first, then SystemSettingsView will show the sheet
            if selectedTab != .system {
                selectedTab = .system
                // Post notification for SystemSettingsView after it's mounted
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: NotificationName.openConvertToolSheet, object: nil)
                }
            }
        }
    }

    @ViewBuilder
    private var sidebarView: some View {
        let list = List(selection: $selectedTab) {
            if searchText.isEmpty {
                // Normal tab list grouped by section
                ForEach(SettingsTabSection.allCases) { section in
                    Section(section.title) {
                        ForEach(section.tabs) { tab in
                            SettingsSidebarRow(tab: tab)
                                .tag(tab)
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        }
                    }
                }
            } else {
                // Search results with improved visual feedback
                if filteredSettings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("Không có kết quả cho \"\(searchText)\"")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Hãy thử từ khóa khác")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ForEach(filteredSettings) { item in
                        SearchResultRow(item: item) {
                            withAnimation(.phtvMorph) {
                                selectedTab = item.tab
                                searchText = ""
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .conditionalSearchable(text: $searchText, prompt: "Tìm nhanh cài đặt…")
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
        .animation(nil, value: selectedTab)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    NotificationCenter.default.post(name: NotificationName.showOnboarding, object: nil)
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("Xem lại hướng dẫn & giới thiệu")
            }
        }

        if #available(macOS 26.0, *) {
            list
        } else {
            list
                .scrollContentBackground(.hidden)
                .background(sidebarBackground)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        // Lazy loading: Only create the view for selected tab
        // This significantly reduces memory usage by not instantiating all 7 tabs at once
        Group {
            if selectedTab == .typing {
                TypingSettingsView()
            } else if selectedTab == .hotkeys {
                HotkeySettingsView()
            } else if selectedTab == .macro {
                MacroSettingsView()
            } else if selectedTab == .apps {
                AppsSettingsView()
            } else if selectedTab == .system {
                SystemSettingsView()
            } else if selectedTab == .bugReport {
                BugReportView()
            } else if selectedTab == .about {
                AboutView()
            }
        }
        // Avoid forced teardown to reduce peak allocations on tab switch.
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor).opacity(0.98),
                    Color(NSColor.controlBackgroundColor).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if #available(macOS 12.0, *) {
                Rectangle()
                    .fill(.thinMaterial)
                    .opacity(0.55)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sidebar Row
struct SettingsSidebarRow: View {
    let tab: SettingsTab
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 10) {
            // Icon with white/neutral background
            ZStack {
                PHTVRoundedRect(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        PHTVRoundedRect(cornerRadius: 6)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
                    )

                Image(systemName: tab.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 24, height: 24)

            Text(tab.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let item: SettingsItem
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon with white/neutral background
                ZStack {
                    PHTVRoundedRect(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            PHTVRoundedRect(cornerRadius: 6)
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
                        )

                    Image(systemName: item.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(item.tab.title)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail View Glass Modifier

/// Applies backgroundExtensionEffect() only to the detail view,
/// preserving the sidebar's native appearance while extending
/// glass effect into the toolbar area for the content pane.
struct DetailViewGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *),
           SettingsVisualEffects.enableBackgroundExtensionEffect,
           !reduceTransparency {
            content
                .backgroundExtensionEffect()
        } else {
            content
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
