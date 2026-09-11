import AppKit

// Deterministic typography keeps the wordmark sharp at every macOS icon size.
let destination = CommandLine.arguments[1]
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 196, yRadius: 196)
NSColor.black.setFill()
tile.fill()
let attributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 156, weight: .semibold),
  .foregroundColor: NSColor.white
]
// AppKit's bitmap origin is at the bottom, so draw the lower word first.
let lines = ["Token", "IsLand"] as [NSString]
let lineSpacing: CGFloat = 18
let heights = lines.map { $0.size(withAttributes: attributes).height }
let totalHeight = heights.reduce(0, +) + lineSpacing
var y = (CGFloat(size) - totalHeight) / 2
for (index, line) in lines.enumerated() {
  let textSize = line.size(withAttributes: attributes)
  line.draw(at: NSPoint(x: (CGFloat(size) - textSize.width) / 2, y: y), withAttributes: attributes)
  y += textSize.height
  if index == 0 { y += lineSpacing }
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
