import SwiftUI

// Pre-game lobby (online mode): players join, mark ready, host starts.
struct LobbyScreen: View {
    let lobby: LobbyView
    let isExpanded: Bool
    let onReady: (Bool) -> Void
    let onStart: () -> Void
    let onRefresh: () -> Void
    let onInvite: () -> Void
    let onSetName: (String) -> Void
    let onExpand: () -> Void

    @AppStorage("playerName") private var playerName = ""

    private var amHost: Bool { lobby.you == 0 }
    private var meReady: Bool { if let y = lobby.you { return lobby.members[y].ready } else { return false } }
    private var readyCount: Int { lobby.members.filter { $0.ready }.count }

    var body: some View {
        if isExpanded { full } else { compact }
    }

    private var compact: some View {
        Button(action: onExpand) {
            HStack(spacing: 12) {
                ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.brand); Image(systemName: "person.3.fill").foregroundStyle(.white) }
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Game lobby").font(.headline)
                    Text("\(lobby.members.count)/\(lobby.maxPlayers) joined · \(readyCount) ready").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.footnote)
            }.padding(12)
        }.buttonStyle(.plain)
    }

    private var full: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill").foregroundStyle(Color.brand)
                Text("Game Lobby").font(.title3.bold())
                Spacer()
                Text("\(lobby.members.count)/\(lobby.maxPlayers)").font(.subheadline).foregroundStyle(.secondary)
                Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }.buttonStyle(.bordered).clipShape(Circle())
            }

            HStack(spacing: 8) {
                Image(systemName: "person.fill").foregroundStyle(.secondary)
                TextField("Your name", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { onSetName(playerName) }
                Button("Set") { onSetName(playerName) }.buttonStyle(.bordered)
            }

            VStack(spacing: 8) {
                ForEach(Array(lobby.members.enumerated()), id: \.offset) { i, m in
                    HStack(spacing: 10) {
                        Circle().fill(ownerColor(i)).frame(width: 10, height: 10)
                        Text(m.name ?? "Player \(i + 1)").font(.subheadline.weight(.medium))
                        if m.isHost { Text("HOST").font(.caption2.bold()).foregroundStyle(.secondary) }
                        if lobby.you == i { Text("(you)").font(.caption2).foregroundStyle(.secondary) }
                        Spacer()
                        Image(systemName: m.ready ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(m.ready ? .green : .secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
                }
            }

            if lobby.you != nil {
                Button { onReady(!meReady) } label: {
                    Label(meReady ? "Ready ✓" : "I'm ready", systemImage: meReady ? "checkmark.seal.fill" : "hand.thumbsup")
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).tint(meReady ? .green : Color.brand)
            }

            if amHost {
                Button(action: onInvite) {
                    Label("Send invite", systemImage: "paperplane.fill").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                Button(action: onStart) {
                    Label("Start game", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).tint(Color.brand).disabled(!lobby.canStart)
                if !lobby.canStart {
                    Text("Send the invite, then start once everyone has joined and readied (tap refresh to update).")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            } else {
                Text("Waiting for the host to start… (tap refresh to update)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}
