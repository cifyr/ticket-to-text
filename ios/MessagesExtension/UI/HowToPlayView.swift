import SwiftUI

// Rules sheet shown from the "?" button.
struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("playerName") private var playerName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PaperFill()
                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    nameField

                    rule(icon: "target", title: "Goal",
                         text: "Score the most points. You earn points by claiming routes, completing your secret destination tickets, and owning the longest continuous route.")

                    rule(icon: "rectangle.stack.badge.plus", title: "On your turn — do ONE",
                         text: "Either draw up to \(Game.maxDraw) train cards (from the face-up market or the face-down deck), claim a route you can afford, or draw new destination tickets.")

                    rule(icon: "paintpalette.fill", title: "Claiming a route",
                         text: "A route shows a color and a length. Spend that many cards of the matching color to claim it. Gray routes accept any single color. Locomotives are wild and substitute for any color. Tap a route on the map to claim it.")

                    mapLegend

                    rule(icon: "ticket.fill", title: "Destination tickets",
                         text: "Secret goals connecting two cities. Complete the connection with your routes to score the points — but unfinished tickets count AGAINST you at the end.")

                    rule(icon: "tram.fill", title: "Trains run out",
                         text: "You start with \(Game.startingTrains) train cars; each route costs its length. When a player drops to \(Game.finalTrainThreshold) or fewer, everyone gets one last turn.")

                    rule(icon: "flag.checkered", title: "Winning",
                         text: "At the end, scores add route points, ticket points (minus unfinished ones), and a +\(Scoring.longestRouteBonus) bonus for the longest route. Highest total wins.")

                    legend
                }
                .padding(20)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Palette.brass) } }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Your name", systemImage: "person.fill").font(.slab(15, .bold)).foregroundStyle(Palette.ink)
            TextField("Enter your name", text: $playerName)
                .font(.sans(15)).foregroundStyle(Palette.ink)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 9).fill(Palette.parchment)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.hairline, lineWidth: 1)))
            Text("Shown to your opponent on your turns. Applied to your next move.")
                .font(.sans(11)).foregroundStyle(Palette.sepiaLight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stub(Palette.parchmentDeep, corner: 14, padding: 14)
    }

    private var header: some View {
        HStack(spacing: 12) {
            TrainBadge(color: Palette.carRed, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ticket to Text").font(.slab(22, .bold)).foregroundStyle(Palette.ink)
                Text("A quick route-claiming game.").font(.sans(13)).foregroundStyle(Palette.sepia)
            }
        }
    }

    private func rule(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.brass).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.slab(16, .bold)).foregroundStyle(Palette.ink)
                Text(text).font(.sans(13)).foregroundStyle(Palette.sepia)
            }
        }
    }

    private var mapLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading the map").font(.slab(15, .bold)).foregroundStyle(Palette.ink)
            legendRow(.owned, "Owned", "Filled in a player's color — already claimed.")
            legendRow(.buyable, "You can buy it", "Solid outline — you have the cards and trains. Tap to claim.")
            legendRow(.open, "Can't buy yet", "Dashed — you can't afford it right now.")
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 12)).foregroundStyle(Palette.brass)
                Text("Zoom in for the train cars; zoom out for the whole map. Tap a player's disc to spotlight only their routes.")
                    .font(.sans(11.5)).foregroundStyle(Palette.sepia)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stub(Palette.parchmentDeep, corner: 14, padding: 14)
    }

    private func legendRow(_ kind: RouteSwatch.Kind, _ title: String, _ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RouteSwatch(kind: kind).frame(width: 60, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.sans(13, .bold)).foregroundStyle(Palette.ink)
                Text(text).font(.sans(11)).foregroundStyle(Palette.sepia)
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Card colors").font(.slab(15, .bold)).foregroundStyle(Palette.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 10) {
                ForEach(Card.allCases, id: \.self) { c in
                    HStack(spacing: 7) {
                        EnamelCard(card: c, height: 22).frame(width: 32)
                        Text(c == .locomotive ? "Wild" : c.rawValue.capitalized).font(.sans(12)).foregroundStyle(Palette.ink)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stub(Palette.parchmentDeep, corner: 14, padding: 14)
    }
}

// A small box-car sample for the map legend, matching the live board styles.
struct RouteSwatch: View {
    enum Kind { case owned, buyable, open }
    let kind: Kind
    var color: Color = Palette.carBlue

    var body: some View {
        Canvas { ctx, size in
            let cars = 3
            let h: CGFloat = min(13, size.height)
            let y = size.height / 2
            let carLen = (size.width / CGFloat(cars)) * 0.74
            for k in 0..<cars {
                let cx = size.width * (CGFloat(k) + 0.5) / CGFloat(cars)
                let car = Self.carPath(center: CGPoint(x: cx, y: y), len: carLen, height: h)
                switch kind {
                case .open:
                    ctx.stroke(car, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 1.7, dash: [3, 2]))
                case .buyable:
                    ctx.stroke(car, with: .color(Palette.brassLight.opacity(0.85)), lineWidth: 4.5)
                    ctx.stroke(car, with: .color(color), lineWidth: 2.4)
                case .owned:
                    ctx.fill(car, with: .color(color))
                    ctx.stroke(car, with: .color(.black.opacity(0.5)), lineWidth: 1)
                }
            }
        }
    }

    private static func carPath(center: CGPoint, len: CGFloat, height: CGFloat) -> Path {
        let s = height * 0.34
        var p = Path()
        p.move(to: CGPoint(x: center.x - len / 2 + s, y: center.y - height / 2))
        p.addLine(to: CGPoint(x: center.x + len / 2 + s, y: center.y - height / 2))
        p.addLine(to: CGPoint(x: center.x + len / 2 - s, y: center.y + height / 2))
        p.addLine(to: CGPoint(x: center.x - len / 2 - s, y: center.y + height / 2))
        p.closeSubpath()
        return p
    }
}
