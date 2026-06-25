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
        return VStack(spacing: 12) {
            Image(systemName: "flag.checkered").font(.largeTitle).foregroundStyle(Color.brand)
            Text(winner == nil ? "Tie game" : "\(name(winner!)) wins!").font(.title3.bold())

            VStack(spacing: 8) {
                ForEach(0..<scores.count, id: \.self) { p in
                    column(player: p, score: scores[p], winner: winner)
                }
            }

            Button("Start a new game", action: onNewGame)
                .buttonStyle(.borderedProminent).tint(Color.brand)
        }
        .frame(maxWidth: .infinity).padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
        .onAppear { Feedback.win() }
    }

    private func column(player: Int, score: FinalScore, winner: Int?) -> some View {
        VStack(spacing: 6) {
            HStack {
                Circle().fill(ownerColor(player)).frame(width: 10, height: 10)
                Text(name(player)).font(.subheadline.bold()).foregroundStyle(ownerColor(player))
                Spacer()
                Text("\(score.total)").font(.title3.bold().monospacedDigit())
            }
            HStack(spacing: 12) {
                tag("Routes", score.routeScore)
                tag("Tickets", score.ticketScore)
                tag("Longest \(score.longestRoute)", score.longestBonus)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.tertiarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(winner == player ? ownerColor(player) : .clear, lineWidth: 2))
    }

    private func tag(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value >= 0 ? "+\(value)" : "\(value)").font(.caption2.monospacedDigit())
                .foregroundStyle(value < 0 ? .red : .primary)
        }
    }
}
