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

    // Three zoom levels: 0 = whole US (with map), 1 = read detail, 2 = closest.
    @State private var zoomLevel = 0
    private let aspect: CGFloat = BoardGeometry.mapAspect   // true US shape
    private let scales: [CGFloat] = [1.0, 3.7, 6.6]

    var body: some View {
        GeometryReader { geo in
            Group {
                if let t = highlightTicket {
                    DestinationBoard(state: state, ticket: t, aspect: aspect)
                } else if let rid = centerRouteId {
                    CenteredRouteBoard(state: state, routeId: rid, aspect: aspect, scale: scales[1], onTap: onClearCenter)
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
        let scale = scales[zoomLevel]
        let zoomedIn = zoomLevel > 0   // detail style + names once zoomed in
        let contentW = fitW * scale
        let contentH = fitW * aspect * scale   // proportional so the US map isn't distorted
        return ScrollView([.horizontal, .vertical], showsIndicators: false) {
            BoardView(state: state, selectedRouteId: selectedRouteId,
                      canAct: canAct, claimable: claimable, onSelect: onSelect,
                      showNames: zoomedIn, style: zoomedIn ? .cars : .thin,
                      focusedOwner: focusedOwner, highlightTickets: highlightTickets,
                      onBackgroundTap: onBackgroundTap)
                .frame(width: contentW, height: contentH)
                .frame(minWidth: geo.size.width, minHeight: geo.size.height) // center when small
        }
    }

    // Cycles overview -> in -> closer -> overview. No animation: animating the
    // scroll content's frame made the background appear to zoom the wrong way.
    private var zoomButton: some View {
        Button { zoomLevel = (zoomLevel + 1) % scales.count } label: {
            Image(systemName: zoomLevel == scales.count - 1 ? "minus.magnifyingglass" : "plus.magnifyingglass")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.sepia)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.parchment).overlay(Circle().stroke(Palette.brassHair, lineWidth: 1)))
        }
        .padding(8)
    }

    private var mapSurface: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0xD7CCB7), Color(hex: 0xCBBB9D), Color(hex: 0xC1AF8C)],
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
    // The board is laid out in a normalized space of width 1 and height mapAspect
    // (the true US aspect ratio). point() fits that box into the frame WITHOUT
    // distortion and centers it, so the dots and the US outline keep real shape.
    static let mapAspect: CGFloat = 0.5715

    static func point(_ nx: Double, _ ny: Double, in size: CGSize) -> CGPoint {
        let padX: CGFloat = 24, padY: CGFloat = 16
        let w = size.width - padX * 2, h = size.height - padY * 2
        let s = min(w, h / mapAspect)               // uniform scale, preserve aspect
        let ox = padX + (w - s) / 2                 // center horizontally
        let oy = padY + (h - s * mapAspect) / 2     // center vertically
        return CGPoint(x: ox + CGFloat(nx) * s, y: oy + CGFloat(ny) * s)
    }

    static func positions(in size: CGSize) -> [CGPoint] {
        GameMap.cities.map { point($0.x, $0.y, in: size) }
    }

    // Faint actual continental-US outline behind the routes so the board reads as
    // a real map. Real Natural-Earth boundary coordinates, projected into the same
    // normalized city space so it aligns with the cities and scales with the board.
    private static let usOutline: [(Double, Double)] = [
        (0.5175, 0.0365), (0.5205, 0.0486), (0.5259, 0.0524), (0.538, 0.0537), (0.5557, 0.0572), (0.5725, 0.064),
        (0.5866, 0.0612), (0.6079, 0.0669), (0.6135, 0.0667), (0.629, 0.0604), (0.6453, 0.0684), (0.6622, 0.0769),
        (0.6762, 0.0843), (0.6897, 0.0913), (0.6914, 0.0971), (0.6955, 0.0993), (0.6944, 0.1014), (0.699, 0.1021),
        (0.7024, 0.0999), (0.7033, 0.1051), (0.7068, 0.1085), (0.7115, 0.1085), (0.7141, 0.1112), (0.7119, 0.1152),
        (0.73, 0.1255), (0.7337, 0.1454), (0.7371, 0.1646), (0.7321, 0.1776), (0.7239, 0.1897), (0.7201, 0.1974),
        (0.7197, 0.1997), (0.7217, 0.2028), (0.7276, 0.2063), (0.7319, 0.2063), (0.752, 0.1945), (0.7699, 0.1911),
        (0.7925, 0.1801), (0.7929, 0.1779), (0.7913, 0.1712), (0.7885, 0.1669), (0.7963, 0.1634), (0.8134, 0.1633),
        (0.8293, 0.1633), (0.8348, 0.1547), (0.837, 0.153), (0.8553, 0.1372), (0.8631, 0.1331), (0.8894, 0.133),
        (0.9213, 0.1329), (0.9231, 0.1275), (0.9286, 0.1264), (0.936, 0.123), (0.9421, 0.113), (0.9474, 0.0959),
        (0.9606, 0.0793), (0.9664, 0.085), (0.978, 0.0813), (0.9857, 0.0877), (0.9857, 0.1177), (0.997, 0.1301),
        (1, 0.1373), (0.9815, 0.148), (0.9637, 0.1556), (0.9454, 0.1621), (0.9362, 0.1751), (0.9333, 0.1801),
        (0.9331, 0.1918), (0.9388, 0.2034), (0.946, 0.204), (0.9442, 0.1959), (0.9494, 0.2008), (0.948, 0.2071),
        (0.9363, 0.2107), (0.928, 0.2103), (0.9152, 0.2141), (0.9077, 0.2152), (0.8976, 0.2163), (0.8831, 0.2227),
        (0.9086, 0.2185), (0.9137, 0.2227), (0.8895, 0.2293), (0.8784, 0.2293), (0.8789, 0.2266), (0.8737, 0.2327),
        (0.8788, 0.2337), (0.875, 0.2495), (0.8624, 0.2665), (0.8611, 0.2608), (0.8573, 0.2597), (0.8516, 0.2542),
        (0.8552, 0.266), (0.8595, 0.2699), (0.8598, 0.2783), (0.8543, 0.2868), (0.8445, 0.3044), (0.8429, 0.3035),
        (0.8483, 0.2885), (0.8394, 0.2801), (0.8374, 0.2619), (0.8341, 0.2714), (0.8378, 0.2853), (0.8263, 0.2819),
        (0.8382, 0.289), (0.839, 0.3099), (0.844, 0.3114), (0.8458, 0.319), (0.8482, 0.3411), (0.8372, 0.3574),
        (0.8193, 0.3639), (0.8079, 0.3768), (0.7992, 0.3782), (0.7904, 0.3863), (0.788, 0.3937), (0.769, 0.408),
        (0.7592, 0.4184), (0.751, 0.4315), (0.7484, 0.4471), (0.7514, 0.4624), (0.7572, 0.4812), (0.7649, 0.4968),
        (0.765, 0.5063), (0.7732, 0.5318), (0.7726, 0.5467), (0.7719, 0.5552), (0.7676, 0.5687), (0.7624, 0.5715),
        (0.7539, 0.5688), (0.7511, 0.5591), (0.7445, 0.5541), (0.7354, 0.5351), (0.7273, 0.5183), (0.7247, 0.5097),
        (0.7283, 0.4951), (0.7234, 0.483), (0.7099, 0.4646), (0.7031, 0.4612), (0.6857, 0.4712), (0.6826, 0.4701),
        (0.6742, 0.4598), (0.6633, 0.4544), (0.6437, 0.4572), (0.6283, 0.4547), (0.6151, 0.4562), (0.608, 0.4597),
        (0.6111, 0.4655), (0.6108, 0.4744), (0.6145, 0.4788), (0.6112, 0.4817), (0.6048, 0.4784), (0.5983, 0.4826),
        (0.5857, 0.4819), (0.5727, 0.4703), (0.5576, 0.473), (0.545, 0.4679), (0.5343, 0.4695), (0.5197, 0.4746),
        (0.5039, 0.4909), (0.4867, 0.5004), (0.4772, 0.5109), (0.4733, 0.5208), (0.4731, 0.536), (0.4739, 0.5466),
        (0.4772, 0.5541), (0.4705, 0.5547), (0.4582, 0.5499), (0.4447, 0.5431), (0.4398, 0.5327), (0.436, 0.5173),
        (0.4258, 0.5048), (0.4198, 0.4919), (0.4111, 0.4768), (0.3989, 0.468), (0.3847, 0.4685), (0.3738, 0.4859),
        (0.3594, 0.4793), (0.3505, 0.4726), (0.3462, 0.4605), (0.3404, 0.449), (0.3301, 0.4393), (0.3213, 0.4324),
        (0.3149, 0.4246), (0.2849, 0.4246), (0.2849, 0.4337), (0.2712, 0.4337), (0.2367, 0.4338), (0.1972, 0.4183),
        (0.171, 0.4076), (0.1727, 0.4033), (0.1506, 0.4057), (0.131, 0.4074), (0.128, 0.3962), (0.1168, 0.3835),
        (0.1087, 0.3809), (0.1068, 0.3746), (0.0971, 0.3735), (0.0909, 0.3675), (0.0748, 0.3653), (0.0704, 0.3618),
        (0.0683, 0.3497), (0.0515, 0.3276), (0.0371, 0.297), (0.0377, 0.2919), (0.03, 0.2847), (0.0166, 0.2662),
        (0.0142, 0.2483), (0.005, 0.2363), (0.0088, 0.218), (0.0082, 0.1991), (0.0027, 0.1823), (0.0094, 0.1615),
        (0.0115, 0.1416), (0.0137, 0.1216), (0.0105, 0.0921), (0.0051, 0.0733), (0, 0.0631), (0.0021, 0.0588),
        (0.0272, 0.0662), (0.0364, 0.087), (0.0407, 0.0812), (0.0379, 0.0632), (0.032, 0.0451), (0.0812, 0.0451),
        (0.1326, 0.0451), (0.1497, 0.0451), (0.2025, 0.0451), (0.2536, 0.0451), (0.3056, 0.0451), (0.3576, 0.0451),
        (0.4164, 0.0451), (0.4757, 0.0451), (0.5116, 0.0451), (0.5116, 0.0367), (0.5175, 0.0365),
    ]

    // Southern Canada, same projection, so the Canadian cities sit on land too.
    // It runs far north; the frame clip crops it to the visible border strip.
    private static let canadaOutline: [(Double, Double)] = [
        (0.5915, -0.4059), (0.5914, -0.3834), (0.6145, -0.4007), (0.6352, -0.3865), (0.6301, -0.3702), (0.6468, -0.3553),
        (0.6649, -0.3712), (0.6776, -0.3902), (0.6785, -0.4144), (0.7031, -0.4127), (0.7287, -0.4095), (0.752, -0.3985),
        (0.753, -0.3876), (0.7401, -0.3759), (0.7524, -0.3641), (0.7502, -0.3534), (0.7162, -0.338), (0.6921, -0.3346),
        (0.6742, -0.3413), (0.6691, -0.3302), (0.6524, -0.3116), (0.6473, -0.302), (0.6272, -0.2871), (0.6024, -0.2857),
        (0.5887, -0.2764), (0.5876, -0.2621), (0.5674, -0.2593), (0.5462, -0.2415), (0.5274, -0.2167), (0.5207, -0.1994),
        (0.5198, -0.1738), (0.5452, -0.1701), (0.553, -0.1495), (0.5611, -0.1328), (0.5854, -0.1372), (0.6176, -0.1277),
        (0.6349, -0.1193), (0.6473, -0.1089), (0.669, -0.1028), (0.6873, -0.0936), (0.716, -0.0923), (0.7348, -0.0902),
        (0.732, -0.0711), (0.7374, -0.049), (0.7499, -0.0244), (0.7757, -0.0035), (0.789, -0.0106), (0.7984, -0.0333),
        (0.7893, -0.068), (0.7771, -0.0796), (0.8049, -0.0899), (0.8245, -0.1053), (0.8341, -0.1207), (0.8327, -0.1354),
        (0.8209, -0.1541), (0.7999, -0.1706), (0.8203, -0.1937), (0.8128, -0.2136), (0.807, -0.248), (0.819, -0.2531),
        (0.8487, -0.2471), (0.8665, -0.2449), (0.8809, -0.2507), (0.897, -0.2433), (0.9184, -0.2305), (0.9236, -0.222),
        (0.9545, -0.2203), (0.954, -0.2018), (0.9598, -0.174), (0.9756, -0.1706), (0.9881, -0.1576), (1.0132, -0.1698),
        (1.0298, -0.1941), (1.0413, -0.2043), (1.0547, -0.1847), (1.0773, -0.1566), (1.0965, -0.1302), (1.0895, -0.1164),
        (1.1125, -0.104), (1.1281, -0.0914), (1.1557, -0.0857), (1.1669, -0.0787), (1.1737, -0.0601), (1.1872, -0.0572),
        (1.1942, -0.0489), (1.1954, -0.0241), (1.1829, -0.0159), (1.1704, -0.0081), (1.1419, -0.0003), (1.1201, 0.0178),
        (1.0908, 0.0213), (1.0537, 0.0167), (1.0277, 0.0165), (1.0098, 0.0181), (0.9953, 0.0339), (0.9732, 0.0436),
        (0.9482, 0.0727), (0.9283, 0.093), (0.943, 0.0894), (0.9708, 0.0605), (1.0071, 0.0422), (1.0331, 0.04),
        (1.0484, 0.0508), (1.032, 0.0656), (1.0375, 0.0893), (1.0432, 0.1059), (1.0657, 0.1169), (1.0943, 0.1137),
        (1.1117, 0.0889), (1.1129, 0.1049), (1.1241, 0.1129), (1.1026, 0.1273), (1.0643, 0.1404), (1.0471, 0.1493),
        (1.0277, 0.1651), (1.0146, 0.1635), (1.0139, 0.1449), (1.044, 0.1267), (1.0163, 0.1274), (0.997, 0.1301),
        (0.9857, 0.1177), (0.9857, 0.0877), (0.978, 0.0813), (0.9664, 0.085), (0.9606, 0.0793), (0.9474, 0.0959),
        (0.9421, 0.113), (0.936, 0.123), (0.9286, 0.1264), (0.9231, 0.1275), (0.9213, 0.1329), (0.8894, 0.133),
        (0.8631, 0.1331), (0.8553, 0.1372), (0.837, 0.153), (0.8348, 0.1547), (0.8293, 0.1633), (0.8134, 0.1633),
        (0.7963, 0.1634), (0.7885, 0.1669), (0.7913, 0.1712), (0.7929, 0.1779), (0.7925, 0.1801), (0.7699, 0.1911),
        (0.752, 0.1945), (0.7319, 0.2063), (0.7276, 0.2063), (0.7217, 0.2028), (0.7197, 0.1997), (0.7201, 0.1974),
        (0.7239, 0.1897), (0.7321, 0.1776), (0.7371, 0.1646), (0.7337, 0.1454), (0.73, 0.1255), (0.7119, 0.1152),
        (0.7141, 0.1112), (0.7115, 0.1085), (0.7068, 0.1085), (0.7033, 0.1051), (0.7024, 0.0999), (0.699, 0.1021),
        (0.6944, 0.1014), (0.6955, 0.0993), (0.6914, 0.0971), (0.6897, 0.0913), (0.6762, 0.0843), (0.6622, 0.0769),
        (0.6453, 0.0684), (0.629, 0.0604), (0.6135, 0.0667), (0.6079, 0.0669), (0.5866, 0.0612), (0.5725, 0.064),
        (0.5557, 0.0572), (0.538, 0.0537), (0.5259, 0.0524), (0.5205, 0.0486), (0.5175, 0.0365), (0.5116, 0.0367),
        (0.5116, 0.0451), (0.4757, 0.0451), (0.4164, 0.0451), (0.3576, 0.0451), (0.3056, 0.0451), (0.2536, 0.0451),
        (0.2025, 0.0451), (0.1497, 0.0451), (0.1326, 0.0451), (0.0812, 0.0451), (0.032, 0.0451), (0.0297, 0.0451),
        (-0.0039, 0.0234), (-0.0162, 0.0139), (-0.0476, 0.0048), (-0.0573, -0.0147), (-0.0548, -0.0282), (-0.077, -0.0375),
        (-0.08, -0.0553), (-0.101, -0.0712), (-0.1013, -0.0826), (-0.0917, -0.0932), (-0.0922, -0.1071), (-0.1216, -0.1211),
        (-0.1393, -0.1462), (-0.1502, -0.162), (-0.166, -0.1719), (-0.1777, -0.1809), (-0.1869, -0.1923), (-0.2043, -0.1851),
        (-0.2211, -0.1728), (-0.2365, -0.1873), (-0.2486, -0.1969), (-0.2655, -0.203), (-0.2826, -0.2037), (-0.2825, -0.329),
        (-0.2824, -0.4106), (-0.25, -0.4053), (-0.2228, -0.3948), (-0.2047, -0.3927), (-0.1895, -0.4019), (-0.1685, -0.4088),
        (-0.1428, -0.4061), (-0.1168, -0.4158), (-0.0885, -0.4212), (-0.0766, -0.4121), (-0.0637, -0.4173), (-0.0598, -0.4276),
        (-0.0478, -0.4253), (-0.0185, -0.4056), (0.0045, -0.4205), (0.0069, -0.4038), (0.0282, -0.4074), (0.0347, -0.4138),
        (0.0557, -0.4125), (0.0822, -0.4033), (0.1227, -0.3952), (0.1466, -0.3915), (0.1635, -0.3929), (0.1869, -0.3818),
        (0.1625, -0.3708), (0.1939, -0.3661), (0.2406, -0.3687), (0.2554, -0.3726), (0.2738, -0.3594), (0.2927, -0.3705),
        (0.275, -0.3798), (0.2862, -0.3874), (0.3073, -0.3884), (0.3211, -0.3906), (0.3351, -0.3853), (0.3525, -0.3734),
        (0.3719, -0.3751), (0.4025, -0.3652), (0.4294, -0.3687), (0.4547, -0.3682), (0.4527, -0.3819), (0.4681, -0.3857),
        (0.4949, -0.3782), (0.4948, -0.3574), (0.5058, -0.375), (0.5198, -0.3744), (0.5276, -0.3965), (0.509, -0.4101),
        (0.4888, -0.419), (0.4902, -0.4433), (0.5107, -0.4592), (0.5335, -0.4557), (0.5511, -0.446), (0.5746, -0.4212),
        (0.5592, -0.4104), (0.5915, -0.4059),
    ]

    static func drawUSMap(in ctx: GraphicsContext, size: CGSize) {
        var c = ctx
        // Mask the land with a vertical alpha gradient so Canada fades out toward
        // the top edge instead of ending in a hard cut (also crops the off-frame north).
        let fadeH = size.height * 0.15
        c.clipToLayer { layer in
            layer.fill(Path(CGRect(x: 0, y: fadeH, width: size.width, height: size.height - fadeH)),
                       with: .color(.white))
            layer.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: fadeH)),
                       with: .linearGradient(Gradient(colors: [.clear, .white]),
                                             startPoint: CGPoint(x: 0, y: 0),
                                             endPoint: CGPoint(x: 0, y: fadeH)))
        }
        fillLand(canadaOutline, in: c, size: size)
        fillLand(usOutline, in: c, size: size)
        for ring in stateOutlines {   // faint interior state lines
            var path = Path()
            for (i, pt) in ring.enumerated() {
                let p = point(pt.0, pt.1, in: size)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            c.stroke(path, with: .color(Palette.sepia.opacity(0.16)), lineWidth: 0.6)
        }
    }

    private static func fillLand(_ outline: [(Double, Double)], in ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        for (i, c) in outline.enumerated() {
            let p = point(c.0, c.1, in: size)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(Color(hex: 0x8AA06A).opacity(0.20)))         // faint land
        ctx.stroke(path, with: .color(Palette.sepia.opacity(0.38)), lineWidth: 1.3) // coastline
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
        if style == .thin { drawUSMap(in: ctx, size: size) }   // map only on the zoomed-out view
        // Group routes by city pair so a double route draws as two offset parallel
        // tracks, and a track locked by its claimed sibling can be faded out.
        var pairs: [Int: [Int]] = [:]
        for r in state.routes {
            let key = min(r.cityA, r.cityB) * 1000 + max(r.cityA, r.cityB)
            pairs[key, default: []].append(r.id)
        }
        for route in state.routes {
            var a = points[route.cityA], b = points[route.cityB]
            let owner = route.claimedBy
            let key = min(route.cityA, route.cityB) * 1000 + max(route.cityA, route.cityB)
            let group = pairs[key] ?? [route.id]
            if group.count > 1, let pos = group.firstIndex(of: route.id) {
                let dx = b.x - a.x, dy = b.y - a.y
                let len = max(hypot(dx, dy), 1)
                let off = (pos == 0 ? -1.0 : 1.0) * (style == .cars ? 9.0 : 5.0)
                let ox = -dy / len * off, oy = dx / len * off
                a = CGPoint(x: a.x + ox, y: a.y + oy); b = CGPoint(x: b.x + ox, y: b.y + oy)
            }
            // Parallel sibling already taken -> this track is locked: grey it out.
            let lockedBySibling = owner == nil && group.contains { id in
                id != route.id && (state.routes.first { $0.id == id }?.claimedBy != nil)
            }
            let claimable = owner == nil && !lockedBySibling && highlightClaimable(route)

            // Focus mode: spotlight one player, fade everything else right down.
            var alpha = 1.0
            if let f = focusedOwner { alpha = (owner == f) ? 1 : 0.07 }
            if lockedBySibling { alpha *= 0.28 }   // greyed-out locked parallel track

            if style == .cars {
                if let owner {
                    drawBoxCars(in: ctx, from: a, to: b, cars: route.length,
                                fill: ownerColor(owner).opacity(alpha), kind: .owned)
                } else if claimable {
                    drawBoxCars(in: ctx, from: a, to: b, cars: route.length,
                                fill: paintColor(route.color).opacity(alpha), kind: .buyable,
                                light: isLightPaint(route.color))
                } else {
                    drawBoxCars(in: ctx, from: a, to: b, cars: route.length,
                                fill: paintColor(route.color).opacity(alpha * 0.85), kind: .open,
                                light: isLightPaint(route.color))
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
                                    cars: Int, fill: Color, kind: CarKind, light: Bool = false) {
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
                // Can't buy it (yet): dashed outline, no fill. Light colors (white/
                // yellow) wash out, so draw them thicker to stay visible.
                ctx.stroke(car, with: .color(fill), style: StrokeStyle(lineWidth: light ? 3.7 : 1.7, dash: [3, 2]))
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
