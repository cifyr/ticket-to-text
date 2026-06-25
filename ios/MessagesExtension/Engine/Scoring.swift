import Foundation

// 1:1 port of src/scoring.ts. TTR point table, ticket connectivity, longest route.
struct FinalScore: Codable, Equatable {
    var routeScore: Int
    var ticketScore: Int
    var longestRoute: Int
    var longestBonus: Int
    var total: Int
}

enum Scoring {
    static let longestRouteBonus = 10
    private static let routeTable: [Int: Int] = [1: 1, 2: 2, 3: 4, 4: 7, 5: 10, 6: 15]

    static func routePoints(_ length: Int) -> Int { routeTable[length] ?? length }

    private static func playerRoutes(_ state: GameState, _ player: Int) -> [Route] {
        state.routes.filter { $0.claimedBy == player }
    }

    private static func adjacency(_ routes: [Route]) -> [Int: [(to: Int, route: Route)]] {
        var adj: [Int: [(to: Int, route: Route)]] = [:]
        for r in routes {
            adj[r.cityA, default: []].append((r.cityB, r))
            adj[r.cityB, default: []].append((r.cityA, r))
        }
        return adj
    }

    static func connected(_ routes: [Route], from: Int, to: Int) -> Bool {
        if from == to { return true }
        let adj = adjacency(routes)
        var seen: Set<Int> = [from]
        var stack = [from]
        while let city = stack.popLast() {
            for (next, _) in adj[city] ?? [] {
                if next == to { return true }
                if !seen.contains(next) { seen.insert(next); stack.append(next) }
            }
        }
        return false
    }

    static func ticketScore(_ state: GameState, _ player: Int) -> Int {
        let routes = playerRoutes(state, player)
        return state.players[player].tickets.reduce(0) { sum, t in
            sum + (connected(routes, from: t.cityA, to: t.cityB) ? t.points : -t.points)
        }
    }

    static func longestRoute(_ state: GameState, _ player: Int) -> Int {
        let adj = adjacency(playerRoutes(state, player))
        var best = 0
        var used: Set<Int> = []
        func dfs(_ city: Int, _ total: Int) {
            if total > best { best = total }
            for (to, route) in adj[city] ?? [] where !used.contains(route.id) {
                used.insert(route.id)
                dfs(to, total + route.length)
                used.remove(route.id)
            }
        }
        for city in adj.keys { dfs(city, 0) }
        return best
    }

    static func finalScores(_ state: GameState) -> [FinalScore] {
        let longest = state.players.indices.map { longestRoute(state, $0) }
        let maxLongest = longest.max() ?? 0
        let uniqueMax = longest.filter { $0 == maxLongest }.count == 1
        return state.players.indices.map { p in
            let routeScore = state.players[p].score
            let tScore = ticketScore(state, p)
            let bonus = (uniqueMax && longest[p] == maxLongest) ? longestRouteBonus : 0
            return FinalScore(routeScore: routeScore, ticketScore: tScore,
                              longestRoute: longest[p], longestBonus: bonus,
                              total: routeScore + tScore + bonus)
        }
    }

    static func finalWinner(_ state: GameState) -> Int? {
        let scores = finalScores(state)
        let maxTotal = scores.map(\.total).max() ?? 0
        let leaders = scores.indices.filter { scores[$0].total == maxTotal }
        return leaders.count == 1 ? leaders[0] : nil
    }
}
