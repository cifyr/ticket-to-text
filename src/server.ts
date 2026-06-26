import { applyMoveBy, assignedIndex, newGame } from "./game.ts";
import { redactFor, type LobbyView, type PlayerView } from "./redact.ts";
import type { GameState, Move } from "./types.ts";

// Authoritative server core. A room is either a pre-game lobby or a running
// game. Clients only ever receive a redacted view; turn/move validation and
// seating happen here. Storage is pluggable (memory for tests; Redis in prod).

export interface LobbyMember { id: string; name: string | null; ready: boolean }
export interface Lobby { members: LobbyMember[]; maxPlayers: number; hostId: string; seed: number }
export type Room = { kind: "lobby"; lobby: Lobby } | { kind: "game"; game: GameState };

export interface Store {
  get(id: string): Room | undefined | Promise<Room | undefined>;
  set(id: string, room: Room): void | Promise<void>;
  // Atomic read-modify-write. `mutate` runs with exclusive access to this id (a
  // distributed lock in Redis; trivially atomic in single-threaded memory), so
  // concurrent joins/readies/moves can't clobber each other. Throwing from
  // `mutate` aborts the write and propagates the error.
  update(id: string, mutate: (room: Room | undefined) => Room): Promise<Room>;
}

export class MemoryStore implements Store {
  private m = new Map<string, Room>();
  get(id: string) { return this.m.get(id); }
  set(id: string, room: Room) { this.m.set(id, room); }
  // The whole read-mutate-write runs synchronously, so nothing can interleave.
  async update(id: string, mutate: (room: Room | undefined) => Room): Promise<Room> {
    const next = mutate(this.m.get(id));
    this.m.set(id, next);
    return next;
  }
}

export class GameNotFound extends Error {
  constructor(id: string) { super(`game ${id} not found`); this.name = "GameNotFound"; }
}
export class BadState extends Error {}

function cryptoId(): string {
  const g = globalThis as { crypto?: { randomUUID?: () => string } };
  if (g.crypto?.randomUUID) return g.crypto.randomUUID().slice(0, 8);
  return Math.random().toString(36).slice(2, 10);
}

function lobbyViewFor(lobby: Lobby, participantId: string): LobbyView {
  const youIdx = lobby.members.findIndex((m) => m.id === participantId);
  return {
    phase: "lobby",
    you: youIdx === -1 ? null : youIdx,
    maxPlayers: lobby.maxPlayers,
    members: lobby.members.map((m, i) => ({ name: m.name, ready: m.ready, isHost: i === 0 })),
    canStart: lobby.members.filter((m) => m.ready).length >= 2, // only readied players are in
  };
}

// --- Lobby ----------------------------------------------------------------

export async function createLobby(
  store: Store, opts: { hostId: string; hostName?: string; maxPlayers?: number; seed?: number; gameId?: string },
): Promise<{ gameId: string; view: LobbyView }> {
  const maxPlayers = Math.max(2, Math.min(4, opts.maxPlayers ?? 4));
  const lobby: Lobby = {
    members: [{ id: opts.hostId, name: opts.hostName ?? null, ready: false }],
    maxPlayers,
    hostId: opts.hostId,
    seed: opts.seed ?? Math.floor(Math.random() * 0xffffffff),
  };
  const gameId = opts.gameId ?? cryptoId();
  await store.set(gameId, { kind: "lobby", lobby });
  return { gameId, view: lobbyViewFor(lobby, opts.hostId) };
}

function lobbyOf(room: Room | undefined, gameId: string): Lobby {
  if (!room) throw new GameNotFound(gameId);
  if (room.kind !== "lobby") throw new BadState("game already started");
  return room.lobby;
}

export async function joinLobby(store: Store, gameId: string, participantId: string, name?: string): Promise<LobbyView> {
  const room = await store.update(gameId, (room) => {
    const lobby = lobbyOf(room, gameId);
    const existing = lobby.members.find((m) => m.id === participantId);
    if (existing) {
      if (name) existing.name = name;
    } else if (lobby.members.length < lobby.maxPlayers) {
      lobby.members.push({ id: participantId, name: name ?? null, ready: false });
    }
    return { kind: "lobby", lobby };
  });
  return lobbyViewFor(lobbyOf(room, gameId), participantId);
}

export async function setReady(store: Store, gameId: string, participantId: string, ready: boolean, name?: string): Promise<LobbyView> {
  const room = await store.update(gameId, (room) => {
    const lobby = lobbyOf(room, gameId);
    let me = lobby.members.find((m) => m.id === participantId);
    if (!me) {
      // Readying up also joins you: that's the only way into a game now.
      if (lobby.members.length >= lobby.maxPlayers) throw new BadState("lobby is full");
      me = { id: participantId, name: name ?? null, ready: false };
      lobby.members.push(me);
    }
    if (name) me.name = name;
    me.ready = ready;
    return { kind: "lobby", lobby };
  });
  return lobbyViewFor(lobbyOf(room, gameId), participantId);
}

export async function leaveLobby(store: Store, gameId: string, participantId: string): Promise<LobbyView> {
  const room = await store.update(gameId, (room) => {
    const lobby = lobbyOf(room, gameId);
    const i = lobby.members.findIndex((m) => m.id === participantId);
    if (i !== -1) lobby.members.splice(i, 1);
    // If the host left, the next remaining member inherits hosting.
    if (lobby.members.length > 0) lobby.hostId = lobby.members[0].id;
    return { kind: "lobby", lobby };
  });
  return lobbyViewFor(lobbyOf(room, gameId), participantId);
}

export async function startLobby(store: Store, gameId: string, participantId: string): Promise<PlayerView> {
  const room = await store.update(gameId, (room) => {
    const lobby = lobbyOf(room, gameId);
    if (participantId !== lobby.hostId) throw new BadState("only the host can start");
    // Only readied members make it into the game; everyone else is left behind.
    const ready = lobby.members.filter((m) => m.ready);
    if (ready.length < 2) throw new BadState("need at least 2 ready players");
    // The host is the one starting and expects a seat: refuse to start unless the
    // host readied, else they'd be dropped and become a spectator of their own game.
    if (!ready.some((m) => m.id === lobby.hostId)) throw new BadState("host must be ready to start");

    const game = newGame(lobby.seed, ready.length);
    ready.forEach((m, i) => { game.playerIDs[i] = m.id; game.playerNames[i] = m.name; });
    return { kind: "game", game };
  });
  if (room.kind !== "game") throw new BadState("game has not started");
  return redactFor(room.game, assignedIndex(room.game, participantId));
}

// --- Game -----------------------------------------------------------------

export async function createGame(
  store: Store, opts: { playerCount: number; hostId: string; hostName?: string; seed?: number; gameId?: string },
): Promise<{ gameId: string; view: PlayerView }> {
  const seed = opts.seed ?? Math.floor(Math.random() * 0xffffffff);
  const state = newGame(seed, opts.playerCount);
  state.playerIDs[0] = opts.hostId;
  if (opts.hostName) state.playerNames[0] = opts.hostName;
  const gameId = opts.gameId ?? cryptoId();
  await store.set(gameId, { kind: "game", game: state });
  return { gameId, view: redactFor(state, 0) };
}

export async function getView(store: Store, gameId: string, participantId: string): Promise<LobbyView | PlayerView> {
  const room = await store.get(gameId);
  if (!room) throw new GameNotFound(gameId);
  if (room.kind === "lobby") return lobbyViewFor(room.lobby, participantId);
  return redactFor(room.game, assignedIndex(room.game, participantId));
}

export async function submitMove(
  store: Store, gameId: string, participantId: string, move: Move, name?: string,
): Promise<PlayerView> {
  const room = await store.update(gameId, (room) => {
    if (!room) throw new GameNotFound(gameId);
    if (room.kind !== "game") throw new BadState("game has not started");
    const next = applyMoveBy(room.game, move, participantId);
    if (name) next.playerNames[assignedIndex(next, participantId)!] = name;
    return { kind: "game", game: next };
  });
  if (room.kind !== "game") throw new BadState("game has not started");
  const seat = assignedIndex(room.game, participantId)!;
  return redactFor(room.game, seat);
}
