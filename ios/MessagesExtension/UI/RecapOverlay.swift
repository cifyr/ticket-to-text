import SwiftUI

// Shown to the receiving player first: what the last player did. For a claimed
// route it shows the full board with the conquered route highlighted in context.
struct RecapOverlay: View {
    let state: GameState
    let actorName: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            PaperFill().opacity(0.98)
            VStack(spacing: 14) {
                Text("Conductor's Report").font(.slab(11, .bold)).tracking(3).textCase(.uppercase)
                    .foregroundStyle(Palette.sepiaLight)
                Text("\(actorName) \(state.lastSummary ?? "moved")")
                    .font(.slab(20, .bold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)

                if state.lastClaimedRouteId != nil {
                    BoardView(state: state, selectedRouteId: nil,
                              canAct: false, claimable: { _ in false }, onSelect: { _ in },
                              showNames: false, reportMode: true)
                        .frame(height: 300)
                        .background(
                            ZStack {
                                RadialGradient(colors: [Color(hex: 0xEFE3CB), Color(hex: 0xE2D0AE)],
                                               center: .center, startRadius: 10, endRadius: 320)
                                Paper.grain.resizable(resizingMode: .tile).opacity(0.4).blendMode(.multiply)
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.brassHair, lineWidth: 1))
                } else if !state.lastPublicDraw.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(state.lastPublicDraw.enumerated()), id: \.offset) { _, card in
                            EnamelCard(card: card, height: 64).frame(width: 46)
                        }
                    }
                    .padding(.vertical, 16)
                } else {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 44)).foregroundStyle(Palette.brass)
                        .padding(.vertical, 20)
                }

                Button(action: onContinue) { Label("Your Turn — Continue", systemImage: "arrow.right.circle.fill") }
                    .buttonStyle(BrassButtonStyle())
            }
            .padding(20)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onContinue)
        .transition(.opacity)
    }
}
