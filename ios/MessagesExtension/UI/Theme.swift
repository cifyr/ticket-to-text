import SwiftUI
import UIKit

// Vintage-railway design system: one palette, two type roles, and the reusable
// "ticket stub / enamel / brass" components every screen is built from.

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
    // Kept for back-compat; the brand accent is now brass, not crimson.
    static let brand = Palette.brass
}

enum Palette {
    static let parchment     = Color(hex: 0xF2E8D5)
    static let parchmentDeep = Color(hex: 0xE8D9BC)
    static let panel         = Color(hex: 0xECE7DD)
    static let ink           = Color(hex: 0x2B211A)
    static let sepia         = Color(hex: 0x6E5C49)
    static let sepiaLight    = Color(hex: 0x9B8E7D)
    static let brass         = Color(hex: 0xC8932B)
    static let brassLight    = Color(hex: 0xE9C97A)
    static let brassDark     = Color(hex: 0x8A6315)
    static let success       = Color(hex: 0x27795B)
    static let danger        = Color(hex: 0xA8301F)
    static let dark          = Color(hex: 0x221C16)
    static let hairline      = Color(hex: 0x6E5C49, alpha: 0.30)
    static let brassHair     = Color(hex: 0xC8932B, alpha: 0.45)
    static let routeHot       = Color(hex: 0xFF6A1A) // most-recent claim / destination line
    static let activeRing     = Color(hex: 0xFFD21E) // bright ring around the player whose turn it is

    // Enamel train-car colors (also used as player/owner colors).
    static let carRed    = Color(hex: 0xC0392B)
    static let carOrange = Color(hex: 0xD9712B)
    static let carYellow = Color(hex: 0xE0A82E)
    static let carGreen  = Color(hex: 0x27795B)
    static let carBlue   = Color(hex: 0x2C6FA6)
    static let carPurple = Color(hex: 0x9457A0)
    static let carWhite  = Color(hex: 0xF5F0E6)
    static let carBlack  = Color(hex: 0x2B2B2B)
}

extension Font {
    // Slab-serif display role (titles, labels, numbers on stubs). System serif
    // approximates Zilla Slab without bundling a font file.
    static func slab(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    // Rounded sans body role, approximating Nunito.
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Paper texture

enum Paper {
    static let grain = Image(uiImage: grainImage)

    private static let grainImage: UIImage = {
        let dim = 90
        let size = CGSize(width: dim, height: dim)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> Double { // xorshift, deterministic so the texture is stable
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Double(seed % 1000) / 1000.0
        }
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            for y in 0..<dim {
                for x in 0..<dim {
                    let g = CGFloat(0.18 + rnd() * 0.62)
                    UIColor(white: g, alpha: 0.07).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        return img.resizableImage(withCapInsets: .zero, resizingMode: .tile)
    }()
}

extension View {
    // Parchment surface + tiled grain, clipped to an optional corner radius.
    func paper(_ color: Color = Palette.parchment, corner: CGFloat = 0) -> some View {
        background(
            ZStack {
                color
                Paper.grain.resizable(resizingMode: .tile).opacity(0.5).blendMode(.multiply)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .allowsHitTesting(false)
        )
    }

    // A printed ticket-stub / luggage-tag panel.
    func stub(_ fill: Color = Palette.parchmentDeep, corner: CGFloat = 13,
              padding: CGFloat = 14, stroke: Color = Palette.hairline) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: corner)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: corner).stroke(stroke, lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: corner)
                        .stroke(.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
                    .shadow(color: Palette.ink.opacity(0.16), radius: 6, y: 3)
            )
    }
}

// MARK: - Buttons

struct BrassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.slab(16, .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color(hex: 0x3A2A0C))
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(LinearGradient(colors: [Color(hex: 0xD9A23B), Color(hex: 0xB97E1C)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.brassDark.opacity(0.45), lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(.white.opacity(0.4), lineWidth: 1).blendMode(.overlay).padding(0.5))
                    .shadow(color: Palette.ink.opacity(0.28), radius: 5, y: 3)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct QuietButtonStyle: ButtonStyle {
    var tint: Color = Palette.sepia
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.slab(15, .semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(Palette.parchment)
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.hairline, lineWidth: 1))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// Small round brass-rimmed icon button used in the header / map.
struct RailIconButton: View {
    let system: String
    var badge: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: system)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.sepia)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(Palette.parchmentDeep)
                            .overlay(Circle().stroke(Palette.brassHair, lineWidth: 1))
                    )
                if let badge {
                    Text(badge)
                        .font(.sans(9, .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Palette.brass))
                        .offset(x: 4, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Decorative pieces

// Enamel app badge: a rounded train tile (compact bubbles, lobby, start screen).
struct TrainBadge: View {
    var color: Color = Palette.carRed
    var size: CGFloat = 50
    private var corner: CGFloat { size * 0.26 }
    var body: some View {
        Image(systemName: "train.side.front.car")
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(Palette.carWhite)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: corner)
                    .fill(LinearGradient(colors: [color, color.opacity(0.78)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: corner).stroke(.black.opacity(0.3), lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: corner).inset(by: 1)
                        .stroke(.white.opacity(0.32), lineWidth: 1).blendMode(.overlay))
                    .shadow(color: Palette.ink.opacity(0.3), radius: 3, y: 3)
            )
    }
}

struct DashedLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p
    }
}

struct DashedRule: View {
    var color: Color = Palette.hairline
    var body: some View {
        DashedLine()
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
            .foregroundStyle(color)
            .frame(height: 1)
    }
}

struct SectionRule: View {
    let title: String
    var body: some View {
        HStack(spacing: 10) {
            line
            Text(title).font(.slab(12, .bold)).tracking(2.5).textCase(.uppercase)
                .foregroundStyle(Palette.sepia)
            line
        }
    }
    private var line: some View { Rectangle().fill(Palette.brassHair).frame(height: 1) }
}

// Player enamel disc; the active player gets a pulsing brass ring.
struct EnamelToken: View {
    let color: Color
    let label: String
    var active = false
    var size: CGFloat = 30
    @State private var pulse = false

    var body: some View {
        Text(label)
            .font(.slab(size * 0.42, .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(RadialGradient(
                    colors: [.white.opacity(0.4), color],
                    center: UnitPoint(x: 0.35, y: 0.28), startRadius: 1, endRadius: size * 0.7))
            )
            .overlay(Circle().stroke(active ? Palette.activeRing : .black.opacity(0.3),
                                     lineWidth: active ? 3 : 1.5))
            .overlay(
                active
                    ? Circle().stroke(Palette.activeRing.opacity(pulse ? 0 : 0.7), lineWidth: pulse ? 10 : 3)
                    : nil
            )
            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            .onAppear {
                guard active else { return }
                withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false)) { pulse = true }
            }
    }
}

// Brass destination-point stamp.
struct PointStamp: View {
    let points: Int
    var size: CGFloat = 50
    var body: some View {
        VStack(spacing: 0) {
            Text("\(points)").font(.slab(size * 0.44, .bold)).lineLimit(1).minimumScaleFactor(0.6)
            Text("PTS").font(.slab(max(7, size * 0.14), .semibold)).tracking(1)
        }
        .foregroundStyle(Color(hex: 0x3A2A0C))
        .frame(width: size, height: size)
        .background(
            Circle().fill(RadialGradient(
                colors: [Palette.brassLight, Palette.brass, Palette.brassDark],
                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: size * 0.7))
        )
        .overlay(Circle().stroke(Color(hex: 0x7A5710), lineWidth: 2))
        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
    }
}

// An enamel train card (hand, market, recap). Locomotive = rainbow shimmer.
struct EnamelCard: View {
    let card: Card
    var selected = false
    var height: CGFloat = 42
    private var corner: CGFloat { height * 0.18 }

    private let rainbow = LinearGradient(
        colors: [Palette.carRed, Palette.carYellow, Palette.carGreen, Palette.carBlue, Palette.carPurple, Palette.carRed],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    private var glyphColor: Color {
        switch card {
        case .white: return Palette.ink
        case .black: return Palette.parchmentDeep
        case .locomotive: return .white
        default: return Palette.carWhite
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: corner)
            .fill(cardColor(card))
            .overlay {
                if card == .locomotive {
                    RoundedRectangle(cornerRadius: corner).fill(rainbow)
                } else {
                    RoundedRectangle(cornerRadius: corner)
                        .fill(LinearGradient(colors: [.white.opacity(0.22), .black.opacity(0.16)],
                                             startPoint: .top, endPoint: .bottom))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: corner - 2).inset(by: 3)
                .stroke(.white.opacity(0.22), lineWidth: 1))
            .overlay(
                Image(systemName: "train.side.front.car")
                    .font(.system(size: height * 0.4, weight: .medium))
                    .foregroundStyle(glyphColor)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            )
            .frame(height: height)
            .overlay(RoundedRectangle(cornerRadius: corner)
                .stroke(selected ? Palette.brass : .black.opacity(0.22), lineWidth: selected ? 2 : 1))
            .shadow(color: Palette.ink.opacity(selected ? 0.3 : 0.22),
                    radius: selected ? 8 : 3, y: selected ? 8 : 2)
            .offset(y: selected ? -8 : 0)
            .animation(.snappy(duration: 0.2), value: selected)
    }
}

// MARK: - Color mapping

func cardColor(_ c: Card) -> Color {
    switch c {
    case .red: return Palette.carRed
    case .orange: return Palette.carOrange
    case .yellow: return Palette.carYellow
    case .green: return Palette.carGreen
    case .blue: return Palette.carBlue
    case .purple: return Palette.carPurple
    case .white: return Palette.carWhite
    case .black: return Palette.carBlack
    case .locomotive: return Palette.brass // rendered as rainbow by EnamelCard
    }
}

func paintColor(_ p: RoutePaint) -> Color {
    if p == .gray { return Palette.sepia.opacity(0.75) }
    return cardColor(Card(rawValue: p.rawValue) ?? .red)
}

private let seatColors: [Color] = [Palette.carRed, Palette.carBlue, Palette.carGreen, Palette.carYellow]

func ownerColor(_ player: Int) -> Color { seatColors[player % seatColors.count] }

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
