import Foundation

// Talks to the authoritative server (see server/README.md). The MSMessage only
// needs to carry the gameId; each device fetches its own redacted PlayerView and
// submits moves here, so hands/deck never travel through Messages.
struct GameClient {
    let baseURL: URL
    var bypassToken: String?   // Vercel Protection Bypass for Automation, if set

    struct ServerError: Error, CustomStringConvertible {
        let status: Int
        let message: String
        var description: String { "server \(status): \(message)" }
    }

    func create(playerCount: Int, hostId: String, hostName: String?) async throws -> CreateResponse {
        var body: [String: Any] = ["playerCount": playerCount, "hostId": hostId]
        if let hostName { body["hostName"] = hostName }
        return try await send("create", method: "POST", query: [:], body: body)
    }

    func view(gameId: String, me: String) async throws -> PlayerView {
        try await send("view", method: "GET", query: ["id": gameId, "me": me], body: nil)
    }

    func move(gameId: String, participantId: String, move: Move, name: String?) async throws -> PlayerView {
        var body: [String: Any] = [
            "gameId": gameId, "participantId": participantId, "move": Self.encodeMove(move),
        ]
        if let name { body["name"] = name }
        return try await send("move", method: "POST", query: [:], body: body)
    }

    // MARK: - Wire encoding

    static func encodeMove(_ move: Move) -> [String: Any] {
        switch move {
        case .drawCards(let picks):
            return ["kind": "drawCards", "picks": picks.map { pick -> [String: Any] in
                switch pick {
                case .blind: return ["from": "blind"]
                case .market(let slot): return ["from": "market", "slot": slot]
                }
            }]
        case .claim(let routeId, let color):
            var d: [String: Any] = ["kind": "claim", "routeId": routeId]
            if let color { d["color"] = color.rawValue }
            return d
        case .drawTickets:
            return ["kind": "drawTickets"]
        }
    }

    // MARK: - Transport

    private func send<T: Decodable>(_ action: String, method: String,
                                    query: [String: String], body: [String: Any]?) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api"), resolvingAgainstBaseURL: false)!
        comps.queryItems = ([("action", action)] + query.map { ($0, $1) }).map { URLQueryItem(name: $0.0, value: $0.1) }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        if let token = bypassToken { req.setValue(token, forHTTPHeaderField: "x-vercel-protection-bypass") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw ServerError(status: status, message: msg ?? String(data: data, encoding: .utf8) ?? "unknown")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
