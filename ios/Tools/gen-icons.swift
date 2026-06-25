// Generates flat brand icons (crimson bg + white disc) at the exact pixel sizes
// the iMessage app icon and host app icon require. Run via the npm "icons" script.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let stickers = CommandLine.arguments[1]   // iMessage App Icon.stickersiconset dir
let appicon = CommandLine.arguments[2]    // AppIcon.appiconset dir

func render(_ width: Int, _ height: Int, to path: String) {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fputs("failed context \(width)x\(height)\n", stderr); exit(1)
    }
    ctx.setFillColor(red: 0xB1/255.0, green: 0x12/255.0, blue: 0x26/255.0, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let d = Double(min(width, height)) * 0.52
    let cx = Double(width) / 2, cy = Double(height) / 2
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fillEllipse(in: CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d))
    guard let img = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil) else {
        fputs("failed write \(path)\n", stderr); exit(1)
    }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let messages: [(String, Int, Int)] = [
    ("icon-29@2x.png", 58, 58),
    ("icon-29@3x.png", 87, 87),
    ("icon-60x45@2x.png", 120, 90),
    ("icon-60x45@3x.png", 180, 135),
    ("icon-29@2x-ipad.png", 58, 58),
    ("icon-67x50@2x.png", 134, 100),
    ("icon-74x55@2x.png", 148, 110),
    ("icon-27x20@2x.png", 54, 40),
    ("icon-27x20@3x.png", 81, 60),
    ("icon-32x24@2x.png", 64, 48),
    ("icon-32x24@3x.png", 96, 72),
    ("icon-1024x768.png", 1024, 768),
]
for (name, w, h) in messages { render(w, h, to: "\(stickers)/\(name)") }
render(1024, 1024, to: "\(appicon)/appicon-1024.png")
print("generated \(messages.count + 1) icons")
