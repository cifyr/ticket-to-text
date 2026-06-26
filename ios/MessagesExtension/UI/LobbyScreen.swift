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
        Group { if isExpanded { full } else { compact } }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paper()
    }

    private var compact: some View {
        Button(action: onExpand) {
            HStack(spacing: 13) {
                TrainBadge(color: Palette.carBlue, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Game Lobby").font(.slab(19, .bold)).foregroundStyle(Palette.ink)
                    Text("\(lobby.members.count)/\(lobby.maxPlayers) joined · \(readyCount) ready")
                        .font(.sans(12.5, .semibold)).foregroundStyle(Palette.sepia)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.brass)
            }
            .stub(Palette.parchment, corner: 18, padding: 16)
        }
        .buttonStyle(.plain)
        .padding(10)
    }

    private var full: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                nameField

                VStack(spacing: 12) {
                    ForEach(Array(lobby.members.enumerated()), id: \.offset) { i, m in
                        luggageTag(i, m)
                    }
                }

                if lobby.you != nil {
                    Button { onReady(!meReady) } label: {
                        Label(meReady ? "Ready ✓" : "I'm Ready", systemImage: meReady ? "checkmark.seal.fill" : "hand.thumbsup")
                    }
                    .buttonStyle(meReady ? AnyButtonStyle(QuietButtonStyle(tint: Palette.success)) : AnyButtonStyle(BrassButtonStyle()))
                }

                if amHost {
                    Button(action: onInvite) { Label("Send Invite", systemImage: "paperplane.fill") }
                        .buttonStyle(QuietButtonStyle())
                    Button(action: onStart) { Label("Depart the Station", systemImage: "play.fill") }
                        .buttonStyle(BrassButtonStyle()).disabled(!lobby.canStart).opacity(lobby.canStart ? 1 : 0.55)
                    Text(lobby.canStart
                         ? "Start whenever you're ready — the game sizes to whoever's aboard (2-4)."
                         : "Send the invite and wait for at least one more player to join.")
                        .font(.sans(11)).foregroundStyle(Palette.sepiaLight).multilineTextAlignment(.center)
                } else {
                    Text("Waiting for the host to start… (tap refresh to update)")
                        .font(.sans(12)).foregroundStyle(Palette.sepia).multilineTextAlignment(.center)
                }
            }
            .padding(18)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                RailIconButton(system: "arrow.clockwise", action: onRefresh)
            }
            Text("ALL ABOARD").font(.slab(32, .bold)).tracking(1)
                .foregroundStyle(Palette.ink)
                .shadow(color: Palette.brass.opacity(0.2), radius: 0, x: 2, y: 2)
            HStack(spacing: 8) {
                line
                Text("\(lobby.members.count)/\(lobby.maxPlayers) aboard · \(readyCount) ready")
                    .font(.sans(11, .bold)).tracking(1).textCase(.uppercase).foregroundStyle(Palette.sepia)
                line
            }
            departureStrip
        }
    }

    private var line: some View { Rectangle().fill(Palette.brassHair).frame(width: 30, height: 1) }

    // Split-flap style title strip.
    private var departureStrip: some View {
        let chars = Array("TICKET TO TEXT")
        return HStack(spacing: 4) {
            ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                Text(ch == " " ? " " : String(ch))
                    .font(.slab(15, .bold)).foregroundStyle(Color(hex: 0xE7C76B))
                    .frame(width: 20, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color(hex: 0x3A322A), Color(hex: 0x272019)],
                                                 startPoint: .top, endPoint: .bottom))
                    )
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.dark))
    }

    private var nameField: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill").foregroundStyle(Palette.sepia)
            TextField("Your name", text: $playerName)
                .font(.sans(15)).foregroundStyle(Palette.ink)
                .onSubmit { onSetName(playerName) }
            Button("Set") { onSetName(playerName) }
                .font(.slab(13, .bold)).foregroundStyle(Color(hex: 0x3A2A0C))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xD9A23B), Color(hex: 0xB97E1C)],
                                                          startPoint: .top, endPoint: .bottom)))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.hairline, lineWidth: 1)))
    }

    private func luggageTag(_ i: Int, _ m: LobbyMemberView) -> some View {
        HStack(spacing: 14) {
            EnamelToken(color: ownerColor(i), label: String((m.name ?? "P").prefix(1)).uppercased(), size: 26)
            Text(m.name ?? "Player \(i + 1)").font(.slab(17, .bold)).foregroundStyle(Palette.ink)
            if m.isHost { Text("HOST").font(.sans(9, .heavy)).tracking(1).foregroundStyle(Palette.sepiaLight) }
            if lobby.you == i { Text("(you)").font(.sans(10)).foregroundStyle(Palette.sepiaLight) }
            Spacer()
            if m.ready {
                Text("READY").font(.slab(12, .bold)).tracking(1.5).foregroundStyle(Palette.success)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.success, lineWidth: 2))
                    .rotationEffect(.degrees(-5)).opacity(0.9)
            } else {
                Text("waiting…").font(.sans(11, .bold)).tracking(0.5).textCase(.uppercase).foregroundStyle(Palette.sepiaLight)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(
            LuggageTagShape()
                .fill(Palette.parchmentDeep)
                .overlay(LuggageTagShape().stroke(Palette.hairline, lineWidth: 1))
                .shadow(color: Palette.ink.opacity(0.14), radius: 4, y: 2)
        )
        .overlay(alignment: .topLeading) {
            Circle().fill(Palette.parchment).overlay(Circle().stroke(Palette.hairline, lineWidth: 1))
                .frame(width: 8, height: 8).offset(x: 9, y: 9)
        }
    }
}

// Luggage tag: a card with a clipped top-left corner.
struct LuggageTagShape: Shape {
    func path(in r: CGRect) -> Path {
        let c: CGFloat = 16
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 6, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 6), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 6))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 6, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 6, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 6), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.closeSubpath()
        return p
    }
}

// Type-erased button style so the ready button can swap styles.
struct AnyButtonStyle: ButtonStyle {
    private let _make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { _make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { _make(configuration) }
}
