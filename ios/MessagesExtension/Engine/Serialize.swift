import Foundation

// Port of src/serialize.ts. The state is base64url'd JSON carried in the
// MSMessage.url as a single "s" query item — this is the iMessage payload.
//
// SECURITY / integrity: with no game server, the FULL state (both hands, the
// deck order, both ticket sets) must travel in the message so the next device
// can continue play. The UI never renders the opponent's hand/tickets/deck
// (see GameView: only `mySeat`'s secrets are shown), so honest play is private.
// But a motivated opponent could decode this payload — true anti-cheat needs a
// server-authoritative model that hands each device only its own view. That is
// the v2 step (a small backend, e.g. on Vercel) and is out of scope here.
enum Serialize {
    private static let scheme = "tickettotext"
    private static let host = "game"
    private static let key = "s"

    static func encode(_ state: GameState) -> String {
        let data = try! JSONEncoder().encode(state)
        return data.base64EncodedString()
    }

    static func decode(_ payload: String) throws -> GameState {
        guard let data = Data(base64Encoded: payload) else {
            throw IllegalMoveError(message: "payload is not valid base64")
        }
        return try JSONDecoder().decode(GameState.self, from: data)
    }

    static func encodedURL(_ state: GameState) -> URL {
        var comps = URLComponents()
        comps.scheme = scheme
        comps.host = host
        comps.queryItems = [URLQueryItem(name: key, value: encode(state))]
        return comps.url!
    }

    static func decode(from url: URL) -> GameState? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let payload = comps.queryItems?.first(where: { $0.name == key })?.value
        else { return nil }
        return try? decode(payload)
    }
}
