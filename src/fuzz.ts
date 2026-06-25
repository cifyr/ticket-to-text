// Plays many random full games (2-4 players, many seeds) and asserts engine
// invariants hold after every move. Catches rare states unit tests miss.
//   run: npm run fuzz

import { applyMove, canClaim, isGameOver, newGame } from "./game.ts";
import { finalScores } from "./scoring.ts";
import { mulberry32 } from "./rng.ts";
import type { GameState, Move } from "./types.ts";

const TOTAL_CARDS = 8 * 12 + 14; // 110
const TOTAL_TICKETS = 30;

function randomMove(state: GameState, rnd: () => number): Move {
  const choices: Move[] = [];
  const claimable = state.routes.filter((r) => canClaim(state, r, state.currentPlayer));
  if (claimable.length) {
    choices.push({ kind: "claim", routeId: claimable[Math.floor(rnd() * claimable.length)].id });
  }
  if (state.market.length > 0) {
    choices.push({ kind: "drawCards", picks: [{ from: "market", slot: Math.floor(rnd() * state.market.length) }] });
  }
  if (state.deck.length + state.discard.length > 0) {
    choices.push({ kind: "drawCards", picks: [{ from: "blind" }] });
  }
  if (state.ticketDeck.length > 0) choices.push({ kind: "drawTickets" });
  return choices[Math.floor(rnd() * choices.length)];
}

function checkInvariants(s: GameState, label: string): void {
  const n = s.players.length;
  const cards =
    s.deck.length + s.discard.length + s.market.length +
    s.players.reduce((a, p) => a + p.hand.length, 0);
  if (cards !== TOTAL_CARDS) throw new Error(`${label}: card count ${cards} != ${TOTAL_CARDS}`);

  const tickets = s.ticketDeck.length + s.players.reduce((a, p) => a + p.tickets.length, 0);
  if (tickets !== TOTAL_TICKETS) throw new Error(`${label}: ticket count ${tickets} != ${TOTAL_TICKETS}`);

  if (s.currentPlayer < 0 || s.currentPlayer >= n) throw new Error(`${label}: bad currentPlayer ${s.currentPlayer}`);
  for (const r of s.routes) {
    if (r.claimedBy !== null && (r.claimedBy < 0 || r.claimedBy >= n)) {
      throw new Error(`${label}: route ${r.id} bad owner ${r.claimedBy}`);
    }
  }
  for (const p of s.players) {
    if (p.trains < 0 || p.trains > 45) throw new Error(`${label}: trains ${p.trains} out of range`);
    if (p.score < 0) throw new Error(`${label}: negative score`);
  }
}

let games = 0, moves = 0;
for (let seed = 1; seed <= 300; seed++) {
  for (const count of [2, 3, 4]) {
    const rnd = mulberry32(seed * 31 + count);
    let s = newGame(seed, count);
    checkInvariants(s, `seed ${seed} c${count} init`);
    let guard = 0;
    while (!isGameOver(s) && guard++ < 5000) {
      s = applyMove(s, randomMove(s, rnd));
      checkInvariants(s, `seed ${seed} c${count} move ${guard}`);
      moves++;
    }
    if (guard >= 5000) throw new Error(`seed ${seed} c${count} did not terminate`);
    const scores = finalScores(s);
    if (scores.length !== count || scores.some((sc) => !Number.isFinite(sc.total))) {
      throw new Error(`seed ${seed} c${count} bad final scores`);
    }
    games++;
  }
}

console.log(`OK: ${games} games, ${moves} moves, all invariants held.`);
