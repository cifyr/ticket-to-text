import SwiftUI

// The board canvas. Tapping near any route reports it via onSelect so the
// caller can show exactly what it costs. The selected route is haloed.
struct BoardView: View {
    let state: GameState
    let selectedRouteId: Int?
    let highlightTicket: Ticket?
    let canAct: Bool
    let claimable: (Route) -> Bool
    let onSelect: (Int) -> Void
    var showNames: Bool = true
    var showLengthPips: Bool = true
    var dotsOnSelected: Bool = false

    var body: some View {
        GeometryReader { geo in
            let pts = BoardGeometry.positions(in: geo.size)
            ZStack {
                Canvas { ctx, size in
                    BoardGeometry.draw(state, in: ctx, points: pts, size: size,
                                       selected: selectedRouteId, highlightTicket: highlightTicket,
                                       showNames: showNames, showLengthPips: showLengthPips,
                                       dotsOnSelected: dotsOnSelected,
                                       highlightClaimable: canAct ? claimable : { _ in false })
                }
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { v in handleTap(v.location, points: pts) })
            }
        }
    }

    private func handleTap(_ p: CGPoint, points: [CGPoint]) {
        var best: (id: Int, dist: CGFloat)?
        for route in state.routes {
            let d = BoardGeometry.distance(from: p, toSegment: points[route.cityA], points[route.cityB])
            if d < 26, best == nil || d < best!.dist { best = (route.id, d) }
        }
        if let best { onSelect(best.id) }
    }
}

// Bigger board the user can pan and zoom, framed like an antique rail map.
struct BoardArea: View {
    let state: GameState
    let selectedRouteId: Int?
    let highlightTicket: Ticket?
    let canAct: Bool
    let claimable: (Route) -> Bool
    let onSelect: (Int) -> Void

    @State private var zoomed = true   // default: zoomed in (names visible)
    private let aspect: CGFloat = 0.74
    // Both levels are already zoomed past fit so the board never shrinks back to the whole-map view.
    private let baseScale: CGFloat = 1.7
    private let closeScale: CGFloat = 2.8

    var body: some View {
        GeometryReader { geo in
            let fitW = min(geo.size.width, geo.size.height / aspect)
            let scale: CGFloat = zoomed ? closeScale : baseScale
            let contentW = fitW * scale
            let contentH = fitW * aspect * scale

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                BoardView(state: state, selectedRouteId: selectedRouteId, highlightTicket: highlightTicket,
                          canAct: canAct, claimable: claimable, onSelect: onSelect, showNames: zoomed)
                    .frame(width: contentW, height: contentH)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height) // center when small
            }
            .background(mapSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.brassHair, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 14).inset(by: 5)
                .stroke(Palette.brassHair, lineWidth: 1).allowsHitTesting(false))
            .overlay(alignment: .bottomLeading) {
                Text("RAIL MAP · 1908").font(.slab(10, .bold)).tracking(3)
                    .foregroundStyle(Palette.sepia.opacity(0.55)).padding(12)
            }
            .overlay(alignment: .topTrailing) {
                Button { withAnimation(.snappy) { zoomed.toggle() } } label: {
                    Image(systemName: zoomed ? "minus.magnifyingglass" : "plus.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.sepia)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Palette.parchment).overlay(Circle().stroke(Palette.brassHair, lineWidth: 1)))
                }
                .padding(8)
            }
            .shadow(color: Palette.ink.opacity(0.12), radius: 6, y: 3)
        }
    }

    private var mapSurface: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0xEFE3CB), Color(hex: 0xE2D0AE), Color(hex: 0xD6C29C)],
                           center: UnitPoint(x: 0.3, y: 0.15), startRadius: 10, endRadius: 520)
            Paper.grain.resizable(resizingMode: .tile).opacity(0.45).blendMode(.multiply)
        }
        .allowsHitTesting(false)
    }
}

// Shared layout + drawing so the live board and the bubble snapshot match.
enum BoardGeometry {
    static func point(_ nx: Double, _ ny: Double, in size: CGSize) -> CGPoint {
        // Generous padding so edge cities and their labels are never clipped.
        let padX: CGFloat = 44, padY: CGFloat = 30
        let w = size.width - padX * 2, h = size.height - padY * 2
        return CGPoint(x: padX + CGFloat(nx) * w, y: padY + CGFloat(ny) * h)
    }

    static func positions(in size: CGSize) -> [CGPoint] {
        GameMap.cities.map { point($0.x, $0.y, in: size) }
    }

    static func draw(_ state: GameState,
                     in ctx: GraphicsContext,
                     points: [CGPoint],
                     size: CGSize,
                     selected: Int?,
                     highlightTicket: Ticket?,
                     showNames: Bool = true,
                     showLengthPips: Bool = true,
                     dotsOnSelected: Bool = false,
                     highlightClaimable: (Route) -> Bool) {
        for route in state.routes {
            let a = points[route.cityA], b = points[route.cityB]
            let owner = route.claimedBy
            let claimable = owner == nil && highlightClaimable(route)
            let fill: Color = owner != nil ? ownerColor(owner!)
                : (claimable ? paintColor(route.color) : paintColor(route.color).opacity(0.4))

            if route.id == selected { // selection / seized-route halo
                var halo = Path(); halo.move(to: a); halo.addLine(to: b)
                ctx.stroke(halo, with: .color(Palette.brass.opacity(0.4)),
                           style: StrokeStyle(lineWidth: 16, lineCap: .round))
            }

            drawTrack(in: ctx, from: a, to: b, cars: route.length, fill: fill,
                      ghost: owner == nil && !claimable, glow: claimable)

            if route.id == selected && dotsOnSelected { drawDots(in: ctx, from: a, to: b, cars: route.length) }

            if showLengthPips {
                let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let pip = CGRect(x: mid.x - 8, y: mid.y - 8, width: 16, height: 16)
                ctx.fill(Path(ellipseIn: pip), with: .radialGradient(
                    Gradient(colors: [Palette.brassLight, Palette.brass, Palette.brassDark]),
                    center: CGPoint(x: mid.x - 2, y: mid.y - 2), startRadius: 0, endRadius: 11))
                ctx.stroke(Path(ellipseIn: pip), with: .color(Color(hex: 0x7A5710)), lineWidth: 1)
                ctx.draw(Text("\(route.length)").font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: 0x3A2A0C)), at: mid)
            }
        }

        for (i, p) in points.enumerated() {
            if dotsOnSelected {
                // Recap image: subtle city markers so only the seized rail stands out.
                let r: CGFloat = 2.5
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(Palette.sepia.opacity(0.55)))
                continue
            }
            let r: CGFloat = 7
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [Palette.brassLight, Palette.brass, Palette.brassDark]),
                center: CGPoint(x: p.x - 2, y: p.y - 2), startRadius: 0, endRadius: r + 2))
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0x5E430C)), lineWidth: 1.5)
            if showNames { drawCityName(GameMap.cities[i].name, at: CGPoint(x: p.x, y: p.y - 17), in: ctx) }
        }

        if let t = highlightTicket {
            let a = points[t.cityA], b = points[t.cityB]
            var line = Path(); line.move(to: a); line.addLine(to: b)
            ctx.stroke(line, with: .color(Palette.brass),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [3, 7]))
            for c in [a, b] {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 12, y: c.y - 12, width: 24, height: 24)),
                           with: .color(Palette.brass), lineWidth: 3)
            }
        }
    }

    // City label set on a small parchment chip so it stays legible over the map.
    private static func drawCityName(_ name: String, at center: CGPoint, in ctx: GraphicsContext) {
        let text = Text(name).font(.system(size: 11, weight: .semibold, design: .serif))
            .foregroundStyle(Palette.ink)
        let resolved = ctx.resolve(text)
        let s = resolved.measure(in: CGSize(width: 200, height: 40))
        let chip = CGRect(x: center.x - s.width / 2 - 5, y: center.y - s.height / 2 - 2,
                          width: s.width + 10, height: s.height + 4)
        let path = Path(roundedRect: chip, cornerRadius: 4)
        ctx.fill(path, with: .color(Palette.parchment.opacity(0.92)))
        ctx.stroke(path, with: .color(Palette.brassHair), lineWidth: 1)
        ctx.draw(resolved, at: center)
    }

    // Beads along a seized rail (used in the move-recap image instead of pips).
    private static func drawDots(in ctx: GraphicsContext, from a: CGPoint, to b: CGPoint, cars: Int) {
        let dx = b.x - a.x, dy = b.y - a.y
        for k in 0..<cars {
            let t = (CGFloat(k) + 0.5) / CGFloat(cars)
            let c = CGPoint(x: a.x + dx * t, y: a.y + dy * t)
            let r: CGFloat = 3.5
            let dot = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(Palette.brass))
            ctx.stroke(dot, with: .color(Color(hex: 0x5E430C)), lineWidth: 1.5)
        }
    }

    // Row of skewed enamel train cars along the route.
    private static func drawTrack(in ctx: GraphicsContext, from a: CGPoint, to b: CGPoint,
                                  cars: Int, fill: Color, ghost: Bool, glow: Bool) {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 1)
        let angle = atan2(dy, dx)
        let carLen = (length / CGFloat(cars)) * 0.74
        let height: CGFloat = 13
        for k in 0..<cars {
            let t = (CGFloat(k) + 0.5) / CGFloat(cars)
            let center = CGPoint(x: a.x + dx * t, y: a.y + dy * t)
            let car = carPath(center: center, len: carLen, height: height, angle: angle)
            if ghost {
                ctx.stroke(car, with: .color(fill.opacity(0.8)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            } else {
                if glow { ctx.stroke(car, with: .color(Palette.brass.opacity(0.55)), lineWidth: 4) }
                ctx.fill(car, with: .color(fill))
                ctx.stroke(car, with: .color(.black.opacity(0.45)), lineWidth: 1)
            }
        }
    }

    private static func carPath(center: CGPoint, len: CGFloat, height: CGFloat, angle: CGFloat) -> Path {
        let s = height * 0.34
        var p = Path()
        p.move(to: CGPoint(x: -len / 2 + s, y: -height / 2))
        p.addLine(to: CGPoint(x: len / 2 + s, y: -height / 2))
        p.addLine(to: CGPoint(x: len / 2 - s, y: height / 2))
        p.addLine(to: CGPoint(x: -len / 2 - s, y: height / 2))
        p.closeSubpath()
        return p.applying(CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle))
    }

    static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = max(0, min(1, t))
        let proj = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return hypot(p.x - proj.x, p.y - proj.y)
    }
}
