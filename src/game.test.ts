import { test } from "node:test";
import assert from "node:assert/strict";

import {
  actingIndex,
  applyMove,
  applyMoveBy,
  assignedIndex,
  canAct,
  canClaim,
  canDraw,
  isGameOver,
  legalMoves,
  newGame,
  STARTING_HAND,
  STARTING_TICKETS,
  STARTING_TRAINS,
  MARKET_SIZE,
} from "./game.ts";
import { decodeState, encodeState } from "./serialize.ts";
import {
  connected,
  finalScores,
  finalWinner,
  longestRoute,
  routePoints,
  ticketScore,
} from "./scoring.ts";
import { IllegalMoveError, type Card, type GameState, type PlayerState, type Route } from "./types.ts";

const P = (o: Partial<PlayerState> = {}): PlayerState => ({
  hand: [], tickets: [], trains: STARTING_TRAINS, score: 0, ...o,
});
const make = (o: Partial<GameState> = {}): GameState => ({
  routes: [], players: [P(), P()], currentPlayer: 0, deck: [], discard: [], market: [],
  ticketDeck: [], finalTurnsLeft: null, over: false, deckSeed: 1, playerIDs: [null, null],
  playerNames: [null, null], moveCount: 0, log: [], lastActor: null, lastSummary: null,
  lastClaimedRouteId: null, lastPublicDraw: [], ...o,
});
const openRoute = (o: Partial<Route> = {}): Route => ({
  id: 99, cityA: 0, cityB: 1, length: 2, color: "red", claimedBy: null, ...o,
});

test("newGame: deals hands, tickets, trains, fills market, reproducible by seed", () => {
  const a = newGame(42);
  assert.deepEqual(a, newGame(42), "same seed => identical");

  assert.equal(a.players[0].hand.length, STARTING_HAND);
  assert.equal(a.players[0].tickets.length, STARTING_TICKETS);
  assert.equal(a.players[0].trains, STARTING_TRAINS);
  assert.equal(a.market.length, MARKET_SIZE);
  // 8 colors x12 + 14 locomotives = 110, minus 2 hands and the market.
  assert.equal(a.deck.length, 110 - 2 * STARTING_HAND - MARKET_SIZE);
  assert.equal(a.ticketDeck.length, 30 - 2 * STARTING_TICKETS);
});

test("draw blind: adds 2 cards from deck, passes turn, doesn't touch market", () => {
  const s0 = newGame(1);
  const deck0 = s0.deck.length;
  const s1 = applyMove(s0, { kind: "drawCards", picks: [{ from: "blind" }, { from: "blind" }] });
  assert.equal(s1.players[0].hand.length, STARTING_HAND + 2);
  assert.equal(s1.deck.length, deck0 - 2);
  assert.equal(s1.market.length, MARKET_SIZE);
  assert.equal(s1.currentPlayer, 1);
});

test("draw from market: takes the card and refills the slot", () => {
  const s = make({
    routes: [openRoute()],
    market: ["red", "blue", "green", "white", "black"],
    deck: ["yellow", "orange"],
  });
  const s1 = applyMove(s, { kind: "drawCards", picks: [{ from: "market", slot: 1 }, { from: "blind" }] });
  assert.ok(s1.players[0].hand.includes("blue"));
  assert.equal(s1.market.length, MARKET_SIZE, "market refilled");
});

test("taking a face-up locomotive uses the whole turn (cannot pair with another pick)", () => {
  const s = make({
    routes: [openRoute()],
    market: ["locomotive", "red", "blue", "green", "white"],
    deck: ["yellow", "orange", "red"],
  });
  assert.throws(
    () => applyMove(s, { kind: "drawCards", picks: [{ from: "market", slot: 0 }, { from: "blind" }] }),
    /whole turn/,
  );
  const ok = applyMove(s, { kind: "drawCards", picks: [{ from: "market", slot: 0 }] });
  assert.ok(ok.players[0].hand.includes("locomotive"));
});

test("claim: locomotives substitute for color, cards go to discard, score uses TTR table", () => {
  const s = make({
    routes: [openRoute({ id: 0, length: 3, color: "red" }), openRoute({ id: 1, cityA: 1, cityB: 2, color: "blue" })],
    players: [P({ hand: ["red", "red", "locomotive", "green"] }), P()],
    deck: ["white"],
  });
  const next = applyMove(s, { kind: "claim", routeId: 0 });
  assert.equal(next.routes[0].claimedBy, 0);
  assert.equal(next.players[0].trains, STARTING_TRAINS - 3);
  assert.equal(next.players[0].score, routePoints(3)); // 4
  assert.deepEqual(next.players[0].hand, ["green"]);
  assert.equal(next.discard.filter((c: Card) => c === "red").length, 2);
  assert.equal(next.discard.filter((c: Card) => c === "locomotive").length, 1);
});

test("gray route can be claimed with any single color", () => {
  const s = make({
    routes: [openRoute({ id: 0, length: 3, color: "gray" })],
    players: [P({ hand: ["blue", "blue", "blue", "red"] }), P()],
    deck: ["white"],
  });
  assert.equal(canClaim(s, s.routes[0], 0), true);
  const next = applyMove(s, { kind: "claim", routeId: 0 });
  assert.equal(next.routes[0].claimedBy, 0);
  assert.deepEqual(next.players[0].hand, ["red"], "spent the 3 blue (fewest locomotives)");
});

test("draw tickets: pending choice, keep >= 1, rest go to bottom, then turn passes", () => {
  const s = make({
    routes: [openRoute()],
    ticketDeck: [
      { id: 0, cityA: 0, cityB: 1, points: 5 },
      { id: 1, cityA: 2, cityB: 3, points: 7 },
      { id: 2, cityA: 0, cityB: 3, points: 9 },
      { id: 9, cityA: 1, cityB: 2, points: 4 }, // stays in the deck (4th)
    ],
    deck: ["red"],
  });
  const drew = applyMove(s, { kind: "drawTickets" });
  assert.equal(drew.pendingTickets?.drawn.length, 3, "drew the top 3");
  assert.equal(drew.players[0].tickets.length, 0, "nothing kept yet");
  assert.equal(drew.currentPlayer, 0, "turn doesn't pass until you choose");

  // Must keep at least one.
  assert.throws(() => applyMove(drew, { kind: "keepTickets", keep: [] }), /at least one/);
  // Other moves are blocked while a draw is pending.
  assert.throws(() => applyMove(drew, { kind: "drawCards", picks: [{ from: "blind" }] }), /keep at least one/);

  const kept = applyMove(drew, { kind: "keepTickets", keep: [0, 2] });
  assert.equal(kept.players[0].tickets.length, 2, "kept two");
  assert.deepEqual(kept.players[0].tickets.map((t) => t.id).sort(), [0, 2]);
  assert.equal(kept.pendingTickets, null);
  assert.equal(kept.currentPlayer, 1, "now the turn passes");
  // The unkept ticket (id 1) went to the bottom, behind the leftover id 9.
  assert.deepEqual(kept.ticketDeck.map((t) => t.id), [9, 1]);
});

test("running low on trains triggers a final round, then the game ends", () => {
  const s = make({
    routes: [openRoute({ id: 0, length: 3, color: "red" }), openRoute({ id: 1, cityA: 1, cityB: 2, color: "blue" })],
    players: [P({ hand: ["red", "red", "red"], trains: 4 }), P()],
    deck: Array.from({ length: 12 }, () => "white") as Card[],
    market: ["red", "blue", "green", "yellow", "orange"],
  });
  const afterClaim = applyMove(s, { kind: "claim", routeId: 0 });
  assert.equal(afterClaim.players[0].trains, 1);
  assert.equal(afterClaim.finalTurnsLeft, 2, "each player incl. the triggerer gets one final turn");
  assert.equal(afterClaim.over, false);

  const afterOpponent = applyMove(afterClaim, { kind: "drawCards", picks: [{ from: "blind" }] });
  assert.equal(afterOpponent.over, false, "the triggering player still gets their final turn");
  assert.equal(afterOpponent.currentPlayer, 0);

  const afterFinal = applyMove(afterOpponent, { kind: "drawCards", picks: [{ from: "blind" }] });
  assert.equal(afterFinal.over, true);
  assert.equal(isGameOver(afterFinal), true);
});

test("ticket scoring: + when connected, - when not", () => {
  const s = make({
    routes: [
      openRoute({ id: 0, cityA: 0, cityB: 1, length: 2, claimedBy: 0 }),
      openRoute({ id: 1, cityA: 1, cityB: 2, length: 2, claimedBy: 0 }),
    ],
    players: [
      P({ tickets: [
        { id: 0, cityA: 0, cityB: 2, points: 10 }, // connected via 0-1-2
        { id: 1, cityA: 0, cityB: 3, points: 5 },  // not connected
      ] }),
      P(),
    ],
  });
  assert.equal(connected(s.routes.filter((r) => r.claimedBy === 0), 0, 2), true);
  assert.equal(ticketScore(s, 0), 10 - 5);
  assert.equal(longestRoute(s, 0), 4); // 2 + 2
});

test("final scoring adds tickets and the longest-route bonus", () => {
  const s = make({
    routes: [
      openRoute({ id: 0, cityA: 0, cityB: 1, length: 3, claimedBy: 0 }),
      openRoute({ id: 1, cityA: 1, cityB: 2, length: 2, claimedBy: 0 }),
    ],
    players: [
      P({ score: 6, tickets: [{ id: 0, cityA: 0, cityB: 2, points: 8 }] }),
      P({ score: 2 }),
    ],
    over: true,
  });
  const [a, b] = finalScores(s);
  assert.equal(a.total, 6 + 8 + 10, "route + ticket + longest bonus");
  assert.equal(b.longestBonus, 0);
  assert.equal(finalWinner(s), 0);
});

test("turn identity: starter owns seat 0, others blocked out of turn", () => {
  const A = "AAAA", B = "BBBB";
  const game = newGame(5);
  game.playerIDs[0] = A;
  assert.equal(canAct(game, A), true);
  assert.equal(canAct(game, B), false);
  assert.throws(() => applyMoveBy(game, { kind: "drawCards", picks: [{ from: "blind" }] }, B), /not your turn/);

  const afterA = applyMoveBy(game, { kind: "drawCards", picks: [{ from: "blind" }] }, A);
  assert.equal(afterA.currentPlayer, 1);
  assert.equal(canAct(afterA, B), true);
  const afterB = applyMoveBy(afterA, { kind: "drawCards", picks: [{ from: "blind" }] }, B);
  assert.equal(assignedIndex(afterB, B), 1);
  assert.equal(actingIndex(afterB, "CCCC"), null);
});

test("moves record a log entry, last-move summary, and claimed route id", () => {
  const s = make({
    routes: [openRoute({ id: 0, length: 3, color: "red" }), openRoute({ id: 1, cityA: 1, cityB: 2, color: "blue" })],
    players: [P({ hand: ["red", "red", "red"] }), P()],
    deck: ["white"],
  });
  const afterClaim = applyMove(s, { kind: "claim", routeId: 0 });
  assert.equal(afterClaim.lastActor, 0);
  assert.match(afterClaim.lastSummary ?? "", /claimed/);
  assert.equal(afterClaim.lastClaimedRouteId, 0);
  assert.equal(afterClaim.log.length, 1);
  assert.equal(afterClaim.moveCount, 1);

  const afterDraw = applyMove(afterClaim, { kind: "drawCards", picks: [{ from: "blind" }] });
  assert.equal(afterDraw.lastActor, 1);
  assert.match(afterDraw.lastSummary ?? "", /drew/);
  assert.equal(afterDraw.lastClaimedRouteId, null);
  assert.equal(afterDraw.log.length, 2);
});

test("supports 4 players: deals all seats and rotates turns 0->1->2->3->0", () => {
  const g = newGame(3, 4);
  assert.equal(g.players.length, 4);
  assert.equal(g.playerIDs.length, 4);
  assert.equal(g.playerNames.length, 4);
  for (const p of g.players) {
    assert.equal(p.hand.length, STARTING_HAND);
    assert.equal(p.tickets.length, STARTING_TICKETS);
  }
  let s = g;
  for (let i = 0; i < 4; i++) {
    assert.equal(s.currentPlayer, i);
    s = applyMove(s, { kind: "drawCards", picks: [{ from: "blind" }] });
  }
  assert.equal(s.currentPlayer, 0, "wraps back to player 0");
});

test("draw log never leaks blind-drawn colors (only face-up market picks)", () => {
  const s = make({
    routes: [openRoute()],
    market: ["red", "blue", "green", "white", "black"],
    deck: ["yellow", "orange"],
  });
  const blind = applyMove(s, { kind: "drawCards", picks: [{ from: "blind" }, { from: "blind" }] });
  assert.match(blind.lastSummary ?? "", /2 cards from the deck/);
  assert.doesNotMatch(blind.lastSummary ?? "", /yellow|orange/, "blind colors stay hidden");

  const market = applyMove(s, { kind: "drawCards", picks: [{ from: "market", slot: 0 }, { from: "blind" }] });
  assert.match(market.lastSummary ?? "", /took red/);   // face-up pick is public
  assert.doesNotMatch(market.lastSummary ?? "", /yellow|orange/);
});

test("deck reshuffles the discard pile when it empties", () => {
  const s = make({
    routes: [openRoute()],
    deck: [],
    discard: ["red", "blue", "green"],
    market: [],
  });
  assert.equal(canDraw(s), true);
  const next = applyMove(s, { kind: "drawCards", picks: [{ from: "blind" }] });
  // 3 discards: 1 drawn into hand, the rest refill the empty market.
  assert.equal(next.players[0].hand.length, 1);
  assert.equal(next.discard.length, 0);
  assert.equal(next.deck.length + next.market.length, 2);
});

test("gray route claimable with mostly wilds; spends color then wilds", () => {
  const s = make({
    routes: [openRoute({ id: 0, length: 3, color: "gray" })],
    players: [P({ hand: ["blue", "locomotive", "locomotive"] }), P()],
    deck: ["red"],
  });
  assert.equal(canClaim(s, s.routes[0], 0), true);
  const next = applyMove(s, { kind: "claim", routeId: 0 });
  assert.equal(next.routes[0].claimedBy, 0);
  assert.equal(next.players[0].hand.length, 0);
  assert.equal(next.discard.filter((c) => c === "locomotive").length, 2);
});

test("specific-color route claimable with only wilds", () => {
  const s = make({
    routes: [openRoute({ id: 0, length: 3, color: "red" })],
    players: [P({ hand: ["locomotive", "locomotive", "locomotive"] }), P()],
    deck: ["red"],
  });
  assert.equal(canClaim(s, s.routes[0], 0), true);
  const next = applyMove(s, { kind: "claim", routeId: 0 });
  assert.equal(next.players[0].hand.length, 0);
});

test("longest route follows the longest trail through a branch", () => {
  const s = make({
    routes: [
      openRoute({ id: 0, cityA: 0, cityB: 1, length: 2, claimedBy: 0 }),
      openRoute({ id: 1, cityA: 1, cityB: 2, length: 2, claimedBy: 0 }),
      openRoute({ id: 2, cityA: 1, cityB: 3, length: 3, claimedBy: 0 }),
    ],
  });
  assert.equal(longestRoute(s, 0), 5); // 2 (0-1) + 3 (1-3)
});

test("4-player final round gives each remaining player one last turn", () => {
  const four = [P({ hand: ["red", "red", "red"], trains: 4 }), P(), P(), P()];
  const s = make({
    players: four,
    routes: [openRoute({ id: 0, length: 3, color: "red" }), openRoute({ id: 1, cityA: 1, cityB: 2, color: "blue" })],
    deck: Array.from({ length: 20 }, () => "white") as Card[],
    market: ["red", "blue", "green", "yellow", "orange"],
    playerIDs: [null, null, null, null],
    playerNames: [null, null, null, null],
  });
  let g = applyMove(s, { kind: "claim", routeId: 0 }); // P0 drops to 1 train
  assert.equal(g.finalTurnsLeft, 4); // each player incl. P0 gets one final turn
  assert.equal(g.over, false);
  for (let i = 0; i < 3; i++) {
    g = applyMove(g, { kind: "drawCards", picks: [{ from: "blind" }] });
    assert.equal(g.over, false);
  }
  g = applyMove(g, { kind: "drawCards", picks: [{ from: "blind" }] }); // P0's final turn
  assert.equal(g.over, true);
});

test("double route: claiming one track locks the parallel one", () => {
  const s = make({
    players: [P({ hand: ["red", "red", "blue", "blue"], trains: 20 }), P({ hand: ["blue", "blue", "blue"], trains: 20 })],
    routes: [
      openRoute({ id: 0, cityA: 0, cityB: 1, length: 2, color: "red" }),
      openRoute({ id: 1, cityA: 0, cityB: 1, length: 2, color: "blue" }), // parallel track
      openRoute({ id: 2, cityA: 2, cityB: 3, length: 2, color: "gray" }),
    ],
    deck: Array.from({ length: 20 }, () => "white") as Card[],
    market: ["red", "blue", "green", "yellow", "orange"],
    playerIDs: [null, null],
    playerNames: [null, null],
  });
  const g = applyMove(s, { kind: "claim", routeId: 0 }); // P0 takes the red track
  const sibling = g.routes.find((r) => r.id === 1)!;
  assert.equal(canClaim(g, sibling, 1), false); // P1 can't take the parallel blue track
  assert.throws(() => applyMove(g, { kind: "claim", routeId: 1 }), /parallel route/);
});

test("equal totals are a tie (no winner)", () => {
  const s = make({ players: [P({ score: 5 }), P({ score: 5 })], over: true });
  assert.equal(finalWinner(s), null);
});

test("state survives the iMessage round-trip", () => {
  const s0 = newGame(7);
  const s1 = applyMove(s0, { kind: "drawCards", picks: [{ from: "blind" }, { from: "blind" }] });
  assert.deepEqual(decodeState(encodeState(s1)), s1);
});

test("a full greedy playthrough terminates with a scored result", () => {
  let state = newGame(2024);
  let guard = 0;
  while (!isGameOver(state) && guard++ < 2000) {
    const claim = legalMoves(state).find((m) => m.kind === "claim");
    if (claim) {
      state = applyMove(state, claim);
    } else if (canDraw(state)) {
      state = applyMove(state, { kind: "drawCards", picks: [{ from: "blind" }, { from: "blind" }] });
    } else {
      state = applyMove(state, { kind: "drawTickets" });
    }
    state = decodeState(encodeState(state)); // round-trip every turn
  }
  assert.ok(isGameOver(state), "game reaches a terminal state");
  assert.ok(guard < 2000, "must not loop forever");
  const [a, b] = finalScores(state);
  assert.ok(Number.isFinite(a.total) && Number.isFinite(b.total));
});
