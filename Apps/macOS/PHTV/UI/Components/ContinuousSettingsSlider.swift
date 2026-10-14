import SwiftUI

/// Continuous pointer tracking with discrete persisted values and no tick marks.
struct ContinuousSettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var onEditingChanged: ((Bool) -> Void)?
    @State private var dragValue: Double?

    var body: some View {
        Slider(
            value: Binding(
                get: { dragValue ?? value },
                set: { proposed in
                    if dragValue != nil { dragValue = proposed }
                    let next = normalized(proposed)
                    if value != next { value = next }
                }
            ),
            in: range,
            onEditingChanged: { editing in
                if editing {
                    dragValue = value
                } else {
                    if let dragValue { value = normalized(dragValue) }
                    dragValue = nil
                }
                onEditingChanged?(editing)
            }
        )
    }

    private func normalized(_ proposed: Double) -> Double {
        let rounded = step > 0
            ? range.lowerBound + ((proposed - range.lowerBound) / step).rounded() * step
            : proposed
        return min(range.upperBound, max(range.lowerBound, rounded))
    }
}
