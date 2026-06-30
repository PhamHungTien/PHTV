//
//  KeyboardCleaningSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct KeyboardCleaningSettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(UserDefaultsKey.keyboardCleaningDuration) private var durationSeconds = Defaults.keyboardCleaningDuration
    @State private var snapshot = PHTVKeyboardCleaningService.snapshot()

    private var canStartCleaning: Bool {
        appState.systemState.isTypingPermissionReady && !snapshot.isActive
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                cleaningSection
                durationSection
                permissionSection

                Spacer(minLength: SettingsLayout.sectionSpacing)
            }
            .settingsPageFrame()
        }
        .settingsBackground()
        .task {
            await refreshCleaningSnapshotLoop()
        }
        .task {
            await observeCleaningStateChanges()
        }
    }

    private var cleaningSection: some View {
        SettingsCard(
            title: "Lau bàn phím",
            subtitle: "Tạm chặn phím khi vệ sinh bàn phím",
            icon: "keyboard.badge.eye"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(snapshot.isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                        Image(systemName: snapshot.isActive ? "lock.fill" : "keyboard")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(snapshot.isActive ? Color.accentColor : .secondary)
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(snapshot.isActive ? "Đang chặn bàn phím" : "Sẵn sàng lau bàn phím")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                if snapshot.isActive {
                    VStack(alignment: .leading, spacing: 7) {
                        ProgressView(value: snapshot.progress, total: 1)
                            .progressViewStyle(.linear)

                        Text("\(snapshot.remainingSeconds) giây còn lại")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        startCleaning()
                    } label: {
                        Label("Bắt đầu", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canStartCleaning)

                    Button {
                        stopCleaning()
                    } label: {
                        Label("Dừng", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!snapshot.isActive)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var durationSection: some View {
        SettingsCard(
            title: "Thời gian",
            subtitle: "Chọn thời lượng chặn phím",
            icon: "timer"
        ) {
            SettingsPickerRow(
                title: "Thời lượng",
                selection: $durationSeconds,
                controlWidth: 150
            ) {
                Text("30 giây").tag(30.0)
                Text("1 phút").tag(60.0)
                Text("2 phút").tag(120.0)
                Text("5 phút").tag(300.0)
            }
        }
    }

    private var permissionSection: some View {
        SettingsCard(
            title: "Quyền nhập liệu",
            subtitle: "Trạng thái quyền cần cho chế độ lau bàn phím",
            icon: "checkmark.shield"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: appState.systemState.isTypingPermissionReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(appState.systemState.isTypingPermissionReady ? .green : .orange)

                    Text(permissionText)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }

                if !appState.systemState.isTypingPermissionReady {
                    Button {
                        AppDelegate.current()?.continuePermissionGuidanceIfNeeded(forceOpenSystemSettings: true)
                    } label: {
                        Label("Cấp quyền nhập liệu", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 3)
        }
    }

    private var statusText: String {
        if snapshot.isActive {
            return "Phím bấm sẽ bị bỏ qua. Chuột và trackpad vẫn dùng để dừng chế độ này."
        }
        if appState.systemState.isTypingPermissionReady {
            return "Bấm Bắt đầu rồi lau bàn phím. Chế độ sẽ tự tắt khi hết thời gian."
        }
        return "Cần quyền Trợ năng để chặn phím an toàn."
    }

    private var permissionText: String {
        switch appState.systemState.typingRuntimeHealth.phase {
        case .ready:
            return "Đã sẵn sàng"
        case .accessibilityRequired:
            return "Cần cấp Accessibility"
        case .waitingForEventTap:
            return "Đã cấp quyền, đang khởi tạo bộ lắng nghe phím"
        case .relaunchPending:
            return "Đang khởi động lại để nhận quyền mới"
        }
    }

    private func startCleaning() {
        snapshot = PHTVKeyboardCleaningService.startCleaning(durationSeconds: durationSeconds)
    }

    private func stopCleaning() {
        snapshot = PHTVKeyboardCleaningService.stopCleaning()
    }

    @MainActor
    private func refreshCleaningSnapshotLoop() async {
        while !Task.isCancelled {
            snapshot = PHTVKeyboardCleaningService.snapshot()
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    @MainActor
    private func observeCleaningStateChanges() async {
        for await notification in NotificationCenter.default.notifications(
            named: NotificationName.keyboardCleaningStateChanged
        ) {
            guard !Task.isCancelled else { return }
            if let nextSnapshot = notification.object as? PHTVKeyboardCleaningSnapshot {
                snapshot = nextSnapshot
            } else {
                snapshot = PHTVKeyboardCleaningService.snapshot()
            }
        }
    }
}

#Preview {
    KeyboardCleaningSettingsView()
        .environment(AppState.shared)
        .frame(width: 560, height: 560)
}
