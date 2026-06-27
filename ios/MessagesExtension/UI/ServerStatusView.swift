import SwiftUI

// Shown in server mode while there is no game loaded yet (or on a server error).
// Compact = a short tappable row (fits the Messages strip); expanded = full start.
struct ServerStatusView: View {
    let error: String?
    let loading: Bool
    let isExpanded: Bool
    let onNewGame: (String) -> Void   // chosen map id
    let onExpand: () -> Void

    @State private var showHelp = false
    @AppStorage("preferredMapId") private var selectedMapId = GameMap.defaultMapId
    private var maps: [GameMapDef] { GameMap.all }

    var body: some View {
        Group { if isExpanded { expanded } else { compact } }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paper()
            .sheet(isPresented: $showHelp) { HowToPlayView() }
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
            if maps.count > 1 {
                VStack(spacing: 6) {
                    Text("Map").font(.sans(11, .bold)).tracking(1).textCase(.uppercase).foregroundStyle(Palette.sepiaLight)
                    Menu {
                        ForEach(maps, id: \.id) { m in
                            Button(m.name) { selectedMapId = m.id }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map.fill").foregroundStyle(Palette.brass)
                            Text(GameMap.name(selectedMapId)).font(.slab(16, .bold)).foregroundStyle(Palette.ink)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.sepia)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.parchment)
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.hairline, lineWidth: 1)))
                    }
                }
            }
            Button { onNewGame(selectedMapId) } label: { Label("Start a New Game", systemImage: "play.fill") }
                .buttonStyle(BrassButtonStyle())
                .padding(.horizontal, 30)
            Button { showHelp = true } label: {
                Label("How to Play", systemImage: "questionmark.circle.fill")
                    .font(.slab(16, .bold))
            }
            .buttonStyle(QuietButtonStyle())
            .padding(.horizontal, 30)
        }
        .padding(24)
    }
}
