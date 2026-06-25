import SwiftUI

// End-of-game scoring breakdown for 2-4 players.
struct FinalScoreView: View {
    let state: GameState
    let onNewGame: () -> Void

    private func name(_ seat: Int) -> String {
        (state.playerNames[safe: seat] ?? nil) ?? "Player \(seat + 1)"
    }

    var body: some View {
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
                        standingRow(rank: rank + 1, player: p, score: scores[p])
                    }
                }

                Button(action: onNewGame) { Label("Start a New Game", systemImage: "arrow.clockwise") }
                    .buttonStyle(BrassButtonStyle())
            }
            .padding(20)
        }
        .background(PaperFill())
        .onAppear { Feedback.win() }
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
                Text("\(score.total)").font(.sans(17, .heavy)).foregroundStyle(Palette.sepia)
            }
            HStack(spacing: 12) {
                tag("Routes", score.routeScore)
                tag("Tickets", score.ticketScore)
                tag("Longest \(score.longestRoute)", score.longestBonus)
                Spacer()
            }
        }
        .stub(Palette.parchmentDeep, corner: 10, padding: 12)
    }

    private func tag(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.sans(10)).foregroundStyle(Palette.sepiaLight)
            Text(value >= 0 ? "+\(value)" : "\(value)").font(.sans(10, .bold))
                .foregroundStyle(value < 0 ? Palette.danger : Palette.ink)
        }
    }
}
