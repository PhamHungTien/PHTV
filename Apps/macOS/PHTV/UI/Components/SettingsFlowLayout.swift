import SwiftUI

/// Wraps action buttons without hiding them in a horizontally clipped toolbar.
struct SettingsFlowLayout: Layout {
    var spacing: CGFloat = 8

    private func arrangement(subviews: Subviews, width: CGFloat) -> ([CGRect], CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (frames, CGSize(width: usedWidth, height: y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = arrangement(subviews: subviews, width: max(0, proposal.width ?? .greatestFiniteMagnitude)).1
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrangement(subviews: subviews, width: bounds.width).0
        for (index, frame) in frames.enumerated() {
            let rowHeight = frames.filter { $0.minY == frame.minY }.map(\.height).max() ?? frame.height
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY + (rowHeight - frame.height) / 2),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
}
