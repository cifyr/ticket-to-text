import SwiftUI
import UIKit

// Renders the message-bubble image: a recap of what the last player just did —
// the conquered route marked with dots on the board (no point clutter), or the
// cards they drew shown along the bottom.
enum BoardSnapshot {
    @MainActor
    static func render(_ state: GameState, caption: String,
                       size: CGSize = CGSize(width: 360, height: 320)) -> UIImage {
        let renderer = ImageRenderer(content:
            MoveRecapImage(state: state, caption: caption).frame(width: size.width, height: size.height))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}

// Image for the lobby invite bubble. Image-less MSMessages render inconsistently,
// so the invite carries a simple branded card like the game bubble does.
enum LobbySnapshot {
    @MainActor
    static func render(joined: Int, max: Int, ready: Int,
                       size: CGSize = CGSize(width: 360, height: 200)) -> UIImage {
        let renderer = ImageRenderer(content:
            LobbyInviteImage(joined: joined, max: max, ready: ready)
                .frame(width: size.width, height: size.height))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}

private struct LobbyInviteImage: View {
    let joined: Int, max: Int, ready: Int
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "train.side.front.car")
                .font(.system(size: 44)).foregroundStyle(Palette.brass)
            Text("ALL ABOARD").font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink).tracking(1)
            Text("\(joined)/\(max) joined · \(ready) ready")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.sepia)
            Text("Tap to join the game").font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(Capsule().fill(Palette.brass))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.parchment)
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
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 6).padding(.horizontal, 10)

            BoardView(state: state, selectedRouteId: nil,
                      canAct: false, claimable: { _ in false }, onSelect: { _ in },
                      showNames: false, style: .thin)

            if state.lastClaimedRouteId == nil { bottomStrip }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                RadialGradient(colors: [Color(hex: 0xEFE3CB), Color(hex: 0xE2D0AE)],
                               center: .center, startRadius: 10, endRadius: 320)
                Paper.grain.resizable(resizingMode: .tile).opacity(0.4).blendMode(.multiply)
            }
        )
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
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(colors: [Color(hex: 0x3A322A), Color(hex: 0x231D17)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 40)
            .overlay(Image(systemName: "train.side.front.car").font(.caption2).foregroundStyle(Palette.brass))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.35), lineWidth: 1))
    }
}
