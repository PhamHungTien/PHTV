//
//  SendKeyStepByStepAppsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct SendKeyStepByStepAppsView: View {
    @Environment(AppState.self) private var appState
    @Binding var showingFilePicker: Bool
    @Binding var showingRunningApps: Bool
    @Binding var showingBundleIdInput: Bool
    var showHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showHeader {
                header
            }

            // Apps List
            if appState.sendKeyStepByStepApps.isEmpty {
                AppSelectionEmptyStateView(
                    iconName: "keyboard.badge.ellipsis",
                    title: "Chưa có ứng dụng nào",
                    subtitle: "Tự động bật gửi theo từng phím khi dùng các ứng dụng này",
                    onPickRunningApps: { showingRunningApps = true },
                    onPickFromApplications: { showingFilePicker = true }
                )
            } else {
                AppSelectionList(apps: appState.sendKeyStepByStepApps) { app in
                    appState.removeSendKeyStepByStepApp(app)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: true
        ) { result in
            handleFilePickerResult(result)
        }
        .sheet(isPresented: $showingRunningApps) {
            AppSelectionRunningAppsPickerView<SendKeyStepByStepApp> { apps in
                for app in apps {
                    appState.addSendKeyStepByStepApp(app)
                }
            }
        }
        .sheet(isPresented: $showingBundleIdInput) {
            ManualBundleIdInputView { bundleId in
                let name = resolveAppName(for: bundleId)
                let app = SendKeyStepByStepApp(bundleIdentifier: bundleId, name: name, path: "")
                appState.addSendKeyStepByStepApp(app)
            }
        }
    }

    private func resolveAppName(for bundleId: String) -> String {
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
           let name = runningApp.localizedName {
            return name
        }
        return bundleId.components(separatedBy: ".").last ?? bundleId
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        for url in urls {
            if let app = SendKeyStepByStepApp(from: url) {
                appState.addSendKeyStepByStepApp(app)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ứng dụng gửi theo từng phím")
                    .font(.headline)

                Text("Tự động bật gửi theo từng phím khi dùng các ứng dụng này")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button(action: { showingRunningApps = true }) {
                    Label("Chọn từ ứng dụng đang chạy", systemImage: "apps.iphone")
                }

                Button(action: { showingFilePicker = true }) {
                    Label("Chọn từ thư mục Applications", systemImage: "folder")
                }

                Divider()

                Button(action: { showingBundleIdInput = true }) {
                    Label("Nhập Bundle ID thủ công", systemImage: "keyboard")
                }
            } label: {
                Label("Thêm", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

#Preview {
    SendKeyStepByStepAppsView(
        showingFilePicker: .constant(false),
        showingRunningApps: .constant(false),
        showingBundleIdInput: .constant(false)
    )
        .environment(AppState.shared)
        .frame(width: 400)
        .padding()
}
