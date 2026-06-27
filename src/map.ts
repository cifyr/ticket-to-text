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

// The registry. New maps are added here (and mirrored in Swift GameMap).
export const MAPS: Record<string, GameMapDef> = {
  [USA.id]: USA,
  [EUROPE.id]: EUROPE,
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
