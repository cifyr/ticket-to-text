// Generates vintage railway icons at the exact sizes required by iMessage and iOS.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let stickers = CommandLine.arguments[1]   // iMessage App Icon.stickersiconset dir (in the extension target)

func color(_ hex: Int) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

let parchment = color(0xF2E8D5)
let deeperParchment = color(0xE8D9BC)
let ink = color(0x2B211A)
let sepia = color(0x6E5C49)
let brass = color(0xC8932B)
let brassLight = color(0xE9C97A)
let brassDark = color(0x8A6315)

func fillRoundedRect(_ rect: CGRect, radius: CGFloat, color: CGColor, in ctx: CGContext) {
    ctx.setFillColor(color)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                       transform: nil))
    ctx.fillPath()
}

func drawLocomotive(center: CGPoint, diameter: CGFloat, in ctx: CGContext) {
    let body = CGRect(x: center.x - diameter * 0.225,
                      y: center.y - diameter * 0.155,
                      width: diameter * 0.45,
                      height: diameter * 0.32)
    fillRoundedRect(body, radius: diameter * 0.045, color: ink, in: ctx)

    let roof = CGMutablePath()
    roof.move(to: CGPoint(x: center.x - diameter * 0.27, y: center.y + diameter * 0.16))
    roof.addLine(to: CGPoint(x: center.x + diameter * 0.27, y: center.y + diameter * 0.16))
    roof.addLine(to: CGPoint(x: center.x + diameter * 0.20, y: center.y + diameter * 0.225))
    roof.addLine(to: CGPoint(x: center.x - diameter * 0.20, y: center.y + diameter * 0.225))
    roof.closeSubpath()
    ctx.setFillColor(ink)
    ctx.addPath(roof)
    ctx.fillPath()

    let chimney = CGRect(x: center.x - diameter * 0.052,
                         y: center.y + diameter * 0.205,
                         width: diameter * 0.104,
                         height: diameter * 0.12)
    ctx.fill(chimney)
    ctx.fill(CGRect(x: center.x - diameter * 0.085,
                    y: center.y + diameter * 0.305,
                    width: diameter * 0.17,
                    height: diameter * 0.04))

    let window = CGRect(x: center.x - diameter * 0.13,
                        y: center.y + diameter * 0.015,
                        width: diameter * 0.26,
                        height: diameter * 0.105)
    fillRoundedRect(window, radius: diameter * 0.018, color: parchment, in: ctx)

    ctx.setFillColor(brassLight)
    ctx.fillEllipse(in: CGRect(x: center.x - diameter * 0.045,
                               y: center.y - diameter * 0.085,
                               width: diameter * 0.09,
                               height: diameter * 0.09))

    ctx.setFillColor(ink)
    ctx.fill(CGRect(x: center.x - diameter * 0.285,
                    y: center.y - diameter * 0.205,
                    width: diameter * 0.57,
                    height: diameter * 0.07))
    let wheelSize = diameter * 0.14
    for offset in [-diameter * 0.17, diameter * 0.17] {
        ctx.fillEllipse(in: CGRect(x: center.x + offset - wheelSize / 2,
                                   y: center.y - diameter * 0.285,
                                   width: wheelSize,
                                   height: wheelSize))
    }
}

func render(_ width: Int, _ height: Int, to path: String) {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fputs("failed context \(width)x\(height)\n", stderr); exit(1)
    }

    let w = CGFloat(width), h = CGFloat(height)
    let scale = min(w, h)
    let center = CGPoint(x: w / 2, y: h / 2)
    let diameter = scale * 0.78
    let outerRect = CGRect(x: center.x - diameter / 2,
                           y: center.y - diameter / 2,
                           width: diameter,
                           height: diameter)
    let innerRect = outerRect.insetBy(dx: diameter * 0.065, dy: diameter * 0.065)

    ctx.setFillColor(parchment)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Short rails give wide icons structure without changing the roundel geometry.
    ctx.setStrokeColor(sepia)
    ctx.setLineWidth(max(1, scale * 0.018))
    for y in [center.y - diameter * 0.13, center.y + diameter * 0.13] {
        ctx.move(to: CGPoint(x: scale * 0.08, y: y))
        ctx.addLine(to: CGPoint(x: center.x - diameter * 0.47, y: y))
        ctx.move(to: CGPoint(x: center.x + diameter * 0.47, y: y))
        ctx.addLine(to: CGPoint(x: w - scale * 0.08, y: y))
    }
    ctx.strokePath()

    ctx.setFillColor(brassDark)
    ctx.fillEllipse(in: outerRect)

    ctx.saveGState()
    ctx.addEllipse(in: innerRect)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: cs,
                              colors: [brassLight, brass, brassDark] as CFArray,
                              locations: [0, 0.58, 1])!
    let radius = innerRect.width / 2
    ctx.drawRadialGradient(gradient,
                           startCenter: CGPoint(x: center.x - radius * 0.28,
                                                y: center.y + radius * 0.28),
                           startRadius: 0,
                           endCenter: center,
                           endRadius: radius,
                           options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    ctx.setStrokeColor(brassLight)
    ctx.setLineWidth(max(1, scale * 0.014))
    ctx.strokeEllipse(in: innerRect.insetBy(dx: diameter * 0.035,
                                            dy: diameter * 0.035))

    drawLocomotive(center: center, diameter: diameter, in: ctx)

    ctx.setStrokeColor(deeperParchment)
    ctx.setLineWidth(max(1, scale * 0.012))
    ctx.strokeEllipse(in: outerRect.insetBy(dx: diameter * 0.018,
                                            dy: diameter * 0.018))

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
print("generated \(messages.count) icons")
