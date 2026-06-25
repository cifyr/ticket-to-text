import Foundation

// Full-scale US/Canada map: 36 cities, ~78 route segments. 1:1 port of src/map.ts.
struct City {
    let name: String
    let x: Double
    let y: Double
}

enum GameMap {
    static let cities: [City] = [
        City(name: "Vancouver", x: 0.06, y: 0.07),
        City(name: "Calgary", x: 0.17, y: 0.05),
        City(name: "Winnipeg", x: 0.41, y: 0.06),
        City(name: "Sault Ste Marie", x: 0.62, y: 0.14),
        City(name: "Montreal", x: 0.83, y: 0.10),
        City(name: "Toronto", x: 0.74, y: 0.17),
        City(name: "Boston", x: 0.94, y: 0.17),
        City(name: "New York", x: 0.88, y: 0.23),
        City(name: "Seattle", x: 0.07, y: 0.14),
        City(name: "Helena", x: 0.25, y: 0.18),
        City(name: "Duluth", x: 0.47, y: 0.17),
        City(name: "Portland", x: 0.06, y: 0.21),
        City(name: "Pittsburgh", x: 0.77, y: 0.25),
        City(name: "Washington", x: 0.86, y: 0.29),
        City(name: "Chicago", x: 0.59, y: 0.23),
        City(name: "Omaha", x: 0.46, y: 0.28),
        City(name: "Salt Lake City", x: 0.21, y: 0.31),
        City(name: "San Francisco", x: 0.04, y: 0.41),
        City(name: "Denver", x: 0.31, y: 0.35),
        City(name: "Kansas City", x: 0.48, y: 0.35),
        City(name: "Saint Louis", x: 0.56, y: 0.34),
        City(name: "Nashville", x: 0.63, y: 0.39),
        City(name: "Raleigh", x: 0.80, y: 0.37),
        City(name: "Las Vegas", x: 0.15, y: 0.43),
        City(name: "Santa Fe", x: 0.31, y: 0.45),
        City(name: "Oklahoma City", x: 0.46, y: 0.45),
        City(name: "Little Rock", x: 0.55, y: 0.45),
        City(name: "Atlanta", x: 0.71, y: 0.45),
        City(name: "Charleston", x: 0.83, y: 0.45),
        City(name: "Los Angeles", x: 0.10, y: 0.51),
        City(name: "Phoenix", x: 0.22, y: 0.53),
        City(name: "El Paso", x: 0.34, y: 0.55),
        City(name: "Dallas", x: 0.49, y: 0.53),
        City(name: "Houston", x: 0.51, y: 0.61),
        City(name: "New Orleans", x: 0.61, y: 0.59),
        City(name: "Miami", x: 0.85, y: 0.67),
    ]

    static var cityNames: [String] { cities.map(\.name) }

    static func routes() -> [Route] {
        let defs: [(Int, Int, Int, RoutePaint)] = [
            (0, 8, 1, .gray), (0, 1, 3, .gray), (1, 8, 4, .gray), (1, 9, 4, .gray), (1, 2, 6, .white),
            (8, 11, 1, .gray), (8, 9, 6, .yellow), (11, 17, 5, .green), (11, 16, 6, .blue),
            (17, 16, 5, .orange), (17, 29, 3, .purple), (29, 23, 2, .gray), (29, 30, 3, .gray),
            (29, 31, 6, .black), (23, 16, 3, .orange), (16, 9, 3, .purple), (16, 18, 3, .red),
            (9, 18, 4, .green), (9, 2, 4, .blue), (9, 10, 6, .orange), (9, 15, 5, .red),
            (30, 18, 5, .white), (30, 24, 3, .gray), (30, 31, 3, .gray), (18, 24, 2, .gray),
            (18, 15, 4, .purple), (18, 19, 4, .black), (18, 25, 4, .red), (24, 31, 2, .gray),
            (24, 25, 3, .blue), (31, 32, 4, .red), (31, 33, 6, .green), (2, 10, 4, .gray),
            (2, 3, 6, .gray), (10, 15, 2, .gray), (10, 14, 3, .red), (10, 3, 3, .purple),
            (10, 5, 6, .purple), (15, 19, 1, .gray), (15, 14, 4, .blue), (19, 20, 2, .blue),
            (19, 25, 2, .gray), (25, 26, 2, .gray), (25, 32, 2, .gray), (32, 33, 1, .gray),
            (32, 26, 2, .gray), (33, 34, 2, .gray), (26, 20, 2, .gray), (26, 21, 3, .white),
            (26, 34, 3, .green), (20, 14, 2, .green), (20, 21, 2, .yellow), (14, 12, 3, .orange),
            (14, 5, 4, .white), (21, 27, 1, .gray), (21, 12, 4, .yellow), (21, 22, 3, .black),
            (34, 27, 4, .yellow), (34, 35, 6, .red), (27, 28, 2, .gray), (27, 22, 2, .gray),
            (27, 35, 5, .blue), (28, 22, 2, .gray), (28, 35, 4, .purple), (22, 12, 2, .gray),
            (22, 13, 2, .gray), (12, 5, 2, .gray), (12, 7, 2, .green), (12, 13, 2, .yellow),
            (13, 7, 2, .orange), (7, 6, 2, .yellow), (7, 4, 3, .blue), (6, 4, 2, .gray),
            (4, 5, 3, .gray), (4, 3, 5, .black), (3, 5, 2, .gray),
        ]
        return defs.enumerated().map { i, d in
            Route(id: i, cityA: d.0, cityB: d.1, length: d.2, color: d.3, claimedBy: nil)
        }
    }

    static func ticketDeck() -> [Ticket] {
        let defs: [(Int, Int, Int)] = [
            (8, 7, 22), (29, 35, 20), (17, 27, 17), (8, 33, 18), (18, 13, 11), (11, 6, 21),
            (30, 14, 12), (32, 7, 11), (16, 35, 16), (6, 35, 12), (14, 33, 9), (23, 27, 13),
            (0, 7, 20), (0, 34, 13), (29, 18, 7), (29, 14, 16), (1, 20, 8), (2, 33, 12),
            (4, 27, 9), (3, 25, 8), (11, 30, 11), (9, 22, 8), (18, 33, 4), (19, 28, 8),
            (10, 7, 14), (24, 34, 5), (16, 21, 6), (31, 4, 16), (12, 35, 7), (15, 22, 7),
        ]
        return defs.enumerated().map { i, d in
            Ticket(id: i, cityA: d.0, cityB: d.1, points: d.2)
        }
    }

    static func label(_ route: Route) -> String {
        "\(cities[route.cityA].name) → \(cities[route.cityB].name)"
    }

    static func ticketLabel(_ t: Ticket) -> String {
        "\(cities[t.cityA].name) → \(cities[t.cityB].name)"
    }
}
