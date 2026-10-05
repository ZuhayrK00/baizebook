import AppKit
import Foundation

let base = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSGradient(starting: NSColor(red: 0.10, green: 0.31, blue: 0.23, alpha: 1), ending: NSColor(red: 0.035, green: 0.13, blue: 0.11, alpha: 1))!.draw(in: rect, angle: -45)
let border = NSBezierPath(roundedRect: NSRect(x: 135, y: 140, width: 754, height: 744), xRadius: 125, yRadius: 125)
NSColor(red: 0.53, green: 0.71, blue: 0.49, alpha: 0.30).setStroke(); border.lineWidth = 8; border.stroke()
// An open scorebook: cream pages and a central spine.
let book = NSBezierPath()
book.move(to: NSPoint(x: 280, y: 318)); book.line(to: NSPoint(x: 280, y: 688))
book.curve(to: NSPoint(x: 510, y: 650), controlPoint1: NSPoint(x: 355, y: 725), controlPoint2: NSPoint(x: 440, y: 700))
book.curve(to: NSPoint(x: 745, y: 688), controlPoint1: NSPoint(x: 588, y: 700), controlPoint2: NSPoint(x: 670, y: 725))
book.line(to: NSPoint(x: 745, y: 318))
book.curve(to: NSPoint(x: 510, y: 280), controlPoint1: NSPoint(x: 664, y: 354), controlPoint2: NSPoint(x: 584, y: 330))
book.curve(to: NSPoint(x: 280, y: 318), controlPoint1: NSPoint(x: 437, y: 330), controlPoint2: NSPoint(x: 353, y: 354))
NSColor(red: 0.90, green: 0.90, blue: 0.78, alpha: 1).setStroke(); book.lineWidth = 32; book.lineJoinStyle = .round; book.lineCapStyle = .round; book.stroke()
let spine = NSBezierPath(); spine.move(to: NSPoint(x: 510, y: 300)); spine.line(to: NSPoint(x: 510, y: 644)); spine.lineWidth = 22; spine.lineCapStyle = .round; spine.stroke()
for y in [428.0, 507.0] {
    let line = NSBezierPath(); line.move(to: NSPoint(x: 338, y: y)); line.line(to: NSPoint(x: 440, y: y-10)); line.lineWidth = 18; line.lineCapStyle = .round; NSColor(red: 0.90, green: 0.90, blue: 0.78, alpha: 0.5).setStroke(); line.stroke()
}
let ballRect = NSRect(x: 559, y: 417, width: 138, height: 138)
NSGradient(starting: NSColor(red: 0.95, green: 0.29, blue: 0.28, alpha: 1), ending: NSColor(red: 0.62, green: 0.07, blue: 0.12, alpha: 1))!.draw(in: NSBezierPath(ovalIn: ballRect), angle: -60)
NSColor.white.withAlphaComponent(0.32).setFill(); NSBezierPath(ovalIn: NSRect(x: 584, y: 511, width: 34, height: 19)).fill()
NSGraphicsContext.restoreGraphicsState()
let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: base.appending(path: "Resources/Assets.xcassets/AppIcon.appiconset/Icon.png"))

try png.write(to: base.appending(path: "Resources/WatchAssets.xcassets/AppIcon.appiconset/Icon.png"))
