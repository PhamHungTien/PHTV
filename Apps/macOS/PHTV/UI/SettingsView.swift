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
    @Environment(AppState.self) private var appState
    @State private var selectedTab: SettingsTab = .typing
    @State private var searchText: String = ""

    private var filteredSettings: [SettingsItem] {
        SettingsItem.search(searchText)
    }

    var body: some View {
        settingsSplitView
            .onChange(of: appState.requestedSettingsTab, initial: true) { _, tab in
                guard let tab else { return }
                selectedTab = tab
                appState.requestedSettingsTab = nil
            }
            .onChange(of: appState.showIconOnDock) { _, newValue in
                // When dock icon toggle is changed, update immediately and save
                let appDelegate = AppDelegate.current()
                NSLog("[SettingsView] onChange - showIconOnDock changed to %@", newValue ? "true" : "false")
                appDelegate?.showIcon(newValue)  // This one saves to UserDefaults
            }
            .task {
                await observeTabSelectionNotification(named: NotificationName.showAboutTab, tab: .about)
            }
            .task {
                await observeTabSelectionNotification(named: NotificationName.showMacroTab, tab: .macro)
            }
            .task {
                await observeTabSelectionNotification(
                    named: NotificationName.showKeyboardCleaningTab,
                    tab: .keyboardCleaning
                )
            }
            .task {
                await observeConvertToolRequests()
            }
    }

    @MainActor
    private func observeTabSelectionNotification(named name: Notification.Name, tab: SettingsTab) async {
        for await _ in NotificationCenter.default.notifications(named: name) {
            guard !Task.isCancelled else { return }
            selectedTab = tab
        }
    }

    @MainActor
    private func observeConvertToolRequests() async {
        for await _ in NotificationCenter.default.notifications(named: NotificationName.showConvertToolSheet) {
            guard !Task.isCancelled else { return }

            // Switch to System tab first, then SystemSettingsView will show the sheet
            guard selectedTab != .system else { continue }
            selectedTab = .system

            // Give SystemSettingsView a moment to mount before asking it to open the sheet.
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(name: NotificationName.openConvertToolSheet, object: nil)
        }
    }

    private var settingsSplitView: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
                .environment(appState)
                .navigationTitle(selectedTab.title)
                // Tab selection replaces content immediately; the system owns sidebar animation.
                .animation(nil, value: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .conditionalSearchable(text: $searchText, prompt: "Tìm nhanh cài đặt…")
        .settingsSearchToolbarBehavior()
        // Let the split view resize its columns inside the freely resizable window.
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var sidebarView: some View {
        let list = List(selection: $selectedTab) {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Normal tab list grouped by section
                ForEach(SettingsTabSection.allCases) { section in
                    Section(section.title) {
                        ForEach(section.tabs) { tab in
                            SettingsSidebarRow(tab: tab)
                                .tag(tab)
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
                            selectedTab = item.tab
                            searchText = ""
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: SettingsLayout.sidebarMinWidth,
            ideal: SettingsLayout.sidebarIdealWidth,
            max: SettingsLayout.sidebarMaxWidth
        )
        .animation(nil, value: selectedTab)

        list
    }

    @ViewBuilder
    private var detailView: some View {
        // Lazy loading: Only create the view for selected tab.
        Group {
            if selectedTab == .typing {
                TypingSettingsView()
            } else if selectedTab == .phtvPicker {
                PHTVPickerSettingsView()
            } else if selectedTab == .clipboardHistory {
                ClipboardHistorySettingsView()
            } else if selectedTab == .keyboardCleaning {
                KeyboardCleaningSettingsView()
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
    }


}

// MARK: - Sidebar Row
struct SettingsSidebarRow: View {
    let tab: SettingsTab

    var body: some View {
        Label {
            Text(tab.title)
                .font(.body)
        } icon: {
            Image(systemName: tab.iconName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let item: SettingsItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.iconName)
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environment(AppState.shared)
}
