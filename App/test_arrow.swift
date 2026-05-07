import AppKit

let width: CGFloat = 660
let height: CGFloat = 400
let canvasRect = NSRect(x: 0, y: 0, width: width, height: height)
let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: Int(width),
  pixelsHigh: Int(height),
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .calibratedRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
)!

NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

if let arrowImage = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil) {
    let arrowColor = NSColor(calibratedRed: 0.65, green: 0.68, blue: 0.72, alpha: 0.8)
    let config = NSImage.SymbolConfiguration(pointSize: 70, weight: .regular)
        .applying(.init(hierarchicalColor: arrowColor))
        
    if let configuredArrow = arrowImage.withSymbolConfiguration(config) {
        let arrowSize = configuredArrow.size
        print("Arrow drawn with size: \(arrowSize)")
    }
}
