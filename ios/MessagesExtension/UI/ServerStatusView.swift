import SwiftUI

// Shown in server mode while there is no game loaded yet (or on a server error).
// Compact = a short tappable row (fits the Messages strip); expanded = full start.
struct ServerStatusView: View {
    let error: String?
    let loading: Bool
    let isExpanded: Bool
    let onNewGame: () -> Void
    let onExpand: () -> Void

    var body: some View {
        Group { if isExpanded { expanded } else { compact } }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paper()
    }

    private var compact: some View {
        Button(action: onExpand) {
            HStack(spacing: 13) {
                TrainBadge(color: Palette.carRed, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ticket to Text").font(.slab(19, .bold)).foregroundStyle(Palette.ink)
                    Text("Tap to start a game").font(.sans(12.5, .semibold)).foregroundStyle(Palette.sepia)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.brass)
            }
            .stub(Palette.parchment, corner: 18, padding: 16)
        }
        .buttonStyle(.plain)
        .padding(10)
    }

    private var expanded: some View {
        VStack(spacing: 16) {
            TrainBadge(color: Palette.carRed, size: 72)
            Text("Ticket to Text").font(.slab(26, .bold)).foregroundStyle(Palette.ink)
            if loading {
                ProgressView().tint(Palette.brass)
            } else if let error {
                Text("Couldn't reach the game server").font(.slab(15, .semibold)).foregroundStyle(Palette.ink)
                Text(error).font(.sans(11)).foregroundStyle(Palette.danger).multilineTextAlignment(.center).padding(.horizontal)
            } else {
                Text("Happy Birthday Dad!").font(.slab(19, .bold)).foregroundStyle(Palette.brass)
            }
            Button(action: onNewGame) { Label("Start a New Game", systemImage: "play.fill") }
                .buttonStyle(BrassButtonStyle())
                .padding(.horizontal, 30)
        }
        .padding(24)
    }
}
