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
        Group {
            if isExpanded { expanded } else { compact }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private var compact: some View {
        Button(action: onExpand) {
            HStack(spacing: 12) {
                ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.brand); Image(systemName: "tram.fill").foregroundStyle(.white) }
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ticket to Text").font(.headline)
                    Text("Tap to start a game").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.footnote)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }

    private var expanded: some View {
        VStack(spacing: 14) {
            Image(systemName: "tram.fill").font(.largeTitle).foregroundStyle(Color.brand)
            Text("Ticket to Text").font(.title2.bold())
            if loading {
                ProgressView()
            } else if let error {
                Text("Couldn't reach the game server").font(.subheadline.weight(.medium))
                Text(error).font(.caption2).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal)
            } else {
                Text("Happy Birthday Dad!").font(.title3.weight(.bold)).foregroundStyle(Color.brand)
            }
            Button(action: onNewGame) {
                Label("Start a new game", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent).tint(Color.brand)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
