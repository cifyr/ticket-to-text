import Foundation

// Multi-map registry. 1:1 port of src/map.ts — route/ticket order must match per
// map (verified by ios:enginecheck). x,y are display-only geographic positions;
// the engine only uses city indices.
struct City {
    let name: String
    let x: Double
    let y: Double
}

struct GameMapDef {
    let id: String
    let name: String
    let cities: [City]
    let routeDefs: [(Int, Int, Int, RoutePaint)]
    let ticketDefs: [(Int, Int, Int)]

    func routes() -> [Route] {
        routeDefs.enumerated().map { i, d in
            Route(id: i, cityA: d.0, cityB: d.1, length: d.2, color: d.3, claimedBy: nil)
        }
    }
    func tickets() -> [Ticket] {
        ticketDefs.enumerated().map { i, d in Ticket(id: i, cityA: d.0, cityB: d.1, points: d.2) }
    }
}

enum GameMap {
    static let defaultMapId = "usa"

    // x,y are real geographic positions (lon/lat, equal-area projected to a
    // normalized space where width=1 and height=mapAspect) so the city dots sit on
    // the actual US outline drawn behind them. Display-only; engine uses indices.
    private static let usaCities: [City] = [
        City(name: "Vancouver", x: 0.0272, y: 0.0389),
        City(name: "Calgary", x: 0.1839, y: 0),
        City(name: "Winnipeg", x: 0.4772, y: 0.0253),
        City(name: "Sault Ste Marie", x: 0.6992, y: 0.0997),
        City(name: "Montreal", x: 0.8856, y: 0.1221),
        City(name: "Toronto", x: 0.7849, y: 0.1628),
        City(name: "Boston", x: 0.9291, y: 0.1912),
        City(name: "New York", x: 0.8779, y: 0.2275),
        City(name: "Seattle", x: 0.0408, y: 0.0757),
        City(name: "Helena", x: 0.2191, y: 0.0981),
        City(name: "Duluth", x: 0.5645, y: 0.0937),
        City(name: "Portland", x: 0.0348, y: 0.1217),
        City(name: "Pittsburgh", x: 0.7742, y: 0.2335),
        City(name: "Washington", x: 0.8255, y: 0.2671),
        City(name: "Chicago", x: 0.642, y: 0.2018),
        City(name: "Omaha", x: 0.4982, y: 0.2154),
        City(name: "Salt Lake City", x: 0.2217, y: 0.2264),
        City(name: "San Francisco", x: 0.0393, y: 0.2922),
        City(name: "Denver", x: 0.3412, y: 0.2489),
        City(name: "Kansas City", x: 0.5216, y: 0.263),
        City(name: "Saint Louis", x: 0.5975, y: 0.2733),
        City(name: "Nashville", x: 0.6567, y: 0.3276),
        City(name: "Raleigh", x: 0.7977, y: 0.336),
        City(name: "Las Vegas", x: 0.1654, y: 0.3274),
        City(name: "Santa Fe", x: 0.3248, y: 0.338),
        City(name: "Oklahoma City", x: 0.4707, y: 0.3428),
        City(name: "Little Rock", x: 0.5613, y: 0.3589),
        City(name: "Atlanta", x: 0.6981, y: 0.3807),
        City(name: "Charleston", x: 0.7754, y: 0.402),
        City(name: "Los Angeles", x: 0.1117, y: 0.3741),
        City(name: "Phoenix", x: 0.2186, y: 0.3873),
        City(name: "El Paso", x: 0.3153, y: 0.4245),
        City(name: "Dallas", x: 0.4831, y: 0.402),
        City(name: "Houston", x: 0.5079, y: 0.4685),
        City(name: "New Orleans", x: 0.5997, y: 0.4643),
        City(name: "Miami", x: 0.7709, y: 0.5565),
    ]

    private static let usaRouteDefs: [(Int, Int, Int, RoutePaint)] = [
            (0, 8, 1, .red), (0, 1, 3, .gray), (1, 8, 4, .gray), (1, 9, 4, .gray), (1, 2, 6, .white),
            (8, 11, 1, .green), (8, 9, 6, .yellow), (11, 17, 5, .green), (11, 16, 6, .blue),
            (17, 16, 5, .orange), (17, 29, 3, .purple), (29, 23, 2, .gray), (29, 30, 3, .gray),
            (29, 31, 6, .black), (23, 16, 3, .orange), (16, 9, 3, .purple), (16, 18, 3, .red),
            (9, 18, 4, .green), (9, 2, 4, .blue), (9, 10, 6, .orange), (9, 15, 5, .red),
            (30, 18, 5, .white), (30, 24, 3, .gray), (30, 31, 3, .gray), (18, 24, 2, .gray),
            (18, 15, 4, .purple), (18, 19, 4, .black), (18, 25, 4, .red), (24, 31, 2, .gray),
            (24, 25, 3, .blue), (31, 32, 4, .red), (31, 33, 6, .green), (2, 10, 4, .gray),
            (2, 3, 6, .gray), (10, 15, 2, .orange), (10, 14, 3, .red), (10, 3, 3, .purple),
            (10, 5, 6, .purple), (15, 19, 1, .gray), (15, 14, 4, .blue), (19, 20, 2, .blue),
            (19, 25, 2, .blue), (25, 26, 2, .gray), (25, 32, 2, .gray), (32, 33, 1, .orange),
            (32, 26, 2, .gray), (33, 34, 2, .gray), (26, 20, 2, .gray), (26, 21, 3, .white),
            (26, 34, 3, .green), (20, 14, 2, .green), (20, 21, 2, .yellow), (14, 12, 3, .orange),
            (14, 5, 4, .white), (21, 27, 1, .gray), (21, 12, 4, .yellow), (21, 22, 3, .black),
            (34, 27, 4, .yellow), (34, 35, 6, .red), (27, 28, 2, .gray), (27, 22, 2, .gray),
            (27, 35, 5, .blue), (28, 22, 2, .gray), (28, 35, 4, .purple), (22, 12, 2, .gray),
            (22, 13, 2, .gray), (12, 5, 2, .gray), (12, 7, 2, .green), (12, 13, 2, .yellow),
            (13, 7, 2, .orange), (7, 6, 2, .yellow), (7, 4, 3, .blue), (6, 4, 2, .gray),
            (4, 5, 3, .gray), (4, 3, 5, .black), (3, 5, 2, .gray),
            // Double routes (mirror Ticket to Ride USA). Same order as src/map.ts so
            // route ids match the server. Only one of each pair is ever claimable.
            (0, 8, 1, .white), (8, 11, 1, .yellow), (11, 17, 5, .purple), (17, 16, 5, .white),
            (9, 18, 4, .red), (18, 15, 4, .white), (18, 19, 4, .orange), (10, 15, 2, .blue),
            (19, 20, 2, .purple), (19, 25, 2, .red), (20, 14, 2, .white), (14, 12, 3, .black),
            (7, 6, 2, .red), (13, 7, 2, .black), (32, 33, 1, .red), (34, 27, 4, .green),
    ]

    private static let usaTicketDefs: [(Int, Int, Int)] = [
            (8, 7, 22), (29, 35, 20), (17, 27, 17), (8, 33, 18), (18, 13, 11), (11, 6, 21),
            (30, 14, 12), (32, 7, 11), (16, 35, 16), (6, 35, 12), (14, 33, 9), (23, 27, 13),
            (0, 7, 20), (0, 34, 13), (29, 18, 7), (29, 14, 16), (1, 20, 8), (2, 33, 12),
            (4, 27, 9), (3, 25, 8), (11, 30, 11), (9, 22, 8), (18, 33, 4), (19, 28, 8),
            (10, 7, 14), (24, 34, 5), (16, 21, 6), (31, 4, 16), (12, 35, 7), (15, 22, 7),
    ]

    static let usa = GameMapDef(id: "usa", name: "USA", cities: usaCities,
                                routeDefs: usaRouteDefs, ticketDefs: usaTicketDefs)

    // ---- Europe (mirror of src/map.ts; route/ticket order must match) --------
    private static let europeCities: [City] = [
        City(name: "Lisbon", x: 0.00, y: 0.500), City(name: "Madrid", x: 0.126, y: 0.450),
        City(name: "Barcelona", x: 0.270, y: 0.390), City(name: "Brest", x: 0.144, y: 0.210),
        City(name: "Paris", x: 0.288, y: 0.240), City(name: "Marseille", x: 0.360, y: 0.360),
        City(name: "London", x: 0.216, y: 0.150), City(name: "Edinburgh", x: 0.162, y: 0.030),
        City(name: "Dublin", x: 0.054, y: 0.105), City(name: "Amsterdam", x: 0.342, y: 0.165),
        City(name: "Brussels", x: 0.306, y: 0.195), City(name: "Frankfurt", x: 0.414, y: 0.195),
        City(name: "Zurich", x: 0.396, y: 0.270), City(name: "Venice", x: 0.486, y: 0.315),
        City(name: "Rome", x: 0.540, y: 0.420), City(name: "Munich", x: 0.468, y: 0.240),
        City(name: "Berlin", x: 0.558, y: 0.150), City(name: "Copenhagen", x: 0.522, y: 0.075),
        City(name: "Stockholm", x: 0.648, y: 0.000), City(name: "Vienna", x: 0.612, y: 0.255),
        City(name: "Prague", x: 0.540, y: 0.195), City(name: "Warsaw", x: 0.702, y: 0.150),
        City(name: "Budapest", x: 0.666, y: 0.285), City(name: "Athens", x: 0.756, y: 0.495),
        City(name: "Bucharest", x: 0.846, y: 0.330), City(name: "Kyiv", x: 0.954, y: 0.195),
    ]
    private static let europeRouteDefs: [(Int, Int, Int, RoutePaint)] = [
        (0, 1, 3, .orange), (1, 2, 2, .yellow), (2, 5, 4, .green), (1, 3, 4, .black),
        (3, 4, 3, .gray), (4, 5, 4, .gray), (6, 3, 2, .red), (6, 7, 4, .gray),
        (7, 8, 2, .gray), (6, 9, 2, .yellow), (6, 4, 2, .white), (4, 10, 2, .yellow),
        (10, 9, 1, .blue), (10, 11, 2, .blue), (9, 11, 2, .red), (4, 12, 3, .purple),
        (11, 12, 2, .white), (11, 15, 2, .orange), (12, 15, 2, .yellow), (12, 13, 2, .green),
        (5, 12, 3, .gray), (5, 14, 4, .red), (13, 14, 2, .black), (13, 15, 2, .blue),
        (15, 16, 3, .gray), (15, 19, 2, .green), (16, 20, 2, .gray), (16, 11, 3, .black),
        (16, 17, 3, .red), (17, 18, 3, .yellow), (16, 21, 3, .gray), (20, 19, 2, .purple),
        (19, 22, 1, .orange), (22, 24, 4, .red), (21, 22, 3, .white), (21, 25, 4, .gray),
        (24, 25, 2, .white), (24, 23, 4, .purple), (22, 23, 5, .blue), (13, 19, 2, .gray),
    ]
    private static let europeTicketDefs: [(Int, Int, Int)] = [
        (0, 16, 21), (7, 14, 20), (8, 18, 22), (1, 15, 13), (6, 19, 12), (5, 25, 20),
        (2, 11, 8), (17, 23, 18), (21, 14, 12), (4, 24, 16), (9, 22, 10), (3, 13, 11),
    ]
    static let europe = GameMapDef(id: "europe", name: "Europe", cities: europeCities,
                                   routeDefs: europeRouteDefs, ticketDefs: europeTicketDefs)

    // ---- Additional boards (mirror src/map.ts; order must match) -------------
    static let germany = GameMapDef(id: "germany", name: "Germany", cities: [
        City(name: "Hamburg", x: 0.42, y: 0.06), City(name: "Bremen", x: 0.30, y: 0.10),
        City(name: "Hannover", x: 0.40, y: 0.16), City(name: "Berlin", x: 0.62, y: 0.12),
        City(name: "Dortmund", x: 0.20, y: 0.20), City(name: "Essen", x: 0.15, y: 0.19),
        City(name: "Cologne", x: 0.16, y: 0.25), City(name: "Frankfurt", x: 0.30, y: 0.30),
        City(name: "Leipzig", x: 0.58, y: 0.22), City(name: "Dresden", x: 0.70, y: 0.24),
        City(name: "Nuremberg", x: 0.50, y: 0.34), City(name: "Stuttgart", x: 0.33, y: 0.40),
        City(name: "Munich", x: 0.52, y: 0.45), City(name: "Kiel", x: 0.40, y: 0.00),
        City(name: "Rostock", x: 0.55, y: 0.03), City(name: "Mannheim", x: 0.27, y: 0.34),
    ], routeDefs: [
        (13, 0, 1, .gray), (14, 0, 2, .gray), (0, 1, 1, .red), (0, 2, 2, .blue),
        (14, 3, 3, .yellow), (1, 4, 3, .green), (2, 3, 3, .orange), (2, 4, 2, .gray),
        (4, 5, 1, .gray), (5, 6, 1, .yellow), (4, 7, 3, .white), (6, 7, 2, .blue),
        (2, 8, 3, .purple), (3, 8, 2, .red), (8, 9, 1, .gray), (8, 10, 3, .green),
        (7, 10, 2, .orange), (7, 15, 1, .gray), (15, 11, 1, .yellow), (11, 12, 3, .purple),
        (10, 12, 2, .blue), (9, 12, 4, .black), (11, 10, 2, .white),
    ], ticketDefs: [
        (13, 12, 18), (0, 9, 12), (5, 12, 15), (3, 11, 13), (1, 10, 11),
        (6, 9, 11), (14, 12, 17), (4, 8, 8), (7, 12, 9), (2, 9, 8),
    ])

    static let france = GameMapDef(id: "france", name: "France", cities: [
        City(name: "Brest", x: 0.04, y: 0.18), City(name: "Paris", x: 0.34, y: 0.16),
        City(name: "Lille", x: 0.40, y: 0.05), City(name: "Strasbourg", x: 0.66, y: 0.18),
        City(name: "Nantes", x: 0.18, y: 0.28), City(name: "Bordeaux", x: 0.20, y: 0.42),
        City(name: "Toulouse", x: 0.34, y: 0.48), City(name: "Marseille", x: 0.58, y: 0.46),
        City(name: "Nice", x: 0.70, y: 0.44), City(name: "Lyon", x: 0.54, y: 0.34),
        City(name: "Dijon", x: 0.54, y: 0.22), City(name: "Clermont", x: 0.44, y: 0.36),
        City(name: "Orleans", x: 0.34, y: 0.24), City(name: "Rennes", x: 0.16, y: 0.20),
        City(name: "Le Havre", x: 0.28, y: 0.10), City(name: "Montpellier", x: 0.46, y: 0.46),
    ], routeDefs: [
        (0, 13, 1, .gray), (13, 4, 1, .green), (13, 1, 3, .gray), (14, 1, 2, .blue),
        (2, 1, 2, .red), (1, 12, 1, .yellow), (1, 10, 3, .purple), (2, 3, 4, .orange),
        (10, 3, 2, .white), (12, 4, 2, .gray), (12, 11, 3, .blue), (4, 5, 3, .yellow),
        (5, 6, 2, .green), (6, 15, 2, .orange), (11, 9, 2, .red), (10, 9, 2, .gray),
        (9, 7, 3, .purple), (15, 7, 1, .blue), (7, 8, 1, .white), (11, 6, 3, .black),
        (9, 8, 4, .yellow), (5, 11, 3, .gray),
    ], ticketDefs: [
        (0, 8, 20), (2, 7, 15), (5, 3, 13), (4, 8, 16), (14, 6, 12),
        (1, 7, 11), (13, 3, 12), (0, 6, 14), (10, 8, 9), (12, 7, 10),
    ])

    static let uk = GameMapDef(id: "uk", name: "United Kingdom", cities: [
        City(name: "Inverness", x: 0.30, y: 0.02), City(name: "Aberdeen", x: 0.40, y: 0.06),
        City(name: "Glasgow", x: 0.28, y: 0.12), City(name: "Edinburgh", x: 0.38, y: 0.12),
        City(name: "Belfast", x: 0.14, y: 0.18), City(name: "Dublin", x: 0.10, y: 0.24),
        City(name: "Newcastle", x: 0.40, y: 0.18), City(name: "Manchester", x: 0.36, y: 0.26),
        City(name: "Liverpool", x: 0.30, y: 0.26), City(name: "Birmingham", x: 0.40, y: 0.32),
        City(name: "Cardiff", x: 0.30, y: 0.38), City(name: "Bristol", x: 0.38, y: 0.38),
        City(name: "London", x: 0.52, y: 0.36), City(name: "Southampton", x: 0.46, y: 0.42),
    ], routeDefs: [
        (0, 1, 2, .gray), (0, 2, 2, .green), (1, 3, 2, .blue), (2, 3, 1, .gray),
        (2, 4, 2, .yellow), (4, 5, 1, .gray), (3, 6, 2, .red), (6, 7, 2, .orange),
        (7, 8, 1, .gray), (5, 8, 3, .white), (7, 9, 1, .purple), (8, 9, 2, .yellow),
        (9, 10, 2, .green), (9, 12, 3, .red), (10, 11, 1, .gray), (11, 13, 2, .blue),
        (11, 12, 2, .orange), (12, 13, 1, .white), (6, 9, 3, .black),
    ], ticketDefs: [
        (0, 12, 20), (5, 12, 16), (1, 13, 18), (2, 10, 12), (4, 9, 11),
        (3, 12, 13), (0, 13, 22), (6, 11, 9), (7, 12, 8),
    ])

    static let switzerland = GameMapDef(id: "switzerland", name: "Switzerland", cities: [
        City(name: "Basel", x: 0.20, y: 0.10), City(name: "Zurich", x: 0.46, y: 0.10),
        City(name: "Bern", x: 0.26, y: 0.30), City(name: "Lucerne", x: 0.44, y: 0.24),
        City(name: "Geneva", x: 0.06, y: 0.46), City(name: "Lausanne", x: 0.12, y: 0.40),
        City(name: "Sion", x: 0.26, y: 0.46), City(name: "Interlaken", x: 0.34, y: 0.36),
        City(name: "Lugano", x: 0.58, y: 0.50), City(name: "Chur", x: 0.66, y: 0.26),
        City(name: "St Gallen", x: 0.62, y: 0.10), City(name: "Neuchatel", x: 0.18, y: 0.28),
    ], routeDefs: [
        (0, 1, 2, .gray), (0, 2, 2, .green), (1, 3, 1, .yellow), (1, 10, 2, .gray),
        (10, 9, 2, .blue), (3, 9, 3, .red), (2, 3, 2, .orange), (2, 11, 1, .gray),
        (11, 5, 1, .white), (5, 4, 1, .gray), (2, 7, 2, .purple), (7, 6, 2, .yellow),
        (6, 4, 3, .green), (7, 8, 3, .blue), (9, 8, 3, .black), (3, 8, 4, .white),
        (5, 6, 2, .red),
    ], ticketDefs: [
        (4, 10, 15), (0, 8, 14), (4, 9, 16), (5, 8, 13), (0, 4, 12),
        (1, 8, 11), (11, 9, 10), (2, 8, 9),
    ])

    static let nordic = GameMapDef(id: "nordic", name: "Nordic Countries", cities: [
        City(name: "Tromso", x: 0.40, y: 0.00), City(name: "Narvik", x: 0.46, y: 0.04),
        City(name: "Trondheim", x: 0.28, y: 0.16), City(name: "Bergen", x: 0.12, y: 0.30),
        City(name: "Oslo", x: 0.26, y: 0.34), City(name: "Stockholm", x: 0.46, y: 0.34),
        City(name: "Gothenburg", x: 0.32, y: 0.42), City(name: "Copenhagen", x: 0.34, y: 0.50),
        City(name: "Sundsvall", x: 0.46, y: 0.22), City(name: "Umea", x: 0.52, y: 0.16),
        City(name: "Helsinki", x: 0.66, y: 0.32), City(name: "Oulu", x: 0.64, y: 0.14),
        City(name: "Lahti", x: 0.64, y: 0.28), City(name: "Murmansk", x: 0.58, y: 0.00),
    ], routeDefs: [
        (0, 1, 1, .gray), (1, 13, 3, .white), (1, 2, 4, .gray), (2, 3, 2, .green),
        (2, 4, 3, .yellow), (3, 4, 2, .gray), (4, 6, 1, .red), (6, 7, 1, .gray),
        (4, 5, 3, .blue), (6, 5, 2, .orange), (2, 8, 3, .purple), (8, 5, 2, .white),
        (8, 9, 1, .gray), (9, 11, 3, .yellow), (11, 13, 4, .black), (11, 12, 2, .green),
        (12, 10, 1, .gray), (5, 10, 3, .red), (9, 12, 3, .blue),
    ], ticketDefs: [
        (7, 13, 22), (3, 10, 18), (0, 7, 20), (3, 5, 12), (4, 11, 14),
        (7, 10, 13), (2, 10, 15), (0, 5, 16), (6, 11, 12),
    ])

    static let india = GameMapDef(id: "india", name: "India", cities: [
        City(name: "Delhi", x: 0.34, y: 0.10), City(name: "Jaipur", x: 0.26, y: 0.16),
        City(name: "Ahmedabad", x: 0.16, y: 0.28), City(name: "Mumbai", x: 0.16, y: 0.40),
        City(name: "Pune", x: 0.20, y: 0.44), City(name: "Hyderabad", x: 0.34, y: 0.42),
        City(name: "Bangalore", x: 0.30, y: 0.52), City(name: "Chennai", x: 0.40, y: 0.52),
        City(name: "Kolkata", x: 0.62, y: 0.30), City(name: "Nagpur", x: 0.40, y: 0.32),
        City(name: "Bhopal", x: 0.34, y: 0.26), City(name: "Kanpur", x: 0.46, y: 0.20),
        City(name: "Patna", x: 0.56, y: 0.22), City(name: "Varanasi", x: 0.50, y: 0.24),
        City(name: "Amritsar", x: 0.28, y: 0.04), City(name: "Lucknow", x: 0.44, y: 0.18),
    ], routeDefs: [
        (14, 0, 2, .gray), (0, 1, 1, .green), (0, 15, 2, .yellow), (15, 11, 1, .gray),
        (11, 13, 2, .blue), (13, 12, 1, .gray), (12, 8, 3, .red), (1, 2, 3, .orange),
        (1, 10, 3, .white), (10, 9, 2, .purple), (10, 11, 3, .gray), (2, 3, 2, .red),
        (3, 4, 1, .gray), (4, 5, 2, .yellow), (9, 5, 2, .green), (9, 8, 4, .black),
        (5, 6, 2, .blue), (6, 7, 1, .gray), (5, 7, 3, .orange), (8, 7, 4, .white),
        (9, 13, 3, .yellow),
    ], ticketDefs: [
        (14, 7, 22), (3, 8, 18), (0, 6, 16), (2, 7, 17), (0, 8, 15),
        (3, 7, 13), (1, 12, 14), (4, 8, 16), (10, 7, 12), (14, 3, 13),
    ])

    static let africa = GameMapDef(id: "africa", name: "Africa", cities: [
        City(name: "Tangier", x: 0.20, y: 0.02), City(name: "Algiers", x: 0.34, y: 0.04),
        City(name: "Tunis", x: 0.44, y: 0.03), City(name: "Cairo", x: 0.66, y: 0.10),
        City(name: "Dakar", x: 0.02, y: 0.26), City(name: "Bamako", x: 0.16, y: 0.28),
        City(name: "Lagos", x: 0.34, y: 0.34), City(name: "Khartoum", x: 0.62, y: 0.24),
        City(name: "Addis Ababa", x: 0.74, y: 0.30), City(name: "Kinshasa", x: 0.46, y: 0.42),
        City(name: "Nairobi", x: 0.72, y: 0.42), City(name: "Luanda", x: 0.42, y: 0.48),
        City(name: "Dar es Salaam", x: 0.74, y: 0.48), City(name: "Lusaka", x: 0.60, y: 0.52),
        City(name: "Windhoek", x: 0.48, y: 0.60), City(name: "Johannesburg", x: 0.60, y: 0.64),
        City(name: "Cape Town", x: 0.50, y: 0.74),
    ], routeDefs: [
        (0, 1, 2, .gray), (1, 2, 1, .yellow), (2, 3, 5, .white), (0, 4, 4, .gray),
        (4, 5, 2, .green), (5, 6, 3, .orange), (1, 5, 4, .red), (6, 7, 5, .blue),
        (3, 7, 4, .gray), (7, 8, 2, .purple), (8, 10, 2, .green), (6, 9, 4, .yellow),
        (9, 10, 4, .red), (9, 11, 2, .gray), (10, 12, 1, .orange), (11, 13, 3, .white),
        (12, 13, 2, .blue), (13, 14, 3, .purple), (13, 15, 2, .black), (14, 16, 3, .gray),
        (15, 16, 3, .yellow), (11, 14, 3, .blue), (7, 8, 3, .gray),
    ], ticketDefs: [
        (0, 16, 22), (4, 12, 20), (3, 16, 21), (0, 10, 16), (5, 13, 15),
        (2, 8, 14), (6, 16, 18), (4, 15, 19), (3, 14, 17), (1, 11, 13),
    ])

    static let asia = GameMapDef(id: "asia", name: "Legendary Asia", cities: [
        City(name: "Tehran", x: 0.06, y: 0.16), City(name: "Karachi", x: 0.16, y: 0.30),
        City(name: "Delhi", x: 0.24, y: 0.26), City(name: "Kolkata", x: 0.36, y: 0.34),
        City(name: "Almaty", x: 0.26, y: 0.06), City(name: "Tashkent", x: 0.16, y: 0.12),
        City(name: "Novosibirsk", x: 0.40, y: 0.00), City(name: "Ulaanbaatar", x: 0.56, y: 0.06),
        City(name: "Beijing", x: 0.66, y: 0.16), City(name: "Lhasa", x: 0.44, y: 0.24),
        City(name: "Chengdu", x: 0.56, y: 0.24), City(name: "Shanghai", x: 0.76, y: 0.24),
        City(name: "Hong Kong", x: 0.68, y: 0.34), City(name: "Hanoi", x: 0.58, y: 0.36),
        City(name: "Bangkok", x: 0.54, y: 0.46), City(name: "Yangon", x: 0.46, y: 0.40),
        City(name: "Singapore", x: 0.58, y: 0.56), City(name: "Vladivostok", x: 0.84, y: 0.08),
    ], routeDefs: [
        (0, 1, 3, .gray), (0, 5, 3, .yellow), (5, 4, 2, .green), (4, 6, 4, .gray),
        (6, 7, 4, .white), (7, 8, 3, .red), (8, 17, 5, .black), (8, 11, 3, .blue),
        (1, 2, 2, .orange), (2, 3, 4, .gray), (2, 9, 3, .purple), (9, 10, 3, .gray),
        (10, 8, 3, .yellow), (10, 13, 4, .green), (3, 15, 2, .red), (15, 14, 2, .gray),
        (13, 14, 2, .orange), (13, 12, 2, .white), (12, 11, 3, .purple), (14, 16, 4, .blue),
        (9, 3, 3, .gray), (4, 9, 4, .blue), (11, 17, 4, .gray),
    ], ticketDefs: [
        (0, 16, 22), (17, 16, 20), (1, 11, 18), (4, 12, 16), (0, 8, 17),
        (3, 11, 13), (7, 16, 21), (5, 14, 19), (2, 16, 18), (6, 16, 22),
    ])

    static let netherlands = GameMapDef(id: "netherlands", name: "Netherlands", cities: [
        City(name: "Groningen", x: 0.62, y: 0.04), City(name: "Leeuwarden", x: 0.46, y: 0.04),
        City(name: "Zwolle", x: 0.58, y: 0.20), City(name: "Amsterdam", x: 0.34, y: 0.18),
        City(name: "Haarlem", x: 0.26, y: 0.18), City(name: "Den Haag", x: 0.18, y: 0.28),
        City(name: "Utrecht", x: 0.40, y: 0.26), City(name: "Rotterdam", x: 0.24, y: 0.32),
        City(name: "Arnhem", x: 0.60, y: 0.30), City(name: "Nijmegen", x: 0.58, y: 0.36),
        City(name: "Eindhoven", x: 0.50, y: 0.44), City(name: "Tilburg", x: 0.42, y: 0.44),
        City(name: "Breda", x: 0.34, y: 0.42), City(name: "Maastricht", x: 0.60, y: 0.56),
        City(name: "Enschede", x: 0.74, y: 0.24), City(name: "Den Bosch", x: 0.46, y: 0.38),
    ], routeDefs: [
        (1, 0, 2, .gray), (1, 3, 3, .yellow), (0, 2, 3, .green), (2, 14, 2, .gray),
        (3, 4, 1, .blue), (4, 5, 2, .gray), (3, 6, 1, .red), (6, 2, 2, .orange),
        (5, 7, 1, .gray), (7, 6, 2, .white), (6, 8, 2, .purple), (8, 14, 2, .gray),
        (8, 9, 1, .yellow), (9, 15, 1, .gray), (7, 12, 2, .green), (12, 11, 1, .gray),
        (11, 15, 1, .blue), (11, 10, 1, .orange), (10, 9, 1, .red), (10, 13, 3, .black),
        (15, 6, 2, .gray), (12, 10, 2, .white),
    ], ticketDefs: [
        (0, 13, 18), (1, 13, 20), (5, 14, 14), (4, 9, 11), (0, 10, 13),
        (5, 13, 16), (14, 13, 12), (3, 13, 13), (1, 10, 12), (7, 8, 8),
    ])

    static let italy = GameMapDef(id: "italy", name: "Italy", cities: [
        City(name: "Turin", x: 0.16, y: 0.14), City(name: "Milan", x: 0.26, y: 0.12),
        City(name: "Venice", x: 0.44, y: 0.14), City(name: "Genoa", x: 0.22, y: 0.22),
        City(name: "Bologna", x: 0.38, y: 0.22), City(name: "Florence", x: 0.40, y: 0.28),
        City(name: "Ancona", x: 0.50, y: 0.30), City(name: "Rome", x: 0.44, y: 0.40),
        City(name: "Pescara", x: 0.54, y: 0.38), City(name: "Naples", x: 0.56, y: 0.46),
        City(name: "Bari", x: 0.70, y: 0.46), City(name: "Taranto", x: 0.72, y: 0.52),
        City(name: "Reggio", x: 0.66, y: 0.62), City(name: "Palermo", x: 0.54, y: 0.66),
        City(name: "Cagliari", x: 0.24, y: 0.54), City(name: "Catania", x: 0.62, y: 0.70),
    ], routeDefs: [
        (0, 1, 1, .gray), (1, 2, 3, .yellow), (0, 3, 2, .green), (1, 4, 2, .gray),
        (2, 4, 2, .orange), (3, 5, 3, .red), (4, 5, 1, .gray), (5, 6, 2, .blue),
        (5, 7, 2, .white), (6, 8, 2, .gray), (7, 8, 2, .purple), (7, 9, 2, .gray),
        (8, 9, 2, .yellow), (9, 10, 3, .green), (10, 11, 1, .gray), (9, 12, 3, .red),
        (11, 12, 2, .blue), (12, 13, 2, .gray), (13, 15, 2, .orange), (7, 14, 4, .black),
        (14, 13, 4, .white), (3, 14, 5, .purple),
    ], ticketDefs: [
        (0, 15, 22), (2, 13, 20), (0, 13, 21), (1, 9, 13), (3, 11, 16),
        (4, 12, 15), (2, 9, 12), (14, 10, 14), (5, 15, 18), (0, 9, 14),
    ])

    static let japan = GameMapDef(id: "japan", name: "Japan", cities: [
        City(name: "Sapporo", x: 0.74, y: 0.04), City(name: "Hakodate", x: 0.68, y: 0.12),
        City(name: "Aomori", x: 0.64, y: 0.18), City(name: "Akita", x: 0.58, y: 0.22),
        City(name: "Sendai", x: 0.62, y: 0.28), City(name: "Niigata", x: 0.52, y: 0.28),
        City(name: "Tokyo", x: 0.58, y: 0.36), City(name: "Nagoya", x: 0.46, y: 0.38),
        City(name: "Kanazawa", x: 0.42, y: 0.30), City(name: "Kyoto", x: 0.40, y: 0.40),
        City(name: "Osaka", x: 0.36, y: 0.42), City(name: "Hiroshima", x: 0.22, y: 0.44),
        City(name: "Matsuyama", x: 0.24, y: 0.50), City(name: "Fukuoka", x: 0.12, y: 0.48),
        City(name: "Kagoshima", x: 0.10, y: 0.58), City(name: "Naha", x: 0.02, y: 0.72),
    ], routeDefs: [
        (0, 1, 2, .gray), (1, 2, 1, .yellow), (2, 3, 2, .green), (3, 4, 2, .gray),
        (2, 4, 3, .red), (3, 5, 2, .orange), (4, 6, 3, .blue), (5, 6, 2, .gray),
        (5, 8, 2, .white), (6, 7, 2, .purple), (7, 8, 1, .gray), (8, 9, 2, .yellow),
        (7, 9, 2, .gray), (9, 10, 1, .red), (10, 11, 3, .green), (11, 12, 1, .gray),
        (11, 13, 2, .blue), (12, 13, 2, .gray), (13, 14, 2, .orange), (14, 15, 4, .black),
        (10, 12, 2, .white), (6, 9, 3, .gray),
    ], ticketDefs: [
        (0, 15, 22), (0, 13, 20), (6, 15, 18), (2, 11, 14), (0, 6, 13),
        (4, 13, 16), (6, 13, 15), (1, 10, 13), (5, 14, 17), (0, 10, 16),
    ])

    static let poland = GameMapDef(id: "poland", name: "Poland", cities: [
        City(name: "Szczecin", x: 0.06, y: 0.12), City(name: "Gdansk", x: 0.40, y: 0.04),
        City(name: "Olsztyn", x: 0.52, y: 0.10), City(name: "Bialystok", x: 0.70, y: 0.14),
        City(name: "Poznan", x: 0.24, y: 0.24), City(name: "Bydgoszcz", x: 0.34, y: 0.16),
        City(name: "Warsaw", x: 0.56, y: 0.24), City(name: "Lodz", x: 0.44, y: 0.28),
        City(name: "Lublin", x: 0.66, y: 0.30), City(name: "Wroclaw", x: 0.28, y: 0.36),
        City(name: "Katowice", x: 0.42, y: 0.42), City(name: "Krakow", x: 0.50, y: 0.44),
        City(name: "Rzeszow", x: 0.64, y: 0.42), City(name: "Zielona Gora", x: 0.14, y: 0.30),
        City(name: "Opole", x: 0.12, y: 0.44), City(name: "Kielce", x: 0.56, y: 0.36),
    ], routeDefs: [
        (0, 5, 3, .gray), (0, 4, 2, .yellow), (1, 2, 2, .green), (2, 3, 3, .gray),
        (1, 5, 2, .red), (5, 4, 1, .gray), (2, 6, 2, .orange), (3, 6, 3, .blue),
        (4, 9, 2, .white), (5, 7, 2, .gray), (6, 7, 1, .purple), (6, 8, 2, .gray),
        (7, 10, 2, .yellow), (9, 10, 2, .gray), (10, 11, 1, .red), (11, 12, 2, .green),
        (8, 12, 2, .gray), (13, 9, 1, .blue), (0, 13, 3, .gray), (13, 14, 2, .orange),
        (14, 9, 1, .gray), (11, 15, 1, .white), (15, 8, 2, .gray),
    ], ticketDefs: [
        (0, 12, 20), (1, 11, 14), (3, 14, 18), (0, 3, 16), (4, 12, 13),
        (13, 8, 15), (1, 12, 16), (9, 8, 11), (2, 11, 12), (0, 8, 17),
    ])

    static let pennsylvania = GameMapDef(id: "pennsylvania", name: "Pennsylvania", cities: [
        City(name: "Erie", x: 0.06, y: 0.06), City(name: "Pittsburgh", x: 0.10, y: 0.30),
        City(name: "Johnstown", x: 0.20, y: 0.32), City(name: "Altoona", x: 0.28, y: 0.28),
        City(name: "State College", x: 0.34, y: 0.24), City(name: "Williamsport", x: 0.44, y: 0.18),
        City(name: "Scranton", x: 0.62, y: 0.14), City(name: "Wilkes-Barre", x: 0.60, y: 0.20),
        City(name: "Allentown", x: 0.66, y: 0.30), City(name: "Reading", x: 0.58, y: 0.34),
        City(name: "Harrisburg", x: 0.48, y: 0.32), City(name: "Lancaster", x: 0.56, y: 0.40),
        City(name: "Philadelphia", x: 0.72, y: 0.40), City(name: "York", x: 0.50, y: 0.42),
        City(name: "Bradford", x: 0.30, y: 0.06), City(name: "Pottsville", x: 0.56, y: 0.26),
    ], routeDefs: [
        (0, 14, 3, .gray), (14, 4, 3, .green), (0, 1, 4, .yellow), (1, 2, 1, .gray),
        (2, 3, 1, .red), (3, 4, 1, .gray), (4, 5, 2, .blue), (5, 6, 3, .orange),
        (6, 7, 1, .gray), (7, 8, 2, .white), (8, 12, 2, .purple), (8, 9, 1, .gray),
        (9, 15, 1, .green), (5, 15, 2, .gray), (15, 10, 2, .yellow), (4, 10, 3, .red),
        (10, 13, 1, .gray), (10, 11, 1, .blue), (11, 13, 1, .gray), (11, 12, 2, .orange),
        (9, 11, 1, .white), (1, 3, 3, .black),
    ], ticketDefs: [
        (0, 12, 20), (1, 12, 18), (1, 6, 12), (14, 8, 13), (0, 8, 16),
        (2, 12, 15), (4, 12, 12), (1, 8, 14), (6, 13, 9), (0, 10, 13),
    ])

    static let oldwest = GameMapDef(id: "oldwest", name: "Old West", cities: [
        City(name: "Seattle", x: 0.10, y: 0.04), City(name: "Portland", x: 0.06, y: 0.12),
        City(name: "San Francisco", x: 0.02, y: 0.34), City(name: "Los Angeles", x: 0.10, y: 0.46),
        City(name: "Sacramento", x: 0.06, y: 0.28), City(name: "Salt Lake City", x: 0.30, y: 0.26),
        City(name: "Helena", x: 0.34, y: 0.08), City(name: "Denver", x: 0.44, y: 0.30),
        City(name: "Santa Fe", x: 0.46, y: 0.42), City(name: "El Paso", x: 0.48, y: 0.52),
        City(name: "Tucson", x: 0.30, y: 0.50), City(name: "Phoenix", x: 0.24, y: 0.46),
        City(name: "Dodge City", x: 0.60, y: 0.34), City(name: "Bismarck", x: 0.58, y: 0.08),
        City(name: "Omaha", x: 0.68, y: 0.26), City(name: "San Antonio", x: 0.62, y: 0.56),
    ], routeDefs: [
        (0, 1, 1, .gray), (1, 4, 3, .green), (4, 2, 1, .gray), (2, 3, 4, .yellow),
        (4, 5, 4, .red), (0, 6, 4, .gray), (6, 5, 3, .blue), (6, 13, 4, .orange),
        (5, 7, 3, .white), (7, 6, 4, .purple), (3, 11, 3, .gray), (11, 10, 1, .gray),
        (11, 5, 5, .black), (10, 9, 2, .yellow), (9, 8, 2, .gray), (8, 7, 2, .green),
        (7, 12, 2, .red), (12, 14, 2, .gray), (13, 14, 3, .blue), (12, 15, 4, .orange),
        (9, 15, 4, .white), (8, 12, 3, .gray), (7, 14, 4, .purple),
    ], ticketDefs: [
        (0, 15, 22), (2, 14, 20), (1, 9, 18), (3, 13, 21), (0, 7, 14),
        (2, 8, 16), (3, 14, 19), (6, 15, 17), (4, 12, 15), (11, 14, 13),
    ])

    static let world = GameMapDef(id: "world", name: "Rails & Sails: World", cities: [
        City(name: "New York", x: 0.26, y: 0.24), City(name: "Los Angeles", x: 0.10, y: 0.30),
        City(name: "Vancouver", x: 0.10, y: 0.18), City(name: "Lima", x: 0.26, y: 0.56),
        City(name: "Buenos Aires", x: 0.32, y: 0.70), City(name: "London", x: 0.46, y: 0.16),
        City(name: "Lisbon", x: 0.42, y: 0.26), City(name: "Cairo", x: 0.56, y: 0.32),
        City(name: "Lagos", x: 0.48, y: 0.44), City(name: "Cape Town", x: 0.54, y: 0.66),
        City(name: "Moscow", x: 0.60, y: 0.12), City(name: "Mumbai", x: 0.70, y: 0.36),
        City(name: "Beijing", x: 0.82, y: 0.20), City(name: "Tokyo", x: 0.92, y: 0.24),
        City(name: "Singapore", x: 0.82, y: 0.46), City(name: "Sydney", x: 0.94, y: 0.66),
        City(name: "Honolulu", x: 0.04, y: 0.36), City(name: "Panama", x: 0.22, y: 0.42),
    ], routeDefs: [
        (2, 0, 4, .gray), (2, 1, 3, .green), (1, 16, 5, .blue), (1, 17, 3, .gray),
        (0, 17, 3, .yellow), (17, 3, 3, .red), (3, 4, 4, .gray), (0, 5, 5, .white),
        (5, 6, 2, .gray), (5, 10, 4, .orange), (6, 8, 4, .purple), (6, 4, 6, .gray),
        (7, 5, 4, .blue), (7, 10, 3, .gray), (7, 8, 3, .yellow), (8, 9, 3, .red),
        (7, 11, 3, .green), (10, 12, 5, .gray), (11, 12, 4, .white), (11, 14, 3, .orange),
        (12, 13, 2, .gray), (12, 14, 4, .purple), (14, 15, 4, .blue), (13, 15, 6, .black),
        (9, 15, 6, .gray), (13, 16, 6, .red),
    ], ticketDefs: [
        (0, 15, 22), (1, 13, 20), (5, 15, 21), (4, 12, 22), (16, 10, 18),
        (3, 11, 20), (9, 13, 21), (2, 14, 19), (0, 11, 16), (6, 15, 22),
    ])

    static let greatlakes = GameMapDef(id: "greatlakes", name: "Rails & Sails: Great Lakes", cities: [
        City(name: "Duluth", x: 0.12, y: 0.18), City(name: "Thunder Bay", x: 0.18, y: 0.06),
        City(name: "Sault Ste Marie", x: 0.46, y: 0.14), City(name: "Marquette", x: 0.34, y: 0.16),
        City(name: "Green Bay", x: 0.34, y: 0.30), City(name: "Milwaukee", x: 0.38, y: 0.40),
        City(name: "Chicago", x: 0.34, y: 0.46), City(name: "Detroit", x: 0.60, y: 0.40),
        City(name: "Toledo", x: 0.58, y: 0.46), City(name: "Cleveland", x: 0.66, y: 0.42),
        City(name: "Buffalo", x: 0.80, y: 0.36), City(name: "Toronto", x: 0.74, y: 0.28),
        City(name: "Ottawa", x: 0.86, y: 0.18), City(name: "Montreal", x: 0.92, y: 0.16),
        City(name: "Erie", x: 0.72, y: 0.42), City(name: "Georgian Bay", x: 0.58, y: 0.24),
    ], routeDefs: [
        (1, 0, 2, .gray), (1, 3, 3, .green), (0, 4, 3, .gray), (3, 2, 2, .yellow),
        (3, 4, 2, .gray), (4, 5, 1, .red), (5, 6, 1, .gray), (4, 6, 2, .blue),
        (2, 15, 2, .gray), (15, 11, 2, .orange), (6, 7, 3, .white), (7, 8, 1, .gray),
        (8, 9, 1, .purple), (7, 11, 2, .gray), (9, 14, 1, .gray), (14, 10, 1, .yellow),
        (10, 11, 2, .gray), (11, 12, 3, .green), (12, 13, 1, .gray), (10, 12, 3, .blue),
        (15, 7, 2, .red), (9, 10, 2, .white),
    ], ticketDefs: [
        (1, 13, 22), (0, 13, 20), (6, 13, 18), (0, 10, 15), (6, 10, 12),
        (1, 7, 13), (4, 9, 11), (2, 13, 14), (6, 11, 9), (0, 7, 12),
    ])

    static let newyork = GameMapDef(id: "newyork", name: "New York", cities: [
        City(name: "Inwood", x: 0.36, y: 0.02), City(name: "Harlem", x: 0.40, y: 0.12),
        City(name: "Upper West Side", x: 0.30, y: 0.22), City(name: "Upper East Side", x: 0.48, y: 0.22),
        City(name: "Midtown", x: 0.38, y: 0.34), City(name: "Chelsea", x: 0.28, y: 0.40),
        City(name: "Greenwich Village", x: 0.36, y: 0.46), City(name: "SoHo", x: 0.34, y: 0.54),
        City(name: "Lower Manhattan", x: 0.40, y: 0.64), City(name: "Brooklyn", x: 0.56, y: 0.66),
        City(name: "Queens", x: 0.64, y: 0.44), City(name: "Bronx", x: 0.56, y: 0.10),
    ], routeDefs: [
        (0, 11, 1, .gray), (0, 1, 1, .green), (1, 11, 1, .yellow), (1, 2, 1, .gray),
        (1, 3, 1, .red), (2, 4, 1, .gray), (3, 4, 1, .blue), (3, 10, 2, .orange),
        (4, 5, 1, .gray), (4, 10, 2, .white), (5, 6, 1, .purple), (6, 7, 1, .gray),
        (7, 8, 1, .yellow), (8, 9, 1, .gray), (9, 10, 2, .green), (6, 4, 1, .gray),
        (8, 10, 2, .red),
    ], ticketDefs: [
        (0, 9, 12), (11, 8, 10), (2, 10, 8), (5, 9, 9), (0, 8, 11),
        (3, 7, 7), (11, 9, 12), (1, 8, 9),
    ])

    static let london = GameMapDef(id: "london", name: "London", cities: [
        City(name: "Camden", x: 0.36, y: 0.16), City(name: "Islington", x: 0.50, y: 0.18),
        City(name: "Paddington", x: 0.26, y: 0.30), City(name: "Westminster", x: 0.36, y: 0.36),
        City(name: "City", x: 0.52, y: 0.34), City(name: "Shoreditch", x: 0.58, y: 0.26),
        City(name: "Kensington", x: 0.22, y: 0.42), City(name: "Southwark", x: 0.46, y: 0.44),
        City(name: "Greenwich", x: 0.66, y: 0.46), City(name: "Brixton", x: 0.42, y: 0.56),
    ], routeDefs: [
        (0, 1, 1, .gray), (0, 2, 2, .green), (1, 5, 1, .yellow), (2, 3, 2, .gray),
        (0, 3, 1, .red), (3, 4, 1, .blue), (1, 4, 1, .gray), (4, 5, 1, .orange),
        (2, 6, 1, .gray), (3, 7, 1, .white), (4, 7, 1, .gray), (5, 8, 3, .purple),
        (7, 8, 2, .gray), (7, 9, 1, .yellow), (6, 9, 2, .gray), (3, 9, 2, .green),
    ], ticketDefs: [
        (6, 8, 12), (2, 8, 11), (0, 9, 8), (6, 5, 10), (2, 9, 9), (0, 8, 12), (6, 4, 8),
    ])

    static let paris = GameMapDef(id: "paris", name: "Paris", cities: [
        City(name: "Montmartre", x: 0.40, y: 0.12), City(name: "La Villette", x: 0.56, y: 0.14),
        City(name: "Champs-Elysees", x: 0.28, y: 0.26), City(name: "Louvre", x: 0.42, y: 0.28),
        City(name: "Bastille", x: 0.56, y: 0.30), City(name: "Eiffel Tower", x: 0.24, y: 0.38),
        City(name: "Latin Quarter", x: 0.44, y: 0.40), City(name: "Bercy", x: 0.58, y: 0.42),
        City(name: "Montparnasse", x: 0.34, y: 0.46), City(name: "Place d'Italie", x: 0.48, y: 0.52),
    ], routeDefs: [
        (0, 2, 2, .gray), (0, 3, 1, .green), (0, 1, 1, .yellow), (1, 4, 1, .gray),
        (2, 3, 1, .red), (3, 4, 1, .blue), (2, 5, 2, .gray), (3, 6, 1, .orange),
        (4, 7, 1, .gray), (5, 8, 2, .white), (6, 8, 1, .gray), (6, 9, 1, .purple),
        (7, 9, 1, .gray), (6, 7, 1, .yellow), (5, 6, 2, .gray), (8, 9, 1, .green),
    ], ticketDefs: [
        (0, 9, 10), (5, 7, 11), (2, 7, 9), (0, 8, 8), (1, 8, 10), (5, 9, 9), (2, 4, 7),
    ])

    static let amsterdam = GameMapDef(id: "amsterdam", name: "Amsterdam", cities: [
        City(name: "Centraal", x: 0.40, y: 0.10), City(name: "Jordaan", x: 0.30, y: 0.20),
        City(name: "Dam", x: 0.42, y: 0.22), City(name: "Plantage", x: 0.56, y: 0.24),
        City(name: "Museumplein", x: 0.34, y: 0.34), City(name: "De Pijp", x: 0.44, y: 0.38),
        City(name: "Oost", x: 0.60, y: 0.36), City(name: "Vondelpark", x: 0.26, y: 0.36),
        City(name: "Zuid", x: 0.40, y: 0.48), City(name: "Oud-West", x: 0.28, y: 0.28),
    ], routeDefs: [
        (0, 1, 1, .gray), (0, 2, 1, .green), (0, 3, 2, .yellow), (1, 9, 1, .gray),
        (2, 3, 1, .red), (2, 4, 2, .blue), (9, 4, 1, .gray), (4, 7, 1, .orange),
        (4, 5, 1, .gray), (3, 6, 1, .white), (5, 6, 2, .gray), (5, 8, 1, .purple),
        (7, 8, 2, .gray), (6, 8, 2, .yellow), (1, 4, 1, .gray), (2, 5, 1, .green),
    ], ticketDefs: [
        (0, 8, 10), (1, 6, 9), (7, 3, 10), (9, 8, 8), (0, 6, 9), (7, 6, 11), (1, 8, 8),
    ])

    static let berlin = GameMapDef(id: "berlin", name: "Berlin", cities: [
        City(name: "Spandau", x: 0.10, y: 0.24), City(name: "Charlottenburg", x: 0.26, y: 0.28),
        City(name: "Mitte", x: 0.44, y: 0.26), City(name: "Prenzlauer Berg", x: 0.52, y: 0.20),
        City(name: "Friedrichshain", x: 0.58, y: 0.30), City(name: "Kreuzberg", x: 0.48, y: 0.36),
        City(name: "Neukolln", x: 0.52, y: 0.46), City(name: "Tempelhof", x: 0.40, y: 0.44),
        City(name: "Schoneberg", x: 0.32, y: 0.40), City(name: "Lichtenberg", x: 0.66, y: 0.24),
    ], routeDefs: [
        (0, 1, 2, .gray), (1, 2, 2, .green), (1, 8, 2, .yellow), (2, 3, 1, .gray),
        (2, 5, 1, .red), (3, 4, 1, .blue), (3, 9, 1, .gray), (4, 9, 1, .orange),
        (4, 5, 1, .gray), (5, 6, 1, .white), (5, 7, 1, .gray), (7, 8, 1, .purple),
        (6, 7, 1, .gray), (8, 1, 1, .yellow), (2, 4, 1, .gray), (6, 9, 2, .green),
    ], ticketDefs: [
        (0, 9, 12), (0, 6, 10), (8, 4, 9), (1, 9, 8), (0, 4, 10), (8, 9, 9), (1, 6, 8),
    ])

    static let sanfrancisco = GameMapDef(id: "sanfrancisco", name: "San Francisco", cities: [
        City(name: "Marina", x: 0.30, y: 0.10), City(name: "North Beach", x: 0.46, y: 0.12),
        City(name: "Richmond", x: 0.14, y: 0.22), City(name: "Nob Hill", x: 0.42, y: 0.22),
        City(name: "Financial District", x: 0.54, y: 0.22), City(name: "Haight", x: 0.30, y: 0.32),
        City(name: "Mission", x: 0.46, y: 0.38), City(name: "Castro", x: 0.34, y: 0.40),
        City(name: "Sunset", x: 0.18, y: 0.40), City(name: "Bayview", x: 0.56, y: 0.50),
    ], routeDefs: [
        (0, 1, 1, .gray), (0, 3, 1, .green), (1, 4, 1, .yellow), (1, 3, 1, .gray),
        (3, 4, 1, .red), (2, 0, 2, .blue), (2, 5, 2, .gray), (3, 5, 1, .orange),
        (4, 6, 1, .gray), (5, 7, 1, .white), (5, 8, 1, .gray), (7, 8, 2, .purple),
        (6, 7, 1, .gray), (6, 9, 1, .yellow), (4, 9, 2, .gray), (7, 9, 2, .green),
    ], ticketDefs: [
        (2, 9, 11), (8, 4, 10), (0, 9, 9), (2, 4, 8), (8, 1, 9), (0, 6, 8), (2, 6, 10),
    ])

    // The registry. New maps are added here (and mirrored in src/map.ts).
    static let maps: [String: GameMapDef] = [
        usa.id: usa, europe.id: europe, germany.id: germany, france.id: france,
        uk.id: uk, switzerland.id: switzerland, nordic.id: nordic, india.id: india,
        africa.id: africa, asia.id: asia, netherlands.id: netherlands, italy.id: italy,
        japan.id: japan, poland.id: poland, pennsylvania.id: pennsylvania, oldwest.id: oldwest,
        world.id: world, greatlakes.id: greatlakes, newyork.id: newyork, london.id: london,
        paris.id: paris, amsterdam.id: amsterdam, berlin.id: berlin, sanfrancisco.id: sanfrancisco,
    ]
    static var all: [GameMapDef] {
        [usa, europe, germany, france, uk, switzerland, nordic, india,
         africa, asia, netherlands, italy, japan, poland, pennsylvania, oldwest,
         world, greatlakes, newyork, london, paris, amsterdam, berlin, sanfrancisco]
    }

    static func def(_ mapId: String) -> GameMapDef { maps[mapId] ?? usa }
    static func cities(_ mapId: String) -> [City] { def(mapId).cities }
    static func name(_ mapId: String) -> String { def(mapId).name }
    static func routes(_ mapId: String) -> [Route] { def(mapId).routes() }
    static func ticketDeck(_ mapId: String) -> [Ticket] { def(mapId).tickets() }

    static func label(_ route: Route, _ mapId: String) -> String {
        let c = cities(mapId)
        return "\(c[route.cityA].name) → \(c[route.cityB].name)"
    }
    static func ticketLabel(_ t: Ticket, _ mapId: String) -> String {
        let c = cities(mapId)
        return "\(c[t.cityA].name) → \(c[t.cityB].name)"
    }
}
