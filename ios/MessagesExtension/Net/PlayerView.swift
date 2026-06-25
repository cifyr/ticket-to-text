import Foundation

// Decoded shape of the server's redacted per-player view (see src/redact.ts).
// Contains only this device's own secrets — never another player's hand/tickets
// or the deck order.
struct PublicPlayer: Codable, Equatable {
    let name: String?
    let score: Int
    let trains: Int
    let handCount: Int
    let ticketCount: Int
    let joined: Bool
}

struct PlayerView: Codable {
    var phase: String = "playing"
    let you: Int?
    let currentPlayer: Int
    let over: Bool
    let players: [PublicPlayer]
    let routes: [Route]
    let market: [Card]
    let deckCount: Int
    let discardCount: Int
    let ticketDeckCount: Int
    let yourHand: [Card]
    let yourTickets: [Ticket]
    let log: [LogEntry]
    let lastActor: Int?
    let lastSummary: String?
    let lastClaimedRouteId: Int?
    let lastPublicDraw: [Card]
    let finalScores: [FinalScore]?
}

struct CreateResponse: Codable {
    let gameId: String
    let view: PlayerView
}

// Pre-game lobby.
struct LobbyMemberView: Codable, Equatable {
    let name: String?
    let ready: Bool
    let isHost: Bool
}

struct LobbyView: Codable {
    var phase: String = "lobby"
    let you: Int?
    let maxPlayers: Int
    let members: [LobbyMemberView]
    let canStart: Bool
}

struct LobbyCreateResponse: Codable {
    let gameId: String
    let view: LobbyView
}

// The /view endpoint returns either a lobby or a game.
enum RoomView {
    case lobby(LobbyView)
    case game(PlayerView)
}
