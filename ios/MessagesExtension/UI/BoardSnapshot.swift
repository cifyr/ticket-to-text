import SwiftUI
import UIKit

// Renders the message-bubble image: a recap of what the last player just did —
// the conquered route highlighted on the board, or the cards they drew.
enum BoardSnapshot {
    @MainActor
    static func render(_ state: GameState, caption: String,
                       size: CGSize = CGSize(width: 360, height: 300)) -> UIImage {
        let renderer = ImageRenderer(content:
            MoveRecapImage(state: state, caption: caption).frame(width: size.width, height: size.height))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}

private struct MoveRecapImage: View {
    let state: GameState
    let caption: String

    var body: some View {
        VStack(spacing: 8) {
            Text(caption)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.brand)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 6).padding(.horizontal, 10)

            if !state.lastPublicDraw.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(state.lastPublicDraw.enumerated()), id: \.offset) { _, card in
                        CardTile(card: card, selected: false).frame(width: 40)
                    }
                }
            }

            BoardView(state: state, selectedRouteId: state.lastClaimedRouteId, highlightTicket: nil,
                      canAct: false, claimable: { _ in false }, onSelect: { _ in }, showNames: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
    }
}
