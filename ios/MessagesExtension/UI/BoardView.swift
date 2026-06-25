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

    var body: some View {
        GeometryReader { geo in
            let pts = BoardGeometry.positions(in: geo.size)
            ZStack {
                Canvas { ctx, size in
                    BoardGeometry.draw(state, in: ctx, points: pts, size: size,
                                       selected: selectedRouteId, highlightTicket: highlightTicket,
                                       showNames: showNames,
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

// Bigger board the user can pan and zoom. Fit mode shows the whole map; the
// zoom button enlarges it and the user drags to move around.
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

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                BoardView(state: state, selectedRouteId: selectedRouteId, highlightTicket: highlightTicket,
                          canAct: canAct, claimable: claimable, onSelect: onSelect, showNames: zoomed)
                    .frame(width: contentW, height: contentH)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height) // center when small
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(UIColor.tertiarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primary.opacity(0.07)))
            .overlay(alignment: .topTrailing) {
                Button { withAnimation(.snappy) { zoomed.toggle() } } label: {
                    Image(systemName: zoomed ? "minus.magnifyingglass" : "plus.magnifyingglass")
                        .font(.body.weight(.semibold)).padding(8)
                        .background(.thinMaterial, in: Circle())
                }
                .padding(8)
            }
        }
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
                     highlightClaimable: (Route) -> Bool) {
        for route in state.routes {
            let a = points[route.cityA], b = points[route.cityB]
            let owner = route.claimedBy
            let claimable = owner == nil && highlightClaimable(route)
            let fill: Color = owner != nil ? ownerColor(owner!)
                : (claimable ? paintColor(route.color) : paintColor(route.color).opacity(0.45))

            if route.id == selected { // selection halo
                var halo = Path(); halo.move(to: a); halo.addLine(to: b)
                ctx.stroke(halo, with: .color(Color.brand.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 16, lineCap: .round))
            }

            drawTrack(in: ctx, from: a, to: b, cars: route.length, fill: fill, ghost: owner == nil && !claimable)

            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            ctx.fill(Path(ellipseIn: CGRect(x: mid.x - 8, y: mid.y - 8, width: 16, height: 16)),
                     with: .color(owner != nil ? ownerColor(owner!) : paintColor(route.color)))
            ctx.stroke(Path(ellipseIn: CGRect(x: mid.x - 8, y: mid.y - 8, width: 16, height: 16)),
                       with: .color(.white.opacity(0.9)), lineWidth: 1)
            ctx.draw(Text("\(route.length)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white), at: mid)
        }

        for (i, p) in points.enumerated() {
            let r: CGFloat = 7
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                       with: .color(Color.brand), lineWidth: 2)
            if showNames {
                ctx.draw(Text(GameMap.cities[i].name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary),
                         at: CGPoint(x: p.x, y: p.y - 15))
            }
        }

        if let t = highlightTicket {
            let a = points[t.cityA], b = points[t.cityB]
            var line = Path(); line.move(to: a); line.addLine(to: b)
            ctx.stroke(line, with: .color(Color.brand),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [3, 7]))
            for c in [a, b] {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 12, y: c.y - 12, width: 24, height: 24)),
                           with: .color(Color.brand), lineWidth: 3)
            }
        }
    }

    private static func drawTrack(in ctx: GraphicsContext, from a: CGPoint, to b: CGPoint,
                                  cars: Int, fill: Color, ghost: Bool) {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 1)
        let angle = atan2(dy, dx)
        let carLen = (length / CGFloat(cars)) * 0.72
        for k in 0..<cars {
            let t = (CGFloat(k) + 0.5) / CGFloat(cars)
            let cx = a.x + dx * t, cy = a.y + dy * t
            var car = ctx
            car.translateBy(x: cx, y: cy)
            car.rotate(by: .radians(angle))
            let rect = CGRect(x: -carLen / 2, y: -3.5, width: carLen, height: 7)
            let body = Path(roundedRect: rect, cornerRadius: 2)
            car.fill(body, with: .color(fill))
            car.stroke(body, with: .color(.black.opacity(ghost ? 0.15 : 0.5)), lineWidth: 1)
        }
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
