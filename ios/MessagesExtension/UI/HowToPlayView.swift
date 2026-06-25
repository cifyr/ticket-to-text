import SwiftUI

// Rules sheet shown from the "?" button.
struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("playerName") private var playerName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    nameField

                    rule(icon: "target", title: "Goal",
                         text: "Score the most points. You earn points by claiming routes, completing your secret destination tickets, and owning the longest continuous route.")

                    rule(icon: "rectangle.stack.badge.plus", title: "On your turn — do ONE",
                         text: "Either draw up to \(Game.maxDraw) train cards (from the face-up market or the face-down deck), claim a route you can afford, or draw new destination tickets.")

                    rule(icon: "paintpalette.fill", title: "Claiming a route",
                         text: "A route shows a color and a length. Spend that many cards of the matching color to claim it. Gray routes accept any single color. Locomotives are wild and substitute for any color. Highlighted routes are ones you can afford — tap one to claim.")

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
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Your name", systemImage: "person.fill").font(.headline)
            TextField("Enter your name", text: $playerName)
                .textFieldStyle(.roundedBorder)
            Text("Shown to your opponent on your turns. Applied to your next move.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.brand)
                Image(systemName: "tram.fill").foregroundStyle(.white).font(.title2)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading) {
                Text("Ticket to Text").font(.title2.bold())
                Text("A quick route-claiming game for two.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func rule(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.brand)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card colors").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 8) {
                ForEach(Card.allCases, id: \.self) { c in
                    HStack(spacing: 6) {
                        Circle().fill(cardColor(c)).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.secondary.opacity(0.4), lineWidth: 0.5))
                        Text(c == .locomotive ? "Wild" : c.rawValue.capitalized).font(.caption)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemBackground)))
    }
}
