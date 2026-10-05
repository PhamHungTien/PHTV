import SwiftUI

struct PHTVCustomConsonantsEditor: View {
    @Binding var entries: [String]
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private var candidate: String? { PHTVCustomConsonants.normalizedEntry(draft) }
    private var validation: String? {
        if entries.count >= PHTVCustomConsonants.maximumCount { return "Tối đa 64 phụ âm tùy chỉnh." }
        guard !draft.isEmpty else { return nil }
        guard let candidate else { return "Nhập 1–2 chữ cái phụ âm không dấu, ví dụ Z hoặc DZ." }
        return entries.contains(candidate) ? "Phụ âm này đã có trong danh sách." : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chấp nhận thêm phụ âm đầu khi kiểm tra chính tả. Phụ âm tiếng Việt chuẩn luôn được giữ nguyên.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if entries.isEmpty {
                Text("Chưa có phụ âm bổ sung.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(entries, id: \.self) { entry in
                        HStack(spacing: 8) {
                            Text(entry).font(.system(.body, design: .monospaced).weight(.semibold))
                            Spacer(minLength: 0)
                            Button {
                                entries.removeAll { $0 == entry }
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Xoá phụ âm \(entry)")
                            .help("Xoá \(entry)")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Z hoặc DZ", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .focused($inputFocused)
                    .accessibilityLabel("Phụ âm mới, một hoặc hai chữ cái")
                    .onSubmit(addEntry)
                Button(action: addEntry) { Label("Thêm", systemImage: "plus") }
                    .disabled(candidate == nil || validation != nil)
                Spacer()
                Button("Khôi phục mặc định") {
                    entries = PHTVCustomConsonants.defaults
                    draft = ""
                }
                .disabled(entries == PHTVCustomConsonants.defaults)
                .help("Khôi phục Z, F, W, J và DZ")
            }
            Text(validation ?? "Một hoặc hai chữ cái • Không phân biệt chữ hoa, chữ thường")
                .font(.caption)
                .foregroundStyle(validation == nil ? Color.secondary : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    private func addEntry() {
        guard let candidate, validation == nil else { return }
        entries.append(candidate)
        draft = ""
        inputFocused = true
    }
}
