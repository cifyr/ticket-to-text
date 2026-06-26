import SwiftUI

// How a board is rendered: detailed enamel box cars (zoomed in) vs thin
// dashed lines (zoomed out & the message snapshot).
enum BoardStyle { case cars, thin }

// The board canvas. Tapping near any route reports it via onSelect so the
// caller can show exactly what it costs. The selected route is haloed.
struct BoardView: View {
    let state: GameState
    let selectedRouteId: Int?
    let canAct: Bool
    let claimable: (Route) -> Bool
    let onSelect: (Int) -> Void
    var showNames: Bool = true
    var nameCities: Set<Int>? = nil   // when set, only label these cities (ticket path)
    var style: BoardStyle = .cars
    var focusedOwner: Int? = nil      // when set, only this player's routes stay lit
    var highlightTickets: [Ticket] = []   // red A->B lines for tickets being chosen
    var onBackgroundTap: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let pts = BoardGeometry.positions(in: geo.size)
            ZStack {
                Canvas { ctx, size in
                    BoardGeometry.draw(state, in: ctx, points: pts, size: size,
                                       selected: selectedRouteId, showNames: showNames,
                                       nameCities: nameCities, style: style, focusedOwner: focusedOwner,
                                       highlightClaimable: canAct ? claimable : { _ in false })
                    for t in highlightTickets {
                        BoardGeometry.drawTicketLine(in: ctx, from: pts[t.cityA], to: pts[t.cityB])
                    }
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
    var highlightTickets: [Ticket] = []   // red A->B lines for tickets being chosen
    var onBackgroundTap: (() -> Void)? = nil
    var centerRouteId: Int? = nil     // parent asks to zoom in + center on this route
    var onClearCenter: () -> Void = {}

    @State private var zoomed = false   // default: zoomed out (thin lines, no names)
    private let aspect: CGFloat = 0.74
    private let baseScale: CGFloat = 1.18   // zoomed out: the whole map roughly fits
    private let closeScale: CGFloat = 3.7   // zoomed in: large enough to read detail

    var body: some View {
        GeometryReader { geo in
            Group {
                if let t = highlightTicket {
                    DestinationBoard(state: state, ticket: t, aspect: aspect)
                } else if let rid = centerRouteId {
                    CenteredRouteBoard(state: state, routeId: rid, aspect: aspect, scale: closeScale, onTap: onClearCenter)
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
        let vStretch: CGFloat = zoomed ? 1 : 1.22   // zoomed-out reads a touch taller
        let contentW = fitW * scale
        let contentH = fitW * aspect * scale * vStretch
        return ScrollView([.horizontal, .vertical], showsIndicators: false) {
            BoardView(state: state, selectedRouteId: selectedRouteId,
                      canAct: canAct, claimable: claimable, onSelect: onSelect,
                      showNames: zoomed, style: zoomed ? .cars : .thin,
                      focusedOwner: focusedOwner, highlightTickets: highlightTickets,
                      onBackgroundTap: onBackgroundTap)
                .frame(width: contentW, height: contentH)
                .frame(minWidth: geo.size.width, minHeight: geo.size.height) // center when small
        }
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

// Zoomed-in board statically translated so a given route sits dead center.
// Deterministic (no scrolling), so a log jump always lands on the right route.
// Tap anywhere to return to the interactive map.
private struct CenteredRouteBoard: View {
    let state: GameState
    let routeId: Int
    let aspect: CGFloat
    let scale: CGFloat
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let fitW = min(geo.size.width, geo.size.height / aspect)
            let contentW = fitW * scale
            let contentH = fitW * aspect * scale
            let mid = routeMidpoint(in: CGSize(width: contentW, height: contentH))
            BoardView(state: state, selectedRouteId: nil, canAct: false,
                      claimable: { _ in false }, onSelect: { _ in }, showNames: true, style: .cars)
                .frame(width: contentW, height: contentH)
                .offset(x: geo.size.width / 2 - mid.x, y: geo.size.height / 2 - mid.y)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                // Auto-release so it never gets stuck; a tap dismisses sooner.
                .task { try? await Task.sleep(nanoseconds: 1_500_000_000); onTap() }
        }
    }

    private func routeMidpoint(in size: CGSize) -> CGPoint {
        guard let r = state.routes.first(where: { $0.id == routeId }) else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let a = BoardGeometry.point(GameMap.cities[r.cityA].x, GameMap.cities[r.cityA].y, in: size)
        let b = BoardGeometry.point(GameMap.cities[r.cityB].x, GameMap.cities[r.cityB].y, in: size)
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

// Centered fit-to-frame board with an animated destination line drawn A -> B.
// Only the two endpoint cities are labelled.
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
                          claimable: { _ in false }, onSelect: { _ in },
                          showNames: true, nameCities: [ticket.cityA, ticket.cityB], style: .thin)
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
    // City coordinates only span x 0.04-0.94 and y 0.05-0.67, so we normalize to
    // those bounds — the map fills the frame instead of leaving a dead bottom third.
    private static let xMin = 0.04, xMax = 0.94, yMin = 0.05, yMax = 0.67

    static func point(_ nx: Double, _ ny: Double, in size: CGSize) -> CGPoint {
        let rx = (nx - xMin) / (xMax - xMin)
        let ry = (ny - yMin) / (yMax - yMin)
        // Generous padding so edge cities and their labels are never clipped.
        let padX: CGFloat = 50, padY: CGFloat = 34
        let w = size.width - padX * 2, h = size.height - padY * 2
        return CGPoint(x: padX + CGFloat(rx) * w, y: padY + CGFloat(ry) * h)
    }

    static func positions(in size: CGSize) -> [CGPoint] {
        GameMap.cities.map { point($0.x, $0.y, in: size) }
    }

    // Faint continent silhouette behind the routes so the board reads as a map.
    // Points are in the same normalized city space, so it aligns with the cities
    // and scales/pans with the board. Clockwise from the Pacific Northwest.
    private static let landOutline: [(Double, Double)] = [
        (0.03, 0.05), (0.18, 0.02), (0.42, 0.015), (0.56, 0.05),
        (0.60, 0.11), (0.66, 0.17), (0.70, 0.11), (0.76, 0.07),
        (0.83, 0.04), (0.92, 0.09), (0.985, 0.13), (0.93, 0.20),
        (0.895, 0.28), (0.865, 0.38), (0.87, 0.44), (0.89, 0.52),
        (0.905, 0.61), (0.872, 0.70), (0.83, 0.60), (0.80, 0.53),
        (0.66, 0.61), (0.55, 0.64), (0.47, 0.61), (0.43, 0.57),
        (0.35, 0.585), (0.31, 0.55), (0.21, 0.555), (0.12, 0.545),
        (0.06, 0.46), (0.025, 0.40), (0.045, 0.30), (0.05, 0.22), (0.05, 0.14),
    ]

    static func drawLandmass(in ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        for (i, c) in landOutline.enumerated() {
            let p = point(c.0, c.1, in: size)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(Color(hex: 0x8AA06A).opacity(0.18)))        // faint land
        ctx.stroke(path, with: .color(Palette.sepia.opacity(0.30)), lineWidth: 1.3) // coastline
    }

    static func draw(_ state: GameState,
                     in ctx: GraphicsContext,
                     points: [CGPoint],
                     size: CGSize,
                     selected: Int?,
                     showNames: Bool,
                     nameCities: Set<Int>?,
                     style: BoardStyle,
                     focusedOwner: Int?,
                     highlightClaimable: (Route) -> Bool) {
        drawLandmass(in: ctx, size: size)
        for route in state.routes {
            let a = points[route.cityA], b = points[route.cityB]
            let owner = route.claimedBy
            let claimable = owner == nil && highlightClaimable(route)

            // Focus mode: spotlight one player, fade everything else right down.
            var alpha = 1.0
            if let f = focusedOwner { alpha = (owner == f) ? 1 : 0.07 }

            if style == .cars {
                if let owner {
                    drawBoxCars(in: ctx, from: a, to: b, cars: route.length,
                                fill: ownerColor(owner).opacity(alpha), kind: .owned)
                } else if claimable {
                    drawBoxCars(in: ctx, from: a, to: b, cars: route.length,
                                fill: paintColor(route.color).opacity(alpha), kind: .buyable)
                } else {
                    drawBoxCars(in: ctx, from: a, to: b, cars: route.length,
                                fill: paintColor(route.color).opacity(alpha * 0.85), kind: .open)
                }
                if route.id == selected {
                    var halo = Path(); halo.move(to: a); halo.addLine(to: b)
                    ctx.stroke(halo, with: .color(Palette.brass.opacity(0.4)),
                               style: StrokeStyle(lineWidth: 18, lineCap: .round))
                }
            } else {
                // Thin lines: owner color / gold (buyable) / lighter gold (open).
                let color: Color = owner != nil ? ownerColor(owner!) : (claimable ? Palette.brass : Palette.routeOpen)
                drawThinLine(in: ctx, from: a, to: b, cars: route.length, color: color.opacity(alpha),
                             solid: route.id == selected)
            }
        }

        let dotAlpha = focusedOwner == nil ? 1.0 : 0.5
        for (i, p) in points.enumerated() {
            let r: CGFloat = style == .cars ? 7 : 5
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [Palette.brassLight, Palette.brass, Palette.brassDark]),
                center: CGPoint(x: p.x - 2, y: p.y - 2), startRadius: 0, endRadius: r + 2))
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0x5E430C)), lineWidth: 1.5)
            let labelThis = showNames && (nameCities == nil || nameCities!.contains(i))
            if labelThis {
                drawCityName(GameMap.cities[i].name, at: CGPoint(x: p.x, y: p.y - 17), in: ctx, alpha: dotAlpha)
            }
        }
    }

    private enum CarKind { case owned, buyable, open }

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

    // Red dashed A->B line for a destination ticket being chosen, with endpoint
    // rings, so the player sees where each kept ticket goes on the zoomed-out map.
    static func drawTicketLine(in ctx: GraphicsContext, from a: CGPoint, to b: CGPoint) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        ctx.stroke(p, with: .color(Palette.routeHot.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 7, lineCap: .round))   // soft glow underlay
        ctx.stroke(p, with: .color(Palette.routeHot),
                   style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [9, 7]))
        for pt in [a, b] {
            let r: CGFloat = 7
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(Palette.routeHot.opacity(0.22)))
            ctx.stroke(Path(ellipseIn: rect), with: .color(Palette.routeHot), lineWidth: 2.5)
        }
    }

    // Thin line per route (zoomed-out & snapshot). Dashed per car so spaces are
    // countable; the selected route draws solid in the same color.
    private static func drawThinLine(in ctx: GraphicsContext, from a: CGPoint, to b: CGPoint,
                                     cars: Int, color: Color, solid: Bool) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        if solid {
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            return
        }
        let len = max(hypot(b.x - a.x, b.y - a.y), 1)
        let cell = len / CGFloat(max(cars, 1))
        let dash = cell * 0.6
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .butt, dash: [dash, cell - dash]))
    }

    // The live board's enamel box cars: one skewed car per train length.
    // owned = flat owner fill; buyable = purchase color + gold glow; open = dashed ghost.
    private static func drawBoxCars(in ctx: GraphicsContext, from a: CGPoint, to b: CGPoint,
                                    cars: Int, fill: Color, kind: CarKind) {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 1)
        let angle = atan2(dy, dx)
        let carLen = (length / CGFloat(max(cars, 1))) * 0.74
        let height: CGFloat = 13
        for k in 0..<cars {
            let t = (CGFloat(k) + 0.5) / CGFloat(cars)
            let center = CGPoint(x: a.x + dx * t, y: a.y + dy * t)
            let car = carPath(center: center, len: carLen, height: height, angle: angle)
            switch kind {
            case .open:
                // Can't buy it (yet): dashed outline, no fill.
                ctx.stroke(car, with: .color(fill), style: StrokeStyle(lineWidth: 1.7, dash: [3, 2]))
            case .buyable:
                // You can buy it: solid outline + gold glow, no fill.
                ctx.stroke(car, with: .color(Palette.brassLight.opacity(0.85)), lineWidth: 4.5)
                ctx.stroke(car, with: .color(fill), lineWidth: 2.4)
            case .owned:
                ctx.fill(car, with: .color(fill))
                ctx.stroke(car, with: .color(.black.opacity(0.5)), lineWidth: 1)
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
