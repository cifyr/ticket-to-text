import SwiftUI

// Shows exactly what a tapped route costs and whether the player can afford it.
// Close is always a clear, full-size button so it's obvious how to get back.
struct RouteDetailCard: View {
    let route: Route
    let hand: [Card]
    let trains: Int
    let affordable: Bool
    let onClaim: () -> Void
    let onClose: () -> Void

    private var wilds: Int { hand.filter { $0 == .locomotive }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(GameMap.label(route)).font(.subheadline.bold())

            HStack(spacing: 6) {
                ForEach(0..<route.length, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3).fill(paintColor(route.color)).frame(width: 18, height: 10)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.4), lineWidth: 0.5))
                }
                Text(costText).font(.caption).foregroundStyle(.secondary)
            }

            if let owner = route.claimedBy {
                Label("Claimed by Player \(owner + 1)", systemImage: "checkmark.seal.fill")
                    .font(.caption).foregroundStyle(ownerColor(owner))
                Button(action: onClose) { Label("Close", systemImage: "xmark").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
            } else {
                Text(affordText).font(.caption).foregroundStyle(affordable ? .primary : .secondary)
                HStack(spacing: 10) {
                    Button(action: onClose) {
                        Label("Close", systemImage: "xmark").frame(maxWidth: .infinity).padding(.vertical, 2)
                    }
                    .buttonStyle(.bordered)
                    Button(action: onClaim) {
                        Label(affordable ? "Claim" : "Can't claim yet", systemImage: "hand.tap.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 2)
                    }
                    .buttonStyle(.borderedProminent).tint(Color.brand).disabled(!affordable)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemBackground)))
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
