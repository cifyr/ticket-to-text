import SwiftUI

// End-of-game scoring for 2-4 players. Two pages: the standings (tap a player
// to expand their breakdown) and a swipe-over view of the final board.
struct FinalScoreView: View {
    let state: GameState

    @State private var page = 0
    @State private var expanded: Int?

    private func name(_ seat: Int) -> String {
        (state.playerNames[safe: seat] ?? nil) ?? "Player \(seat + 1)"
    }

    var body: some View {
        TabView(selection: $page) {
            scoresPage.tag(0)
            mapPage.tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(PaperFill())
        .onAppear { Feedback.win() }
    }

    private var scoresPage: some View {
        let scores = Scoring.finalScores(state)
        let winner = Scoring.finalWinner(state)
        let order = (0..<scores.count).sorted { scores[$0].total > scores[$1].total }
        return ScrollView {
            VStack(spacing: 16) {
                Text("End of the Line").font(.slab(12, .bold)).tracking(4).textCase(.uppercase)
                    .foregroundStyle(Palette.sepiaLight)

                if let w = winner { certificate(player: w, score: scores[w]) }

                VStack(spacing: 10) {
                    ForEach(Array(order.enumerated()), id: \.offset) { rank, p in
                        Button { withAnimation(.snappy) { expanded = (expanded == p) ? nil : p } } label: {
                            standingRow(rank: rank + 1, player: p, score: scores[p])
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Tap a player for their breakdown · swipe for the final map")
                    .font(.sans(11)).foregroundStyle(Palette.sepiaLight)
                    .multilineTextAlignment(.center).padding(.top, 4)
            }
            .padding(20).padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
    }

    private var mapPage: some View {
        VStack(spacing: 10) {
            Text("Final Board").font(.slab(12, .bold)).tracking(3).textCase(.uppercase)
                .foregroundStyle(Palette.sepiaLight)
            BoardArea(state: state, selectedRouteId: nil, highlightTicket: nil,
                      canAct: false, claimable: { _ in false }, onSelect: { _ in })
            Text("Zoom in for detail.").font(.sans(11)).foregroundStyle(Palette.sepiaLight)
        }
        .padding(16).padding(.bottom, 28)
    }

    private func certificate(player: Int, score: FinalScore) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(hex: 0xF2D277), Palette.brass, Palette.brassDark],
                                             center: UnitPoint(x: 0.35, y: 0.28), startRadius: 1, endRadius: 34))
                    .frame(width: 62, height: 62)
                    .overlay(Circle().stroke(Color(hex: 0x7A5710), lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                Image(systemName: "rosette").font(.system(size: 26, weight: .bold)).foregroundStyle(Color(hex: 0x3A2A0C))
            }
            Text("Winner").font(.slab(13, .bold)).tracking(4).textCase(.uppercase).foregroundStyle(Color(hex: 0xB97E1C))
            Text(name(player).uppercased()).font(.slab(28, .bold)).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score.total)").font(.sans(24, .heavy)).foregroundStyle(Color(hex: 0xF2D277))
                Text("POINTS").font(.slab(11, .semibold)).tracking(2).foregroundStyle(Palette.brass)
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9).fill(Palette.ink))
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(hex: 0xF3E9D4), Palette.parchmentDeep], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.brass, lineWidth: 2))
                .overlay(RoundedRectangle(cornerRadius: 9).inset(by: 6).stroke(Palette.brassHair, lineWidth: 1))
                .shadow(color: Palette.ink.opacity(0.22), radius: 8, y: 4)
        )
    }

    private func standingRow(rank: Int, player: Int, score: FinalScore) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 12) {
                Text("\(rank)").font(.slab(15, .bold)).foregroundStyle(Palette.sepiaLight).frame(width: 18)
                EnamelToken(color: ownerColor(player), label: String(name(player).prefix(1)).uppercased(), size: 24)
                Text(name(player)).font(.slab(16, .bold)).foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: expanded == player ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.sepiaLight)
                Text("\(score.total)").font(.sans(17, .heavy)).foregroundStyle(Palette.sepia)
            }
            HStack(spacing: 12) {
                tag("Routes", score.routeScore)
                tag("Tickets", score.ticketScore)
                tag("Longest \(score.longestRoute)", score.longestBonus)
                Spacer()
            }
            if expanded == player { breakdown(player: player, score: score) }
        }
        .stub(Palette.parchmentDeep, corner: 10, padding: 12)
    }

    // Expanded detail. Tickets are only known for the local player (others'
    // stay secret), so we always show the point components and add per-ticket
    // detail when it's you.
    @ViewBuilder private func breakdown(player: Int, score: FinalScore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DashedRule()
            line("Route cards", score.routeScore)
            line("Destination tickets", score.ticketScore)
            line("Longest path (\(score.longestRoute))", score.longestBonus)
            Divider().background(Palette.hairline)
            line("Total", score.total, bold: true)

            let tickets = state.players[safe: player]?.tickets ?? []
            if !tickets.isEmpty {
                Text("Your tickets").font(.sans(10, .bold)).tracking(1).textCase(.uppercase)
                    .foregroundStyle(Palette.sepiaLight).padding(.top, 4)
                ForEach(tickets) { t in
                    let done = Scoring.connected(state.routes.filter { $0.claimedBy == player }, from: t.cityA, to: t.cityB)
                    HStack(spacing: 6) {
                        Image(systemName: done ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12)).foregroundStyle(done ? Palette.success : Palette.danger)
                        Text("\(GameMap.cities[t.cityA].name) → \(GameMap.cities[t.cityB].name)")
                            .font(.sans(11)).foregroundStyle(Palette.ink)
                        Spacer(minLength: 4)
                        Text(done ? "+\(t.points)" : "-\(t.points)").font(.sans(11, .bold))
                            .foregroundStyle(done ? Palette.ink : Palette.danger)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private func line(_ label: String, _ value: Int, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.sans(12, bold ? .heavy : .semibold)).foregroundStyle(Palette.sepia)
            Spacer()
            Text(value >= 0 ? "+\(value)" : "\(value)").font(.sans(12, bold ? .heavy : .bold))
                .foregroundStyle(value < 0 ? Palette.danger : Palette.ink)
        }
    }

    private func tag(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.sans(10)).foregroundStyle(Palette.sepiaLight)
            Text(value >= 0 ? "+\(value)" : "\(value)").font(.sans(10, .bold))
                .foregroundStyle(value < 0 ? Palette.danger : Palette.ink)
        }
    }
}
