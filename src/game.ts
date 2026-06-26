import {
  ALL_CARDS,
  IllegalMoveError,
  ROUTE_COLORS,
  type Card,
  type DrawPick,
  type GameState,
  type Move,
  type PlayerState,
  type Route,
  type RouteColor,
} from "./types.ts";
import { mapRoutes, routeLabel, ticketDeck } from "./map.ts";
import { routePoints } from "./scoring.ts";
import { mulberry32, shuffle } from "./rng.ts";

export const STARTING_HAND = 4;
export const STARTING_TICKETS = 3;
export const STARTING_TRAINS = 45;
export const MARKET_SIZE = 5;
export const FINAL_TRAIN_THRESHOLD = 2;
export const MAX_DRAW = 2;
const CARDS_PER_COLOR = 12;
const LOCOMOTIVES = 14;

function buildDeck(seed: number): Card[] {
  const flat: Card[] = [];
  for (const color of ROUTE_COLORS) for (let i = 0; i < CARDS_PER_COLOR; i++) flat.push(color);
  for (let i = 0; i < LOCOMOTIVES; i++) flat.push("locomotive");
  return shuffle(flat, mulberry32(seed));
}

// Draw the top card, reshuffling the discard pile in deterministically when the
// deck runs out (both devices share state, so the reshuffle is reproducible).
function drawTop(state: GameState): Card | undefined {
  if (state.deck.length === 0) {
    if (state.discard.length === 0) return undefined;
    state.deck = shuffle(state.discard, mulberry32((state.deckSeed + state.discard.length) >>> 0));
    state.discard = [];
  }
  return state.deck.pop();
}

function refillMarket(state: GameState): void {
  while (state.market.length < MARKET_SIZE) {
    const c = drawTop(state);
    if (c === undefined) break;
    state.market.push(c);
  }
}

export function newGame(seed = 0xc0ffee, playerCount = 2): GameState {
  const count = Math.max(2, Math.min(4, playerCount));
  const deck = buildDeck(seed);
  const draw = (n: number): Card[] => deck.splice(deck.length - n, n);
  const tDeck = shuffle(ticketDeck(), mulberry32((seed ^ 0x9e3779b9) >>> 0));

  const players: PlayerState[] = [];
  for (let i = 0; i < count; i++) {
    players.push({
      hand: draw(STARTING_HAND),
      tickets: tDeck.splice(0, STARTING_TICKETS),
      trains: STARTING_TRAINS,
      score: 0,
    });
  }

  const state: GameState = {
    routes: mapRoutes(),
    players,
    currentPlayer: 0,
    deck,
    discard: [],
    market: [],
    ticketDeck: tDeck,
    finalTurnsLeft: null,
    over: false,
    deckSeed: seed,
    playerIDs: Array(count).fill(null),
    playerNames: Array(count).fill(null),
    moveCount: 0,
    log: [],
    lastActor: null,
    lastSummary: null,
    lastClaimedRouteId: null,
    lastPublicDraw: [],
    pendingTickets: null,
  };
  refillMarket(state);
  return state;
}

// --- Claiming --------------------------------------------------------------

function colorCount(hand: Card[], color: RouteColor): number {
  return hand.filter((c) => c === color).length;
}
function locoCount(hand: Card[]): number {
  return hand.filter((c) => c === "locomotive").length;
}

// The color a gray route should be paid with to use the fewest locomotives.
function bestGrayColor(hand: Card[]): RouteColor {
  let best: RouteColor = ROUTE_COLORS[0];
  let bestCount = -1;
  for (const c of ROUTE_COLORS) {
    const n = colorCount(hand, c);
    if (n > bestCount) { bestCount = n; best = c; }
  }
  return best;
}

// A double route's parallel track: same city pair, different id. Only one of a
// pair may ever be claimed, so a claimed sibling locks the other.
export function siblingClaimed(state: GameState, route: Route): boolean {
  return state.routes.some((r) =>
    r.id !== route.id && r.claimedBy !== null &&
    ((r.cityA === route.cityA && r.cityB === route.cityB) ||
     (r.cityA === route.cityB && r.cityB === route.cityA)));
}

export function canClaim(state: GameState, route: Route, player: number): boolean {
  if (route.claimedBy !== null) return false;
  if (siblingClaimed(state, route)) return false;
  const p = state.players[player];
  if (p.trains < route.length) return false;
  const loco = locoCount(p.hand);
  if (route.color === "gray") {
    return ROUTE_COLORS.some((c) => colorCount(p.hand, c) + loco >= route.length);
  }
  return colorCount(p.hand, route.color) + loco >= route.length;
}

function payColorFor(state: GameState, route: Route, player: number, chosen?: RouteColor): RouteColor {
  if (route.color !== "gray") return route.color;
  if (chosen) return chosen;
  return bestGrayColor(state.players[player].hand);
}

// --- Moves -----------------------------------------------------------------

function applyClaim(state: GameState, routeId: number, chosen?: RouteColor): Route {
  const p = state.currentPlayer;
  const route = state.routes.find((r) => r.id === routeId);
  if (!route) throw new IllegalMoveError(`no route with id ${routeId}`);
  if (route.claimedBy !== null) throw new IllegalMoveError(`route ${routeId} already claimed`);
  if (siblingClaimed(state, route)) throw new IllegalMoveError(`parallel route to ${routeId} already claimed`);
  if (state.players[p].trains < route.length) throw new IllegalMoveError("not enough trains");

  const payColor = payColorFor(state, route, p, chosen);
  const hand = state.players[p].hand;
  const have = colorCount(hand, payColor);
  const useColor = Math.min(have, route.length);
  const useLoco = route.length - useColor;
  if (locoCount(hand) < useLoco) {
    throw new IllegalMoveError(`not enough ${payColor}/locomotive cards for route ${routeId}`);
  }

  let color = useColor, loco = useLoco;
  state.players[p].hand = hand.filter((c) => {
    if (c === payColor && color > 0) { color--; state.discard.push(c); return false; }
    if (c === "locomotive" && loco > 0) { loco--; state.discard.push(c); return false; }
    return true;
  });
  route.claimedBy = p;
  state.players[p].trains -= route.length;
  state.players[p].score += routePoints(route.length);
  return route;
}

function applyDraw(state: GameState, picks: DrawPick[]): Card[] {
  if (picks.length < 1 || picks.length > MAX_DRAW) {
    throw new IllegalMoveError(`must draw 1-${MAX_DRAW} cards`);
  }
  const hand = state.players[state.currentPlayer].hand;

  // Market slots are resolved against the snapshot the player saw (no refill
  // between picks), so indices stay stable for the UI.
  const slots = picks.flatMap((p) => (p.from === "market" ? [p.slot] : []));
  if (new Set(slots).size !== slots.length) throw new IllegalMoveError("duplicate market slot");
  for (const slot of slots) {
    if (slot < 0 || slot >= state.market.length) throw new IllegalMoveError(`invalid market slot ${slot}`);
    if (state.market[slot] === "locomotive" && picks.length !== 1) {
      throw new IllegalMoveError("taking a face-up locomotive uses your whole turn");
    }
  }
  const drawn: Card[] = slots.map((s) => state.market[s]);
  for (const s of [...slots].sort((a, b) => b - a)) state.market.splice(s, 1);

  for (const pick of picks) {
    if (pick.from === "blind") {
      const card = drawTop(state);
      if (card === undefined) throw new IllegalMoveError("no cards left to draw");
      drawn.push(card);
    }
  }
  hand.push(...drawn);
  refillMarket(state);
  return drawn;
}

function applyDrawTickets(state: GameState): number {
  if (state.ticketDeck.length === 0) throw new IllegalMoveError("no tickets left");
  const drawn = state.ticketDeck.splice(0, STARTING_TICKETS);
  // Held in a pending choice; the player keeps >= 1 and the turn waits.
  state.pendingTickets = { player: state.currentPlayer, drawn };
  return drawn.length;
}

function applyKeepTickets(state: GameState, keep: number[]): number {
  const pending = state.pendingTickets;
  if (!pending) throw new IllegalMoveError("no tickets to keep");
  if (pending.player !== state.currentPlayer) throw new IllegalMoveError("not your tickets");
  const drawnIds = new Set(pending.drawn.map((t) => t.id));
  const keepSet = new Set(keep.filter((id) => drawnIds.has(id)));
  if (keepSet.size < 1) throw new IllegalMoveError("keep at least one ticket");
  const kept = pending.drawn.filter((t) => keepSet.has(t.id));
  const returned = pending.drawn.filter((t) => !keepSet.has(t.id));
  state.players[pending.player].tickets.push(...kept);
  state.ticketDeck.push(...returned); // returned cards go to the bottom of the deck
  state.pendingTickets = null;
  return kept.length;
}

function endOfTurn(state: GameState): void {
  // With double routes one of each pair stays null forever, so "all claimed"
  // means every route is either claimed or blocked by a claimed sibling.
  if (state.routes.every((r) => r.claimedBy !== null || siblingClaimed(state, r))) {
    state.over = true;
    return;
  }
  if (state.finalTurnsLeft === null) {
    if (state.players[state.currentPlayer].trains <= FINAL_TRAIN_THRESHOLD) {
      state.finalTurnsLeft = state.players.length; // each player, incl. this one, gets one final turn
    }
  } else {
    state.finalTurnsLeft -= 1;
    if (state.finalTurnsLeft <= 0) state.over = true;
  }
  if (!state.over) state.currentPlayer = (state.currentPlayer + 1) % state.players.length;
}

// Reveals only public info: face-up market picks (everyone saw them); blind
// draws are reported as a count so a player's hand stays hidden.
function describeDraw(marketCards: Card[], blindCount: number): string {
  if (marketCards.length === 0) return `drew ${blindCount} card${blindCount === 1 ? "" : "s"} from the deck`;
  const took = `took ${marketCards.join(", ")}`;
  if (blindCount === 0) return took;
  return `${took} and drew ${blindCount} from the deck`;
}

export function applyMove(state: GameState, move: Move): GameState {
  if (isGameOver(state)) throw new IllegalMoveError("game is already over");
  // A pending ticket draw must be resolved before anything else.
  if (state.pendingTickets && move.kind !== "keepTickets") {
    throw new IllegalMoveError("keep at least one of your drawn tickets first");
  }
  const next: GameState = structuredClone(state);
  const actor = next.currentPlayer;

  let summary: string;
  let claimedId: number | null = null;
  let publicDraw: Card[] = [];
  let advance = true; // a pending ticket draw keeps the turn open
  switch (move.kind) {
    case "drawCards": {
      const marketCards = move.picks.flatMap((p) => (p.from === "market" ? [next.market[p.slot]] : []));
      const blindCount = move.picks.filter((p) => p.from === "blind").length;
      applyDraw(next, move.picks);
      summary = describeDraw(marketCards, blindCount);
      publicDraw = marketCards;
      break;
    }
    case "claim": {
      const route = applyClaim(next, move.routeId, move.color);
      summary = `claimed ${routeLabel(route)}`;
      claimedId = route.id;
      break;
    }
    case "drawTickets": {
      const n = applyDrawTickets(next);
      summary = `drew ${n} destination tickets`;
      advance = false; // wait for the keep/discard choice
      break;
    }
    case "keepTickets": {
      const n = applyKeepTickets(next, move.keep);
      summary = `kept ${n} destination ticket${n === 1 ? "" : "s"}`;
      break;
    }
  }

  next.lastActor = actor;
  next.lastSummary = summary;
  next.lastClaimedRouteId = claimedId;
  next.lastPublicDraw = publicDraw;
  next.log.push({ actor, text: summary });
  next.moveCount += 1;

  if (advance) endOfTurn(next);
  return next;
}

// --- Queries ---------------------------------------------------------------

export function canDraw(state: GameState): boolean {
  return state.market.length > 0 || state.deck.length > 0 || state.discard.length > 0;
}

export function legalMoves(state: GameState): Move[] {
  const moves: Move[] = [];
  if (canDraw(state)) moves.push({ kind: "drawCards", picks: [{ from: "blind" }] });
  for (const route of state.routes) {
    if (canClaim(state, route, state.currentPlayer)) moves.push({ kind: "claim", routeId: route.id });
  }
  if (state.ticketDeck.length > 0) moves.push({ kind: "drawTickets" });
  return moves;
}

export function isGameOver(state: GameState): boolean {
  return state.over || state.routes.every((r) => r.claimedBy !== null) || legalMoves(state).length === 0;
}

// --- Turn identity ---------------------------------------------------------

export function assignedIndex(state: GameState, participantID: string): number | null {
  const i = state.playerIDs.indexOf(participantID);
  return i === -1 ? null : i;
}

export function actingIndex(state: GameState, participantID: string): number | null {
  const assigned = assignedIndex(state, participantID);
  if (assigned !== null) return assigned;
  if (state.playerIDs[state.currentPlayer] === null) return state.currentPlayer;
  return null;
}

export function canAct(state: GameState, participantID: string): boolean {
  return !isGameOver(state) && actingIndex(state, participantID) === state.currentPlayer;
}

export function applyMoveBy(state: GameState, move: Move, participantID: string): GameState {
  const seat = actingIndex(state, participantID);
  if (seat === null || seat !== state.currentPlayer) {
    throw new IllegalMoveError("it is not your turn");
  }
  const seated: GameState = structuredClone(state);
  seated.playerIDs[seat] = participantID;
  return applyMove(seated, move);
}

export { ALL_CARDS };
