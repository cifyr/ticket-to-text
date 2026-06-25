import Foundation

// Exercises the SHIPPING Swift engine (compiled with the real Engine/*.swift)
// to verify behavior parity with the TypeScript test suite.

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if !cond { print("FAIL: \(msg)"); failures += 1 } else { print("ok: \(msg)") }
}

func pl(_ hand: [Card] = [], trains: Int = 45, score: Int = 0, tickets: [Ticket] = []) -> PlayerState {
    PlayerState(hand: hand, tickets: tickets, trains: trains, score: score)
}
func rt(_ id: Int, _ a: Int, _ b: Int, _ len: Int, _ c: RoutePaint, _ claimedBy: Int? = nil) -> Route {
    Route(id: id, cityA: a, cityB: b, length: len, color: c, claimedBy: claimedBy)
}
func mk(routes: [Route], players: [PlayerState], deck: [Card] = [], market: [Card] = [],
        discard: [Card] = [], current: Int = 0) -> GameState {
    GameState(routes: routes, players: players, currentPlayer: current, deck: deck, discard: discard,
              market: market, ticketDeck: [], finalTurnsLeft: nil, over: false, deckSeed: 1,
              playerIDs: Array(repeating: nil, count: players.count),
              playerNames: Array(repeating: nil, count: players.count),
              moveCount: 0, log: [], lastActor: nil, lastSummary: nil, lastClaimedRouteId: nil,
              lastPublicDraw: [])
}

// 1. Deterministic newGame
check(Game.newGame(seed: 42) == Game.newGame(seed: 42), "newGame deterministic by seed")

// 2. 4-player deal + rotation 0->1->2->3->0
let four = Game.newGame(seed: 3, playerCount: 4)
check(four.players.count == 4 && four.playerIDs.count == 4 && four.playerNames.count == 4, "4 players dealt")
do {
    var s = four
    var rotated = true
    for i in 0..<4 { if s.currentPlayer != i { rotated = false }; s = try! Game.applyMove(s, .drawCards([.blind])) }
    check(rotated && s.currentPlayer == 0, "turns rotate 0->1->2->3->0")
}

// 3. Gray route claimable mostly with wilds
do {
    let s = mk(routes: [rt(0, 0, 1, 3, .gray)], players: [pl([.blue, .locomotive, .locomotive]), pl()], deck: [.red])
    check(Game.canClaim(s, s.routes[0], player: 0), "gray claimable with wilds")
    let n = try! Game.applyMove(s, .claim(routeId: 0, color: nil))
    check(n.routes[0].claimedBy == 0 && n.players[0].hand.isEmpty, "gray claim spends color+wilds")
}

// 4. Specific-color route claimable with only wilds
do {
    let s = mk(routes: [rt(0, 0, 1, 3, .red)], players: [pl([.locomotive, .locomotive, .locomotive]), pl()], deck: [.red])
    check(Game.canClaim(s, s.routes[0], player: 0), "specific color claimable with only wilds")
}

// 5. TTR scoring table + trains spent
do {
    let s = mk(routes: [rt(0, 0, 1, 4, .red)], players: [pl([.red, .red, .red, .red]), pl()], deck: [.blue])
    let n = try! Game.applyMove(s, .claim(routeId: 0, color: nil))
    check(n.players[0].score == 7 && n.players[0].trains == 41, "len-4 route = 7 pts, 4 trains")
}

// 6. Longest route through a branch
do {
    let s = mk(routes: [rt(0, 0, 1, 2, .red, 0), rt(1, 1, 2, 2, .red, 0), rt(2, 1, 3, 3, .red, 0)],
               players: [pl(), pl()])
    check(Scoring.longestRoute(s, 0) == 5, "longest trail through branch = 5")
}

// 7. Ticket scoring + tie
do {
    let s = mk(routes: [rt(0, 0, 1, 2, .red, 0), rt(1, 1, 2, 2, .red, 0)],
               players: [pl(tickets: [Ticket(id: 0, cityA: 0, cityB: 2, points: 10),
                                      Ticket(id: 1, cityA: 0, cityB: 3, points: 5)]), pl()])
    check(Scoring.ticketScore(s, 0) == 5, "ticket +10 connected, -5 not")
}
do {
    let s = mk(routes: [], players: [pl(score: 5), pl(score: 5)])
    check(Scoring.finalWinner(s) == nil, "equal totals = tie")
}

// 8. No leak: blind draws never reveal colors
do {
    let s = mk(routes: [rt(0, 0, 1, 2, .red)], players: [pl(), pl()],
               deck: [.yellow, .orange], market: [.red, .blue, .green, .white, .black])
    let n = try! Game.applyMove(s, .drawCards([.blind, .blind]))
    let sum = n.lastSummary ?? ""
    check(!sum.contains("yellow") && !sum.contains("orange"), "blind colors hidden in log")
    let m = try! Game.applyMove(s, .drawCards([.market(slot: 0)]))
    check((m.lastSummary ?? "").contains("red"), "face-up market pick is public")
}

print(failures == 0 ? "\nALL SWIFT ENGINE CHECKS PASSED" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
