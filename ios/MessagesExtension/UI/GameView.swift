import SwiftUI

// The playable surface. Reflects the passed-in `state` directly. Actions are
// gated by `canAct` (relaxed by the controller for solo testing).
struct GameView: View {
    let state: GameState
    let isExpanded: Bool
    let localParticipantID: String
    let canAct: Bool
    let enforceTurns: Bool
    let onMove: (Move, String) -> Void   // controller applies (local) or sends to server
    let onRequestExpand: () -> Void
    let onNewGame: () -> Void

    @State private var errorText: String?
    @State private var showHelp = false
    @State private var showTickets = false
    @State private var showResults = false
    @State private var showLog = false
    @State private var selectedRouteId: Int?
    @State private var highlightTicket: Ticket?
    @State private var draft: [DrawPick] = []
    @State private var recapDismissedFor = -1
    @State private var confirmedSeat: Int?

    private var mySeat: Int {
        Game.actingIndex(state, participantID: localParticipantID) ?? state.currentPlayer
    }

    private var amAssigned: Bool {
        Game.assignedIndex(state, participantID: localParticipantID) != nil
    }

    // An unassigned player must explicitly join the open seat before acting, so
    // seats aren't taken by accident in a group chat.
    private var needsJoin: Bool {
        enforceTurns && !Game.isGameOver(state) && !amAssigned
            && Game.actingIndex(state, participantID: localParticipantID) == state.currentPlayer
            && confirmedSeat != state.currentPlayer
    }

    private var effectiveCanAct: Bool {
        canAct && (!enforceTurns || amAssigned || confirmedSeat == state.currentPlayer)
    }

    private func name(_ seat: Int) -> String {
        (state.playerNames[safe: seat] ?? nil) ?? "Player \(seat + 1)"
    }

    // Show the last move to the receiver before they play.
    private var pendingRecap: Bool {
        isExpanded && !Game.isGameOver(state) && state.lastActor != nil
            && state.lastActor != mySeat && state.moveCount > 0
    }
    private var showRecap: Bool { pendingRecap && recapDismissedFor != state.moveCount }

    var body: some View {
        Group {
            if isExpanded { expanded } else { compact }
        }
        .overlay {
            if showRecap {
                RecapOverlay(state: state, actorName: name(state.lastActor ?? 0),
                             onContinue: { withAnimation { recapDismissedFor = state.moveCount } })
            }
        }
        .task(id: state.moveCount) {
            guard pendingRecap else { return }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation { recapDismissedFor = state.moveCount }
        }
        .sheet(isPresented: $showHelp) { HowToPlayView() }
        .sheet(isPresented: $showLog) { LogSheet(log: state.log, name: name) }
        .sheet(isPresented: $showResults) {
            FinalScoreView(state: state, onNewGame: { showResults = false; onNewGame() })
        }
        .sheet(isPresented: $showTickets) {
            TicketsSheet(tickets: state.players[mySeat].tickets,
                         myRoutes: state.routes.filter { $0.claimedBy == mySeat },
                         ticketsLeft: state.ticketDeck.count, canDraw: canAct,
                         onDraw: {
                             showTickets = false
                             apply(.drawTickets, caption: "drew \(min(Game.startingTickets, state.ticketDeck.count)) tickets")
                         },
                         onShow: { t in showTickets = false; flashTicket(t) })
        }
    }

    // MARK: Compact

    private var compact: some View {
        Button(action: onRequestExpand) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.brand)
                    Image(systemName: "tram.fill").foregroundStyle(.white)
                }.frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ticket to Text").font(.headline)
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.footnote)
            }.padding(12)
        }.buttonStyle(.plain)
    }

    // MARK: Expanded

    private var expanded: some View {
        VStack(spacing: 10) {
            topBar
            turnBoard
            bottom
            if let errorText { Text(errorText).font(.caption).foregroundStyle(.red) }
        }
        .padding(12)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "tram.fill").foregroundStyle(Color.brand)
            Text("Ticket to Text").font(.headline)
            Spacer()
            Button { showTickets = true } label: {
                Label("\(state.players[mySeat].tickets.count)", systemImage: "ticket.fill").font(.caption.weight(.semibold))
            }.buttonStyle(.bordered)
            Button { showLog = true } label: { Image(systemName: "clock.arrow.circlepath") }.buttonStyle(.bordered).clipShape(Circle())
            Button { showHelp = true } label: { Image(systemName: "questionmark") }.buttonStyle(.bordered).clipShape(Circle())
            Button { onNewGame() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.bordered).clipShape(Circle())
        }
    }

    private var turnBoard: some View {
        VStack(spacing: 8) {
            namePlates
            BoardArea(state: state, selectedRouteId: selectedRouteId, highlightTicket: highlightTicket,
                      canAct: effectiveCanAct, claimable: { Game.canClaim(state, $0, player: mySeat) },
                      onSelect: { selectedRouteId = $0 })
                .frame(maxHeight: .infinity)
        }
    }

    // Whose turn it is shown purely by highlighting their name. Wraps to a grid
    // for 3-4 players.
    private var namePlates: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(state.players.count, 2)), spacing: 8) {
            ForEach(0..<state.players.count, id: \.self) { p in
                let active = !Game.isGameOver(state) && state.currentPlayer == p
                let mine = Game.assignedIndex(state, participantID: localParticipantID) == p
                VStack(spacing: 1) {
                    HStack(spacing: 6) {
                        Circle().fill(ownerColor(p)).frame(width: 9, height: 9)
                        Text(name(p) + (mine ? " (you)" : "")).font(.caption.weight(active ? .bold : .regular))
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        Text("\(state.players[p].score)").font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(ownerColor(p)).contentTransition(.numericText())
                        Label("\(state.players[p].trains)", systemImage: "tram.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                        if active { Text("● to move").font(.caption2.bold()).foregroundStyle(ownerColor(p)) }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(active ? ownerColor(p).opacity(0.18) : Color(UIColor.secondarySystemBackground)))
                .overlay(Capsule().stroke(active ? ownerColor(p) : .clear, lineWidth: 1.5))
            }
        }
    }

    // MARK: Bottom panel

    @ViewBuilder private var bottom: some View {
        if Game.isGameOver(state) {
            gameOverBar
        } else if needsJoin {
            joinCard
        } else if effectiveCanAct {
            VStack(spacing: 8) {
                if let id = selectedRouteId, let route = state.routes.first(where: { $0.id == id }) {
                    RouteDetailCard(
                        route: route, hand: state.players[mySeat].hand, trains: state.players[mySeat].trains,
                        affordable: Game.canClaim(state, route, player: mySeat),
                        onClaim: {
                            apply(.claim(routeId: route.id, color: nil), caption: "claimed \(GameMap.label(route))")
                            selectedRouteId = nil
                        },
                        onClose: { selectedRouteId = nil })
                } else {
                    hintLine
                    drawRow
                }
                handStrip
            }
        } else {
            waiting
        }
    }

    private var joinCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.badge.plus").font(.title2).foregroundStyle(Color.brand)
            Text("Open seat: \(name(state.currentPlayer))").font(.subheadline.weight(.semibold))
            Text("Join to take this turn. Set your name in the ? menu.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { withAnimation { confirmedSeat = state.currentPlayer } } label: {
                Label("Join as \(name(state.currentPlayer))", systemImage: "checkmark")
                    .frame(maxWidth: .infinity).padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent).tint(Color.brand)
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var gameOverBar: some View {
        HStack {
            Image(systemName: "flag.checkered").foregroundStyle(Color.brand)
            Text(statusText).font(.subheadline.bold())
            Spacer()
            Button("Results") { showResults = true }.buttonStyle(.bordered)
            Button("New") { onNewGame() }.buttonStyle(.borderedProminent).tint(Color.brand)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemBackground)))
        .onAppear { showResults = true }
    }

    private var hintLine: some View {
        Text(draft.isEmpty ? "Tap a route to see its cost, or pick cards to draw."
                           : "Tap Draw to take \(draft.count), or pick more.")
            .font(.caption).foregroundStyle(.secondary)
    }

    private var drawRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(state.market.enumerated()), id: \.offset) { i, card in
                    CardTile(card: card, selected: draft.contains(.market(slot: i)))
                        .onTapGesture { selectMarket(i, card: card) }
                }
                DeckTile(count: state.deck.count).onTapGesture { selectBlind() }
            }
            HStack {
                Button { commitDraw() } label: { Text("Draw \(draft.count)").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(Color.brand).disabled(draft.isEmpty)
                if !draft.isEmpty { Button("Clear") { draft = [] }.buttonStyle(.bordered) }
            }
        }
    }

    private var handStrip: some View {
        let hand = state.players[mySeat].hand
        return HStack(spacing: 5) {
            ForEach(Card.allCases, id: \.self) { card in
                let count = hand.filter { $0 == card }.count
                HStack(spacing: 3) {
                    Circle().fill(cardColor(card)).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.secondary.opacity(0.4), lineWidth: 0.5))
                    Text("\(count)").font(.caption2.weight(.semibold).monospacedDigit())
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(Capsule().fill(cardColor(card).opacity(0.14)))
                .opacity(count == 0 ? 0.35 : 1)
            }
        }
    }

    private var waiting: some View {
        VStack(spacing: 6) {
            ProgressView()
            Text("Waiting for \(name(state.currentPlayer))").font(.subheadline.weight(.medium))
            Text("Tap routes to inspect the board. Reopen after they send their turn.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemBackground)))
    }

    // MARK: Actions

    private func flashTicket(_ t: Ticket) {
        withAnimation { highlightTicket = t }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation { if highlightTicket?.id == t.id { highlightTicket = nil } }
        }
    }

    private func selectMarket(_ i: Int, card: Card) {
        guard effectiveCanAct else { return }
        if let idx = draft.firstIndex(of: .market(slot: i)) { draft.remove(at: idx); return }
        if card == .locomotive { draft = [.market(slot: i)]; commitDraw(); return }
        guard !draftHasLocomotive, draft.count < Game.maxDraw else { return }
        draft.append(.market(slot: i))
    }

    private func selectBlind() {
        guard effectiveCanAct, !draftHasLocomotive, draft.count < Game.maxDraw else { return }
        draft.append(.blind)
    }

    private var draftHasLocomotive: Bool {
        draft.contains { if case .market(let s) = $0 { return state.market[safe: s] == .locomotive } else { return false } }
    }

    private func commitDraw() {
        guard !draft.isEmpty else { return }
        let picks = draft; draft = []
        apply(.drawCards(picks), caption: "drew \(picks.count) card\(picks.count == 1 ? "" : "s")")
    }

    private func apply(_ move: Move, caption: String) {
        if case .claim = move { Feedback.claim() } else { Feedback.draw() }
        onMove(move, caption)
    }

    private var statusText: String {
        if Game.isGameOver(state) {
            switch Scoring.finalWinner(state) {
            case nil: return "Tie game"
            case let w?: return "\(name(w)) wins!"
            }
        }
        return "\(name(state.currentPlayer)) to move"
    }
}

// MARK: - Card tiles

struct CardTile: View {
    let card: Card
    let selected: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(cardColor(card))
            .frame(height: 42)
            .overlay { if card == .locomotive { Image(systemName: "sparkles").font(.caption).foregroundStyle(.white) } }
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.primary.opacity(0.25), lineWidth: 0.5))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? Color.brand : .clear, lineWidth: 3))
            .frame(maxWidth: .infinity)
    }
}

struct DeckTile: View {
    let count: Int
    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(LinearGradient(colors: [Color.gray, Color(white: 0.35)], startPoint: .top, endPoint: .bottom))
            .frame(height: 42)
            .overlay {
                VStack(spacing: 0) {
                    Image(systemName: "square.stack.fill").font(.caption2).foregroundStyle(.white)
                    Text("\(count)").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.primary.opacity(0.25), lineWidth: 0.5))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Theme / colors

extension Color {
    static let brand = Color(red: 177 / 255, green: 18 / 255, blue: 38 / 255) // #B11226
}

func cardColor(_ c: Card) -> Color {
    switch c {
    case .red: return Color(red: 0.85, green: 0.20, blue: 0.20)
    case .orange: return Color(red: 0.95, green: 0.55, blue: 0.15)
    case .yellow: return Color(red: 0.92, green: 0.78, blue: 0.12)
    case .green: return Color(red: 0.18, green: 0.62, blue: 0.35)
    case .blue: return Color(red: 0.16, green: 0.45, blue: 0.90)
    case .purple: return Color(red: 0.55, green: 0.28, blue: 0.75)
    case .white: return Color(white: 0.95)
    case .black: return Color(white: 0.20)
    case .locomotive: return Color(red: 0.45, green: 0.45, blue: 0.50)
    }
}

func paintColor(_ p: RoutePaint) -> Color {
    if p == .gray { return Color.gray }
    return cardColor(Card(rawValue: p.rawValue) ?? .red)
}

private let seatColors: [Color] = [
    Color(red: 0.16, green: 0.45, blue: 0.90), // blue
    Color(red: 0.95, green: 0.45, blue: 0.10), // orange
    Color(red: 0.18, green: 0.62, blue: 0.35), // green
    Color(red: 0.55, green: 0.28, blue: 0.75), // purple
]

func ownerColor(_ player: Int) -> Color {
    seatColors[player % seatColors.count]
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
