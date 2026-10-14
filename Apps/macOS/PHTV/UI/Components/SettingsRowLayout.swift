import SwiftUI

/// Keeps a label and its controls on one line only when both fit at their ideal size.
/// A single layout preserves control identity, focus and recording state while resizing.
struct SettingsRowLayout: Layout {
    var spacing: CGFloat = 12

    private func measurement(_ subviews: Subviews, width: CGFloat?) -> (CGSize, CGSize, Bool) {
        let label = subviews[0].sizeThatFits(.unspecified)
        let control = subviews[1].sizeThatFits(.unspecified)
        let available = max(0, width ?? (label.width + spacing + control.width))
        let stacked = label.width + spacing + control.width > available
        let labelSize = subviews[0].sizeThatFits(ProposedViewSize(
            width: stacked ? available : max(0, available - spacing - control.width), height: nil
        ))
        let controlSize = subviews[1].sizeThatFits(ProposedViewSize(width: min(available, control.width), height: nil))
        return (labelSize, controlSize, stacked)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let (label, control, stacked) = measurement(subviews, width: proposal.width)
        return CGSize(
            width: proposal.width ?? (label.width + spacing + control.width),
            height: stacked ? label.height + spacing + control.height : max(label.height, control.height)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let (label, control, stacked) = measurement(subviews, width: bounds.width)
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: stacked ? bounds.minY : bounds.midY - label.height / 2),
            proposal: ProposedViewSize(label)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.maxX - control.width, y: stacked ? bounds.minY + label.height + spacing : bounds.midY - control.height / 2),
            proposal: ProposedViewSize(control)
        )
    }
}
