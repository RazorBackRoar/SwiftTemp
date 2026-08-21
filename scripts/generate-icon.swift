#!/usr/bin/env swift

import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("AppIcon.iconset")
let resourceIcon = root.appendingPathComponent("Sources/SwiftTemp/Resources/AppIcon.icns")
let legacyIcon = root.appendingPathComponent("Resources/AppIcon.icns")
let canvas: CGFloat = 1024
let body = NSRect(x: 100, y: 100, width: 824, height: 824)

func roundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func makeMaster() -> NSImage {
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()

    let shell = roundedPath(body, radius: 190)
    let shellGradient = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.02, green: 0.18, blue: 0.42, alpha: 1), 0.0),
        (NSColor(calibratedRed: 0.03, green: 0.48, blue: 0.91, alpha: 1), 0.48),
        (NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.04, alpha: 1), 1.0)
    )!
    shellGradient.draw(in: shell, angle: -42)

    NSGraphicsContext.saveGraphicsState()
    shell.addClip()
    let glow = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.30),
        NSColor.white.withAlphaComponent(0.0)
    ])!
    glow.draw(fromCenter: NSPoint(x: 310, y: 770), radius: 0,
              toCenter: NSPoint(x: 310, y: 770), radius: 470,
              options: [.drawsAfterEndingLocation])
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.22).setStroke()
    shell.lineWidth = 7
    shell.stroke()

    NSGraphicsContext.saveGraphicsState()
    let glyphShadow = NSShadow()
    glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    glyphShadow.shadowBlurRadius = 15
    glyphShadow.shadowOffset = NSSize(width: 0, height: -7)
    glyphShadow.set()

    let stem = roundedPath(NSRect(x: 421, y: 320, width: 182, height: 430), radius: 91)
    NSColor.white.setFill()
    stem.fill()

    let bulb = NSBezierPath(ovalIn: NSRect(x: 352, y: 214, width: 320, height: 320))
    NSColor.white.setFill()
    bulb.fill()
    NSGraphicsContext.restoreGraphicsState()

    let innerStem = roundedPath(NSRect(x: 477, y: 365, width: 70, height: 330), radius: 35)
    let orange = NSColor(calibratedRed: 1.0, green: 0.34, blue: 0.03, alpha: 1)
    orange.setFill()
    innerStem.fill()

    let innerBulb = NSBezierPath(ovalIn: NSRect(x: 414, y: 276, width: 196, height: 196))
    orange.setFill()
    innerBulb.fill()

    for y in [650, 585, 520] as [CGFloat] {
        let tick = roundedPath(NSRect(x: 623, y: y, width: 112, height: 22), radius: 11)
        NSColor.white.withAlphaComponent(0.92).setFill()
        tick.fill()
    }

    image.unlockFocus()
    return image
}

func pngData(_ image: NSImage, size: Int) -> Data {
    let target = NSImage(size: NSSize(width: size, height: size))
    target.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: NSRect(x: 0, y: 0, width: canvas, height: canvas),
               operation: .copy, fraction: 1)
    target.unlockFocus()
    let representation = NSBitmapImageRep(data: target.tiffRepresentation!)!
    return representation.representation(using: .png, properties: [.compressionFactor: 1])!
}

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let master = makeMaster()
let sizes = [
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024
]
for (name, size) in sizes {
    try pngData(master, size: size).write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", resourceIcon.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
try FileManager.default.copyItemReplacingItem(at: resourceIcon, to: legacyIcon)
print("Generated \(resourceIcon.path)")

extension FileManager {
    func copyItemReplacingItem(at source: URL, to destination: URL) throws {
        if fileExists(atPath: destination.path) { try removeItem(at: destination) }
        try copyItem(at: source, to: destination)
    }
}
