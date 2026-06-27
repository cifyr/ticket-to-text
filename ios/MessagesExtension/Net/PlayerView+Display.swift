import Foundation

// Adapts a server PlayerView into the GameState shape the UI already renders.
// Only this device's own hand/tickets are real; other players are counts only,
// and the deck/discard/ticket-deck are length-accurate placeholders (their
// contents are never read by the UI). This keeps GameView unchanged across modes.
extension PlayerView {
    func displayState(localID: String) -> GameState {
        let n = players.count
        let ids: [String?] = (0..<n).map { i in
            i == you ? localID : (players[i].joined ? "seat\(i)" : nil)
        }
        let names: [String?] = players.map { $0.name }
        let ps: [PlayerState] = (0..<n).map { i in
            // Your own tickets are always real; others' are revealed only at game end.
            PlayerState(hand: i == you ? yourHand : [],
                        tickets: i == you ? yourTickets : players[i].tickets,
                        trains: players[i].trains, score: players[i].score)
        }
        let placeholderTicket = Ticket(id: -1, cityA: 0, cityB: 0, points: 0)
        return GameState(
            mapId: mapId ?? GameMap.defaultMapId,
            routes: routes,
            players: ps,
            currentPlayer: currentPlayer,
            deck: Array(repeating: .locomotive, count: deckCount),
            discard: Array(repeating: .locomotive, count: discardCount),
            market: market,
            ticketDeck: Array(repeating: placeholderTicket, count: ticketDeckCount),
            finalTurnsLeft: nil,
            over: over,
            deckSeed: 0,
            playerIDs: ids,
            playerNames: names,
            moveCount: log.count,
            log: log,
            lastActor: lastActor,
            lastSummary: lastSummary,
            lastClaimedRouteId: lastClaimedRouteId,
            lastPublicDraw: lastPublicDraw,
            pendingTickets: pendingTickets.map { PendingTickets(player: you ?? currentPlayer, drawn: $0) }
        )
    }
}
