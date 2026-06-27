import type { RoutePaint, Route, Ticket } from "./types.ts";

// Multi-map registry. Each GameMapDef is one playable board: its cities, route
// network, and destination tickets. The engine only ever uses city *indices*,
// so route/ticket order must match the Swift port 1:1 per map (verified by
// ios:enginecheck). City coords here are display-only; the iOS renderer carries
// its own geographic coords. Mirror of Swift GameMap.
export interface City {
  name: string;
  x: number;
  y: number;
}

export interface GameMapDef {
  id: string;
  name: string;
  cities: City[];
  routeDefs: [number, number, number, RoutePaint][];
  ticketDefs: [number, number, number][];
}

const USA_CITIES: City[] = [
  { name: "Vancouver", x: 0.06, y: 0.07 },        // 0
  { name: "Calgary", x: 0.17, y: 0.05 },          // 1
  { name: "Winnipeg", x: 0.41, y: 0.06 },         // 2
  { name: "Sault Ste Marie", x: 0.62, y: 0.14 },  // 3
  { name: "Montreal", x: 0.83, y: 0.10 },         // 4
  { name: "Toronto", x: 0.74, y: 0.17 },          // 5
  { name: "Boston", x: 0.94, y: 0.17 },           // 6
  { name: "New York", x: 0.88, y: 0.23 },         // 7
  { name: "Seattle", x: 0.07, y: 0.14 },          // 8
  { name: "Helena", x: 0.25, y: 0.18 },           // 9
  { name: "Duluth", x: 0.47, y: 0.17 },           // 10
  { name: "Portland", x: 0.06, y: 0.21 },         // 11
  { name: "Pittsburgh", x: 0.77, y: 0.25 },       // 12
  { name: "Washington", x: 0.86, y: 0.29 },       // 13
  { name: "Chicago", x: 0.59, y: 0.23 },          // 14
  { name: "Omaha", x: 0.46, y: 0.28 },            // 15
  { name: "Salt Lake City", x: 0.21, y: 0.31 },   // 16
  { name: "San Francisco", x: 0.04, y: 0.41 },    // 17
  { name: "Denver", x: 0.31, y: 0.35 },           // 18
  { name: "Kansas City", x: 0.48, y: 0.35 },      // 19
  { name: "Saint Louis", x: 0.56, y: 0.34 },      // 20
  { name: "Nashville", x: 0.63, y: 0.39 },        // 21
  { name: "Raleigh", x: 0.80, y: 0.37 },          // 22
  { name: "Las Vegas", x: 0.15, y: 0.43 },        // 23
  { name: "Santa Fe", x: 0.31, y: 0.45 },         // 24
  { name: "Oklahoma City", x: 0.46, y: 0.45 },    // 25
  { name: "Little Rock", x: 0.55, y: 0.45 },      // 26
  { name: "Atlanta", x: 0.71, y: 0.45 },          // 27
  { name: "Charleston", x: 0.83, y: 0.45 },       // 28
  { name: "Los Angeles", x: 0.10, y: 0.51 },      // 29
  { name: "Phoenix", x: 0.22, y: 0.53 },          // 30
  { name: "El Paso", x: 0.34, y: 0.55 },          // 31
  { name: "Dallas", x: 0.49, y: 0.53 },           // 32
  { name: "Houston", x: 0.51, y: 0.61 },          // 33
  { name: "New Orleans", x: 0.61, y: 0.59 },      // 34
  { name: "Miami", x: 0.85, y: 0.67 },            // 35
];

const USA_ROUTE_DEFS: [number, number, number, RoutePaint][] = [
  [0, 8, 1, "red"],     // Vancouver - Seattle
  [0, 1, 3, "gray"],    // Vancouver - Calgary
  [1, 8, 4, "gray"],    // Calgary - Seattle
  [1, 9, 4, "gray"],    // Calgary - Helena
  [1, 2, 6, "white"],   // Calgary - Winnipeg
  [8, 11, 1, "green"],  // Seattle - Portland
  [8, 9, 6, "yellow"],  // Seattle - Helena
  [11, 17, 5, "green"], // Portland - San Francisco
  [11, 16, 6, "blue"],  // Portland - Salt Lake City
  [17, 16, 5, "orange"],// San Francisco - Salt Lake City
  [17, 29, 3, "purple"],// San Francisco - Los Angeles
  [29, 23, 2, "gray"],  // Los Angeles - Las Vegas
  [29, 30, 3, "gray"],  // Los Angeles - Phoenix
  [29, 31, 6, "black"], // Los Angeles - El Paso
  [23, 16, 3, "orange"],// Las Vegas - Salt Lake City
  [16, 9, 3, "purple"], // Salt Lake City - Helena
  [16, 18, 3, "red"],   // Salt Lake City - Denver
  [9, 18, 4, "green"],  // Helena - Denver
  [9, 2, 4, "blue"],    // Helena - Winnipeg
  [9, 10, 6, "orange"], // Helena - Duluth
  [9, 15, 5, "red"],    // Helena - Omaha
  [30, 18, 5, "white"], // Phoenix - Denver
  [30, 24, 3, "gray"],  // Phoenix - Santa Fe
  [30, 31, 3, "gray"],  // Phoenix - El Paso
  [18, 24, 2, "gray"],  // Denver - Santa Fe
  [18, 15, 4, "purple"],// Denver - Omaha
  [18, 19, 4, "black"], // Denver - Kansas City
  [18, 25, 4, "red"],   // Denver - Oklahoma City
  [24, 31, 2, "gray"],  // Santa Fe - El Paso
  [24, 25, 3, "blue"],  // Santa Fe - Oklahoma City
  [31, 32, 4, "red"],   // El Paso - Dallas
  [31, 33, 6, "green"], // El Paso - Houston
  [2, 10, 4, "gray"],   // Winnipeg - Duluth
  [2, 3, 6, "gray"],    // Winnipeg - Sault Ste Marie
  [10, 15, 2, "orange"],// Duluth - Omaha
  [10, 14, 3, "red"],   // Duluth - Chicago
  [10, 3, 3, "purple"], // Duluth - Sault Ste Marie
  [10, 5, 6, "purple"], // Duluth - Toronto
  [15, 19, 1, "gray"],  // Omaha - Kansas City
  [15, 14, 4, "blue"],  // Omaha - Chicago
  [19, 20, 2, "blue"],  // Kansas City - Saint Louis
  [19, 25, 2, "blue"],  // Kansas City - Oklahoma City
  [25, 26, 2, "gray"],  // Oklahoma City - Little Rock
  [25, 32, 2, "gray"],  // Oklahoma City - Dallas
  [32, 33, 1, "orange"],// Dallas - Houston
  [32, 26, 2, "gray"],  // Dallas - Little Rock
  [33, 34, 2, "gray"],  // Houston - New Orleans
  [26, 20, 2, "gray"],  // Little Rock - Saint Louis
  [26, 21, 3, "white"], // Little Rock - Nashville
  [26, 34, 3, "green"], // Little Rock - New Orleans
  [20, 14, 2, "green"], // Saint Louis - Chicago
  [20, 21, 2, "yellow"],// Saint Louis - Nashville
  [14, 12, 3, "orange"],// Chicago - Pittsburgh
  [14, 5, 4, "white"],  // Chicago - Toronto
  [21, 27, 1, "gray"],  // Nashville - Atlanta
  [21, 12, 4, "yellow"],// Nashville - Pittsburgh
  [21, 22, 3, "black"], // Nashville - Raleigh
  [34, 27, 4, "yellow"],// New Orleans - Atlanta
  [34, 35, 6, "red"],   // New Orleans - Miami
  [27, 28, 2, "gray"],  // Atlanta - Charleston
  [27, 22, 2, "gray"],  // Atlanta - Raleigh
  [27, 35, 5, "blue"],  // Atlanta - Miami
  [28, 22, 2, "gray"],  // Charleston - Raleigh
  [28, 35, 4, "purple"],// Charleston - Miami
  [22, 12, 2, "gray"],  // Raleigh - Pittsburgh
  [22, 13, 2, "gray"],  // Raleigh - Washington
  [12, 5, 2, "gray"],   // Pittsburgh - Toronto
  [12, 7, 2, "green"],  // Pittsburgh - New York
  [12, 13, 2, "yellow"],// Pittsburgh - Washington
  [13, 7, 2, "orange"], // Washington - New York
  [7, 6, 2, "yellow"],  // New York - Boston
  [7, 4, 3, "blue"],    // New York - Montreal
  [6, 4, 2, "gray"],    // Boston - Montreal
  [4, 5, 3, "gray"],    // Montreal - Toronto
  [4, 3, 5, "black"],   // Montreal - Sault Ste Marie
  [3, 5, 2, "gray"],    // Sault Ste Marie - Toronto
  // Double routes (mirror Ticket to Ride USA). A parallel second track between
  // the same two cities; only ONE of each pair may ever be claimed (see canClaim).
  [0, 8, 1, "white"],   // Vancouver - Seattle (2)        pairs with red
  [8, 11, 1, "yellow"], // Seattle - Portland (2)         pairs with green
  [11, 17, 5, "purple"],// Portland - San Francisco (2)   pairs with green
  [17, 16, 5, "white"], // San Francisco - Salt Lake City (2) pairs with orange
  [9, 18, 4, "red"],    // Helena - Denver (2)            pairs with green
  [18, 15, 4, "white"], // Denver - Omaha (2)             pairs with purple
  [18, 19, 4, "orange"],// Denver - Kansas City (2)       pairs with black
  [10, 15, 2, "blue"],  // Duluth - Omaha (2)             pairs with orange
  [19, 20, 2, "purple"],// Kansas City - Saint Louis (2)  pairs with blue
  [19, 25, 2, "red"],   // Kansas City - Oklahoma City (2) pairs with blue
  [20, 14, 2, "white"], // Saint Louis - Chicago (2)      pairs with green
  [14, 12, 3, "black"], // Chicago - Pittsburgh (2)       pairs with orange
  [7, 6, 2, "red"],     // New York - Boston (2)          pairs with yellow
  [13, 7, 2, "black"],  // Washington - New York (2)      pairs with orange
  [32, 33, 1, "red"],   // Dallas - Houston (2)           pairs with orange
  [34, 27, 4, "green"], // New Orleans - Atlanta (2)      pairs with yellow
];

const USA_TICKET_DEFS: [number, number, number][] = [
  [8, 7, 22],   // Seattle - New York
  [29, 35, 20], // Los Angeles - Miami
  [17, 27, 17], // San Francisco - Atlanta
  [8, 33, 18],  // Seattle - Houston
  [18, 13, 11], // Denver - Washington
  [11, 6, 21],  // Portland - Boston
  [30, 14, 12], // Phoenix - Chicago
  [32, 7, 11],  // Dallas - New York
  [16, 35, 16], // Salt Lake City - Miami
  [6, 35, 12],  // Boston - Miami
  [14, 33, 9],  // Chicago - Houston
  [23, 27, 13], // Las Vegas - Atlanta
  [0, 7, 20],   // Vancouver - New York
  [0, 34, 13],  // Vancouver - New Orleans
  [29, 18, 7],  // Los Angeles - Denver
  [29, 14, 16], // Los Angeles - Chicago
  [1, 20, 8],   // Calgary - Saint Louis
  [2, 33, 12],  // Winnipeg - Houston
  [4, 27, 9],   // Montreal - Atlanta
  [3, 25, 8],   // Sault Ste Marie - Oklahoma City
  [11, 30, 11], // Portland - Phoenix
  [9, 22, 8],   // Helena - Raleigh
  [18, 33, 4,], // Denver - Houston
  [19, 28, 8],  // Kansas City - Charleston
  [10, 7, 14],  // Duluth - New York
  [24, 34, 5],  // Santa Fe - New Orleans
  [16, 21, 6],  // Salt Lake City - Nashville
  [31, 4, 16],  // El Paso - Montreal
  [12, 35, 7],  // Pittsburgh - Miami
  [15, 22, 7],  // Omaha - Raleigh
];

const USA: GameMapDef = {
  id: "usa",
  name: "USA",
  cities: USA_CITIES,
  routeDefs: USA_ROUTE_DEFS,
  ticketDefs: USA_TICKET_DEFS,
};

// ---- Europe --------------------------------------------------------------
// Real European cities at geographic positions with an original route network
// (same stance as the USA board). Standard rules for now; map-specific rules
// (ferries/tunnels/stations) are a later batch.
// Coords normalized to fill the board box (~[0,0.95] x [0,0.5]).
const EUROPE_CITIES: City[] = [
  { name: "Lisbon", x: 0.00, y: 0.500 },     // 0
  { name: "Madrid", x: 0.126, y: 0.450 },    // 1
  { name: "Barcelona", x: 0.270, y: 0.390 }, // 2
  { name: "Brest", x: 0.144, y: 0.210 },     // 3
  { name: "Paris", x: 0.288, y: 0.240 },     // 4
  { name: "Marseille", x: 0.360, y: 0.360 }, // 5
  { name: "London", x: 0.216, y: 0.150 },    // 6
  { name: "Edinburgh", x: 0.162, y: 0.030 }, // 7
  { name: "Dublin", x: 0.054, y: 0.105 },    // 8
  { name: "Amsterdam", x: 0.342, y: 0.165 }, // 9
  { name: "Brussels", x: 0.306, y: 0.195 },  // 10
  { name: "Frankfurt", x: 0.414, y: 0.195 }, // 11
  { name: "Zurich", x: 0.396, y: 0.270 },    // 12
  { name: "Venice", x: 0.486, y: 0.315 },    // 13
  { name: "Rome", x: 0.540, y: 0.420 },      // 14
  { name: "Munich", x: 0.468, y: 0.240 },    // 15
  { name: "Berlin", x: 0.558, y: 0.150 },    // 16
  { name: "Copenhagen", x: 0.522, y: 0.075 },// 17
  { name: "Stockholm", x: 0.648, y: 0.000 }, // 18
  { name: "Vienna", x: 0.612, y: 0.255 },    // 19
  { name: "Prague", x: 0.540, y: 0.195 },    // 20
  { name: "Warsaw", x: 0.702, y: 0.150 },    // 21
  { name: "Budapest", x: 0.666, y: 0.285 },  // 22
  { name: "Athens", x: 0.756, y: 0.495 },    // 23
  { name: "Bucharest", x: 0.846, y: 0.330 }, // 24
  { name: "Kyiv", x: 0.954, y: 0.195 },      // 25
];

const EUROPE_ROUTE_DEFS: [number, number, number, RoutePaint][] = [
  [0, 1, 3, "orange"], [1, 2, 2, "yellow"], [2, 5, 4, "green"], [1, 3, 4, "black"],
  [3, 4, 3, "gray"], [4, 5, 4, "gray"], [6, 3, 2, "red"], [6, 7, 4, "gray"],
  [7, 8, 2, "gray"], [6, 9, 2, "yellow"], [6, 4, 2, "white"], [4, 10, 2, "yellow"],
  [10, 9, 1, "blue"], [10, 11, 2, "blue"], [9, 11, 2, "red"], [4, 12, 3, "purple"],
  [11, 12, 2, "white"], [11, 15, 2, "orange"], [12, 15, 2, "yellow"], [12, 13, 2, "green"],
  [5, 12, 3, "gray"], [5, 14, 4, "red"], [13, 14, 2, "black"], [13, 15, 2, "blue"],
  [15, 16, 3, "gray"], [15, 19, 2, "green"], [16, 20, 2, "gray"], [16, 11, 3, "black"],
  [16, 17, 3, "red"], [17, 18, 3, "yellow"], [16, 21, 3, "gray"], [20, 19, 2, "purple"],
  [19, 22, 1, "orange"], [22, 24, 4, "red"], [21, 22, 3, "white"], [21, 25, 4, "gray"],
  [24, 25, 2, "white"], [24, 23, 4, "purple"], [22, 23, 5, "blue"], [13, 19, 2, "gray"],
];

const EUROPE_TICKET_DEFS: [number, number, number][] = [
  [0, 16, 21], [7, 14, 20], [8, 18, 22], [1, 15, 13], [6, 19, 12], [5, 25, 20],
  [2, 11, 8], [17, 23, 18], [21, 14, 12], [4, 24, 16], [9, 22, 10], [3, 13, 11],
];

const EUROPE: GameMapDef = {
  id: "europe",
  name: "Europe",
  cities: EUROPE_CITIES,
  routeDefs: EUROPE_ROUTE_DEFS,
  ticketDefs: EUROPE_TICKET_DEFS,
};

// ---- Additional boards (real cities, original networks; standard rules) ----
// Compact, connected boards mirrored 1:1 in Swift GameMap (same order).
const GERMANY: GameMapDef = {
  id: "germany", name: "Germany",
  cities: [
    { name: "Hamburg", x: 0.42, y: 0.06 }, { name: "Bremen", x: 0.30, y: 0.10 },
    { name: "Hannover", x: 0.40, y: 0.16 }, { name: "Berlin", x: 0.62, y: 0.12 },
    { name: "Dortmund", x: 0.20, y: 0.20 }, { name: "Essen", x: 0.15, y: 0.19 },
    { name: "Cologne", x: 0.16, y: 0.25 }, { name: "Frankfurt", x: 0.30, y: 0.30 },
    { name: "Leipzig", x: 0.58, y: 0.22 }, { name: "Dresden", x: 0.70, y: 0.24 },
    { name: "Nuremberg", x: 0.50, y: 0.34 }, { name: "Stuttgart", x: 0.33, y: 0.40 },
    { name: "Munich", x: 0.52, y: 0.45 }, { name: "Kiel", x: 0.40, y: 0.00 },
    { name: "Rostock", x: 0.55, y: 0.03 }, { name: "Mannheim", x: 0.27, y: 0.34 },
  ],
  routeDefs: [
    [13, 0, 1, "gray"], [14, 0, 2, "gray"], [0, 1, 1, "red"], [0, 2, 2, "blue"],
    [14, 3, 3, "yellow"], [1, 4, 3, "green"], [2, 3, 3, "orange"], [2, 4, 2, "gray"],
    [4, 5, 1, "gray"], [5, 6, 1, "yellow"], [4, 7, 3, "white"], [6, 7, 2, "blue"],
    [2, 8, 3, "purple"], [3, 8, 2, "red"], [8, 9, 1, "gray"], [8, 10, 3, "green"],
    [7, 10, 2, "orange"], [7, 15, 1, "gray"], [15, 11, 1, "yellow"], [11, 12, 3, "purple"],
    [10, 12, 2, "blue"], [9, 12, 4, "black"], [11, 10, 2, "white"],
  ],
  ticketDefs: [
    [13, 12, 18], [0, 9, 12], [5, 12, 15], [3, 11, 13], [1, 10, 11],
    [6, 9, 11], [14, 12, 17], [4, 8, 8], [7, 12, 9], [2, 9, 8],
  ],
};

const FRANCE: GameMapDef = {
  id: "france", name: "France",
  cities: [
    { name: "Brest", x: 0.04, y: 0.18 }, { name: "Paris", x: 0.34, y: 0.16 },
    { name: "Lille", x: 0.40, y: 0.05 }, { name: "Strasbourg", x: 0.66, y: 0.18 },
    { name: "Nantes", x: 0.18, y: 0.28 }, { name: "Bordeaux", x: 0.20, y: 0.42 },
    { name: "Toulouse", x: 0.34, y: 0.48 }, { name: "Marseille", x: 0.58, y: 0.46 },
    { name: "Nice", x: 0.70, y: 0.44 }, { name: "Lyon", x: 0.54, y: 0.34 },
    { name: "Dijon", x: 0.54, y: 0.22 }, { name: "Clermont", x: 0.44, y: 0.36 },
    { name: "Orleans", x: 0.34, y: 0.24 }, { name: "Rennes", x: 0.16, y: 0.20 },
    { name: "Le Havre", x: 0.28, y: 0.10 }, { name: "Montpellier", x: 0.46, y: 0.46 },
  ],
  routeDefs: [
    [0, 13, 1, "gray"], [13, 4, 1, "green"], [13, 1, 3, "gray"], [14, 1, 2, "blue"],
    [2, 1, 2, "red"], [1, 12, 1, "yellow"], [1, 10, 3, "purple"], [2, 3, 4, "orange"],
    [10, 3, 2, "white"], [12, 4, 2, "gray"], [12, 11, 3, "blue"], [4, 5, 3, "yellow"],
    [5, 6, 2, "green"], [6, 15, 2, "orange"], [11, 9, 2, "red"], [10, 9, 2, "gray"],
    [9, 7, 3, "purple"], [15, 7, 1, "blue"], [7, 8, 1, "white"], [11, 6, 3, "black"],
    [9, 8, 4, "yellow"], [5, 11, 3, "gray"],
  ],
  ticketDefs: [
    [0, 8, 20], [2, 7, 15], [5, 3, 13], [4, 8, 16], [14, 6, 12],
    [1, 7, 11], [13, 3, 12], [0, 6, 14], [10, 8, 9], [12, 7, 10],
  ],
};

const UK: GameMapDef = {
  id: "uk", name: "United Kingdom",
  cities: [
    { name: "Inverness", x: 0.30, y: 0.02 }, { name: "Aberdeen", x: 0.40, y: 0.06 },
    { name: "Glasgow", x: 0.28, y: 0.12 }, { name: "Edinburgh", x: 0.38, y: 0.12 },
    { name: "Belfast", x: 0.14, y: 0.18 }, { name: "Dublin", x: 0.10, y: 0.24 },
    { name: "Newcastle", x: 0.40, y: 0.18 }, { name: "Manchester", x: 0.36, y: 0.26 },
    { name: "Liverpool", x: 0.30, y: 0.26 }, { name: "Birmingham", x: 0.40, y: 0.32 },
    { name: "Cardiff", x: 0.30, y: 0.38 }, { name: "Bristol", x: 0.38, y: 0.38 },
    { name: "London", x: 0.52, y: 0.36 }, { name: "Southampton", x: 0.46, y: 0.42 },
  ],
  routeDefs: [
    [0, 1, 2, "gray"], [0, 2, 2, "green"], [1, 3, 2, "blue"], [2, 3, 1, "gray"],
    [2, 4, 2, "yellow"], [4, 5, 1, "gray"], [3, 6, 2, "red"], [6, 7, 2, "orange"],
    [7, 8, 1, "gray"], [5, 8, 3, "white"], [7, 9, 1, "purple"], [8, 9, 2, "yellow"],
    [9, 10, 2, "green"], [9, 12, 3, "red"], [10, 11, 1, "gray"], [11, 13, 2, "blue"],
    [11, 12, 2, "orange"], [12, 13, 1, "white"], [6, 9, 3, "black"],
  ],
  ticketDefs: [
    [0, 12, 20], [5, 12, 16], [1, 13, 18], [2, 10, 12], [4, 9, 11],
    [3, 12, 13], [0, 13, 22], [6, 11, 9], [7, 12, 8],
  ],
};

const SWITZERLAND: GameMapDef = {
  id: "switzerland", name: "Switzerland",
  cities: [
    { name: "Basel", x: 0.20, y: 0.10 }, { name: "Zurich", x: 0.46, y: 0.10 },
    { name: "Bern", x: 0.26, y: 0.30 }, { name: "Lucerne", x: 0.44, y: 0.24 },
    { name: "Geneva", x: 0.06, y: 0.46 }, { name: "Lausanne", x: 0.12, y: 0.40 },
    { name: "Sion", x: 0.26, y: 0.46 }, { name: "Interlaken", x: 0.34, y: 0.36 },
    { name: "Lugano", x: 0.58, y: 0.50 }, { name: "Chur", x: 0.66, y: 0.26 },
    { name: "St Gallen", x: 0.62, y: 0.10 }, { name: "Neuchatel", x: 0.18, y: 0.28 },
  ],
  routeDefs: [
    [0, 1, 2, "gray"], [0, 2, 2, "green"], [1, 3, 1, "yellow"], [1, 10, 2, "gray"],
    [10, 9, 2, "blue"], [3, 9, 3, "red"], [2, 3, 2, "orange"], [2, 11, 1, "gray"],
    [11, 5, 1, "white"], [5, 4, 1, "gray"], [2, 7, 2, "purple"], [7, 6, 2, "yellow"],
    [6, 4, 3, "green"], [7, 8, 3, "blue"], [9, 8, 3, "black"], [3, 8, 4, "white"],
    [5, 6, 2, "red"],
  ],
  ticketDefs: [
    [4, 10, 15], [0, 8, 14], [4, 9, 16], [5, 8, 13], [0, 4, 12],
    [1, 8, 11], [11, 9, 10], [2, 8, 9],
  ],
};

const NORDIC: GameMapDef = {
  id: "nordic", name: "Nordic Countries",
  cities: [
    { name: "Tromso", x: 0.40, y: 0.00 }, { name: "Narvik", x: 0.46, y: 0.04 },
    { name: "Trondheim", x: 0.28, y: 0.16 }, { name: "Bergen", x: 0.12, y: 0.30 },
    { name: "Oslo", x: 0.26, y: 0.34 }, { name: "Stockholm", x: 0.46, y: 0.34 },
    { name: "Gothenburg", x: 0.32, y: 0.42 }, { name: "Copenhagen", x: 0.34, y: 0.50 },
    { name: "Sundsvall", x: 0.46, y: 0.22 }, { name: "Umea", x: 0.52, y: 0.16 },
    { name: "Helsinki", x: 0.66, y: 0.32 }, { name: "Oulu", x: 0.64, y: 0.14 },
    { name: "Lahti", x: 0.64, y: 0.28 }, { name: "Murmansk", x: 0.58, y: 0.00 },
  ],
  routeDefs: [
    [0, 1, 1, "gray"], [1, 13, 3, "white"], [1, 2, 4, "gray"], [2, 3, 2, "green"],
    [2, 4, 3, "yellow"], [3, 4, 2, "gray"], [4, 6, 1, "red"], [6, 7, 1, "gray"],
    [4, 5, 3, "blue"], [6, 5, 2, "orange"], [2, 8, 3, "purple"], [8, 5, 2, "white"],
    [8, 9, 1, "gray"], [9, 11, 3, "yellow"], [11, 13, 4, "black"], [11, 12, 2, "green"],
    [12, 10, 1, "gray"], [5, 10, 3, "red"], [9, 12, 3, "blue"],
  ],
  ticketDefs: [
    [7, 13, 22], [3, 10, 18], [0, 7, 20], [3, 5, 12], [4, 11, 14],
    [7, 10, 13], [2, 10, 15], [0, 5, 16], [6, 11, 12],
  ],
};

const INDIA: GameMapDef = {
  id: "india", name: "India",
  cities: [
    { name: "Delhi", x: 0.34, y: 0.10 }, { name: "Jaipur", x: 0.26, y: 0.16 },
    { name: "Ahmedabad", x: 0.16, y: 0.28 }, { name: "Mumbai", x: 0.16, y: 0.40 },
    { name: "Pune", x: 0.20, y: 0.44 }, { name: "Hyderabad", x: 0.34, y: 0.42 },
    { name: "Bangalore", x: 0.30, y: 0.52 }, { name: "Chennai", x: 0.40, y: 0.52 },
    { name: "Kolkata", x: 0.62, y: 0.30 }, { name: "Nagpur", x: 0.40, y: 0.32 },
    { name: "Bhopal", x: 0.34, y: 0.26 }, { name: "Kanpur", x: 0.46, y: 0.20 },
    { name: "Patna", x: 0.56, y: 0.22 }, { name: "Varanasi", x: 0.50, y: 0.24 },
    { name: "Amritsar", x: 0.28, y: 0.04 }, { name: "Lucknow", x: 0.44, y: 0.18 },
  ],
  routeDefs: [
    [14, 0, 2, "gray"], [0, 1, 1, "green"], [0, 15, 2, "yellow"], [15, 11, 1, "gray"],
    [11, 13, 2, "blue"], [13, 12, 1, "gray"], [12, 8, 3, "red"], [1, 2, 3, "orange"],
    [1, 10, 3, "white"], [10, 9, 2, "purple"], [10, 11, 3, "gray"], [2, 3, 2, "red"],
    [3, 4, 1, "gray"], [4, 5, 2, "yellow"], [9, 5, 2, "green"], [9, 8, 4, "black"],
    [5, 6, 2, "blue"], [6, 7, 1, "gray"], [5, 7, 3, "orange"], [8, 7, 4, "white"],
    [9, 13, 3, "yellow"],
  ],
  ticketDefs: [
    [14, 7, 22], [3, 8, 18], [0, 6, 16], [2, 7, 17], [0, 8, 15],
    [3, 7, 13], [1, 12, 14], [4, 8, 16], [10, 7, 12], [14, 3, 13],
  ],
};

const AFRICA: GameMapDef = {
  id: "africa", name: "Africa",
  cities: [
    { name: "Tangier", x: 0.20, y: 0.02 }, { name: "Algiers", x: 0.34, y: 0.04 },
    { name: "Tunis", x: 0.44, y: 0.03 }, { name: "Cairo", x: 0.66, y: 0.10 },
    { name: "Dakar", x: 0.02, y: 0.26 }, { name: "Bamako", x: 0.16, y: 0.28 },
    { name: "Lagos", x: 0.34, y: 0.34 }, { name: "Khartoum", x: 0.62, y: 0.24 },
    { name: "Addis Ababa", x: 0.74, y: 0.30 }, { name: "Kinshasa", x: 0.46, y: 0.42 },
    { name: "Nairobi", x: 0.72, y: 0.42 }, { name: "Luanda", x: 0.42, y: 0.48 },
    { name: "Dar es Salaam", x: 0.74, y: 0.48 }, { name: "Lusaka", x: 0.60, y: 0.52 },
    { name: "Windhoek", x: 0.48, y: 0.60 }, { name: "Johannesburg", x: 0.60, y: 0.64 },
    { name: "Cape Town", x: 0.50, y: 0.74 },
  ],
  routeDefs: [
    [0, 1, 2, "gray"], [1, 2, 1, "yellow"], [2, 3, 5, "white"], [0, 4, 4, "gray"],
    [4, 5, 2, "green"], [5, 6, 3, "orange"], [1, 5, 4, "red"], [6, 7, 5, "blue"],
    [3, 7, 4, "gray"], [7, 8, 2, "purple"], [8, 10, 2, "green"], [6, 9, 4, "yellow"],
    [9, 10, 4, "red"], [9, 11, 2, "gray"], [10, 12, 1, "orange"], [11, 13, 3, "white"],
    [12, 13, 2, "blue"], [13, 14, 3, "purple"], [13, 15, 2, "black"], [14, 16, 3, "gray"],
    [15, 16, 3, "yellow"], [11, 14, 3, "blue"], [7, 8, 3, "gray"],
  ],
  ticketDefs: [
    [0, 16, 22], [4, 12, 20], [3, 16, 21], [0, 10, 16], [5, 13, 15],
    [2, 8, 14], [6, 16, 18], [4, 15, 19], [3, 14, 17], [1, 11, 13],
  ],
};

const ASIA: GameMapDef = {
  id: "asia", name: "Legendary Asia",
  cities: [
    { name: "Tehran", x: 0.06, y: 0.16 }, { name: "Karachi", x: 0.16, y: 0.30 },
    { name: "Delhi", x: 0.24, y: 0.26 }, { name: "Kolkata", x: 0.36, y: 0.34 },
    { name: "Almaty", x: 0.26, y: 0.06 }, { name: "Tashkent", x: 0.16, y: 0.12 },
    { name: "Novosibirsk", x: 0.40, y: 0.00 }, { name: "Ulaanbaatar", x: 0.56, y: 0.06 },
    { name: "Beijing", x: 0.66, y: 0.16 }, { name: "Lhasa", x: 0.44, y: 0.24 },
    { name: "Chengdu", x: 0.56, y: 0.24 }, { name: "Shanghai", x: 0.76, y: 0.24 },
    { name: "Hong Kong", x: 0.68, y: 0.34 }, { name: "Hanoi", x: 0.58, y: 0.36 },
    { name: "Bangkok", x: 0.54, y: 0.46 }, { name: "Yangon", x: 0.46, y: 0.40 },
    { name: "Singapore", x: 0.58, y: 0.56 }, { name: "Vladivostok", x: 0.84, y: 0.08 },
  ],
  routeDefs: [
    [0, 1, 3, "gray"], [0, 5, 3, "yellow"], [5, 4, 2, "green"], [4, 6, 4, "gray"],
    [6, 7, 4, "white"], [7, 8, 3, "red"], [8, 17, 5, "black"], [8, 11, 3, "blue"],
    [1, 2, 2, "orange"], [2, 3, 4, "gray"], [2, 9, 3, "purple"], [9, 10, 3, "gray"],
    [10, 8, 3, "yellow"], [10, 13, 4, "green"], [3, 15, 2, "red"], [15, 14, 2, "gray"],
    [13, 14, 2, "orange"], [13, 12, 2, "white"], [12, 11, 3, "purple"], [14, 16, 4, "blue"],
    [9, 3, 3, "gray"], [4, 9, 4, "blue"], [11, 17, 4, "gray"],
  ],
  ticketDefs: [
    [0, 16, 22], [17, 16, 20], [1, 11, 18], [4, 12, 16], [0, 8, 17],
    [3, 11, 13], [7, 16, 21], [5, 14, 19], [2, 16, 18], [6, 16, 22],
  ],
};

const NETHERLANDS: GameMapDef = {
  id: "netherlands", name: "Netherlands",
  cities: [
    { name: "Groningen", x: 0.62, y: 0.04 }, { name: "Leeuwarden", x: 0.46, y: 0.04 },
    { name: "Zwolle", x: 0.58, y: 0.20 }, { name: "Amsterdam", x: 0.34, y: 0.18 },
    { name: "Haarlem", x: 0.26, y: 0.18 }, { name: "Den Haag", x: 0.18, y: 0.28 },
    { name: "Utrecht", x: 0.40, y: 0.26 }, { name: "Rotterdam", x: 0.24, y: 0.32 },
    { name: "Arnhem", x: 0.60, y: 0.30 }, { name: "Nijmegen", x: 0.58, y: 0.36 },
    { name: "Eindhoven", x: 0.50, y: 0.44 }, { name: "Tilburg", x: 0.42, y: 0.44 },
    { name: "Breda", x: 0.34, y: 0.42 }, { name: "Maastricht", x: 0.60, y: 0.56 },
    { name: "Enschede", x: 0.74, y: 0.24 }, { name: "Den Bosch", x: 0.46, y: 0.38 },
  ],
  routeDefs: [
    [1, 0, 2, "gray"], [1, 3, 3, "yellow"], [0, 2, 3, "green"], [2, 14, 2, "gray"],
    [3, 4, 1, "blue"], [4, 5, 2, "gray"], [3, 6, 1, "red"], [6, 2, 2, "orange"],
    [5, 7, 1, "gray"], [7, 6, 2, "white"], [6, 8, 2, "purple"], [8, 14, 2, "gray"],
    [8, 9, 1, "yellow"], [9, 15, 1, "gray"], [7, 12, 2, "green"], [12, 11, 1, "gray"],
    [11, 15, 1, "blue"], [11, 10, 1, "orange"], [10, 9, 1, "red"], [10, 13, 3, "black"],
    [15, 6, 2, "gray"], [12, 10, 2, "white"],
  ],
  ticketDefs: [
    [0, 13, 18], [1, 13, 20], [5, 14, 14], [4, 9, 11], [0, 10, 13],
    [5, 13, 16], [14, 13, 12], [3, 13, 13], [1, 10, 12], [7, 8, 8],
  ],
};

const ITALY: GameMapDef = {
  id: "italy", name: "Italy",
  cities: [
    { name: "Turin", x: 0.16, y: 0.14 }, { name: "Milan", x: 0.26, y: 0.12 },
    { name: "Venice", x: 0.44, y: 0.14 }, { name: "Genoa", x: 0.22, y: 0.22 },
    { name: "Bologna", x: 0.38, y: 0.22 }, { name: "Florence", x: 0.40, y: 0.28 },
    { name: "Ancona", x: 0.50, y: 0.30 }, { name: "Rome", x: 0.44, y: 0.40 },
    { name: "Pescara", x: 0.54, y: 0.38 }, { name: "Naples", x: 0.56, y: 0.46 },
    { name: "Bari", x: 0.70, y: 0.46 }, { name: "Taranto", x: 0.72, y: 0.52 },
    { name: "Reggio", x: 0.66, y: 0.62 }, { name: "Palermo", x: 0.54, y: 0.66 },
    { name: "Cagliari", x: 0.24, y: 0.54 }, { name: "Catania", x: 0.62, y: 0.70 },
  ],
  routeDefs: [
    [0, 1, 1, "gray"], [1, 2, 3, "yellow"], [0, 3, 2, "green"], [1, 4, 2, "gray"],
    [2, 4, 2, "orange"], [3, 5, 3, "red"], [4, 5, 1, "gray"], [5, 6, 2, "blue"],
    [5, 7, 2, "white"], [6, 8, 2, "gray"], [7, 8, 2, "purple"], [7, 9, 2, "gray"],
    [8, 9, 2, "yellow"], [9, 10, 3, "green"], [10, 11, 1, "gray"], [9, 12, 3, "red"],
    [11, 12, 2, "blue"], [12, 13, 2, "gray"], [13, 15, 2, "orange"], [7, 14, 4, "black"],
    [14, 13, 4, "white"], [3, 14, 5, "purple"],
  ],
  ticketDefs: [
    [0, 15, 22], [2, 13, 20], [0, 13, 21], [1, 9, 13], [3, 11, 16],
    [4, 12, 15], [2, 9, 12], [14, 10, 14], [5, 15, 18], [0, 9, 14],
  ],
};

const JAPAN: GameMapDef = {
  id: "japan", name: "Japan",
  cities: [
    { name: "Sapporo", x: 0.74, y: 0.04 }, { name: "Hakodate", x: 0.68, y: 0.12 },
    { name: "Aomori", x: 0.64, y: 0.18 }, { name: "Akita", x: 0.58, y: 0.22 },
    { name: "Sendai", x: 0.62, y: 0.28 }, { name: "Niigata", x: 0.52, y: 0.28 },
    { name: "Tokyo", x: 0.58, y: 0.36 }, { name: "Nagoya", x: 0.46, y: 0.38 },
    { name: "Kanazawa", x: 0.42, y: 0.30 }, { name: "Kyoto", x: 0.40, y: 0.40 },
    { name: "Osaka", x: 0.36, y: 0.42 }, { name: "Hiroshima", x: 0.22, y: 0.44 },
    { name: "Matsuyama", x: 0.24, y: 0.50 }, { name: "Fukuoka", x: 0.12, y: 0.48 },
    { name: "Kagoshima", x: 0.10, y: 0.58 }, { name: "Naha", x: 0.02, y: 0.72 },
  ],
  routeDefs: [
    [0, 1, 2, "gray"], [1, 2, 1, "yellow"], [2, 3, 2, "green"], [3, 4, 2, "gray"],
    [2, 4, 3, "red"], [3, 5, 2, "orange"], [4, 6, 3, "blue"], [5, 6, 2, "gray"],
    [5, 8, 2, "white"], [6, 7, 2, "purple"], [7, 8, 1, "gray"], [8, 9, 2, "yellow"],
    [7, 9, 2, "gray"], [9, 10, 1, "red"], [10, 11, 3, "green"], [11, 12, 1, "gray"],
    [11, 13, 2, "blue"], [12, 13, 2, "gray"], [13, 14, 2, "orange"], [14, 15, 4, "black"],
    [10, 12, 2, "white"], [6, 9, 3, "gray"],
  ],
  ticketDefs: [
    [0, 15, 22], [0, 13, 20], [6, 15, 18], [2, 11, 14], [0, 6, 13],
    [4, 13, 16], [6, 13, 15], [1, 10, 13], [5, 14, 17], [0, 10, 16],
  ],
};

const POLAND: GameMapDef = {
  id: "poland", name: "Poland",
  cities: [
    { name: "Szczecin", x: 0.06, y: 0.12 }, { name: "Gdansk", x: 0.40, y: 0.04 },
    { name: "Olsztyn", x: 0.52, y: 0.10 }, { name: "Bialystok", x: 0.70, y: 0.14 },
    { name: "Poznan", x: 0.24, y: 0.24 }, { name: "Bydgoszcz", x: 0.34, y: 0.16 },
    { name: "Warsaw", x: 0.56, y: 0.24 }, { name: "Lodz", x: 0.44, y: 0.28 },
    { name: "Lublin", x: 0.66, y: 0.30 }, { name: "Wroclaw", x: 0.28, y: 0.36 },
    { name: "Katowice", x: 0.42, y: 0.42 }, { name: "Krakow", x: 0.50, y: 0.44 },
    { name: "Rzeszow", x: 0.64, y: 0.42 }, { name: "Zielona Gora", x: 0.14, y: 0.30 },
    { name: "Opole", x: 0.12, y: 0.44 }, { name: "Kielce", x: 0.56, y: 0.36 },
  ],
  routeDefs: [
    [0, 5, 3, "gray"], [0, 4, 2, "yellow"], [1, 2, 2, "green"], [2, 3, 3, "gray"],
    [1, 5, 2, "red"], [5, 4, 1, "gray"], [2, 6, 2, "orange"], [3, 6, 3, "blue"],
    [4, 9, 2, "white"], [5, 7, 2, "gray"], [6, 7, 1, "purple"], [6, 8, 2, "gray"],
    [7, 10, 2, "yellow"], [9, 10, 2, "gray"], [10, 11, 1, "red"], [11, 12, 2, "green"],
    [8, 12, 2, "gray"], [13, 9, 1, "blue"], [0, 13, 3, "gray"], [13, 14, 2, "orange"],
    [14, 9, 1, "gray"], [11, 15, 1, "white"], [15, 8, 2, "gray"],
  ],
  ticketDefs: [
    [0, 12, 20], [1, 11, 14], [3, 14, 18], [0, 3, 16], [4, 12, 13],
    [13, 8, 15], [1, 12, 16], [9, 8, 11], [2, 11, 12], [0, 8, 17],
  ],
};

const PENNSYLVANIA: GameMapDef = {
  id: "pennsylvania", name: "Pennsylvania",
  cities: [
    { name: "Erie", x: 0.06, y: 0.06 }, { name: "Pittsburgh", x: 0.10, y: 0.30 },
    { name: "Johnstown", x: 0.20, y: 0.32 }, { name: "Altoona", x: 0.28, y: 0.28 },
    { name: "State College", x: 0.34, y: 0.24 }, { name: "Williamsport", x: 0.44, y: 0.18 },
    { name: "Scranton", x: 0.62, y: 0.14 }, { name: "Wilkes-Barre", x: 0.60, y: 0.20 },
    { name: "Allentown", x: 0.66, y: 0.30 }, { name: "Reading", x: 0.58, y: 0.34 },
    { name: "Harrisburg", x: 0.48, y: 0.32 }, { name: "Lancaster", x: 0.56, y: 0.40 },
    { name: "Philadelphia", x: 0.72, y: 0.40 }, { name: "York", x: 0.50, y: 0.42 },
    { name: "Bradford", x: 0.30, y: 0.06 }, { name: "Pottsville", x: 0.56, y: 0.26 },
  ],
  routeDefs: [
    [0, 14, 3, "gray"], [14, 4, 3, "green"], [0, 1, 4, "yellow"], [1, 2, 1, "gray"],
    [2, 3, 1, "red"], [3, 4, 1, "gray"], [4, 5, 2, "blue"], [5, 6, 3, "orange"],
    [6, 7, 1, "gray"], [7, 8, 2, "white"], [8, 12, 2, "purple"], [8, 9, 1, "gray"],
    [9, 15, 1, "green"], [5, 15, 2, "gray"], [15, 10, 2, "yellow"], [4, 10, 3, "red"],
    [10, 13, 1, "gray"], [10, 11, 1, "blue"], [11, 13, 1, "gray"], [11, 12, 2, "orange"],
    [9, 11, 1, "white"], [1, 3, 3, "black"],
  ],
  ticketDefs: [
    [0, 12, 20], [1, 12, 18], [1, 6, 12], [14, 8, 13], [0, 8, 16],
    [2, 12, 15], [4, 12, 12], [1, 8, 14], [6, 13, 9], [0, 10, 13],
  ],
};

const OLD_WEST: GameMapDef = {
  id: "oldwest", name: "Old West",
  cities: [
    { name: "Seattle", x: 0.10, y: 0.04 }, { name: "Portland", x: 0.06, y: 0.12 },
    { name: "San Francisco", x: 0.02, y: 0.34 }, { name: "Los Angeles", x: 0.10, y: 0.46 },
    { name: "Sacramento", x: 0.06, y: 0.28 }, { name: "Salt Lake City", x: 0.30, y: 0.26 },
    { name: "Helena", x: 0.34, y: 0.08 }, { name: "Denver", x: 0.44, y: 0.30 },
    { name: "Santa Fe", x: 0.46, y: 0.42 }, { name: "El Paso", x: 0.48, y: 0.52 },
    { name: "Tucson", x: 0.30, y: 0.50 }, { name: "Phoenix", x: 0.24, y: 0.46 },
    { name: "Dodge City", x: 0.60, y: 0.34 }, { name: "Bismarck", x: 0.58, y: 0.08 },
    { name: "Omaha", x: 0.68, y: 0.26 }, { name: "San Antonio", x: 0.62, y: 0.56 },
  ],
  routeDefs: [
    [0, 1, 1, "gray"], [1, 4, 3, "green"], [4, 2, 1, "gray"], [2, 3, 4, "yellow"],
    [4, 5, 4, "red"], [0, 6, 4, "gray"], [6, 5, 3, "blue"], [6, 13, 4, "orange"],
    [5, 7, 3, "white"], [7, 6, 4, "purple"], [3, 11, 3, "gray"], [11, 10, 1, "gray"],
    [11, 5, 5, "black"], [10, 9, 2, "yellow"], [9, 8, 2, "gray"], [8, 7, 2, "green"],
    [7, 12, 2, "red"], [12, 14, 2, "gray"], [13, 14, 3, "blue"], [12, 15, 4, "orange"],
    [9, 15, 4, "white"], [8, 12, 3, "gray"], [7, 14, 4, "purple"],
  ],
  ticketDefs: [
    [0, 15, 22], [2, 14, 20], [1, 9, 18], [3, 13, 21], [0, 7, 14],
    [2, 8, 16], [3, 14, 19], [6, 15, 17], [4, 12, 15], [11, 14, 13],
  ],
};

const RAILS_WORLD: GameMapDef = {
  id: "world", name: "Rails & Sails: World",
  cities: [
    { name: "New York", x: 0.26, y: 0.24 }, { name: "Los Angeles", x: 0.10, y: 0.30 },
    { name: "Vancouver", x: 0.10, y: 0.18 }, { name: "Lima", x: 0.26, y: 0.56 },
    { name: "Buenos Aires", x: 0.32, y: 0.70 }, { name: "London", x: 0.46, y: 0.16 },
    { name: "Lisbon", x: 0.42, y: 0.26 }, { name: "Cairo", x: 0.56, y: 0.32 },
    { name: "Lagos", x: 0.48, y: 0.44 }, { name: "Cape Town", x: 0.54, y: 0.66 },
    { name: "Moscow", x: 0.60, y: 0.12 }, { name: "Mumbai", x: 0.70, y: 0.36 },
    { name: "Beijing", x: 0.82, y: 0.20 }, { name: "Tokyo", x: 0.92, y: 0.24 },
    { name: "Singapore", x: 0.82, y: 0.46 }, { name: "Sydney", x: 0.94, y: 0.66 },
    { name: "Honolulu", x: 0.04, y: 0.36 }, { name: "Panama", x: 0.22, y: 0.42 },
  ],
  routeDefs: [
    [2, 0, 4, "gray"], [2, 1, 3, "green"], [1, 16, 5, "blue"], [1, 17, 3, "gray"],
    [0, 17, 3, "yellow"], [17, 3, 3, "red"], [3, 4, 4, "gray"], [0, 5, 5, "white"],
    [5, 6, 2, "gray"], [5, 10, 4, "orange"], [6, 8, 4, "purple"], [6, 4, 6, "gray"],
    [7, 5, 4, "blue"], [7, 10, 3, "gray"], [7, 8, 3, "yellow"], [8, 9, 3, "red"],
    [7, 11, 3, "green"], [10, 12, 5, "gray"], [11, 12, 4, "white"], [11, 14, 3, "orange"],
    [12, 13, 2, "gray"], [12, 14, 4, "purple"], [14, 15, 4, "blue"], [13, 15, 6, "black"],
    [9, 15, 6, "gray"], [13, 16, 6, "red"],
  ],
  ticketDefs: [
    [0, 15, 22], [1, 13, 20], [5, 15, 21], [4, 12, 22], [16, 10, 18],
    [3, 11, 20], [9, 13, 21], [2, 14, 19], [0, 11, 16], [6, 15, 22],
  ],
};

const RAILS_LAKES: GameMapDef = {
  id: "greatlakes", name: "Rails & Sails: Great Lakes",
  cities: [
    { name: "Duluth", x: 0.12, y: 0.18 }, { name: "Thunder Bay", x: 0.18, y: 0.06 },
    { name: "Sault Ste Marie", x: 0.46, y: 0.14 }, { name: "Marquette", x: 0.34, y: 0.16 },
    { name: "Green Bay", x: 0.34, y: 0.30 }, { name: "Milwaukee", x: 0.38, y: 0.40 },
    { name: "Chicago", x: 0.34, y: 0.46 }, { name: "Detroit", x: 0.60, y: 0.40 },
    { name: "Toledo", x: 0.58, y: 0.46 }, { name: "Cleveland", x: 0.66, y: 0.42 },
    { name: "Buffalo", x: 0.80, y: 0.36 }, { name: "Toronto", x: 0.74, y: 0.28 },
    { name: "Ottawa", x: 0.86, y: 0.18 }, { name: "Montreal", x: 0.92, y: 0.16 },
    { name: "Erie", x: 0.72, y: 0.42 }, { name: "Georgian Bay", x: 0.58, y: 0.24 },
  ],
  routeDefs: [
    [1, 0, 2, "gray"], [1, 3, 3, "green"], [0, 4, 3, "gray"], [3, 2, 2, "yellow"],
    [3, 4, 2, "gray"], [4, 5, 1, "red"], [5, 6, 1, "gray"], [4, 6, 2, "blue"],
    [2, 15, 2, "gray"], [15, 11, 2, "orange"], [6, 7, 3, "white"], [7, 8, 1, "gray"],
    [8, 9, 1, "purple"], [7, 11, 2, "gray"], [9, 14, 1, "gray"], [14, 10, 1, "yellow"],
    [10, 11, 2, "gray"], [11, 12, 3, "green"], [12, 13, 1, "gray"], [10, 12, 3, "blue"],
    [15, 7, 2, "red"], [9, 10, 2, "white"],
  ],
  ticketDefs: [
    [1, 13, 22], [0, 13, 20], [6, 13, 18], [0, 10, 15], [6, 10, 12],
    [1, 7, 13], [4, 9, 11], [2, 13, 14], [6, 11, 9], [0, 7, 12],
  ],
};

const NEW_YORK: GameMapDef = {
  id: "newyork", name: "New York",
  cities: [
    { name: "Inwood", x: 0.36, y: 0.02 }, { name: "Harlem", x: 0.40, y: 0.12 },
    { name: "Upper West Side", x: 0.30, y: 0.22 }, { name: "Upper East Side", x: 0.48, y: 0.22 },
    { name: "Midtown", x: 0.38, y: 0.34 }, { name: "Chelsea", x: 0.28, y: 0.40 },
    { name: "Greenwich Village", x: 0.36, y: 0.46 }, { name: "SoHo", x: 0.34, y: 0.54 },
    { name: "Lower Manhattan", x: 0.40, y: 0.64 }, { name: "Brooklyn", x: 0.56, y: 0.66 },
    { name: "Queens", x: 0.64, y: 0.44 }, { name: "Bronx", x: 0.56, y: 0.10 },
  ],
  routeDefs: [
    [0, 11, 1, "gray"], [0, 1, 1, "green"], [1, 11, 1, "yellow"], [1, 2, 1, "gray"],
    [1, 3, 1, "red"], [2, 4, 1, "gray"], [3, 4, 1, "blue"], [3, 10, 2, "orange"],
    [4, 5, 1, "gray"], [4, 10, 2, "white"], [5, 6, 1, "purple"], [6, 7, 1, "gray"],
    [7, 8, 1, "yellow"], [8, 9, 1, "gray"], [9, 10, 2, "green"], [6, 4, 1, "gray"],
    [8, 10, 2, "red"],
  ],
  ticketDefs: [
    [0, 9, 12], [11, 8, 10], [2, 10, 8], [5, 9, 9], [0, 8, 11],
    [3, 7, 7], [11, 9, 12], [1, 8, 9],
  ],
};

const LONDON: GameMapDef = {
  id: "london", name: "London",
  cities: [
    { name: "Camden", x: 0.36, y: 0.16 }, { name: "Islington", x: 0.50, y: 0.18 },
    { name: "Paddington", x: 0.26, y: 0.30 }, { name: "Westminster", x: 0.36, y: 0.36 },
    { name: "City", x: 0.52, y: 0.34 }, { name: "Shoreditch", x: 0.58, y: 0.26 },
    { name: "Kensington", x: 0.22, y: 0.42 }, { name: "Southwark", x: 0.46, y: 0.44 },
    { name: "Greenwich", x: 0.66, y: 0.46 }, { name: "Brixton", x: 0.42, y: 0.56 },
  ],
  routeDefs: [
    [0, 1, 1, "gray"], [0, 2, 2, "green"], [1, 5, 1, "yellow"], [2, 3, 2, "gray"],
    [0, 3, 1, "red"], [3, 4, 1, "blue"], [1, 4, 1, "gray"], [4, 5, 1, "orange"],
    [2, 6, 1, "gray"], [3, 7, 1, "white"], [4, 7, 1, "gray"], [5, 8, 3, "purple"],
    [7, 8, 2, "gray"], [7, 9, 1, "yellow"], [6, 9, 2, "gray"], [3, 9, 2, "green"],
  ],
  ticketDefs: [
    [6, 8, 12], [2, 8, 11], [0, 9, 8], [6, 5, 10], [2, 9, 9], [0, 8, 12], [6, 4, 8],
  ],
};

const PARIS: GameMapDef = {
  id: "paris", name: "Paris",
  cities: [
    { name: "Montmartre", x: 0.40, y: 0.12 }, { name: "La Villette", x: 0.56, y: 0.14 },
    { name: "Champs-Elysees", x: 0.28, y: 0.26 }, { name: "Louvre", x: 0.42, y: 0.28 },
    { name: "Bastille", x: 0.56, y: 0.30 }, { name: "Eiffel Tower", x: 0.24, y: 0.38 },
    { name: "Latin Quarter", x: 0.44, y: 0.40 }, { name: "Bercy", x: 0.58, y: 0.42 },
    { name: "Montparnasse", x: 0.34, y: 0.46 }, { name: "Place d'Italie", x: 0.48, y: 0.52 },
  ],
  routeDefs: [
    [0, 2, 2, "gray"], [0, 3, 1, "green"], [0, 1, 1, "yellow"], [1, 4, 1, "gray"],
    [2, 3, 1, "red"], [3, 4, 1, "blue"], [2, 5, 2, "gray"], [3, 6, 1, "orange"],
    [4, 7, 1, "gray"], [5, 8, 2, "white"], [6, 8, 1, "gray"], [6, 9, 1, "purple"],
    [7, 9, 1, "gray"], [6, 7, 1, "yellow"], [5, 6, 2, "gray"], [8, 9, 1, "green"],
  ],
  ticketDefs: [
    [0, 9, 10], [5, 7, 11], [2, 7, 9], [0, 8, 8], [1, 8, 10], [5, 9, 9], [2, 4, 7],
  ],
};

const AMSTERDAM: GameMapDef = {
  id: "amsterdam", name: "Amsterdam",
  cities: [
    { name: "Centraal", x: 0.40, y: 0.10 }, { name: "Jordaan", x: 0.30, y: 0.20 },
    { name: "Dam", x: 0.42, y: 0.22 }, { name: "Plantage", x: 0.56, y: 0.24 },
    { name: "Museumplein", x: 0.34, y: 0.34 }, { name: "De Pijp", x: 0.44, y: 0.38 },
    { name: "Oost", x: 0.60, y: 0.36 }, { name: "Vondelpark", x: 0.26, y: 0.36 },
    { name: "Zuid", x: 0.40, y: 0.48 }, { name: "Oud-West", x: 0.28, y: 0.28 },
  ],
  routeDefs: [
    [0, 1, 1, "gray"], [0, 2, 1, "green"], [0, 3, 2, "yellow"], [1, 9, 1, "gray"],
    [2, 3, 1, "red"], [2, 4, 2, "blue"], [9, 4, 1, "gray"], [4, 7, 1, "orange"],
    [4, 5, 1, "gray"], [3, 6, 1, "white"], [5, 6, 2, "gray"], [5, 8, 1, "purple"],
    [7, 8, 2, "gray"], [6, 8, 2, "yellow"], [1, 4, 1, "gray"], [2, 5, 1, "green"],
  ],
  ticketDefs: [
    [0, 8, 10], [1, 6, 9], [7, 3, 10], [9, 8, 8], [0, 6, 9], [7, 6, 11], [1, 8, 8],
  ],
};

const BERLIN: GameMapDef = {
  id: "berlin", name: "Berlin",
  cities: [
    { name: "Spandau", x: 0.10, y: 0.24 }, { name: "Charlottenburg", x: 0.26, y: 0.28 },
    { name: "Mitte", x: 0.44, y: 0.26 }, { name: "Prenzlauer Berg", x: 0.52, y: 0.20 },
    { name: "Friedrichshain", x: 0.58, y: 0.30 }, { name: "Kreuzberg", x: 0.48, y: 0.36 },
    { name: "Neukolln", x: 0.52, y: 0.46 }, { name: "Tempelhof", x: 0.40, y: 0.44 },
    { name: "Schoneberg", x: 0.32, y: 0.40 }, { name: "Lichtenberg", x: 0.66, y: 0.24 },
  ],
  routeDefs: [
    [0, 1, 2, "gray"], [1, 2, 2, "green"], [1, 8, 2, "yellow"], [2, 3, 1, "gray"],
    [2, 5, 1, "red"], [3, 4, 1, "blue"], [3, 9, 1, "gray"], [4, 9, 1, "orange"],
    [4, 5, 1, "gray"], [5, 6, 1, "white"], [5, 7, 1, "gray"], [7, 8, 1, "purple"],
    [6, 7, 1, "gray"], [8, 1, 1, "yellow"], [2, 4, 1, "gray"], [6, 9, 2, "green"],
  ],
  ticketDefs: [
    [0, 9, 12], [0, 6, 10], [8, 4, 9], [1, 9, 8], [0, 4, 10], [8, 9, 9], [1, 6, 8],
  ],
};

const SAN_FRANCISCO: GameMapDef = {
  id: "sanfrancisco", name: "San Francisco",
  cities: [
    { name: "Marina", x: 0.30, y: 0.10 }, { name: "North Beach", x: 0.46, y: 0.12 },
    { name: "Richmond", x: 0.14, y: 0.22 }, { name: "Nob Hill", x: 0.42, y: 0.22 },
    { name: "Financial District", x: 0.54, y: 0.22 }, { name: "Haight", x: 0.30, y: 0.32 },
    { name: "Mission", x: 0.46, y: 0.38 }, { name: "Castro", x: 0.34, y: 0.40 },
    { name: "Sunset", x: 0.18, y: 0.40 }, { name: "Bayview", x: 0.56, y: 0.50 },
  ],
  routeDefs: [
    [0, 1, 1, "gray"], [0, 3, 1, "green"], [1, 4, 1, "yellow"], [1, 3, 1, "gray"],
    [3, 4, 1, "red"], [2, 0, 2, "blue"], [2, 5, 2, "gray"], [3, 5, 1, "orange"],
    [4, 6, 1, "gray"], [5, 7, 1, "white"], [5, 8, 1, "gray"], [7, 8, 2, "purple"],
    [6, 7, 1, "gray"], [6, 9, 1, "yellow"], [4, 9, 2, "gray"], [7, 9, 2, "green"],
  ],
  ticketDefs: [
    [2, 9, 11], [8, 4, 10], [0, 9, 9], [2, 4, 8], [8, 1, 9], [0, 6, 8], [2, 6, 10],
  ],
};

// The registry. New maps are added here (and mirrored in Swift GameMap).
export const MAPS: Record<string, GameMapDef> = {
  [USA.id]: USA,
  [EUROPE.id]: EUROPE,
  [GERMANY.id]: GERMANY,
  [FRANCE.id]: FRANCE,
  [UK.id]: UK,
  [SWITZERLAND.id]: SWITZERLAND,
  [NORDIC.id]: NORDIC,
  [INDIA.id]: INDIA,
  [AFRICA.id]: AFRICA,
  [ASIA.id]: ASIA,
  [NETHERLANDS.id]: NETHERLANDS,
  [ITALY.id]: ITALY,
  [JAPAN.id]: JAPAN,
  [POLAND.id]: POLAND,
  [PENNSYLVANIA.id]: PENNSYLVANIA,
  [OLD_WEST.id]: OLD_WEST,
  [RAILS_WORLD.id]: RAILS_WORLD,
  [RAILS_LAKES.id]: RAILS_LAKES,
  [NEW_YORK.id]: NEW_YORK,
  [LONDON.id]: LONDON,
  [PARIS.id]: PARIS,
  [AMSTERDAM.id]: AMSTERDAM,
  [BERLIN.id]: BERLIN,
  [SAN_FRANCISCO.id]: SAN_FRANCISCO,
};

export const DEFAULT_MAP_ID = "usa";

export function getMap(mapId: string): GameMapDef {
  return MAPS[mapId] ?? MAPS[DEFAULT_MAP_ID];
}

export function listMaps(): { id: string; name: string }[] {
  return Object.values(MAPS).map((m) => ({ id: m.id, name: m.name }));
}

// USA exported for any callers/tests that still want the default board directly.
export const CITIES = USA_CITIES;
export const CITY_NAMES = USA_CITIES.map((c) => c.name);

export function mapCities(mapId: string = DEFAULT_MAP_ID): City[] {
  return getMap(mapId).cities;
}

export function mapRoutes(mapId: string = DEFAULT_MAP_ID): Route[] {
  return getMap(mapId).routeDefs.map(([cityA, cityB, length, color], id) => ({
    id, cityA, cityB, length, color, claimedBy: null,
  }));
}

export function ticketDeck(mapId: string = DEFAULT_MAP_ID): Ticket[] {
  return getMap(mapId).ticketDefs.map(([cityA, cityB, points], id) => ({ id, cityA, cityB, points }));
}

export function routeLabel(route: Route, mapId: string = DEFAULT_MAP_ID): string {
  const c = getMap(mapId).cities;
  return `${c[route.cityA].name} → ${c[route.cityB].name}`;
}

export function ticketLabel(ticket: Ticket, mapId: string = DEFAULT_MAP_ID): string {
  const c = getMap(mapId).cities;
  return `${c[ticket.cityA].name} → ${c[ticket.cityB].name}`;
}
