import Foundation

// 1:1 port of src/game.ts. Value-type structs make "immutable" natural.
enum Game {
    static let startingHand = 4
    static let startingTickets = 3
    static let startingTrains = 45
    static let marketSize = 5
    static let finalTrainThreshold = 2
    static let maxDraw = 2
    private static let cardsPerColor = 12
    private static let locomotives = 14

    private static func buildDeck(seed: UInt32) -> [Card] {
        var flat: [Card] = []
        for color in Card.baseColors { for _ in 0..<cardsPerColor { flat.append(color) } }
        for _ in 0..<locomotives { flat.append(.locomotive) }
        var rng = Mulberry32(seed: seed)
        return shuffle(flat, &rng)
    }

    private static func drawTop(_ state: inout GameState) -> Card? {
        if state.deck.isEmpty {
            if state.discard.isEmpty { return nil }
            var rng = Mulberry32(seed: state.deckSeed &+ UInt32(state.discard.count))
            state.deck = shuffle(state.discard, &rng)
            state.discard = []
        }
        return state.deck.popLast()
    }

    private static func refillMarket(_ state: inout GameState) {
        while state.market.count < marketSize {
            guard let c = drawTop(&state) else { break }
            state.market.append(c)
        }
    }

    static func newGame(seed: UInt32 = 0xC0FFEE, playerCount: Int = 2, mapId: String = GameMap.defaultMapId) -> GameState {
        let count = max(2, min(4, playerCount))
        var deck = buildDeck(seed: seed)
        func draw(_ n: Int) -> [Card] {
            let dealt = Array(deck.suffix(n)); deck.removeLast(n); return dealt
        }
        var rng = Mulberry32(seed: seed ^ 0x9E3779B9)
        var tDeck = shuffle(GameMap.ticketDeck(mapId), &rng)
        func dealTickets() -> [Ticket] {
            let t = Array(tDeck.prefix(startingTickets)); tDeck.removeFirst(startingTickets); return t
        }
        var players: [PlayerState] = []
        for _ in 0..<count {
            players.append(PlayerState(hand: draw(startingHand), tickets: dealTickets(),
                                       trains: startingTrains, score: 0))
        }
        var state = GameState(mapId: mapId, routes: GameMap.routes(mapId), players: players, currentPlayer: 0,
                              deck: deck, discard: [], market: [], ticketDeck: tDeck,
                              finalTurnsLeft: nil, over: false, deckSeed: seed,
                              playerIDs: Array(repeating: nil, count: count),
                              playerNames: Array(repeating: nil, count: count), moveCount: 0, log: [],
                              lastActor: nil, lastSummary: nil, lastClaimedRouteId: nil, lastPublicDraw: [],
                              pendingTickets: nil)
        refillMarket(&state)
        return state
    }

    // MARK: Claiming

    private static func colorCount(_ hand: [Card], _ color: Card) -> Int {
        hand.filter { $0 == color }.count
    }
    private static func locoCount(_ hand: [Card]) -> Int {
        hand.filter { $0 == .locomotive }.count
    }

    private static func bestGrayColor(_ hand: [Card]) -> Card {
        var best = Card.baseColors[0], bestCount = -1
        for c in Card.baseColors {
            let n = colorCount(hand, c)
            if n > bestCount { bestCount = n; best = c }
        }
        return best
    }

    // The base color matching a route paint, or nil for gray.
    private static func baseColor(_ paint: RoutePaint) -> Card? {
        Card(rawValue: paint.rawValue)
    }

    // A double route's parallel track: same city pair, different id. Only one of
    // a pair may ever be claimed, so a claimed sibling locks the other.
    static func siblingClaimed(_ state: GameState, _ route: Route) -> Bool {
        state.routes.contains { r in
            r.id != route.id && r.claimedBy != nil &&
            ((r.cityA == route.cityA && r.cityB == route.cityB) ||
             (r.cityA == route.cityB && r.cityB == route.cityA))
        }
    }

    static func canClaim(_ state: GameState, _ route: Route, player: Int) -> Bool {
        guard route.claimedBy == nil else { return false }
        guard !siblingClaimed(state, route) else { return false }
        let p = state.players[player]
        guard p.trains >= route.length else { return false }
        let loco = locoCount(p.hand)
        if route.color == .gray {
            return Card.baseColors.contains { colorCount(p.hand, $0) + loco >= route.length }
        }
        guard let c = baseColor(route.color) else { return false }
        return colorCount(p.hand, c) + loco >= route.length
    }

    private static func payColorFor(_ state: GameState, _ route: Route, player: Int, chosen: Card?) -> Card {
        if route.color != .gray { return baseColor(route.color)! }
        if let chosen { return chosen }
        return bestGrayColor(state.players[player].hand)
    }

    // MARK: Moves

    @discardableResult
    private static func applyClaim(_ state: inout GameState, routeId: Int, chosen: Card?) throws -> Route {
        let p = state.currentPlayer
        guard let idx = state.routes.firstIndex(where: { $0.id == routeId }) else {
            throw IllegalMoveError(message: "no route with id \(routeId)")
        }
        let route = state.routes[idx]
        guard route.claimedBy == nil else { throw IllegalMoveError(message: "route \(routeId) already claimed") }
        guard !siblingClaimed(state, route) else { throw IllegalMoveError(message: "parallel route to \(routeId) already claimed") }
        guard state.players[p].trains >= route.length else { throw IllegalMoveError(message: "not enough trains") }

        let payColor = payColorFor(state, route, player: p, chosen: chosen)
        let hand = state.players[p].hand
        let have = colorCount(hand, payColor)
        let useColor = min(have, route.length)
        let useLoco = route.length - useColor
        guard locoCount(hand) >= useLoco else {
            throw IllegalMoveError(message: "not enough \(payColor.rawValue)/locomotive cards for route \(routeId)")
        }

        var colorLeft = useColor, locoLeft = useLoco
        state.players[p].hand = hand.filter { c in
            if c == payColor && colorLeft > 0 { colorLeft -= 1; state.discard.append(c); return false }
            if c == .locomotive && locoLeft > 0 { locoLeft -= 1; state.discard.append(c); return false }
            return true
        }
        state.routes[idx].claimedBy = p
        state.players[p].trains -= route.length
        state.players[p].score += Scoring.routePoints(route.length)
        return state.routes[idx]
    }

    @discardableResult
    private static func applyDraw(_ state: inout GameState, picks: [DrawPick]) throws -> [Card] {
        guard picks.count >= 1 && picks.count <= maxDraw else {
            throw IllegalMoveError(message: "must draw 1-\(maxDraw) cards")
        }
        let p = state.currentPlayer

        // Market slots resolve against the snapshot the player saw (no refill
        // between picks) so indices stay stable for the UI.
        let slots: [Int] = picks.compactMap { if case .market(let s) = $0 { return s } else { return nil } }
        guard Set(slots).count == slots.count else { throw IllegalMoveError(message: "duplicate market slot") }
        for slot in slots {
            guard slot >= 0 && slot < state.market.count else {
                throw IllegalMoveError(message: "invalid market slot \(slot)")
            }
            if state.market[slot] == .locomotive && picks.count != 1 {
                throw IllegalMoveError(message: "taking a face-up locomotive uses your whole turn")
            }
        }
        var drawn = slots.map { state.market[$0] }
        for s in slots.sorted(by: >) { state.market.remove(at: s) }

        for pick in picks {
            if case .blind = pick {
                guard let card = drawTop(&state) else {
                    throw IllegalMoveError(message: "no cards left to draw")
                }
                drawn.append(card)
            }
        }
        state.players[p].hand.append(contentsOf: drawn)
        refillMarket(&state)
        return drawn
    }

    @discardableResult
    private static func applyDrawTickets(_ state: inout GameState) throws -> Int {
        guard !state.ticketDeck.isEmpty else { throw IllegalMoveError(message: "no tickets left") }
        let n = min(startingTickets, state.ticketDeck.count)
        let drawn = Array(state.ticketDeck.prefix(n))
        state.ticketDeck.removeFirst(n)
        // Held for the keep/discard choice; the turn waits.
        state.pendingTickets = PendingTickets(player: state.currentPlayer, drawn: drawn)
        return n
    }

    @discardableResult
    private static func applyKeepTickets(_ state: inout GameState, keep: [Int]) throws -> Int {
        guard let pending = state.pendingTickets else { throw IllegalMoveError(message: "no tickets to keep") }
        guard pending.player == state.currentPlayer else { throw IllegalMoveError(message: "not your tickets") }
        let drawnIds = Set(pending.drawn.map { $0.id })
        let keepSet = Set(keep.filter { drawnIds.contains($0) })
        guard keepSet.count >= 1 else { throw IllegalMoveError(message: "keep at least one ticket") }
        let kept = pending.drawn.filter { keepSet.contains($0.id) }
        let returned = pending.drawn.filter { !keepSet.contains($0.id) }
        state.players[pending.player].tickets.append(contentsOf: kept)
        state.ticketDeck.append(contentsOf: returned) // returned go to the bottom of the deck
        state.pendingTickets = nil
        return kept.count
    }

    private static func endOfTurn(_ state: inout GameState) {
        // With double routes one of each pair stays nil forever, so "all claimed"
        // means every route is claimed or blocked by a claimed sibling.
        let s = state
        if state.routes.allSatisfy({ $0.claimedBy != nil || siblingClaimed(s, $0) }) { state.over = true; return }
        if state.finalTurnsLeft == nil {
            if state.players[state.currentPlayer].trains <= finalTrainThreshold {
                state.finalTurnsLeft = state.players.count // each player, incl. this one, gets one final turn
            }
        } else {
            state.finalTurnsLeft! -= 1
            if state.finalTurnsLeft! <= 0 { state.over = true }
        }
        if !state.over { state.currentPlayer = (state.currentPlayer + 1) % state.players.count }
    }

    // Reveals only public info: face-up market picks; blind draws as a count.
    private static func describeDraw(_ marketCards: [Card], _ blindCount: Int) -> String {
        if marketCards.isEmpty { return "drew \(blindCount) card\(blindCount == 1 ? "" : "s") from the deck" }
        let took = "took " + marketCards.map { $0.rawValue }.joined(separator: ", ")
        if blindCount == 0 { return took }
        return "\(took) and drew \(blindCount) from the deck"
    }

    static func applyMove(_ state: GameState, _ move: Move) throws -> GameState {
        if isGameOver(state) { throw IllegalMoveError(message: "game is already over") }
        // A pending ticket draw must be resolved before anything else.
        if state.pendingTickets != nil, case .keepTickets = move {} else if state.pendingTickets != nil {
            throw IllegalMoveError(message: "keep at least one of your drawn tickets first")
        }
        var next = state
        let actor = next.currentPlayer

        let summary: String
        var claimedId: Int? = nil
        var publicDraw: [Card] = []
        var advance = true // a pending ticket draw keeps the turn open
        switch move {
        case .drawCards(let picks):
            let marketCards: [Card] = picks.compactMap {
                if case .market(let s) = $0, s >= 0, s < next.market.count { return next.market[s] } else { return nil }
            }
            let blindCount = picks.filter { if case .blind = $0 { return true } else { return false } }.count
            try applyDraw(&next, picks: picks)
            summary = describeDraw(marketCards, blindCount)
            publicDraw = marketCards
        case .claim(let routeId, let color):
            let route = try applyClaim(&next, routeId: routeId, chosen: color)
            summary = "claimed \(GameMap.label(route, state.mapId))"
            claimedId = route.id
        case .drawTickets:
            let n = try applyDrawTickets(&next)
            summary = "drew \(n) destination tickets"
            advance = false // wait for the keep/discard choice
        case .keepTickets(let keep):
            let n = try applyKeepTickets(&next, keep: keep)
            summary = "kept \(n) destination ticket\(n == 1 ? "" : "s")"
        }

        next.lastActor = actor
        next.lastSummary = summary
        next.lastClaimedRouteId = claimedId
        next.lastPublicDraw = publicDraw
        next.log.append(LogEntry(actor: actor, text: summary))
        next.moveCount += 1

        if advance { endOfTurn(&next) }
        return next
    }

    // MARK: Queries

    static func canDraw(_ state: GameState) -> Bool {
        !state.market.isEmpty || !state.deck.isEmpty || !state.discard.isEmpty
    }

    static func legalMoves(_ state: GameState) -> [Move] {
        var moves: [Move] = []
        if canDraw(state) { moves.append(.drawCards([.blind])) }
        for route in state.routes where canClaim(state, route, player: state.currentPlayer) {
            moves.append(.claim(routeId: route.id, color: nil))
        }
        if !state.ticketDeck.isEmpty { moves.append(.drawTickets) }
        return moves
    }

    static func isGameOver(_ state: GameState) -> Bool {
        state.over || state.routes.allSatisfy { $0.claimedBy != nil || siblingClaimed(state, $0) } || legalMoves(state).isEmpty
    }

    // MARK: Turn identity

    static func assignedIndex(_ state: GameState, participantID: String) -> Int? {
        state.playerIDs.firstIndex(where: { $0 == participantID })
    }

    static func actingIndex(_ state: GameState, participantID: String) -> Int? {
        if let i = assignedIndex(state, participantID: participantID) { return i }
        if state.playerIDs[state.currentPlayer] == nil { return state.currentPlayer }
        return nil
    }

    static func canAct(_ state: GameState, participantID: String) -> Bool {
        !isGameOver(state) && actingIndex(state, participantID: participantID) == state.currentPlayer
    }

    static func applyMove(_ state: GameState, _ move: Move, by participantID: String) throws -> GameState {
        guard let seat = actingIndex(state, participantID: participantID), seat == state.currentPlayer else {
            throw IllegalMoveError(message: "it is not your turn")
        }
        var seated = state
        seated.playerIDs[seat] = participantID
        return try applyMove(seated, move)
    }
}
