// Renders casky's app icon to a 1024×1024 PNG, following Apple's macOS
// icon template: an 824pt rounded square with continuous corners centered
// on the canvas, a soft drop shadow, and one simple front-facing glyph.
// Usage: swift scripts/make-icon.swift <output.png> [tiles|package|monogram]
// "tiles" is the shipped icon; the others were the alternatives considered.
import AppKit

let size: CGFloat = 1024
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let arguments = Array(CommandLine.arguments.dropFirst())
let output = arguments.first ?? "icon.png"
let variant = arguments.dropFirst().first ?? "tiles"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Rounded rect with continuous ("squircle") corners, like Apple's icons.
func squircle(_ rect: CGRect, radius r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let k: CGFloat = 1.28
    let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
    path.move(to: CGPoint(x: minX + r * k, y: minY))
    path.addLine(to: CGPoint(x: maxX - r * k, y: minY))
    path.addCurve(to: CGPoint(x: maxX, y: minY + r * k), control1: CGPoint(x: maxX - r * 0.35, y: minY), control2: CGPoint(x: maxX, y: minY + r * 0.35))
    path.addLine(to: CGPoint(x: maxX, y: maxY - r * k))
    path.addCurve(to: CGPoint(x: maxX - r * k, y: maxY), control1: CGPoint(x: maxX, y: maxY - r * 0.35), control2: CGPoint(x: maxX - r * 0.35, y: maxY))
    path.addLine(to: CGPoint(x: minX + r * k, y: maxY))
    path.addCurve(to: CGPoint(x: minX, y: maxY - r * k), control1: CGPoint(x: minX + r * 0.35, y: maxY), control2: CGPoint(x: minX, y: maxY - r * 0.35))
    path.addLine(to: CGPoint(x: minX, y: minY + r * k))
    path.addCurve(to: CGPoint(x: minX + r * k, y: minY), control1: CGPoint(x: minX, y: minY + r * 0.35), control2: CGPoint(x: minX + r * 0.35, y: minY))
    path.closeSubpath()
    return path
}

func fill(_ path: CGPath, _ colors: [CGColor], from start: CGPoint, to end: CGPoint) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
}

func shadowed(_ offset: CGFloat, blur: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -offset), blur: blur, color: color(0x000000, alpha))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    draw()
    context.endTransparencyLayer()
    context.restoreGState()
}

/// A bold downward arrow (shaft + head) centered at `center`.
func arrow(center: CGPoint, width: CGFloat, height: CGFloat, shaft: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let headHeight = width * 0.62
    let top = center.y + height / 2, bottom = center.y - height / 2
    path.move(to: CGPoint(x: center.x - shaft / 2, y: top))
    path.addLine(to: CGPoint(x: center.x + shaft / 2, y: top))
    path.addLine(to: CGPoint(x: center.x + shaft / 2, y: bottom + headHeight))
    path.addLine(to: CGPoint(x: center.x + width / 2, y: bottom + headHeight))
    path.addLine(to: CGPoint(x: center.x, y: bottom))
    path.addLine(to: CGPoint(x: center.x - width / 2, y: bottom + headHeight))
    path.addLine(to: CGPoint(x: center.x - shaft / 2, y: bottom + headHeight))
    path.closeSubpath()
    return path
}

func rounded(_ path: CGPath, _ radius: CGFloat) -> CGPath {
    path.copy(strokingWithWidth: radius * 2, lineCap: .round, lineJoin: .round, miterLimit: 1).union(path)
}

// Background tile with the template's drop shadow.
let background = squircle(tile, radius: 185)
let palettes: [String: [CGColor]] = [
    "package": [color(0x5B8CFF), color(0x2F3FD6)],
    "monogram": [color(0x3A3F4B), color(0x14161B)],
    "tiles": [color(0x8E7CFF), color(0x4B3BDB)],
]
shadowed(10, blur: 28, alpha: 0.3) {
    context.addPath(background)
    context.setFillColor(color(0x000000))
    context.fillPath()
}
fill(background, palettes[variant] ?? palettes["package"]!, from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
// Soft light from the top, as on Apple's own icons.
fill(background, [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 520))

let white = [color(0xFFFFFF), color(0xE6EBF5)]

switch variant {
case "monogram":
    // A thick "c": a ring with an opening on the right, and a dot in the
    // opening, as if something is dropping in.
    let center = CGPoint(x: 500, y: 512)
    let ring = CGMutablePath()
    ring.addArc(center: center, radius: 220, startAngle: .pi * 0.23, endAngle: -.pi * 0.23, clockwise: false)
    let stroke = ring.copy(strokingWithWidth: 118, lineCap: .round, lineJoin: .round, miterLimit: 1)
    shadowed(10, blur: 24, alpha: 0.35) {
        fill(stroke, white, from: CGPoint(x: 512, y: 760), to: CGPoint(x: 512, y: 260))
    }
    let dot = CGPath(ellipseIn: CGRect(x: 640, y: 452, width: 120, height: 120), transform: nil)
    shadowed(8, blur: 18, alpha: 0.35) {
        fill(dot, [color(0x7FB2FF), color(0x3D7BFF)], from: CGPoint(x: 700, y: 572), to: CGPoint(x: 700, y: 452))
    }

case "tiles":
    // Three app tiles fanned out, the front one carrying a download arrow.
    let tileSize: CGFloat = 380
    // Back tiles: smaller, tilted outward around their own centers, peeking
    // out above the front tile's shoulders. Drawn opaque into one layer that
    // is faded as a whole, so their overlap doesn't show as a brighter patch.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: color(0x000000, 0.18))
    context.setAlpha(0.55)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    for (centerX, angle) in [(CGFloat(420), CGFloat(0.20)), (CGFloat(604), CGFloat(-0.20))] {
        context.saveGState()
        context.translateBy(x: centerX, y: 548)
        context.rotate(by: angle)
        let back = squircle(CGRect(x: -150, y: -150, width: 300, height: 300), radius: 70)
        fill(back, [color(0xFFFFFF), color(0xE9E6FF)], from: CGPoint(x: 0, y: 150), to: CGPoint(x: 0, y: -150))
        context.restoreGState()
    }
    context.endTransparencyLayer()
    context.restoreGState()
    let front = squircle(CGRect(x: 512 - tileSize / 2, y: 450 - tileSize / 2, width: tileSize, height: tileSize), radius: 88)
    shadowed(14, blur: 30, alpha: 0.35) {
        fill(front, white, from: CGPoint(x: 512, y: 640), to: CGPoint(x: 512, y: 260))
    }
    let glyph = rounded(arrow(center: CGPoint(x: 512, y: 450), width: 190, height: 220, shaft: 64), 8)
    fill(glyph, palettes["tiles"]!, from: CGPoint(x: 512, y: 560), to: CGPoint(x: 512, y: 340))

default: // "package"
    // A box seen from the front: lid band on top, body below, and a
    // download arrow cut out of the body.
    let body = squircle(CGRect(x: 262, y: 230, width: 500, height: 430), radius: 70)
    let lid = squircle(CGRect(x: 232, y: 610, width: 560, height: 150), radius: 56)
    let cut = rounded(arrow(center: CGPoint(x: 512, y: 432), width: 230, height: 280, shaft: 78), 10)
    shadowed(14, blur: 30, alpha: 0.35) {
        context.saveGState()
        // Even-odd: the arrow becomes a hole in the body.
        let shape = CGMutablePath()
        shape.addPath(body)
        shape.addPath(cut)
        context.addPath(shape)
        context.clip(using: .evenOdd)
        let gradient = CGGradient(colorsSpace: colorSpace, colors: white as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 660), end: CGPoint(x: 512, y: 230), options: [])
        context.restoreGState()
        fill(lid, [color(0xFFFFFF), color(0xF1F4FA)], from: CGPoint(x: 512, y: 760), to: CGPoint(x: 512, y: 610))
    }
}

NSGraphicsContext.current = nil
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("wrote \(output) (\(variant))")
