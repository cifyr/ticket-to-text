import Foundation

// Verifies the Swift GameClient against the LIVE server. Pass base URL + a
// Vercel share token (cookie bypass for the protected deployment) as args.
//   swiftc <engine+net> main.swift && ./netcheck <baseURL> <shareToken>

let base = URL(string: CommandLine.arguments[1])!
let shareToken = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil

func run() async {
    do {
        if let shareToken {
            let share = URL(string: base.absoluteString + "/?_vercel_share=" + shareToken)!
            _ = try await URLSession.shared.data(from: share) // primes the auth cookie
        }
        let client = GameClient(baseURL: base, bypassToken: nil)

        let created = try await client.create(playerCount: 2, hostId: "A", hostName: "Alice")
        print("create: gameId=\(created.gameId) hostHand=\(created.view.yourHand.map { $0.rawValue })")

        let b = try await client.view(gameId: created.gameId, me: "B")
        print("B view: you=\(String(describing: b.you)) yourHand=\(b.yourHand) player0.handCount=\(b.players[0].handCount)")
        precondition(b.you == nil && b.yourHand.isEmpty, "opponent must not receive a hand")

        // Verify the PlayerView -> display GameState adapter on real server data.
        let hostDS = created.view.displayState(localID: "A")
        precondition(Game.actingIndex(hostDS, participantID: "A") == 0, "host maps to seat 0")
        precondition(Game.canAct(hostDS, participantID: "A"), "host can act on its turn")
        let bDS = b.displayState(localID: "B")
        precondition(!Game.canAct(bDS, participantID: "B"), "B cannot act on host's turn")
        precondition(hostDS.routes.count == GameMap.routes(GameMap.defaultMapId).count, "full map round-tripped (\(hostDS.routes.count) routes)")
        print("displayState adapter OK — routes=\(hostDS.routes.count)")

        do {
            _ = try await client.move(gameId: created.gameId, participantId: "B",
                                      move: .drawCards([.blind]), name: "Bob")
            print("FAIL: B moved out of turn")
        } catch {
            print("B out-of-turn rejected: \(error)")
        }

        let after = try await client.move(gameId: created.gameId, participantId: "A",
                                          move: .drawCards([.blind, .blind]), name: "Alice")
        print("after A: currentPlayer=\(after.currentPlayer) lastSummary=\(String(describing: after.lastSummary))")
        print("SWIFT CLIENT <-> LIVE SERVER OK")
    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
}

let sem = DispatchSemaphore(value: 0)
Task { await run(); sem.signal() }
sem.wait()
