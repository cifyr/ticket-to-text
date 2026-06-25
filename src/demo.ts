// Auto-plays a full game between two greedy bots so you can eyeball the rules.
// State is encoded->decoded each turn to simulate the iMessage round-trip.
//   run: npm run demo

import { applyMove, canDraw, isGameOver, legalMoves, newGame } from "./game.ts";
import { routeLabel } from "./map.ts";
import { finalScores, finalWinner } from "./scoring.ts";
import { decodeState, encodeState } from "./serialize.ts";
import type { GameState, Move } from "./types.ts";

// Greedy: claim the longest route you can, else draw 2 cards.
function pickMove(state: GameState): Move {
  const claims = legalMoves(state).filter((m) => m.kind === "claim");
  if (claims.length > 0) {
    claims.sort((a, b) => {
      const ra = state.routes.find((r) => r.id === (a as { routeId: number }).routeId)!;
      const rb = state.routes.find((r) => r.id === (b as { routeId: number }).routeId)!;
      return rb.length - ra.length;
    });
    return claims[0];
  }
  if (canDraw(state)) return { kind: "drawCards", picks: [{ from: "blind" }, { from: "blind" }] };
  return { kind: "drawTickets" };
}

function describe(state: GameState, move: Move): string {
  const p = state.currentPlayer;
  if (move.kind === "drawCards") return `P${p} draws ${move.picks.length} cards`;
  if (move.kind === "drawTickets") return `P${p} draws tickets`;
  const route = state.routes.find((r) => r.id === move.routeId)!;
  return `P${p} claims ${routeLabel(route)} (${route.color} ${route.length})`;
}

let state = newGame(2024);
let turn = 0;
while (!isGameOver(state) && turn < 2000) {
  const move = pickMove(state);
  console.log(`turn ${++turn}: ${describe(state, move)}`);
  state = applyMove(state, move);
  state = decodeState(encodeState(state));
}

const [a, b] = finalScores(state);
const w = finalWinner(state);
console.log("---");
console.log(`P0  routes ${a.routeScore}  tickets ${a.ticketScore}  longest ${a.longestRoute}(+${a.longestBonus})  = ${a.total}`);
console.log(`P1  routes ${b.routeScore}  tickets ${b.ticketScore}  longest ${b.longestRoute}(+${b.longestBonus})  = ${b.total}`);
console.log(`routes claimed: ${state.routes.filter((r) => r.claimedBy !== null).length}/${state.routes.length}`);
console.log(w === null ? "result: tie" : `result: P${w} wins`);
