import SwiftUI

/// The system popover supplies the glass surface; the QR stays opaque for scanning.
struct DonateQRPopoverView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Text("Ủng hộ PHTV")
                    .font(.headline)

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 16, height: 16)
                }
                .adaptiveBorderedButtonStyle()
                .buttonBorderShape(.circle)
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)
                .help("Đóng")
                .accessibilityLabel("Đóng mã QR ủng hộ")
            }

            Link(destination: PHTVCommunityLinks.youtube) {
                Label("Đăng ký kênh YouTube", systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .adaptiveBorderedButtonStyle()
            .controlSize(.large)
            .help("Theo dõi kênh YouTube của Phạm Hùng Tiến để ủng hộ PHTV")

            qrCode

            Text("Quét bằng ngân hàng hoặc MoMo")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Link(destination: URL(string: "https://www.paypal.com/paypalme/phamhungtien1404")!) {
                Label("Ủng hộ qua PayPal", systemImage: "arrow.up.right")
                    .frame(maxWidth: .infinity)
            }
            .adaptiveBorderedButtonStyle()
            .controlSize(.large)
            .help("Mở trang PayPal của Phạm Hùng Tiến trong trình duyệt")
        }
        .padding(20)
        .frame(width: 336)
    }

    @ViewBuilder
    private var qrCode: some View {
        if let image = NSImage(named: "donate") {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 264, height: 264)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                }
                .accessibilityLabel("Mã VietQR ủng hộ PHTV qua TPBank")
        } else {
            ContentUnavailableView(
                "Không tìm thấy mã QR",
                systemImage: "qrcode",
                description: Text("Vui lòng đóng và mở lại cửa sổ này.")
            )
            .frame(height: 288)
        }
    }
}

#Preview {
    DonateQRPopoverView()
}
