// Faithful Ticket-to-Ride-style model. Mirrors the Swift engine. Whole state is
// JSON-serializable so it can ride inside an iMessage payload.

// The 8 route/card colors plus the wild "locomotive".
export const ROUTE_COLORS = [
  "red", "orange", "yellow", "green", "blue", "purple", "white", "black",
] as const;
export type RouteColor = (typeof ROUTE_COLORS)[number];

export type Card = RouteColor | "locomotive";
export const ALL_CARDS: Card[] = [...ROUTE_COLORS, "locomotive"];

// "gray" routes accept any single color (locomotives still substitute).
export type RoutePaint = RouteColor | "gray";

export interface Route {
  id: number;
  cityA: number;
  cityB: number;
  length: number;
  color: RoutePaint;
  claimedBy: number | null;
}

export interface Ticket {
  id: number;
  cityA: number;
  cityB: number;
  points: number;
}

export interface PlayerState {
  hand: Card[];
  tickets: Ticket[];
  trains: number; // remaining train cars
  score: number;  // running route score; tickets + bonus added at game end
}

export interface LogEntry {
  actor: number; // player index
  text: string;  // name-neutral, e.g. "claimed Denver → Dallas" or "drew red, blue"
}

export interface GameState {
  mapId: string;       // which board this game uses (see src/map.ts registry)
  routes: Route[];
  players: PlayerState[]; // 2-4
  currentPlayer: number;
  deck: Card[];        // face-down draw pile
  discard: Card[];     // spent cards; reshuffled into deck when it empties
  market: Card[];      // 5 face-up cards
  ticketDeck: Ticket[];
  finalTurnsLeft: number | null; // set when a player's trains run low
  over: boolean;
  deckSeed: number;
  playerIDs: (string | null)[];
  playerNames: (string | null)[];
  moveCount: number;
  log: LogEntry[];
  lastActor: number | null;          // who made the most recent move
  lastSummary: string | null;        // what they did (name-neutral)
  lastClaimedRouteId: number | null; // set when the last move claimed a route
  lastPublicDraw: Card[];            // face-up cards taken last move (public; blind draws excluded)
  pendingTickets: PendingTickets | null; // mid-turn: drawn tickets awaiting keep/discard
}

// After drawing destination tickets the player must keep >= 1; the rest go to
// the bottom of the deck. The turn doesn't advance until they choose.
export interface PendingTickets {
  player: number;
  drawn: Ticket[];
}

// One face-up market slot or a blind draw from the deck.
export type DrawPick = { from: "market"; slot: number } | { from: "blind" };

export type Move =
  | { kind: "drawCards"; picks: DrawPick[] }       // take up to 2 train cards
  | { kind: "claim"; routeId: number; color?: RouteColor } // color = chosen paint for gray
  | { kind: "drawTickets" }                         // draw destination tickets (then keep >= 1)
  | { kind: "keepTickets"; keep: number[] };        // resolve a pending ticket draw

export class IllegalMoveError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "IllegalMoveError";
  }
}
