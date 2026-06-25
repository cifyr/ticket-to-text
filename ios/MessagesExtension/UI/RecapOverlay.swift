import SwiftUI

// Shown to the receiving player first: what the last player did. For a claimed
// route it shows the full board with the conquered route highlighted in context.
struct RecapOverlay: View {
    let state: GameState
    let actorName: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).opacity(0.97).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Last move").font(.caption).foregroundStyle(.secondary)
                Text("\(actorName) \(state.lastSummary ?? "moved")")
                    .font(.title3.bold()).multilineTextAlignment(.center)

                if let rid = state.lastClaimedRouteId {
                    BoardView(state: state, selectedRouteId: rid, highlightTicket: nil,
                              canAct: false, claimable: { _ in false }, onSelect: { _ in })
                        .frame(height: 300)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.tertiarySystemBackground)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.07)))
                } else if !state.lastPublicDraw.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(state.lastPublicDraw.enumerated()), id: \.offset) { _, card in
                            CardTile(card: card, selected: false).frame(width: 46)
                        }
                    }
                    .padding(.vertical, 16)
                } else {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 44)).foregroundStyle(Color.brand)
                        .padding(.vertical, 20)
                }

                Button(action: onContinue) {
                    Label("Your turn — continue", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).tint(Color.brand)
            }
            .padding(20)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onContinue)
        .transition(.opacity)
    }
}
