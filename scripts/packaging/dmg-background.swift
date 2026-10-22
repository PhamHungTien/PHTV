#!/usr/bin/env swift
import AppKit
import Foundation

// Keep logical dimensions and icon centres aligned with dmg-settings.py.
guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: dmg-background.swift OUTPUT.png")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let width: CGFloat = 640
let height: CGFloat = 420
for scale in [1, 2] {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width) * scale, pixelsHigh: Int(height) * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to allocate DMG background")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let rect = NSRect(x: 0, y: 0, width: width, height: height)
    NSGradient(starting: NSColor(srgbRed: 0.98, green: 0.985, blue: 1, alpha: 1),
               ending: NSColor(srgbRed: 0.93, green: 0.95, blue: 0.98, alpha: 1))!
        .draw(in: rect, angle: -90)

    func centered(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
        ]
        let textWidth = text.size(withAttributes: attributes).width
        text.draw(at: NSPoint(x: (width - textWidth) / 2, y: y), withAttributes: attributes)
    }
    let ink = NSColor(srgbRed: 0.12, green: 0.16, blue: 0.23, alpha: 1)
    let secondary = NSColor(srgbRed: 0.38, green: 0.43, blue: 0.51, alpha: 1)
    centered("PHTV", y: 330, size: 30, weight: .semibold, color: ink)
    centered("Kéo PHTV vào Applications để cài đặt", y: 300, size: 15, weight: .regular, color: secondary)

    for x: CGFloat in [170, 470] {
        NSColor.white.withAlphaComponent(0.65).setFill()
        let well = NSBezierPath(roundedRect: NSRect(x: x - 65, y: 145, width: 130, height: 130),
                                xRadius: 28, yRadius: 28)
        well.fill()
    }
    let arrow = NSBezierPath()
    arrow.lineWidth = 2.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 296, y: 210))
    arrow.line(to: NSPoint(x: 344, y: 210))
    arrow.move(to: NSPoint(x: 334, y: 220))
    arrow.line(to: NSPoint(x: 344, y: 210))
    arrow.line(to: NSPoint(x: 334, y: 200))
    secondary.withAlphaComponent(0.65).setStroke()
    arrow.stroke()

    centered("Sau khi cài, mở PHTV từ thư mục Applications.", y: 64, size: 13, weight: .regular, color: secondary)
    centered("phamhungtien.com/PHTV", y: 40, size: 11, weight: .medium, color: secondary)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode DMG background")
    }
    // Retina naming is basename@2x.png, recognized automatically by dmgbuild.
    let target = scale == 1 ? output : output.deletingLastPathComponent()
        .appendingPathComponent(output.deletingPathExtension().lastPathComponent + "@2x.png")
    try png.write(to: target, options: .atomic)
}
