//
//  ViewModifiers.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Shape Utilities

struct PHTVRoundedRect: InsettableShape {
    var cornerRadius: CGFloat
    var style: RoundedCornerStyle = .continuous
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> PHTVRoundedRect {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let effectiveRadius = max(0, cornerRadius - insetAmount)

        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            return ConcentricRectangle
                .rect(corners: .fixed(effectiveRadius), isUniform: true)
                .path(in: insetRect)
        } else {
            return RoundedRectangle(cornerRadius: effectiveRadius, style: style)
                .path(in: insetRect)
        }
    }
}

extension View {
    // Apply consistent defaults for TextField across the app
    @ViewBuilder
    func settingsTextField() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || targetEnvironment(macCatalyst)
        if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *) {
            self
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
        } else {
            self
                .disableAutocorrection(true)
        }
        #elseif os(macOS)
        self
            .disableAutocorrection(true)
        #else
        self
        #endif
    }

    // Native text area fill for TextEditor and similar inputs
    func roundedTextArea() -> some View {
        self
            .padding(6)
            .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Settings Glass Effect

extension View {
    /// Uses the system's default Liquid Glass shape on macOS 26. The corner
    /// parameter is retained for older call sites, but Settings no longer
    /// forces custom radii for Liquid Glass.
    @ViewBuilder
    func settingsGlassEffect(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect()
        } else {
            self
        }
    }

    /// Uses the system's default Liquid Glass effect. Shape-specialized call
    /// sites are intentionally normalized to the default native shape.
    @ViewBuilder
    func settingsGlassEffect<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect()
        } else {
            self
        }
    }

    /// Uses interactive Liquid Glass with the default system shape.
    @ViewBuilder
    func settingsInteractiveGlassEffect(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive())
        } else {
            self
        }
    }

    /// Uses tinted Liquid Glass with the default system shape.
    @ViewBuilder
    func settingsTintedGlassEffect(cornerRadius: CGFloat, tint: Color) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint))
        } else {
            self
        }
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.6))
            .foregroundColor(.primary)
            .cornerRadius(6)
            .overlay(
                PHTVRoundedRect(cornerRadius: 6)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Liquid Glass Pill Button Style (macOS 26+)

struct GlassPillButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var tint: Color = .accentColor
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? tint.opacity(colorScheme == .dark ? 0.2 : 0.15) : Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.6))
            )
            .foregroundStyle(isSelected ? tint : .secondary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? tint.opacity(colorScheme == .dark ? 0.3 : 0.25) : Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Animations

extension Animation {
    static let phtv = Animation.easeInOut(duration: 0.25)
    static let phtvSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    // macOS 26+ animations
    @available(macOS 26.0, *)
    static let phtvBouncy = Animation.bouncy(duration: 0.4, extraBounce: 0.15)

    @available(macOS 26.0, *)
    static let phtvSnappy = Animation.snappy(duration: 0.3)

    // Glass morphing animation - smoother transitions
    static let phtvMorph = Animation.spring(response: 0.35, dampingFraction: 0.85)
}

// MARK: - Color Extensions

extension Color {
    static let phtvPrimary = Color.accentColor
    static let phtvSecondary = Color(NSColor.secondaryLabelColor)
    static let phtvBackground = Color(NSColor.windowBackgroundColor)
    static let phtvSurface = Color(NSColor.controlBackgroundColor)
}

// MARK: - Adaptive Button Styles

extension View {
    /// Uses the native prominent button surface for the current OS.
    @ViewBuilder
    func adaptiveProminentButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Uses the native bordered button surface for the current OS.
    @ViewBuilder
    func adaptiveBorderedButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Applies the native Settings control button style without custom shapes.
    @ViewBuilder
    func settingsControlButtonStyle(isProminent: Bool = false) -> some View {
        if isProminent {
            adaptiveProminentButtonStyle()
        } else {
            adaptiveBorderedButtonStyle()
        }
    }
}

struct SettingsIconTile<Content: View>: View {
    let color: Color
    var size: CGFloat = 24
    var cornerRadius: CGFloat = 6
    let content: Content

    init(
        color: Color,
        size: CGFloat = 24,
        cornerRadius: CGFloat = 6,
        @ViewBuilder content: () -> Content
    ) {
        self.color = color
        self.size = size
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Settings View Background

/// Central toggle for heavy visual effects in Settings.
/// Keep custom visual effects off so Settings relies on system controls and GroupBox chrome.
enum SettingsVisualEffects {
    static let enableGlassEffects = false
    static let enableMaterials = false
}

/// Applies consistent background for settings views
struct SettingsViewBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

extension View {
    /// Applies appropriate background for settings detail views
    func settingsBackground() -> some View {
        modifier(SettingsViewBackground())
    }

    /// Applies searchable modifier to the sidebar
    func conditionalSearchable(text: Binding<String>, prompt: String) -> some View {
        self.searchable(text: text, placement: .sidebar, prompt: prompt)
    }

    /// Uses the macOS 26 native search-toolbar behavior when available.
    @ViewBuilder
    func settingsSearchToolbarBehavior() -> some View {
        if #available(macOS 26.0, *) {
            self.searchToolbarBehavior(.automatic)
        } else {
            self
        }
    }

    /// Retained for older call sites; Settings now uses the system scene background.
    @ViewBuilder
    func settingsNativeWindowBackground() -> some View {
        self
    }

    /// Compatible foregroundStyle
    func compatForegroundStyle<S: ShapeStyle>(_ style: S) -> some View {
        self.foregroundStyle(style)
    }

    /// Compatible foregroundStyle for HierarchicalShapeStyle
    func compatForegroundPrimary() -> some View {
        self.foregroundStyle(.primary)
    }

    func compatForegroundSecondary() -> some View {
        self.foregroundStyle(.secondary)
    }

    @ViewBuilder
    func settingsGlassContainer() -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func settingsGlassContainer(spacing: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func settingsGlassID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

// MARK: - Tab Indicator

/// A morphing tab indicator with matchedGeometryEffect
struct LiquidGlassTabIndicator: View {
    let isSelected: Bool
    let cornerRadius: CGFloat
    let namespace: Namespace.ID
    let id: String

    @Environment(\.colorScheme) private var colorScheme

    init(
        isSelected: Bool,
        cornerRadius: CGFloat = 8,
        namespace: Namespace.ID,
        id: String = "tabIndicator"
    ) {
        self.isSelected = isSelected
        self.cornerRadius = cornerRadius
        self.namespace = namespace
        self.id = id
    }

    var body: some View {
        if isSelected {
            PHTVRoundedRect(cornerRadius: cornerRadius)
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                .overlay(
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                )
                .matchedGeometryEffect(id: id, in: namespace)
        }
    }
}

// MARK: - Floating Glass Card (macOS 26+)

/// A floating card container that uses native glass on macOS 26 when enabled.
struct FloatingGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                if #available(macOS 26.0, *),
                   SettingsVisualEffects.enableGlassEffects,
                   !reduceTransparency {
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(colorScheme == .dark ? 0.2 : 0.25))
                        .settingsGlassEffect(cornerRadius: cornerRadius)
                } else if SettingsVisualEffects.enableMaterials, !reduceTransparency {
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .fill(.regularMaterial)
                } else {
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
                }
            }
            .overlay(
                PHTVRoundedRect(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08), lineWidth: 1)
            )
    }
}

// MARK: - Glass Close Button (macOS 26+)

/// A circular close button with Liquid Glass effect
struct GlassCloseButton: View {
    let action: () -> Void
    var size: CGFloat = 28
    var iconSize: CGFloat = 11

    @State private var isHovering = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(isHovering ? 0.25 : 0.15))
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(isHovering ? 0.35 : 0.2), lineWidth: 1)
                    )
                Image(systemName: "xmark")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(.red)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
            }
            .frame(width: size, height: size)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Glass Segmented Control (macOS 26+)

/// A segmented control with Liquid Glass effect and morphing selection
struct GlassSegmentedControl<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    let content: Content

    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: 8) {
                content
            }
        } else {
            HStack(spacing: 4) {
                content
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)
        }
    }
}

// MARK: - Glass Segmented Picker (macOS 26+)

/// A picker that uses Liquid Glass morphing effect for segment selection
struct GlassSegmentedPicker<SelectionValue: Hashable & CaseIterable & Identifiable, Label: View>: View
where SelectionValue.AllCases: RandomAccessCollection {
    @Binding var selection: SelectionValue
    let label: (SelectionValue) -> Label

    @Namespace private var pickerNamespace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    init(
        selection: Binding<SelectionValue>,
        @ViewBuilder label: @escaping (SelectionValue) -> Label
    ) {
        self._selection = selection
        self.label = label
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(SelectionValue.allCases)) { item in
                segmentButton(for: item)
            }
        }
        .padding(4)
        .background(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segmentButton(for item: SelectionValue) -> some View {
        let isSelected = selection == item

        Button {
            withAnimation(.phtvMorph) {
                selection = item
            }
        } label: {
            label(item)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        PHTVRoundedRect(cornerRadius: 7)
                            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                            .overlay(
                                PHTVRoundedRect(cornerRadius: 7)
                                    .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "segmentSelection", in: pickerNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

/// Convenience extension for String-labelled pickers
extension GlassSegmentedPicker where Label == Text {
    init<S: StringProtocol>(
        selection: Binding<SelectionValue>,
        label: @escaping (SelectionValue) -> S
    ) {
        self._selection = selection
        self.label = { Text(label($0)) }
    }
}

// MARK: - Menu Picker Style

/// No-op retained so older call sites use native menu picker styling.
struct GlassMenuPickerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    /// Uses native menu picker styling.
    func glassMenuPickerStyle() -> some View {
        modifier(GlassMenuPickerStyle())
    }
}

// MARK: - Search Field Style

struct GlassSearchFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    /// Uses native search field styling.
    func glassSearchFieldStyle() -> some View {
        modifier(GlassSearchFieldStyle())
    }
}

// MARK: - Conditional Symbol Effects (macOS 14+)

extension View {
    func conditionalPulseEffect() -> some View {
        self.symbolEffect(.pulse, options: .repeating)
    }

    func conditionalPulseEffect<V: Equatable>(value: V) -> some View {
        self.symbolEffect(.pulse, options: .repeating, value: value)
    }

    func conditionalBounceEffect<V: Equatable>(value: V) -> some View {
        self.symbolEffect(.bounce, value: value)
    }
}
