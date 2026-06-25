import { test } from "node:test";
import assert from "node:assert/strict";

import {
  createGame, createLobby, getView, joinLobby, MemoryStore, setReady, startLobby, submitMove,
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
    assert.equal("tickets" in p, false, "public player has no tickets array");
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

  // B and C join (3-player game forms from who shows up).
  await joinLobby(store, gameId, "B", "Bob");
  const afterC = await joinLobby(store, gameId, "C", "Cara");
  assert.equal(afterC.members.length, 3);

  // Can't start until everyone is ready.
  await setReady(store, gameId, "A", true);
  await setReady(store, gameId, "B", true);
  let v = await setReady(store, gameId, "C", false);
  assert.equal(v.canStart, false);
  await assert.rejects(() => startLobby(store, gameId, "A"), /ready/);

  v = await setReady(store, gameId, "C", true);
  assert.equal(v.canStart, true);

  // Only the host can start.
  await assert.rejects(() => startLobby(store, gameId, "B"), /host/);

  const game = await startLobby(store, gameId, "A");
  assert.equal(game.phase, "playing");
  assert.equal(game.players.length, 3, "game sized to the 3 who joined");
  assert.equal(game.you, 0);

  // After start, the view is the game (not the lobby), and moves work.
  const cView = await getView(store, gameId, "C");
  assert.equal(cView.phase, "playing");
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
