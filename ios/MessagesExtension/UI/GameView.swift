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
    @State private var page = 0   // 0 = map, 1 = cards

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

    private func initial(_ seat: Int) -> String { String(name(seat).prefix(1)).uppercased() }

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
                         onShow: { t in showTickets = false; page = 0; flashTicket(t) })
        }
    }

    // MARK: Compact

    private var compact: some View {
        Button(action: onRequestExpand) { compactCard }
            .buttonStyle(.plain)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paper()
    }

    private var aboard: Int { max(2, state.playerIDs.compactMap { $0 }.count) }

    private var compactCard: some View {
        VStack(spacing: 11) {
            HStack(spacing: 13) {
                TrainBadge(color: Palette.carRed, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ticket to Text").font(.slab(19, .bold)).foregroundStyle(Palette.ink)
                    Text(statusText).font(.sans(12.5, .semibold)).foregroundStyle(Palette.sepia).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.brass)
            }
            VStack(spacing: 9) {
                DashedRule()
                HStack {
                    Text("Tap to board the table").font(.slab(10, .semibold))
                        .tracking(1.4).textCase(.uppercase).foregroundStyle(Palette.sepiaLight)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Palette.success).frame(width: 6, height: 6)
                        Text("\(aboard) aboard").font(.sans(11, .heavy)).foregroundStyle(Palette.success)
                    }
                }
            }
        }
        .stub(Palette.parchment, corner: 18, padding: 16)
    }

    // MARK: Expanded

    private var expanded: some View {
        VStack(spacing: 10) {
            header
            turnBar
            content
            if let errorText { Text(errorText).font(.sans(12)).foregroundStyle(Palette.danger) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paper()
    }

    private var header: some View {
        HStack(spacing: 10) {
            TrainBadge(color: Palette.carRed, size: 38)
            VStack(alignment: .leading, spacing: 0) {
                Text("Ticket to Text").font(.slab(18, .bold)).foregroundStyle(Palette.ink)
                Text(statusText).font(.sans(11, .semibold)).foregroundStyle(Palette.sepia).lineLimit(1)
            }
            Spacer(minLength: 4)
            RailIconButton(system: "ticket.fill", badge: "\(state.players[mySeat].tickets.count)") { showTickets = true }
            RailIconButton(system: "clock.arrow.circlepath") { showLog = true }
            RailIconButton(system: "questionmark") { showHelp = true }
            RailIconButton(system: "arrow.clockwise") { onNewGame() }
        }
    }

    // Player discs (active one pulses) + the local player's trains and score.
    private var turnBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(0..<state.players.count, id: \.self) { p in
                    EnamelToken(color: ownerColor(p), label: initial(p),
                                active: !Game.isGameOver(state) && state.currentPlayer == p, size: 30)
                }
            }
            Spacer(minLength: 4)
            pill {
                Image(systemName: "train.side.front.car").font(.system(size: 12)).foregroundStyle(Palette.sepia)
                Text("\(state.players[mySeat].trains)").font(.sans(14, .heavy)).foregroundStyle(Palette.ink)
            }
            pill {
                Text("\(state.players[mySeat].score)").font(.sans(14, .heavy)).foregroundStyle(Palette.ink)
                Text("PTS").font(.slab(9, .semibold)).tracking(1).foregroundStyle(Palette.sepiaLight)
            }
        }
        .stub(Palette.parchmentDeep, corner: 13, padding: 10)
    }

    private func pill<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 5) { content() }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 9).fill(Palette.parchment)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.hairline, lineWidth: 1))
            )
    }

    // MARK: Content (paged: map / cards) or a status panel

    @ViewBuilder private var content: some View {
        if Game.isGameOver(state) {
            gameOverBar
            Spacer(minLength: 0)
        } else if needsJoin {
            joinCard
            Spacer(minLength: 0)
        } else {
            VStack(spacing: 8) {
                TabView(selection: $page) {
                    mapPage.tag(0)
                    cardsPage.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                segments
            }
        }
    }

    private var segments: some View {
        HStack(spacing: 0) {
            seg("Map", 0, "map.fill")
            seg("Cards", 1, "rectangle.on.rectangle.angled")
        }
        .padding(3)
        .background(Capsule().fill(Palette.parchmentDeep).overlay(Capsule().stroke(Palette.brassHair, lineWidth: 1)))
    }

    private func seg(_ title: String, _ idx: Int, _ icon: String) -> some View {
        let on = page == idx
        return Button { withAnimation(.snappy) { page = idx } } label: {
            HStack(spacing: 6) { Image(systemName: icon); Text(title) }
                .font(.slab(14, .bold))
                .foregroundStyle(on ? Color(hex: 0x3A2A0C) : Palette.sepia)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(
                    Capsule().fill(on
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xD9A23B), Color(hex: 0xB97E1C)],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.clear))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Map page

    private var mapPage: some View {
        BoardArea(state: state, selectedRouteId: selectedRouteId, highlightTicket: highlightTicket,
                  canAct: effectiveCanAct, claimable: { Game.canClaim(state, $0, player: mySeat) },
                  onSelect: { id in withAnimation(.snappy) { selectedRouteId = id } })
            .overlay(alignment: .bottom) {
                if let id = selectedRouteId, let route = state.routes.first(where: { $0.id == id }) {
                    RouteDetailCard(
                        route: route, hand: state.players[mySeat].hand, trains: state.players[mySeat].trains,
                        affordable: effectiveCanAct && Game.canClaim(state, route, player: mySeat),
                        onClaim: {
                            apply(.claim(routeId: route.id, color: nil), caption: "claimed \(GameMap.label(route))")
                            withAnimation { selectedRouteId = nil }
                        },
                        onClose: { withAnimation { selectedRouteId = nil } })
                        .padding(8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }

    // MARK: Cards page

    private var cardsPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                if effectiveCanAct { drawSection } else { waiting }
                handSection
            }
            .padding(.top, 4).padding(.bottom, 8)
        }
    }

    private var drawSection: some View {
        VStack(spacing: 10) {
            SectionRule(title: "Face-up Market")
            HStack(spacing: 8) {
                ForEach(Array(state.market.enumerated()), id: \.offset) { i, card in
                    EnamelCard(card: card, selected: draft.contains(.market(slot: i)), height: 58)
                        .frame(maxWidth: .infinity)
                        .onTapGesture { selectMarket(i, card: card) }
                }
                DeckTile(count: state.deck.count)
                    .frame(maxWidth: .infinity)
                    .onTapGesture { selectBlind() }
            }
            HStack(spacing: 10) {
                Button { commitDraw() } label: { Text(draft.isEmpty ? "Draw cards" : "Draw \(draft.count)") }
                    .buttonStyle(BrassButtonStyle()).disabled(draft.isEmpty).opacity(draft.isEmpty ? 0.55 : 1)
                if !draft.isEmpty {
                    Button { draft = [] } label: { Text("Clear") }
                        .buttonStyle(QuietButtonStyle()).frame(width: 110)
                }
            }
            Text(draft.isEmpty ? "Pick up to \(Game.maxDraw) cards, or tap a route on the map to claim it."
                               : "Tap Draw to take \(draft.count), or pick more.")
                .font(.sans(11)).foregroundStyle(Palette.sepiaLight).multilineTextAlignment(.center)
        }
    }

    private var handSection: some View {
        let hand = state.players[mySeat].hand
        let held = Card.allCases.compactMap { c -> (Card, Int)? in
            let n = hand.filter { $0 == c }.count
            return n > 0 ? (c, n) : nil
        }
        return VStack(spacing: 10) {
            SectionRule(title: "Your Cars · \(hand.count) in hand")
            if held.isEmpty {
                Text("No cards yet — draw some on your turn.")
                    .font(.sans(12)).foregroundStyle(Palette.sepiaLight).padding(.vertical, 8)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(held, id: \.0) { card, n in
                        EnamelCard(card: card, height: 66)
                            .overlay(alignment: .bottomTrailing) {
                                Text("\(n)").font(.sans(11, .heavy)).foregroundStyle(Palette.ink)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Palette.parchment)
                                        .overlay(Circle().stroke(Palette.brassHair, lineWidth: 1)))
                                    .offset(x: 5, y: 5)
                            }
                    }
                }
            }
        }
        .stub(Palette.parchmentDeep, corner: 13, padding: 12)
    }

    // MARK: Status panels

    private var joinCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.badge.plus").font(.title2).foregroundStyle(Palette.brass)
            Text("Open seat: \(name(state.currentPlayer))").font(.slab(17, .bold)).foregroundStyle(Palette.ink)
            Text("Join to take this turn. Set your name in the ? menu.")
                .font(.sans(12)).foregroundStyle(Palette.sepia).multilineTextAlignment(.center)
            Button { withAnimation { confirmedSeat = state.currentPlayer } } label: {
                Label("Join as \(name(state.currentPlayer))", systemImage: "checkmark")
            }
            .buttonStyle(BrassButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .stub(Palette.parchmentDeep, corner: 14, padding: 18)
    }

    private var gameOverBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered").foregroundStyle(Palette.brass)
            Text(statusText).font(.slab(17, .bold)).foregroundStyle(Palette.ink)
            Spacer()
            Button { showResults = true } label: { Text("Results") }.buttonStyle(QuietButtonStyle()).frame(width: 100)
            Button { onNewGame() } label: { Text("New") }.buttonStyle(BrassButtonStyle()).frame(width: 90)
        }
        .stub(Palette.parchmentDeep, corner: 14, padding: 12)
        .onAppear { showResults = true }
    }

    private var waiting: some View {
        VStack(spacing: 6) {
            ProgressView().tint(Palette.brass)
            Text("Waiting for \(name(state.currentPlayer))").font(.slab(15, .semibold)).foregroundStyle(Palette.ink)
            Text("Inspect the board, then reopen after they send their turn.")
                .font(.sans(11)).foregroundStyle(Palette.sepia).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .stub(Palette.parchmentDeep, corner: 14, padding: 8)
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
        if Game.assignedIndex(state, participantID: localParticipantID) == state.currentPlayer {
            return "Your turn"
        }
        return "\(name(state.currentPlayer))'s turn"
    }
}

// MARK: - Card tiles (face-up market card + face-down deck)

struct CardTile: View {
    let card: Card
    let selected: Bool
    var body: some View {
        EnamelCard(card: card, selected: selected, height: 42).frame(maxWidth: .infinity)
    }
}

struct DeckTile: View {
    let count: Int
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [Color(hex: 0x3A322A), Color(hex: 0x231D17)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 58)
            .overlay {
                VStack(spacing: 2) {
                    Image(systemName: "square.stack.fill").font(.system(size: 15)).foregroundStyle(Palette.brass)
                    Text("\(count)").font(.sans(9, .bold)).foregroundStyle(Palette.brassLight)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.35), lineWidth: 1))
            .shadow(color: Palette.ink.opacity(0.25), radius: 3, y: 2)
    }
}
