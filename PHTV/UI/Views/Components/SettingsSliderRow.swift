//
//  SettingsSliderRow.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

struct SettingsSliderRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let minValue: Double
    let maxValue: Double
    let step: Double
    @Binding var value: Double
    var valueFormatter: (Double) -> String = { String(format: "%.0f", $0) }
    var onEditingChanged: ((Bool) -> Void)? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            ZStack {
                PHTVRoundedRect(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        PHTVRoundedRect(cornerRadius: 8)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 36, height: 36)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Slider & Value (Right aligned)
            VStack(alignment: .trailing, spacing: 4) {
                // Value Display
                Text(valueFormatter(value))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(iconColor)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background {
                        Capsule()
                            .fill(iconColor.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    }
                
                // Slider
                NonDraggableSlider(
                    value: $value,
                    in: minValue...maxValue,
                    step: step,
                    tint: iconColor,
                    onEditingChanged: onEditingChanged
                )
                .frame(width: 130, height: 20)
            }
            .padding(.top, -2)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    VStack(spacing: 16) {
        SettingsSliderRow(
            icon: "speaker.wave.2",
            iconColor: .blue,
            title: "Âm lượng beep",
            subtitle: "Điều chỉnh mức âm lượng tiếng beep",
            minValue: 0.0,
            maxValue: 1.0,
            step: 0.1,
            value: .constant(0.5),
            valueFormatter: { String(format: "%.0f%%", $0 * 100) }
        )

        Divider()
            .padding(.leading, 50)

        SettingsSliderRow(
            icon: "arrow.up.left.and.arrow.down.right",
            iconColor: .blue,
            title: "Kích thước icon",
            subtitle: "Điều chỉnh kích thước icon trên menu bar",
            minValue: 8.0,
            maxValue: 24.0,
            step: 1.0,
            value: .constant(14.0),
            valueFormatter: { String(format: "%.0f pt", $0) }
        )
    }
    .padding(16)
}

// MARK: - Non-Draggable Slider

/// A slider that prevents window dragging when interacting with it
struct NonDraggableSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color
    var onEditingChanged: ((Bool) -> Void)?

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        tint: Color,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.tint = tint
        self.onEditingChanged = onEditingChanged
    }

    func makeNSView(context: Context) -> NonDraggableSliderContainer {
        let container = NonDraggableSliderContainer()
        
        let slider = container.slider
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        slider.isContinuous = true
        
        // Remove tick marks
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false

        // Style the slider
        if #available(macOS 11.0, *) {
            slider.controlSize = .small
        }
        
        // Apply tint
        if let nsColor = convertToNSColor(tint) {
             slider.trackFillColor = nsColor
        }

        return container
    }

    func updateNSView(_ container: NonDraggableSliderContainer, context: Context) {
        let slider = container.slider
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        if abs(slider.doubleValue - value) > 0.001 {
            slider.doubleValue = value
        }
        
        // Update tint color
        if let nsColor = convertToNSColor(tint) {
             slider.trackFillColor = nsColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: NonDraggableSlider
        var isEditing = false

        init(_ parent: NonDraggableSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NSSlider) {
            let newValue = sender.doubleValue
            let steppedValue = round(newValue / parent.step) * parent.step
            parent.value = steppedValue

            // Handle editing state
            let currentEvent = NSApp.currentEvent
            let isMouseUp = currentEvent?.type == .leftMouseUp

            if !isEditing {
                isEditing = true
                parent.onEditingChanged?(true)
            }

            if isMouseUp {
                isEditing = false
                parent.onEditingChanged?(false)
            }
        }
    }
}

/// Container view that prevents window dragging
class NonDraggableSliderContainer: NSView {
    let slider = NonDraggableNSSlider()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSlider()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSlider()
    }

    private func setupSlider() {
        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)
        
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    override var mouseDownCanMoveWindow: Bool { false }
    
    // Ensure mouse down events are handled by this view or its subviews
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }
}

/// Custom NSSlider that prevents window dragging
class NonDraggableNSSlider: NSSlider {
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

// Helper to convert SwiftUI Color to NSColor
fileprivate func convertToNSColor(_ color: Color) -> NSColor? {
    guard let cgColor = color.cgColor else { return nil }
    return NSColor(cgColor: cgColor)
}
