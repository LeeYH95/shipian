import AppKit

// A separate development icon made from a system glyph. No upstream artwork.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("Icon bitmap failed") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let size = CGFloat(pixels)
        NSColor(srgbRed: 0.94, green: 0.96, blue: 1, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: size * 0.06, y: size * 0.06, width: size * 0.88, height: size * 0.88), xRadius: size * 0.20, yRadius: size * 0.20).fill()
        if let glyph = NSImage(systemSymbolName: "note.text", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size * 0.55, weight: .regular)) {
            let rect = NSRect(x: size * 0.24, y: size * 0.22, width: size * 0.52, height: size * 0.56)
            NSColor(srgbRed: 0.25, green: 0.36, blue: 0.69, alpha: 1).setFill()
            glyph.draw(in: rect)
            rect.fill(using: .sourceAtop)
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Icon encoding failed") }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
