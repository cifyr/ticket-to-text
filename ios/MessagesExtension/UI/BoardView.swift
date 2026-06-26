import SwiftUI

// The board canvas. Tapping near any route reports it via onSelect so the
// caller can show exactly what it costs. The selected route is haloed.
struct BoardView: View {
    let state: GameState
    let selectedRouteId: Int?
    let canAct: Bool
    let claimable: (Route) -> Bool
    let onSelect: (Int) -> Void
    var showNames: Bool = true
    var reportMode: Bool = false      // bubble snapshot / recap: thin colored lines
    var focusedOwner: Int? = nil      // when set, only this player's routes stay lit
    var onBackgroundTap: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let pts = BoardGeometry.positions(in: geo.size)
            ZStack {
                Canvas { ctx, size in
                    BoardGeometry.draw(state, in: ctx, points: pts, size: size,
                                       selected: selectedRouteId, showNames: showNames,
                                       focusedOwner: focusedOwner, reportMode: reportMode,
                                       highlightClaimable: canAct ? claimable : { _ in false })
                }
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { v in handleTap(v.location, points: pts) })
            }
        }
    }

    private func handleTap(_ p: CGPoint, points: [CGPoint]) {
        if focusedOwner != nil { onBackgroundTap?(); return }   // a tap clears the focus first
        var best: (id: Int, dist: CGFloat)?
        for route in state.routes {
            let d = BoardGeometry.distance(from: p, toSegment: points[route.cityA], points[route.cityB])
            if d < 26, best == nil || d < best!.dist { best = (route.id, d) }
        }
        if let best { onSelect(best.id) } else { onBackgroundTap?() }
    }
}

// Bigger board the user can pan and zoom, framed like an antique rail map.
// When showing a destination ticket it switches to a centered fit view that
// animates the A->B line in.
struct BoardArea: View {
    let state: GameState
    let selectedRouteId: Int?
    let highlightTicket: Ticket?
    let canAct: Bool
    let claimable: (Route) -> Bool
    let onSelect: (Int) -> Void
    var focusedOwner: Int? = nil
    var onBackgroundTap: (() -> Void)? = nil
    var centerRouteId: Int? = nil     // parent asks to zoom in + center on this route

    @State private var zoomed = false   // default: zoomed out (whole map, no names)
    private let aspect: CGFloat = 0.74
    private let baseScale: CGFloat = 1.18   // zoomed out: the whole map roughly fits
    private let closeScale: CGFloat = 3.7   // zoomed in: large enough to read detail

    var body: some View {
        GeometryReader { geo in
            Group {
                if let t = highlightTicket {
                    DestinationBoard(state: state, ticket: t, aspect: aspect)
                } else {
                    scrollMap(geo)
                }
            }
            .background(mapSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.brassHair, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 14).inset(by: 5)
                .stroke(Palette.brassHair, lineWidth: 1).allowsHitTesting(false))
            .overlay(alignment: .bottomLeading) {
                Text("RAIL MAP · 1908").font(.slab(10, .bold)).tracking(3)
                    .foregroundStyle(Palette.sepia.opacity(0.55)).padding(12).allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) { if highlightTicket == nil { zoomButton } }
            .shadow(color: Palette.ink.opacity(0.12), radius: 6, y: 3)
        }
    }

    private func scrollMap(_ geo: GeometryProxy) -> some View {
        let fitW = min(geo.size.width, geo.size.height / aspect)
        let scale: CGFloat = zoomed ? closeScale : baseScale
        let contentW = fitW * scale
        let contentH = fitW * aspect * scale
        return ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                BoardView(state: state, selectedRouteId: selectedRouteId,
                          canAct: canAct, claimable: claimable, onSelect: onSelect,
                          showNames: zoomed, focusedOwner: focusedOwner, onBackgroundTap: onBackgroundTap)
                    .frame(width: contentW, height: contentH)
                    .overlay { routeAnchors(CGSize(width: contentW, height: contentH)) }
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height) // center when small
            }
            .onChange(of: centerRouteId) { _, new in
                guard let id = new else { return }
                zoomed = true   // log jumps always land in the readable zoomed-in view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeInOut) { proxy.scrollTo("rt-\(id)", anchor: .center) }
                }
            }
        }
    }

    // Invisible center anchors so ScrollViewReader can recenter on any route.
    private func routeAnchors(_ size: CGSize) -> some View {
        ZStack {
            ForEach(state.routes) { r in
                let a = BoardGeometry.point(GameMap.cities[r.cityA].x, GameMap.cities[r.cityA].y, in: size)
                let b = BoardGeometry.point(GameMap.cities[r.cityB].x, GameMap.cities[r.cityB].y, in: size)
                Color.clear.frame(width: 1, height: 1)
                    .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    .id("rt-\(r.id)")
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private var zoomButton: some View {
        Button { withAnimation(.snappy) { zoomed.toggle() } } label: {
            Image(systemName: zoomed ? "minus.magnifyingglass" : "plus.magnifyingglass")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.sepia)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.parchment).overlay(Circle().stroke(Palette.brassHair, lineWidth: 1)))
        }
        .padding(8)
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

// Centered fit-to-frame board with an animated destination line drawn A -> B.
private struct DestinationBoard: View {
    let state: GameState
    let ticket: Ticket
    let aspect: CGFloat

    var body: some View {
        GeometryReader { geo in
            let fitW = min(geo.size.width, geo.size.height / aspect)
            let fitH = fitW * aspect
            let frame = CGSize(width: fitW, height: fitH)
            ZStack {
                BoardView(state: state, selectedRouteId: nil, canAct: false,
                          claimable: { _ in false }, onSelect: { _ in }, showNames: true)
                    .frame(width: fitW, height: fitH)
                DestinationLine(ticket: ticket, size: frame)
                    .frame(width: fitW, height: fitH)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct DestinationLine: View {
    let ticket: Ticket
    let size: CGSize
    @State private var progress: CGFloat = 0

    var body: some View {
        let a = BoardGeometry.point(GameMap.cities[ticket.cityA].x, GameMap.cities[ticket.cityA].y, in: size)
        let b = BoardGeometry.point(GameMap.cities[ticket.cityB].x, GameMap.cities[ticket.cityB].y, in: size)
        ZStack {
            Path { p in p.move(to: a); p.addLine(to: b) }
                .trim(from: 0, to: progress)
                .stroke(Palette.routeHot, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [9, 7]))
                .shadow(color: Palette.routeHot.opacity(0.6), radius: 6)
            ForEach([a, b].indices, id: \.self) { i in
                Circle().stroke(Palette.routeHot, lineWidth: 3)
                    .background(Circle().fill(Palette.routeHot.opacity(0.18)))
                    .frame(width: 26, height: 26)
                    .position([a, b][i])
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.0)) { progress = 1 } }
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
                     showNames: Bool,
                     focusedOwner: Int?,
                     reportMode: Bool,
                     highlightClaimable: (Route) -> Bool) {
        let newest = state.lastClaimedRouteId

        for route in state.routes {
            let a = points[route.cityA], b = points[route.cityB]
            let owner = route.claimedBy
            let claimable = owner == nil && highlightClaimable(route)
            let isNew = route.id == newest

            // Focus mode: spotlight one player, fade everything else right down.
            var alpha = 1.0
            if let f = focusedOwner { alpha = (owner == f) ? 1 : 0.07 }

            if route.id == selected && !reportMode {
                var halo = Path(); halo.move(to: a); halo.addLine(to: b)
                ctx.stroke(halo, with: .color(Palette.brass.opacity(0.4)),
                           style: StrokeStyle(lineWidth: 16, lineCap: .round))
            }

            if reportMode {
                // Simplified "send" view: one thin colored line per route.
                let color: Color = owner != nil ? (isNew ? Palette.routeHot : ownerColor(owner!)) : Palette.routeOpen
                drawThinLine(in: ctx, from: a, to: b, color: color.opacity(alpha),
                             width: isNew ? 3 : 2.2, glow: isNew ? Palette.routeHot.opacity(0.5 * alpha) : nil)
            } else {
                // Live board: the box-car design.
                let fill: Color
                let style: CarStyle
                if let owner {
                    fill = isNew ? Palette.routeHot : ownerColor(owner)
                    style = isNew ? .glow : .filled
                } else if claimable {
                    fill = Palette.brass; style = .glow
                } else {
                    fill = Palette.routeOpen; style = .ghost
                }
                drawBoxCars(in: ctx, from: a, to: b, cars: route.length, fill: fill.opacity(alpha), style: style)
            }
        }

        let dotAlpha = focusedOwner == nil ? 1.0 : 0.5
        for (i, p) in points.enumerated() {
            let r: CGFloat = reportMode ? 5 : 7
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [Palette.brassLight, Palette.brass, Palette.brassDark]),
                center: CGPoint(x: p.x - 2, y: p.y - 2), startRadius: 0, endRadius: r + 2))
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0x5E430C)), lineWidth: 1.5)
            if showNames {
                drawCityName(GameMap.cities[i].name, at: CGPoint(x: p.x, y: p.y - 17),
                             in: ctx, alpha: dotAlpha)
            }
        }
    }

    private enum CarStyle { case filled, glow, ghost }

    // City label set on a small parchment chip so it stays legible over the map.
    private static func drawCityName(_ name: String, at center: CGPoint, in ctx: GraphicsContext, alpha: Double) {
        let text = Text(name).font(.system(size: 11, weight: .semibold, design: .serif))
            .foregroundStyle(Palette.ink.opacity(alpha))
        let resolved = ctx.resolve(text)
        let s = resolved.measure(in: CGSize(width: 200, height: 40))
        let chip = CGRect(x: center.x - s.width / 2 - 5, y: center.y - s.height / 2 - 2,
                          width: s.width + 10, height: s.height + 4)
        let path = Path(roundedRect: chip, cornerRadius: 4)
        ctx.fill(path, with: .color(Palette.parchment.opacity(0.92 * alpha)))
        ctx.stroke(path, with: .color(Palette.brassHair.opacity(alpha)), lineWidth: 1)
        ctx.draw(resolved, at: center)
    }

    // A thin single line per route for the simplified "send" snapshot.
    private static func drawThinLine(in ctx: GraphicsContext, from a: CGPoint, to b: CGPoint,
                                     color: Color, width: CGFloat, glow: Color?) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        if let glow {
            ctx.stroke(p, with: .color(glow), style: StrokeStyle(lineWidth: width + 4, lineCap: .round))
        }
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    // The live board's enamel box cars: one skewed car per train length.
    private static func drawBoxCars(in ctx: GraphicsContext, from a: CGPoint, to b: CGPoint,
                                    cars: Int, fill: Color, style: CarStyle) {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 1)
        let angle = atan2(dy, dx)
        let carLen = (length / CGFloat(max(cars, 1))) * 0.74
        let height: CGFloat = 13
        for k in 0..<cars {
            let t = (CGFloat(k) + 0.5) / CGFloat(cars)
            let center = CGPoint(x: a.x + dx * t, y: a.y + dy * t)
            let car = carPath(center: center, len: carLen, height: height, angle: angle)
            switch style {
            case .ghost:
                ctx.stroke(car, with: .color(fill), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            case .glow:
                ctx.stroke(car, with: .color(Palette.brassLight.opacity(0.7)), lineWidth: 5)
                ctx.fill(car, with: .color(fill))
                ctx.stroke(car, with: .color(.black.opacity(0.45)), lineWidth: 1)
            case .filled:
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
