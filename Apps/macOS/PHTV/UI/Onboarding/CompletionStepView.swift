import SwiftUI

struct CompletionStepView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: appState.isTypingPermissionReady ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(appState.isTypingPermissionReady ? "Sẵn sàng gõ tiếng Việt" : "Đã lưu thiết lập")
                .font(.system(size: 26, weight: .bold))
            Text(appState.isTypingPermissionReady
                 ? "Chuyển Việt/Anh từ thanh menu. Mở Cài đặt bất cứ khi nào bạn cần."
                 : "Cấp quyền nhập liệu trong Cài đặt để bắt đầu dùng bộ gõ.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
