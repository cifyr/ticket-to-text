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
    var onEndGame: (() -> Void)? = nil   // server mode: end the game for everyone

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
    @State private var focusedOwner: Int?   // tap a player to spotlight their routes
    @State private var centerRouteId: Int?  // log jump: zoom+center this route
    @State private var pendingDrawCount: Int?     // cards just drawn, awaiting reveal
    @State private var revealCards: [Card]?       // private "you drew" reveal

    // Destination tickets I drew this turn that still need a keep/discard choice.
    private var myPendingTickets: [Ticket]? {
        guard let p = state.pendingTickets, p.player == mySeat else { return nil }
        return p.drawn
    }

    // Resolve a claim log entry back to a route by matching its printed label.
    private func routeIdForLog(_ entry: LogEntry) -> Int? {
        guard entry.text.hasPrefix("claimed ") else { return nil }
        let label = String(entry.text.dropFirst("claimed ".count))
        return state.routes.first(where: { GameMap.label($0) == label })?.id
    }

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
        .overlay { if let cards = revealCards { DrawRevealView(cards: cards) } }
        .overlay {
            if let drawn = myPendingTickets {
                TicketChooserView(drawn: drawn, state: state, mySeat: mySeat,
                                  onConfirm: { keep in apply(.keepTickets(keep), caption: "kept \(keep.count) tickets") })
            }
        }
        .task(id: state.moveCount) {
            guard pendingRecap else { return }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation { recapDismissedFor = state.moveCount }
        }
        .onChange(of: state.moveCount) { _, _ in showRevealForMyDraw() }
        .sheet(isPresented: $showHelp) { HowToPlayView(onEndGame: onEndGame) }
        .sheet(isPresented: $showLog) {
            LogSheet(log: state.log, name: name, routeId: routeIdForLog,
                     onShowRoute: { rid in showLog = false; page = 0; withAnimation(.snappy) { centerRouteId = rid } })
        }
        .sheet(isPresented: $showResults) {
            FinalScoreView(state: state)
        }
        .sheet(isPresented: $showTickets) {
            TicketsSheet(tickets: state.players[mySeat].tickets,
                         myRoutes: state.routes.filter { $0.claimedBy == mySeat },
                         ticketsLeft: state.ticketDeck.count, canDraw: effectiveCanAct,
                         onDraw: {
                             showTickets = false
                             apply(.drawTickets, caption: "drew destination tickets")
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
        }
    }

    // Player discs (active one pulses) + the local player's trains and score.
    // Tapping a disc spotlights that player's routes on the map.
    private var turnBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(0..<state.players.count, id: \.self) { p in
                    Button {
                        withAnimation(.snappy) { focusedOwner = (focusedOwner == p) ? nil : p; page = 0 }
                    } label: {
                        EnamelToken(color: ownerColor(p), label: initial(p),
                                    active: !Game.isGameOver(state) && state.currentPlayer == p, size: 30)
                            .overlay(Circle().stroke(Palette.ink, lineWidth: focusedOwner == p ? 2.5 : 0))
                            .opacity(focusedOwner == nil || focusedOwner == p ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
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
                  onSelect: { id in withAnimation(.snappy) { selectedRouteId = id } },
                  focusedOwner: focusedOwner,
                  onBackgroundTap: { withAnimation(.snappy) { focusedOwner = nil } },
                  centerRouteId: centerRouteId,
                  onClearCenter: { withAnimation(.snappy) { centerRouteId = nil } })
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
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 16) { drawSection; handSection }
                        .padding(.horizontal, 2)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: geo.size.height)
            }
        }
    }

    // The face-up market is always visible; off-turn it's just non-interactive.
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
            .opacity(effectiveCanAct ? 1 : 0.6)

            if effectiveCanAct {
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
            } else {
                Text("Waiting for \(name(state.currentPlayer)) — scout the market and board while you wait.")
                    .font(.sans(11)).foregroundStyle(Palette.sepiaLight).multilineTextAlignment(.center)
            }
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
            Button { showResults = true } label: { Text("Results") }.buttonStyle(BrassButtonStyle()).frame(width: 120)
        }
        .stub(Palette.parchmentDeep, corner: 14, padding: 12)
        .onAppear { showResults = true }
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
        // A face-up locomotive uses the whole turn, so it stands alone — but it's
        // only selected here; the player still has to press Draw to submit.
        if card == .locomotive { draft = [.market(slot: i)]; return }
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
        pendingDrawCount = picks.count
        apply(.drawCards(picks), caption: "drew \(picks.count) card\(picks.count == 1 ? "" : "s")")
    }

    // After my own card draw resolves, privately show what I got before the bubble posts.
    private func showRevealForMyDraw() {
        guard state.lastActor == mySeat, let k = pendingDrawCount else { pendingDrawCount = nil; return }
        pendingDrawCount = nil
        let hand = state.players[mySeat].hand
        withAnimation(.spring(duration: 0.35)) { revealCards = Array(hand.suffix(k)) }
        Task { try? await Task.sleep(nanoseconds: 1_600_000_000); withAnimation { revealCards = nil } }
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

// MARK: - Draw reveals (private to the actor, shown before the bubble posts)

// "You drew" card reveal. Blind cards are shown to you only.
struct DrawRevealView: View {
    let cards: [Card]
    @State private var shown = false
    var body: some View {
        ZStack {
            PaperFill().opacity(0.97)
            VStack(spacing: 16) {
                Text("You Drew").font(.slab(13, .bold)).tracking(3).textCase(.uppercase)
                    .foregroundStyle(Palette.sepia)
                HStack(spacing: 12) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                        EnamelCard(card: card, height: 96).frame(width: 66)
                            .scaleEffect(shown ? 1 : 0.5).opacity(shown ? 1 : 0)
                            .animation(.spring(duration: 0.4).delay(Double(i) * 0.12), value: shown)
                    }
                }
                Text("Face-up cards are public — only deck draws stay secret.")
                    .font(.sans(11)).foregroundStyle(Palette.sepiaLight).multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .transition(.opacity)
        .onAppear { shown = true }
    }
}

// Fullscreen keep/discard chooser for freshly drawn destination tickets.
// You must keep at least one; the rest return to the bottom of the deck. Swipe
// to the board page to study the map before deciding.
struct TicketChooserView: View {
    let drawn: [Ticket]
    let state: GameState
    let mySeat: Int
    let onConfirm: ([Int]) -> Void

    @State private var keep: Set<Int> = []
    @State private var shown = false
    @State private var page = 0

    private var myRoutes: [Route] { state.routes.filter { $0.claimedBy == mySeat } }

    var body: some View {
        ZStack {
            PaperFill()
            TabView(selection: $page) {
                chooserPage.tag(0)
                mapPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .transition(.opacity)
        .onAppear { shown = true; if let first = drawn.first { keep = [first.id] } } // default-keep one
    }

    private var chooserPage: some View {
        VStack(spacing: 14) {
            Text("Keep Destination Tickets").font(.slab(14, .bold)).tracking(1.5).textCase(.uppercase)
                .foregroundStyle(Palette.sepia)
            Text("Keep at least one — the rest go to the bottom of the deck. Swipe to check the map.")
                .font(.sans(12)).foregroundStyle(Palette.sepiaLight).multilineTextAlignment(.center)

            ForEach(Array(drawn.enumerated()), id: \.offset) { i, t in
                let on = keep.contains(t.id)
                Button { toggle(t.id) } label: { row(t, on: on) }
                    .buttonStyle(.plain)
                    .scaleEffect(shown ? 1 : 0.7).opacity(shown ? 1 : 0)
                    .animation(.spring(duration: 0.4).delay(Double(i) * 0.12), value: shown)
            }

            Button { onConfirm(Array(keep)) } label: {
                Label(keep.isEmpty ? "Keep at least one" : "Keep \(keep.count)", systemImage: "checkmark")
            }
            .buttonStyle(BrassButtonStyle()).disabled(keep.isEmpty).opacity(keep.isEmpty ? 0.55 : 1)
            .padding(.top, 4)
        }
        .padding(24).padding(.bottom, 20)
    }

    private var mapPage: some View {
        VStack(spacing: 10) {
            Text("Your Board").font(.slab(12, .bold)).tracking(3).textCase(.uppercase)
                .foregroundStyle(Palette.sepiaLight)
            BoardArea(state: state, selectedRouteId: nil, highlightTicket: nil,
                      canAct: false, claimable: { _ in false }, onSelect: { _ in },
                      highlightTickets: drawn.filter { keep.contains($0.id) })
            Text("Red lines show the tickets you're keeping. Zoom in to plan, then swipe back to choose.")
                .font(.sans(11)).foregroundStyle(Palette.sepiaLight).multilineTextAlignment(.center)
        }
        .padding(16).padding(.bottom, 20)
    }

    private func toggle(_ id: Int) {
        if keep.contains(id) { keep.remove(id) } else { keep.insert(id) }
    }

    private func row(_ t: Ticket, on: Bool) -> some View {
        let done = Scoring.connected(myRoutes, from: t.cityA, to: t.cityB)
        return HStack(spacing: 10) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20)).foregroundStyle(on ? Palette.success : Palette.sepiaLight)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(GameMap.cities[t.cityA].name).font(.slab(15, .bold)).foregroundStyle(Palette.ink)
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.brass)
                    Text(GameMap.cities[t.cityB].name).font(.slab(15, .bold)).foregroundStyle(Palette.ink)
                }
                if done {
                    Text("Already connected").font(.sans(10, .bold)).textCase(.uppercase).foregroundStyle(Palette.success)
                }
            }
            Spacer(minLength: 8)
            PointStamp(points: t.points, size: 40)
        }
        .stub(on ? Color(hex: 0xD7E8D5) : Palette.parchmentDeep, corner: 12, padding: 12,
              stroke: on ? Palette.success.opacity(0.55) : Palette.hairline)
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
