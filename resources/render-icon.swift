#!/usr/bin/swift
import AppKit
import Foundation

/// Build AppIcon.iconset and AppIcon.icns from app-icon.png.
/// Usage (from this directory): swift render-icon.swift

let fm = FileManager.default
let resources = URL(fileURLWithPath: fm.currentDirectoryPath)
let sourceURL = resources.appendingPathComponent("app-icon.png")

guard let source = NSImage(contentsOf: sourceURL), source.size.width > 0 else {
  fputs("missing or empty \(sourceURL.path)\n", stderr)
  exit(1)
}

func bitmap(_ pixels: Int) -> NSBitmapImageRep {
  guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ) else {
    fputs("bitmap \(pixels) failed\n", stderr)
    exit(1)
  }
  rep.size = NSSize(width: pixels, height: pixels)
  return rep
}

func scaled(_ pixels: Int) -> NSBitmapImageRep {
  let dest = bitmap(pixels)
  NSGraphicsContext.saveGraphicsState()
  guard let ctx = NSGraphicsContext(bitmapImageRep: dest) else {
    fputs("scale context failed\n", stderr)
    exit(1)
  }
  ctx.imageInterpolation = .high
  NSGraphicsContext.current = ctx
  let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
  source.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
  NSGraphicsContext.restoreGraphicsState()
  return dest
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
  guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("png encode failed\n", stderr)
    exit(1)
  }
  try data.write(to: url)
  print("wrote \(url.path)")
}

let setDir = resources.appendingPathComponent("AppIcon.iconset")
try fm.createDirectory(at: setDir, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024),
]

for (name, px) in variants {
  try writePNG(scaled(px), to: setDir.appendingPathComponent(name))
}

let icns = resources.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", "-o", icns.path, setDir.path]
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
  fputs("iconutil failed\n", stderr)
  exit(Int32(iconutil.terminationStatus))
}
print("wrote \(icns.path)")
