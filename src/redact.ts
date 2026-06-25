import { isGameOver } from "./game.ts";
import { finalScores, type FinalScore } from "./scoring.ts";
import type { Card, GameState, LogEntry, Route, Ticket } from "./types.ts";

// What every player is allowed to see about another player.
export interface PublicPlayer {
  name: string | null;
  score: number;
  trains: number;
  handCount: number;   // count only — never the actual cards
  ticketCount: number; // count only — never the actual tickets
  joined: boolean;
}

// The redacted, per-player view sent over the wire. Crucially this contains NO
// other player's hand/tickets and NO deck/ticket-deck ordering — only the
// requesting seat's own secrets. This is what makes the server cheat-proof.
// Pre-game lobby roster (everyone sees who has joined and who is ready).
export interface LobbyMemberView {
  name: string | null;
  ready: boolean;
  isHost: boolean;
}
export interface LobbyView {
  phase: "lobby";
  you: number | null; // your index in the lobby, or null if you haven't joined
  maxPlayers: number;
  members: LobbyMemberView[];
  canStart: boolean;
}

export interface PlayerView {
  phase: "playing";
  you: number | null; // your seat, or null if you're a spectator / not yet joined
  currentPlayer: number;
  over: boolean;
  players: PublicPlayer[];
  routes: Route[];          // public
  market: Card[];           // public (face-up)
  deckCount: number;        // count only — order hidden
  discardCount: number;
  ticketDeckCount: number;  // count only — contents hidden
  yourHand: Card[];         // only yours
  yourTickets: Ticket[];    // only yours
  log: LogEntry[];
  lastActor: number | null;
  lastSummary: string | null;
  lastClaimedRouteId: number | null;
  lastPublicDraw: Card[];
  finalScores: FinalScore[] | null;
}

export function redactFor(state: GameState, seat: number | null): PlayerView {
  const over = isGameOver(state);
  return {
    phase: "playing",
    you: seat,
    currentPlayer: state.currentPlayer,
    over,
    players: state.players.map((p, i) => ({
      name: state.playerNames[i] ?? null,
      score: p.score,
      trains: p.trains,
      handCount: p.hand.length,
      ticketCount: p.tickets.length,
      joined: state.playerIDs[i] != null,
    })),
    routes: state.routes,
    market: state.market,
    deckCount: state.deck.length,
    discardCount: state.discard.length,
    ticketDeckCount: state.ticketDeck.length,
    yourHand: seat != null ? state.players[seat].hand : [],
    yourTickets: seat != null ? state.players[seat].tickets : [],
    log: state.log,
    lastActor: state.lastActor,
    lastSummary: state.lastSummary,
    lastClaimedRouteId: state.lastClaimedRouteId,
    lastPublicDraw: state.lastPublicDraw,
    finalScores: over ? finalScores(state) : null,
  };
}
