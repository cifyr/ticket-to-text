import SwiftUI

// Shown in server mode while there is no game loaded yet (or on a server error).
struct ServerStatusView: View {
    let error: String?
    let loading: Bool
    let isExpanded: Bool
    let onNewGame: () -> Void
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tram.fill").font(.largeTitle).foregroundStyle(Color.brand)
            Text("Ticket to Text").font(.headline)
            if loading {
                ProgressView()
            } else if let error {
                Text("Couldn't reach the game server").font(.subheadline.weight(.medium))
                Text(error).font(.caption2).foregroundStyle(.red).multilineTextAlignment(.center)
                Text("Turn off Deployment Protection (or set a bypass token). See server/README.md.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                Text("Online mode — cheat-proof").font(.caption).foregroundStyle(.secondary)
            }
            if isExpanded {
                Button("Start a new game", action: onNewGame).buttonStyle(.borderedProminent).tint(Color.brand)
            } else {
                Button("Open", action: onExpand).buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
