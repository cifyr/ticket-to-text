import SwiftUI
import UIKit

// Renders the message-bubble image: a recap of what the last player just did —
// the conquered route marked with dots on the board (no point clutter), or the
// cards they drew shown along the bottom.
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

    private var isTicketDraw: Bool { (state.lastSummary ?? "").contains("ticket") }
    // Blind cards drawn (count only; never the actual cards — stays leak-free).
    private var blindCount: Int {
        guard let s = state.lastSummary,
              let m = s.range(of: #"drew (\d+)"#, options: .regularExpression) else { return 0 }
        return Int(s[m].replacingOccurrences(of: "drew ", with: "")) ?? 0
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(caption)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.brand)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 6).padding(.horizontal, 10)

            BoardView(state: state, selectedRouteId: state.lastClaimedRouteId, highlightTicket: nil,
                      canAct: false, claimable: { _ in false }, onSelect: { _ in },
                      showNames: false, showLengthPips: false, dotsOnSelected: true)

            if state.lastClaimedRouteId == nil { bottomStrip }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
    }

    @ViewBuilder private var bottomStrip: some View {
        if isTicketDraw {
            Label("drew tickets", systemImage: "ticket.fill")
                .font(.caption.bold()).foregroundStyle(Color.brand).padding(.bottom, 8)
        } else {
            HStack(spacing: 8) {
                ForEach(Array(state.lastPublicDraw.enumerated()), id: \.offset) { _, card in
                    CardTile(card: card, selected: false).frame(width: 38)
                }
                ForEach(0..<blindCount, id: \.self) { _ in CardBackTile().frame(width: 38) }
            }
            .padding(.bottom, 8)
        }
    }
}

// Face-down card to show a blind draw without revealing the card.
private struct CardBackTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(LinearGradient(colors: [Color.gray, Color(white: 0.35)], startPoint: .top, endPoint: .bottom))
            .frame(height: 40)
            .overlay(Image(systemName: "tram.fill").font(.caption2).foregroundStyle(.white.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.primary.opacity(0.25), lineWidth: 0.5))
    }
}
