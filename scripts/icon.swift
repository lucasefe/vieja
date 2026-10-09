// Renders the menu-bar symbol as a 1024px app icon PNG. Usage: swift scripts/icon.swift out.png
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    // macOS icon grid: the squircle fills ~82% of the canvas
    let inset = size * 0.09
    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: size * 0.18, yRadius: size * 0.18)
    NSGradient(starting: NSColor(red: 0.36, green: 0.42, blue: 0.95, alpha: 1),
               ending: NSColor(red: 0.22, green: 0.24, blue: 0.70, alpha: 1))!
        .draw(in: bg, angle: -90)
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
    let sym = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)!
        .withSymbolConfiguration(cfg)!
    let tinted = NSImage(size: sym.size, flipped: false) { r in
        sym.draw(in: r)
        NSColor.white.set()
        r.fill(using: .sourceAtop)
        return true
    }
    let s = tinted.size
    tinted.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))
    return true
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: out)
