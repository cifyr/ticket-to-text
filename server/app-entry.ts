// Single HTTP server entrypoint for Vercel's Node builder. Bundled (with the
// engine inlined) to app.js by `npm run build:server`, so the deployed file is
// self-contained. Routes:
//   GET  /                                        -> health
//   POST /api?action=create  { playerCount, hostId, hostName }     -> { gameId, view }
//   GET  /api?action=view&id=<id>&me=<participantId>               -> view
//   POST /api?action=move    { gameId, participantId, move, name } -> view

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { Redis } from "@upstash/redis";
import {
  createGame, createLobby, getView, joinLobby, leaveLobby, setReady, startLobby, submitMove,
  MemoryStore, type Room, type Store,
} from "../src/server.ts";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Durable store: each room (lobby or game) persists under `game:<id>` so
// concurrent games survive across serverless instances. Falls back to in-memory
// until Upstash env vars are present (set when you connect the integration).
class RedisStore implements Store {
  constructor(private redis: Redis) {}
  async get(id: string): Promise<Room | undefined> {
    return (await this.redis.get<Room>(`game:${id}`)) ?? undefined;
  }
  async set(id: string, room: Room): Promise<void> {
    await this.redis.set(`game:${id}`, room, { ex: 60 * 60 * 24 * 7 }); // 7-day TTL
  }

  // Upstash REST is stateless, so WATCH/MULTI isn't viable; use a short-lived
  // per-game lock (SET NX PX) instead. Two players readying or moving at once
  // would otherwise read-then-write the same room and lose one update.
  async update(id: string, mutate: (room: Room | undefined) => Room): Promise<Room> {
    const lockKey = `lock:${id}`;
    const token = cryptoToken();
    const acquired = await this.acquire(lockKey, token);
    if (!acquired) throw new BadStateBusy(id);
    try {
      const next = mutate(await this.get(id)); // throws before write on validation errors
      await this.set(id, next);
      return next;
    } finally {
      // Compare-and-delete so we only release a lock we still own (best-effort).
      const release = `if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end`;
      try { await this.redis.eval(release, [lockKey], [token]); } catch { /* lock TTL will clear it */ }
    }
  }

  private async acquire(lockKey: string, token: string): Promise<boolean> {
    for (let attempt = 0; attempt < 40; attempt++) { // ~4s ceiling; lock held only for one get+set
      const ok = await this.redis.set(lockKey, token, { nx: true, px: 5000 });
      if (ok === "OK") return true;
      await sleep(100);
    }
    return false;
  }
}

// Signals lock contention that outlived the retry window — surfaced as a 409 so
// the client can retry (lobby polling re-fetches; a move can be re-sent).
class BadStateBusy extends Error {
  constructor(id: string) { super(`game ${id} is busy, try again`); this.name = "BadStateBusy"; }
}

function cryptoToken(): string {
  const g = globalThis as { crypto?: { randomUUID?: () => string } };
  return g.crypto?.randomUUID ? g.crypto.randomUUID() : Math.random().toString(36).slice(2);
}

function makeStore(): Store {
  const url = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;
  if (url && token) {
    console.log("store: upstash redis");
    return new RedisStore(new Redis({ url, token }));
  }
  console.log("store: in-memory (no upstash env found)");
  return new MemoryStore();
}

const store: Store = makeStore();

function send(res: ServerResponse, status: number, obj: unknown): void {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(obj));
}

function readBody(req: IncomingMessage): Promise<any> {
  return new Promise((resolve) => {
    let data = "";
    req.on("data", (c) => (data += c));
    req.on("end", () => { try { resolve(data ? JSON.parse(data) : {}); } catch { resolve({}); } });
    req.on("error", () => resolve({}));
  });
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? "/", "http://localhost");
    const action = url.searchParams.get("action");

    if (req.method === "GET" && !action) {
      send(res, 200, { ok: true, service: "ticket-to-text" });
      return;
    }
    if (req.method === "POST" && action === "create") {
      send(res, 200, await createGame(store, await readBody(req)));
      return;
    }
    if (req.method === "GET" && action === "view") {
      send(res, 200, await getView(store, String(url.searchParams.get("id")), String(url.searchParams.get("me"))));
      return;
    }
    if (req.method === "POST" && action === "move") {
      const b = await readBody(req);
      send(res, 200, await submitMove(store, b.gameId, b.participantId, b.move, b.name));
      return;
    }
    // Lobby actions
    if (req.method === "POST" && action === "create-lobby") {
      send(res, 200, await createLobby(store, await readBody(req)));
      return;
    }
    if (req.method === "POST" && action === "join") {
      const b = await readBody(req);
      send(res, 200, await joinLobby(store, b.gameId, b.participantId, b.name));
      return;
    }
    if (req.method === "POST" && action === "ready") {
      const b = await readBody(req);
      send(res, 200, await setReady(store, b.gameId, b.participantId, !!b.ready, b.name));
      return;
    }
    if (req.method === "POST" && action === "leave") {
      const b = await readBody(req);
      send(res, 200, await leaveLobby(store, b.gameId, b.participantId));
      return;
    }
    if (req.method === "POST" && action === "start") {
      const b = await readBody(req);
      send(res, 200, await startLobby(store, b.gameId, b.participantId));
      return;
    }
    send(res, 400, { error: "unknown action" });
  } catch (e: any) {
    const msg = e?.message ?? String(e);
    const conflict = /not your turn|not found|not started|host|ready|already started|2 players|busy/.test(msg);
    send(res, conflict ? 409 : 400, { error: msg });
  }
});

const port = process.env.PORT ? Number(process.env.PORT) : 3000;
server.listen(port, () => console.log(`ticket-to-text listening on ${port}`));
