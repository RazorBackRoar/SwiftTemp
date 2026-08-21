#!/usr/bin/env swift

import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("AppIcon.iconset")
let resourceIcon = root.appendingPathComponent("Sources/SwiftTemp/Resources/AppIcon.icns")
let legacyIcon = root.appendingPathComponent("Resources/AppIcon.icns")
let canvas: CGFloat = 1024
let body = NSRect(x: 100, y: 100, width: 824, height: 824)

func makeMaster() -> NSImage {
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()

    let shell = NSBezierPath(roundedRect: body, xRadius: 188, yRadius: 188)
    let background = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.02, green: 0.22, blue: 0.52, alpha: 1), 0.0),
        (NSColor(calibratedRed: 0.98, green: 0.35, blue: 0.03, alpha: 1), 1.0)
    )!
    background.draw(in: shell, angle: 90)

    NSColor.white.withAlphaComponent(0.14).setStroke()
    shell.lineWidth = 4
    shell.stroke()

    NSGraphicsContext.saveGraphicsState()
    let glyphShadow = NSShadow()
    glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    glyphShadow.shadowBlurRadius = 8
    glyphShadow.shadowOffset = NSSize(width: 0, height: -4)
    glyphShadow.set()

    let stem = NSBezierPath(roundedRect: NSRect(x: 430, y: 350, width: 164, height: 390), xRadius: 82, yRadius: 82)
    let bulb = NSBezierPath(ovalIn: NSRect(x: 344, y: 218, width: 336, height: 336))
    NSColor.white.setFill()
    stem.fill()
    bulb.fill()
    NSGraphicsContext.restoreGraphicsState()

    let fluidStem = NSBezierPath(roundedRect: NSRect(x: 478, y: 397, width: 68, height: 277), xRadius: 34, yRadius: 34)
    let fluidBulb = NSBezierPath(ovalIn: NSRect(x: 407, y: 281, width: 196, height: 196))
    let redOrange = NSColor(calibratedRed: 1.0, green: 0.22, blue: 0.03, alpha: 1)
    redOrange.setFill()
    fluidStem.fill()
    fluidBulb.fill()

    let highlight = NSBezierPath(roundedRect: NSRect(x: 496, y: 421, width: 16, height: 180), xRadius: 8, yRadius: 8)
    NSColor.white.withAlphaComponent(0.22).setFill()
    highlight.fill()

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
