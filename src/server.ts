import { applyMoveBy, assignedIndex, newGame } from "./game.ts";
import { redactFor, type PlayerView } from "./redact.ts";
import type { GameState, Move } from "./types.ts";

// Authoritative server core. Holds the full GameState; hands each device only a
// redacted PlayerView. Turn enforcement + move validation happen here, not on
// the client, so a tampered client can't cheat. Storage is pluggable (memory
// for tests; swap in Vercel KV / Upstash Redis in production).

export interface Store {
  get(id: string): GameState | undefined | Promise<GameState | undefined>;
  set(id: string, state: GameState): void | Promise<void>;
}

export class MemoryStore implements Store {
  private m = new Map<string, GameState>();
  get(id: string) { return this.m.get(id); }
  set(id: string, state: GameState) { this.m.set(id, state); }
}

export class GameNotFound extends Error {
  constructor(id: string) { super(`game ${id} not found`); this.name = "GameNotFound"; }
}

export interface CreateOpts {
  playerCount: number;
  hostId: string;
  hostName?: string;
  seed?: number;
  gameId?: string;
}

export async function createGame(store: Store, opts: CreateOpts): Promise<{ gameId: string; view: PlayerView }> {
  const seed = opts.seed ?? Math.floor(Math.random() * 0xffffffff);
  const state = newGame(seed, opts.playerCount);
  state.playerIDs[0] = opts.hostId;       // host owns seat 0
  if (opts.hostName) state.playerNames[0] = opts.hostName;
  const gameId = opts.gameId ?? cryptoId();
  await store.set(gameId, state);
  return { gameId, view: redactFor(state, 0) };
}

export async function getView(store: Store, gameId: string, participantId: string): Promise<PlayerView> {
  const state = await store.get(gameId);
  if (!state) throw new GameNotFound(gameId);
  return redactFor(state, assignedIndex(state, participantId));
}

export async function submitMove(
  store: Store, gameId: string, participantId: string, move: Move, name?: string,
): Promise<PlayerView> {
  const state = await store.get(gameId);
  if (!state) throw new GameNotFound(gameId);
  const next = applyMoveBy(state, move, participantId); // throws if not this participant's turn
  const seat = assignedIndex(next, participantId)!;
  if (name) next.playerNames[seat] = name;
  await store.set(gameId, next);
  return redactFor(next, seat);
}

function cryptoId(): string {
  // Node 19+/browsers: crypto.randomUUID. Falls back to a short random string.
  const g = globalThis as { crypto?: { randomUUID?: () => string } };
  if (g.crypto?.randomUUID) return g.crypto.randomUUID().slice(0, 8);
  return Math.random().toString(36).slice(2, 10);
}
