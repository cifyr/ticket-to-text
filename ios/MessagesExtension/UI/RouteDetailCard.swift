import SwiftUI

// Shows exactly what a tapped route costs and whether the player can afford it.
// Close is always a clear, full-size button so it's obvious how to get back.
struct RouteDetailCard: View {
    let route: Route
    let hand: [Card]
    let trains: Int
    let affordable: Bool
    var ownerName: String? = nil
    let onClaim: () -> Void
    let onClose: () -> Void

    private var wilds: Int { hand.filter { $0 == .locomotive }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(GameMap.label(route)).font(.slab(16, .bold)).foregroundStyle(Palette.ink).lineLimit(2)
                Spacer(minLength: 4)
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.sepia)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Palette.parchment).overlay(Circle().stroke(Palette.hairline, lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach(0..<route.length, id: \.self) { _ in
                    Parallelogram()
                        .fill(paintColor(route.color))
                        .frame(width: 20, height: 11)
                        .overlay(Parallelogram().stroke(.black.opacity(0.4), lineWidth: 0.75))
                }
                Text(costText).font(.sans(11)).foregroundStyle(Palette.sepia)
            }

            if let owner = route.claimedBy {
                Label("Claimed by \(ownerName ?? "Player \(owner + 1)")", systemImage: "checkmark.seal.fill")
                    .font(.sans(12, .semibold)).foregroundStyle(ownerColor(owner))
            } else {
                Text(affordText).font(.sans(11)).foregroundStyle(affordable ? Palette.ink : Palette.sepiaLight)
                // The claim button only appears when it's actually your turn and
                // you can pay — no dead "can't claim yet" button otherwise.
                if affordable {
                    Button(action: onClaim) { Label("Claim route", systemImage: "hand.tap.fill") }
                        .buttonStyle(BrassButtonStyle())
                }
            }
        }
        .stub(Palette.parchment, corner: 14, padding: 14, stroke: Palette.brassHair)
    }

    private var costText: String {
        let where_ = route.color == .gray ? "any one color" : route.color.rawValue
        return "\(route.length) trains · \(where_)"
    }

    private var affordText: String {
        if route.color == .gray {
            let best = Card.baseColors.max(by: { count($0) < count($1) }) ?? .red
            return "Pay any one color + wilds. Best: \(count(best)) \(best.rawValue) + \(wilds) wild (need \(route.length))."
        }
        let c = Card(rawValue: route.color.rawValue) ?? .red
        return "You have \(count(c)) \(c.rawValue) + \(wilds) wild (need \(route.length)). Trains left: \(trains)."
    }

    private func count(_ c: Card) -> Int { hand.filter { $0 == c }.count }
}

// Skewed train-car shape for cost previews.
struct Parallelogram: Shape {
    func path(in r: CGRect) -> Path {
        let s = r.height * 0.34
        var p = Path()
        p.move(to: CGPoint(x: r.minX + s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
