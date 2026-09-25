#!/usr/bin/swift
import AppKit
import Foundation

/// Finder window is 660×520 pt. This PNG is 2× so it stays sharp on Retina.
/// Icon centers (pt, top-left origin) must match resources/dmg-setup.applescript.
let winW = 660.0
let winH = 520.0
let scale = 2.0
let W = Int(winW * scale)
let H = Int(winH * scale)

let appCenter = CGPoint(x: 180, y: 185)
let appsCenter = CGPoint(x: 480, y: 185)
let iconPt = 128.0
let padPt = 148.0

guard let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: W,
  pixelsHigh: H,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
) else {
  fputs("bitmap failed\n", stderr)
  exit(1)
}
rep.size = NSSize(width: winW, height: winH)

NSGraphicsContext.saveGraphicsState()
guard let nsctx = NSGraphicsContext(bitmapImageRep: rep) else {
  fputs("context failed\n", stderr)
  exit(1)
}
NSGraphicsContext.current = nsctx
let cg = nsctx.cgContext

func fromFinder(_ p: CGPoint) -> CGPoint {
  CGPoint(x: p.x, y: winH - p.y)
}

let bg = NSColor(white: 0.07, alpha: 1)
bg.setFill()
cg.fill(CGRect(x: 0, y: 0, width: winW, height: winH))

let grad = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: [
    NSColor(white: 0.11, alpha: 1).cgColor,
    NSColor(white: 0.05, alpha: 1).cgColor,
  ] as CFArray,
  locations: [0, 1]
)!
cg.drawLinearGradient(
  grad,
  start: CGPoint(x: winW * 0.5, y: 0),
  end: CGPoint(x: winW * 0.5, y: winH),
  options: []
)

func drawPad(center: CGPoint) {
  let r = CGRect(
    x: center.x - padPt / 2,
    y: center.y - padPt / 2,
    width: padPt,
    height: padPt
  )
  let path = NSBezierPath(roundedRect: r, xRadius: 28, yRadius: 28)
  NSColor(white: 0.14, alpha: 1).setFill()
  path.fill()
  NSColor(white: 1, alpha: 0.10).setStroke()
  path.lineWidth = 1.5
  path.stroke()
}

let appCG = fromFinder(appCenter)
let appsCG = fromFinder(appsCenter)
drawPad(center: appCG)
drawPad(center: appsCG)

let midX = (appCG.x + appsCG.x) / 2
let midY = appCG.y
let arrow = NSBezierPath()
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.lineWidth = 5
let stemL: CGFloat = 36
arrow.move(to: CGPoint(x: midX - stemL, y: midY))
arrow.line(to: CGPoint(x: midX + stemL - 6, y: midY))
arrow.move(to: CGPoint(x: midX + stemL - 18, y: midY - 14))
arrow.line(to: CGPoint(x: midX + stemL, y: midY))
arrow.line(to: CGPoint(x: midX + stemL - 18, y: midY + 14))
NSColor(white: 1, alpha: 0.55).setStroke()
arrow.stroke()

let caption = "Drag to Applications" as NSString
let attrs: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 13, weight: .medium),
  .foregroundColor: NSColor(white: 1, alpha: 0.45),
]
let size = caption.size(withAttributes: attrs)
caption.draw(
  at: CGPoint(x: (winW - size.width) / 2, y: 28),
  withAttributes: attrs
)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
  fputs("png encode failed\n", stderr)
  exit(1)
}
let out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  .appendingPathComponent("dmg-background.png")
try data.write(to: out)
print("wrote \(out.path)")
