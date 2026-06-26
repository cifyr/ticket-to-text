import Foundation

// Faithful Ticket-to-Ride-style model. 1:1 port of src/types.ts. GameState is
// Codable so the whole state rides inside an iMessage payload. Move/DrawPick are
// transient (created in the UI, applied immediately) so they need not be Codable.

// 8 colors + the wild locomotive. rawValues match the TS strings.
enum Card: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, white, black, locomotive

    static var baseColors: [Card] { allCases.filter { $0 != .locomotive } }
}

// Route paint: the 8 colors plus "gray" (accepts any single color).
enum RoutePaint: String, Codable {
    case red, orange, yellow, green, blue, purple, white, black, gray
}

struct Route: Codable, Equatable, Identifiable {
    let id: Int
    let cityA: Int
    let cityB: Int
    let length: Int
    let color: RoutePaint
    var claimedBy: Int?
}

struct Ticket: Codable, Equatable, Identifiable {
    let id: Int
    let cityA: Int
    let cityB: Int
    let points: Int
}

struct PlayerState: Codable, Equatable {
    var hand: [Card]
    var tickets: [Ticket]
    var trains: Int
    var score: Int
}

struct LogEntry: Codable, Equatable {
    let actor: Int
    let text: String
}

struct GameState: Codable, Equatable {
    var routes: [Route]
    var players: [PlayerState]
    var currentPlayer: Int
    var deck: [Card]
    var discard: [Card]
    var market: [Card]
    var ticketDeck: [Ticket]
    var finalTurnsLeft: Int?
    var over: Bool
    var deckSeed: UInt32
    var playerIDs: [String?]
    var playerNames: [String?]
    var moveCount: Int
    var log: [LogEntry]
    var lastActor: Int?
    var lastSummary: String?
    var lastClaimedRouteId: Int?
    var lastPublicDraw: [Card]
    var pendingTickets: PendingTickets?
}

// Drawn destination tickets awaiting the player's keep/discard choice.
struct PendingTickets: Codable, Equatable {
    var player: Int
    var drawn: [Ticket]
}

enum DrawPick: Equatable {
    case market(slot: Int)
    case blind
}

enum Move: Equatable {
    case drawCards([DrawPick])
    case claim(routeId: Int, color: Card?)
    case drawTickets
    case keepTickets([Int])
}

struct IllegalMoveError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
