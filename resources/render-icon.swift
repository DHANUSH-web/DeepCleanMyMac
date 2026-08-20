#!/usr/bin/swift
import AppKit
import Foundation

let size: CGFloat = 1024
let radius: CGFloat = size * 0.2237
let out = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/icon-master.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let plate = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
plate.addClip()

NSColor.black.setFill()
plate.fill()

let gradient = NSGradient(colorsAndLocations:
    (NSColor(white: 0.16, alpha: 1), 0.0),
    (NSColor(white: 0.02, alpha: 1), 0.42),
    (NSColor.black, 1.0)
)!
gradient.draw(in: plate, angle: -90)

let shine = NSGradient(colors: [
    NSColor(white: 1, alpha: 0.14),
    NSColor(white: 1, alpha: 0.0),
])!
let shineRect = NSRect(x: 0, y: size * 0.62, width: size, height: size * 0.38)
shine.draw(in: shineRect, angle: -90)

guard let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil) else {
    fputs("sparkles symbol missing\n", stderr)
    exit(1)
}
let config = NSImage.SymbolConfiguration(pointSize: 390, weight: .regular, scale: .large)
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
guard let glyph = symbol.withSymbolConfiguration(config) else {
    fputs("symbol configuration failed\n", stderr)
    exit(1)
}
let gsize = glyph.size
let dest = NSRect(
    x: (size - gsize.width) / 2,
    y: (size - gsize.height) / 2 - 8,
    width: gsize.width,
    height: gsize.height
)
glyph.draw(in: dest, from: .zero, operation: .sourceOver, fraction: 1)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("png encode failed\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
