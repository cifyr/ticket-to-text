import { test } from "node:test";
import assert from "node:assert/strict";

import {
  createGame, createLobby, endGame, getView, joinLobby, leaveLobby, MemoryStore, setReady, startLobby, submitMove,
  type Room, type Store,
} from "./server.ts";

test("host view exposes only the host's own secrets", async () => {
  const store = new MemoryStore();
  const { gameId, view } = await createGame(store, { playerCount: 2, hostId: "A", hostName: "Alice", seed: 5 });

  assert.equal(view.you, 0);
  assert.equal(view.yourHand.length, 4);
  assert.equal(view.players.length, 2);
  assert.equal(view.players[0].joined, true);
  assert.equal(view.players[1].joined, false);
  assert.equal(view.players[0].name, "Alice");

  // Redaction: no deck array, no other player's hand/tickets in the payload.
  assert.equal((view as Record<string, unknown>).deck, undefined);
  assert.equal((view as Record<string, unknown>).ticketDeck, undefined);
  for (const p of view.players) {
    assert.equal("hand" in p, false, "public player has no hand array");
    assert.equal(p.tickets.length, 0, "tickets stay hidden until the game is over");
    assert.equal(typeof p.handCount, "number");
  }
  assert.ok(typeof view.deckCount === "number");
  assert.ok(gameId.length > 0);
});

test("an opponent's view never contains the host's actual cards", async () => {
  const store = new MemoryStore();
  const { gameId } = await createGame(store, { playerCount: 2, hostId: "A", hostName: "Alice", seed: 9 });

  // Host plays; then B opens. B's view must not reveal A's hand or the deck.
  await submitMove(store, gameId, "A", { kind: "drawCards", picks: [{ from: "blind" }] }, "Alice");
  const bView = await getView(store, gameId, "B");

  // B isn't seated yet -> no own hand, and certainly not A's.
  assert.equal(bView.you, null);
  assert.deepEqual(bView.yourHand, []);
  const serialized = JSON.stringify(bView);
  assert.equal(serialized.includes('"deck"'), false);
  // The only card arrays in the view are the public market and B's own (empty) hand.
  assert.equal(bView.market.length, 5);
});

test("server enforces turns: a non-current participant is rejected", async () => {
  const store = new MemoryStore();
  const { gameId } = await createGame(store, { playerCount: 2, hostId: "A", seed: 1 });

  await assert.rejects(
    () => submitMove(store, gameId, "B", { kind: "drawCards", picks: [{ from: "blind" }] }),
    /not your turn/,
  );

  const afterA = await submitMove(store, gameId, "A", { kind: "drawCards", picks: [{ from: "blind" }] });
  assert.equal(afterA.currentPlayer, 1);

  // Now B may move and is assigned seat 1 with their name.
  const afterB = await submitMove(store, gameId, "B", { kind: "drawCards", picks: [{ from: "blind" }] }, "Bob");
  assert.equal(afterB.you, 1);
  assert.equal(afterB.players[1].name, "Bob");
  assert.equal(afterB.players[1].joined, true);
});

test("unknown game id is reported clearly", async () => {
  const store = new MemoryStore();
  await assert.rejects(() => getView(store, "nope", "A"), /not found/);
});

test("lobby: players join, ready up, host starts; sizes to the join count", async () => {
  const store = new MemoryStore();
  const { gameId, view } = await createLobby(store, { hostId: "A", hostName: "Alice" });
  assert.equal(view.phase, "lobby");
  assert.equal(view.members.length, 1);
  assert.equal(view.you, 0);
  assert.equal(view.members[0].isHost, true);
  assert.equal(view.canStart, false);

  // B and C join; C never readies.
  await joinLobby(store, gameId, "B", "Bob");
  await joinLobby(store, gameId, "C", "Cara");

  // Can't start until at least 2 are ready (only readied players are in).
  await setReady(store, gameId, "A", true);
  let v = await getView(store, gameId, "A");
  assert.equal(v.canStart, false, "one ready isn't enough");
  await assert.rejects(() => startLobby(store, gameId, "A"), /ready/);
  v = await setReady(store, gameId, "B", true);
  assert.equal(v.canStart, true);

  // Only the host can start.
  await assert.rejects(() => startLobby(store, gameId, "B"), /host/);

  // C never readied, so the game forms from the 2 ready players only.
  const game = await startLobby(store, gameId, "A");
  assert.equal(game.phase, "playing");
  assert.equal(game.players.length, 2, "game sized to the 2 ready players");
  assert.equal(game.you, 0);

  // The unready player isn't in the game.
  const cView = await getView(store, gameId, "C");
  assert.equal(cView.phase, "playing");
  assert.equal(cView.you, null, "C was left behind");
});

test("lobby: readying up also joins you", async () => {
  const store = new MemoryStore();
  const { gameId } = await createLobby(store, { hostId: "A", hostName: "Alice" });
  const v = await setReady(store, gameId, "Z", true, "Zoe"); // never joined first
  assert.equal(v.members.length, 2);
  assert.equal(v.members[1].name, "Zoe");
  assert.equal(v.members[1].ready, true);
});

test("lobby: moving before start is rejected; lobby respects max players", async () => {
  const store = new MemoryStore();
  const { gameId } = await createLobby(store, { hostId: "H", maxPlayers: 2 });
  await assert.rejects(
    () => submitMove(store, gameId, "H", { kind: "drawCards", picks: [{ from: "blind" }] }),
    /not started/,
  );
  await joinLobby(store, gameId, "X");
  const full = await joinLobby(store, gameId, "Y"); // exceeds max 2 -> ignored
  assert.equal(full.members.length, 2);
});

test("lobby: host can't start unless the host is ready (no self-spectating)", async () => {
  const store = new MemoryStore();
  const { gameId } = await createLobby(store, { hostId: "A", hostName: "Alice" });
  await setReady(store, gameId, "B", true, "Bob");
  await setReady(store, gameId, "C", true, "Cara");
  // Two non-hosts are ready but the host never readied: starting must be refused.
  await assert.rejects(() => startLobby(store, gameId, "A"), /host/);

  // Once the host readies, the start succeeds and the host gets seat 0.
  await setReady(store, gameId, "A", true);
  const game = await startLobby(store, gameId, "A");
  assert.equal(game.you, 0, "host is a player, not a spectator");
  assert.equal(game.players.length, 3);
});

// A stand-in for the Redis store: get/set really await, so a mutator that did its
// own read-then-write would interleave and lose an update. store.update must
// serialize, like the production distributed lock does.
class AsyncStore implements Store {
  private m = new Map<string, Room>();
  private chain: Promise<unknown> = Promise.resolve();
  private tick() { return new Promise<void>((r) => setTimeout(r, 0)); }
  async get(id: string) { await this.tick(); return this.m.get(id); }
  async set(id: string, room: Room) { await this.tick(); this.m.set(id, room); }
  update(id: string, mutate: (room: Room | undefined) => Room): Promise<Room> {
    const run = this.chain.then(async () => {
      await this.tick();
      const next = mutate(this.m.get(id));
      await this.tick();
      this.m.set(id, next);
      return next;
    });
    this.chain = run.catch(() => {});
    return run;
  }
}

test("concurrent readies don't clobber each other (atomic update)", async () => {
  const store = new AsyncStore();
  const { gameId } = await createLobby(store, { hostId: "A", hostName: "Alice" });
  // Three players ready up simultaneously against an awaiting store.
  await Promise.all([
    setReady(store, gameId, "B", true, "Bob"),
    setReady(store, gameId, "C", true, "Cara"),
    setReady(store, gameId, "D", true, "Dee"),
  ]);
  const v = await getView(store, gameId, "A");
  assert.equal(v.phase, "lobby");
  if (v.phase !== "lobby") return;
  assert.equal(v.members.length, 4, "no readied player was lost to a race");
  assert.equal(v.members.filter((m) => m.ready).length, 3);
});

test("concurrent leave + join stay consistent (atomic update)", async () => {
  const store = new AsyncStore();
  const { gameId } = await createLobby(store, { hostId: "A" });
  await joinLobby(store, gameId, "B");
  await Promise.all([
    leaveLobby(store, gameId, "B"),
    joinLobby(store, gameId, "C"),
  ]);
  const v = await getView(store, gameId, "A");
  if (v.phase !== "lobby") { assert.fail("expected lobby"); return; }
  assert.equal(v.members.length, 2, "A and C remain after B leaves");
  assert.equal(v.members[0].isHost, true, "host seat is intact");
});

test("endGame: any participant ends the game for everyone; next view shows it over", async () => {
  const store = new MemoryStore();
  const { gameId } = await createGame(store, { playerCount: 2, hostId: "A", hostName: "Alice", seed: 7 });
  // Seat B by taking a turn after A, so B is a real participant.
  await submitMove(store, gameId, "A", { kind: "drawCards", picks: [{ from: "blind" }] }, "Alice");
  await submitMove(store, gameId, "B", { kind: "drawCards", picks: [{ from: "blind" }] }, "Bob");

  // The non-host (B) ends it.
  const ended = await endGame(store, gameId, "B");
  assert.equal(ended.over, true, "ender's view is over");
  assert.ok(ended.finalScores, "final scores tallied");

  // Everyone else sees it over too, with tickets revealed.
  const aView = await getView(store, gameId, "A");
  if (aView.phase !== "playing") { assert.fail("expected playing view"); return; }
  assert.equal(aView.over, true, "other player sees the game as over");
  assert.equal(ended.lastSummary, "ended the game");
});

test("endGame: rejected before the game has started (lobby)", async () => {
  const store = new MemoryStore();
  const { gameId } = await createLobby(store, { hostId: "A", hostName: "Alice" });
  await assert.rejects(() => endGame(store, gameId, "A"), /not started/);
});

test("map selection: lobby's mapId threads into the started game's view; unknown falls back", async () => {
  const store = new MemoryStore();
  const { gameId } = await createLobby(store, { hostId: "A", hostName: "Alice", mapId: "usa" });
  await setReady(store, gameId, "A", true);
  await setReady(store, gameId, "B", true, "Bob");
  const game = await startLobby(store, gameId, "A");
  if (game.phase !== "playing") { assert.fail("expected playing"); return; }
  assert.equal(game.mapId, "usa", "started game reports its map");

  // Unknown ids are validated against the registry and fall back to the default.
  const { gameId: g2 } = await createLobby(store, { hostId: "C", mapId: "atlantis" });
  const v2 = await getView(store, g2, "C");
  if (v2.phase !== "lobby") { assert.fail("expected lobby"); return; }
  assert.equal(v2.mapId, "usa", "invalid map falls back to the default");
});
