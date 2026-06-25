// Detailed integration test against the LIVE deployed server (Vercel + Upstash).
// Plays full 2/3/4-player games to completion over HTTP, asserting redaction,
// turn enforcement, persistence, concurrency, scoring, and error handling.
//   run: node src/livetest.ts [baseURL]

import type { Card, RouteColor } from "./types.ts";

const BASE = process.argv[2] ?? "https://ticket-to-text.vercel.app";
const COLORS: RouteColor[] = ["red", "orange", "yellow", "green", "blue", "purple", "white", "black"];

let checks = 0;
function ok(cond: boolean, msg: string) {
  checks++;
  if (!cond) throw new Error("ASSERT FAILED: " + msg);
}

async function api(method: string, action: string, opts: { query?: Record<string, string>; body?: unknown } = {}) {
  const url = new URL(BASE + "/api");
  url.searchParams.set("action", action);
  for (const [k, v] of Object.entries(opts.query ?? {})) url.searchParams.set(k, v);
  const res = await fetch(url, {
    method,
    headers: opts.body ? { "content-type": "application/json" } : {},
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await res.text();
  let json: any;
  try { json = JSON.parse(text); } catch { json = { _raw: text }; }
  return { status: res.status, json };
}

// What the acting player (from their own view) can afford right now.
function affordableRoutes(view: any): number[] {
  const hand: Card[] = view.yourHand;
  const loco = hand.filter((c) => c === "locomotive").length;
  const trains = view.you != null ? view.players[view.you].trains : 0;
  const count = (c: RouteColor) => hand.filter((x) => x === c).length;
  return view.routes
    .filter((r: any) => r.claimedBy === null && r.length <= trains && (
      r.color === "gray"
        ? COLORS.some((c) => count(c) + loco >= r.length)
        : count(r.color as RouteColor) + loco >= r.length
    ))
    .map((r: any) => r.id);
}

function assertRedacted(view: any, label: string) {
  ok(!("deck" in view), `${label}: no deck array in view`);
  ok(!("discard" in view), `${label}: no discard array`);
  ok(!("ticketDeck" in view), `${label}: no ticketDeck array`);
  ok(Array.isArray(view.yourHand), `${label}: yourHand present`);
  for (const p of view.players) {
    ok(!("hand" in p), `${label}: other player exposes no hand`);
    ok(!("tickets" in p), `${label}: other player exposes no tickets`);
    ok(typeof p.handCount === "number", `${label}: handCount is a number`);
  }
}

function chooseMove(view: any): any {
  const claims = affordableRoutes(view);
  if (claims.length && Math.random() < 0.7) return { kind: "claim", routeId: claims[(Math.random() * claims.length) | 0] };
  if (view.deckCount > 0) return { kind: "drawCards", picks: [{ from: "blind" }, { from: "blind" }] };
  if (view.market.length > 0) return { kind: "drawCards", picks: [{ from: "market", slot: 0 }] };
  if (claims.length) return { kind: "claim", routeId: claims[0] };
  if (view.ticketDeckCount > 0) return { kind: "drawTickets" };
  return null;
}

async function playGame(playerCount: number) {
  const players = Array.from({ length: playerCount }, (_, i) => `T${Date.now()}-${playerCount}-${i}`);
  const created = await api("POST", "create", { body: { playerCount, hostId: players[0], hostName: `Host${playerCount}` } });
  ok(created.status === 200, `create ${playerCount}p status`);
  const gameId = created.json.gameId;
  ok(typeof gameId === "string" && gameId.length > 0, "gameId returned");
  ok(created.json.view.you === 0, "host is seat 0");
  ok(created.json.view.routes.length === 76, `full map (76 routes), got ${created.json.view.routes.length}`);
  assertRedacted(created.json.view, "host create view");

  let turn = 0;
  let lastView = created.json.view;
  const assigned = new Set<number>([0]); // host owns seat 0 from creation
  while (!lastView.over && turn < 600) {
    const cur = lastView.currentPlayer;
    const meView = (await api("GET", "view", { query: { id: gameId, me: players[cur] } })).json;

    // Spot-check redaction + turn enforcement on the first turns and periodically.
    if (turn < 4 || turn % 25 === 0) {
      const peek = (cur + 1) % playerCount;
      const otherView = (await api("GET", "view", { query: { id: gameId, me: players[peek] } })).json;
      assertRedacted(otherView, `p${peek} view`);
      ok(otherView.yourHand.length === 0 || peek === otherView.you, "a player sees only their own hand");
      // Turn enforcement: an ALREADY-ASSIGNED player who isn't current must be
      // rejected. (An unassigned player may legitimately claim an open seat.)
      const wrong = [...assigned].find((s) => s !== cur);
      if (wrong !== undefined) {
        const reject = await api("POST", "move", { body: { gameId, participantId: players[wrong], move: { kind: "drawCards", picks: [{ from: "blind" }] } } });
        ok(reject.status === 409, `assigned out-of-turn player rejected (got ${reject.status})`);
      }
    }

    const move = chooseMove(meView);
    if (!move) break;
    const res = await api("POST", "move", { body: { gameId, participantId: players[cur], move, name: `P${cur}` } });
    ok(res.status === 200, `move status (turn ${turn}, got ${res.status}: ${JSON.stringify(res.json).slice(0, 120)})`);
    ok(res.json.currentPlayer !== undefined, "move returns a view");
    ok(res.json.players[cur].trains <= 45 && res.json.players[cur].trains >= 0, "trains in range");
    assigned.add(cur); // mover now owns seat `cur`
    lastView = res.json;
    turn++;
  }

  ok(lastView.over, `game ${playerCount}p reached game over (turns=${turn})`);
  ok(Array.isArray(lastView.finalScores) && lastView.finalScores.length === playerCount, "finalScores present for all players");
  for (const s of lastView.finalScores) ok(Number.isFinite(s.total), "finite total score");
  console.log(`  ${playerCount}-player game: ${turn} turns, scores [${lastView.finalScores.map((s: any) => s.total).join(", ")}]`);
}

async function testErrors() {
  const unknown = await api("GET", "view", { query: { id: "does-not-exist", me: "x" } });
  ok(unknown.status >= 400, `unknown game id errors (got ${unknown.status})`);
  ok(/not found/i.test(JSON.stringify(unknown.json)), "unknown game id message");

  const created = await api("POST", "create", { body: { playerCount: 2, hostId: "errHost" } });
  const gid = created.json.gameId;
  const badMove = await api("POST", "move", { body: { gameId: gid, participantId: "errHost", move: { kind: "claim", routeId: 9999 } } });
  ok(badMove.status >= 400, `invalid claim rejected (got ${badMove.status})`);
  console.log("  error handling: unknown game + invalid move both rejected");
}

async function testPersistenceAndConcurrency() {
  // Three concurrent games, interleaved moves, then read each back independently.
  const ids: string[] = [];
  for (let i = 0; i < 3; i++) {
    const c = await api("POST", "create", { body: { playerCount: 2, hostId: `host${i}`, hostName: `Host${i}` } });
    ids.push(c.json.gameId);
  }
  ok(new Set(ids).size === 3, "three distinct game ids");
  // Make one move in each (host draws).
  for (let i = 0; i < 3; i++) {
    const r = await api("POST", "move", { body: { gameId: ids[i], participantId: `host${i}`, move: { kind: "drawCards", picks: [{ from: "blind" }] }, name: `Host${i}` } });
    ok(r.status === 200, `concurrent move ${i}`);
  }
  // Read each back fresh — proves Upstash persistence + isolation.
  for (let i = 0; i < 3; i++) {
    const v = (await api("GET", "view", { query: { id: ids[i], me: `host${i}` } })).json;
    ok(v.players[0].name === `Host${i}`, `game ${i} persisted with correct host`);
    ok(v.players[0].handCount === 5, `game ${i} reflects the draw (hand 5)`);
    ok(v.currentPlayer === 1, `game ${i} turn advanced`);
  }
  console.log("  persistence + concurrency: 3 isolated games persisted and read back correctly");
}

console.log(`Live integration test against ${BASE}`);
await testErrors();
await testPersistenceAndConcurrency();
for (const pc of [2, 3, 4]) await playGame(pc);
console.log(`\nALL LIVE CHECKS PASSED (${checks} assertions)`);
