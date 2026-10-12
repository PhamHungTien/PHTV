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
        VStack(alignment: .leading, spacing: 8) {
            if entries.isEmpty {
                Text("Chưa có phụ âm bổ sung.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56, maximum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(entries, id: \.self) { entry in
                        HStack(spacing: 4) {
                            Text(entry).font(.system(.callout, design: .monospaced).weight(.medium))
                            Spacer(minLength: 0)
                            Button {
                                entries.removeAll { $0 == entry }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Xoá phụ âm \(entry)")
                            .help("Xoá \(entry)")
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Z, DZ", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .focused($inputFocused)
                    .accessibilityLabel("Phụ âm mới, một hoặc hai chữ cái")
                    .help("Nhập 1–2 chữ cái phụ âm không dấu. Không phân biệt hoa/thường.")
                    .onSubmit(addEntry)
                Button(action: addEntry) { Label("Thêm", systemImage: "plus") }
                    .disabled(candidate == nil || validation != nil)
                Spacer()
                Button("Mặc định") {
                    entries = PHTVCustomConsonants.defaults
                    draft = ""
                }
                .disabled(entries == PHTVCustomConsonants.defaults)
                .help("Khôi phục Z, F, W, J và DZ")
                .accessibilityLabel("Khôi phục phụ âm mặc định")
            }
            .controlSize(.small)
            if let validation {
                Text(validation)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private func addEntry() {
        guard let candidate, validation == nil else { return }
        entries.append(candidate)
        draft = ""
        inputFocused = true
    }
}
