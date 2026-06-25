// Single HTTP server entrypoint for Vercel's Node builder. Bundled (with the
// engine inlined) to app.js by `npm run build:server`, so the deployed file is
// self-contained. Routes:
//   GET  /                                        -> health
//   POST /api?action=create  { playerCount, hostId, hostName }     -> { gameId, view }
//   GET  /api?action=view&id=<id>&me=<participantId>               -> view
//   POST /api?action=move    { gameId, participantId, move, name } -> view

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { Redis } from "@upstash/redis";
import { createGame, getView, submitMove, MemoryStore, type Store } from "../src/server.ts";
import type { GameState } from "../src/types.ts";

// Durable store: each game persists under `game:<id>` so concurrent games
// survive across serverless instances. Falls back to in-memory until Upstash
// env vars are present (set automatically when you connect the integration).
class RedisStore implements Store {
  constructor(private redis: Redis) {}
  async get(id: string): Promise<GameState | undefined> {
    return (await this.redis.get<GameState>(`game:${id}`)) ?? undefined;
  }
  async set(id: string, state: GameState): Promise<void> {
    await this.redis.set(`game:${id}`, state, { ex: 60 * 60 * 24 * 7 }); // 7-day TTL
  }
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
    send(res, 400, { error: "unknown action; use create | view | move" });
  } catch (e: any) {
    const msg = e?.message ?? String(e);
    send(res, /not your turn|not found/.test(msg) ? 409 : 400, { error: msg });
  }
});

const port = process.env.PORT ? Number(process.env.PORT) : 3000;
server.listen(port, () => console.log(`ticket-to-text listening on ${port}`));
