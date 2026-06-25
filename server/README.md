# Ticket to Text — authoritative server (DEPLOYED, cheat-proof hidden info)

The full `GameState` lives server-side; each device only ever receives a
**redacted `PlayerView`** of its own secrets. The deck order and other players'
hands/tickets never leave the server. Move legality + turn order are enforced
server-side, so a tampered client can't cheat.

## Status

- **Deployed** to Vercel: project `ticket-to-text` (team caden-7895's projects),
  single Node server `app.js`. Latest production deployment:
  `https://ticket-to-text-qsz0juse7-caden-7895s-projects.vercel.app`
  (the stable production alias is on the Vercel dashboard / `vercel ls`).
- **Verified live** end-to-end (curl + the Swift `GameClient`): create returns
  the host's hand; an opponent's view has `you=null`, `yourHand=[]`, no `deck`
  key, and only counts for other players; out-of-turn moves get `409`.
- **Swift client implemented**: `ios/MessagesExtension/Net/GameClient.swift` +
  `PlayerView.swift`, proven against the live server (`ios/Tools/netcheck`).

## One decision needed from you (security)

The deployment has **Deployment Protection (Vercel Authentication)** on, so the
app can't call it yet. I did not disable it on my own (that loosens access).
Pick one:

1. **Disable protection** — Vercel dashboard → project → Settings → Deployment
   Protection → Vercel Authentication → Disabled. Simplest; makes the API public.
2. **Protection Bypass for Automation** — same settings page → generate a secret.
   Keep protection on; the app sends it. `GameClient` already supports this via
   its `bypassToken` (sent as the `x-vercel-protection-bypass` header).

## Architecture

- `src/redact.ts` — `redactFor(state, seat)` → `PlayerView` (own secrets only).
- `src/server.ts` — `createGame` / `getView` / `submitMove` (+ `Store` interface,
  `MemoryStore`). `submitMove` calls `applyMoveBy`, rejecting wrong-turn moves.
- `server/app-entry.ts` — HTTP server, bundled to `app.js` by `npm run build:server`.

## Endpoints

- `POST /api?action=create  { playerCount, hostId, hostName }` → `{ gameId, view }`
- `GET  /api?action=view&id=<id>&me=<participantId>` → `view`
- `POST /api?action=move    { gameId, participantId, move, name }` → `view`

## Redeploy after engine changes

```
npm run build:server   # re-bundle app.js (engine inlined)
vercel deploy --prod --yes
```

## Storage (durability)

`MemoryStore` is shared only within a warm instance — fine for a casual game,
but two phones can hit different instances. For real durability, swap in Upstash
Redis (Vercel Marketplace) behind the `Store` interface — no other code changes.

## App wiring (DONE — behind a flag)

The extension is wired for both modes. In `ios/MessagesExtension/Net/AppConfig.swift`:

```swift
static let useServer = false   // flip to true for cheat-proof online mode
```

When `useServer == true`:
- New game → `GameClient.create`; the `MSMessage` carries only `{ g: gameId }`.
- Open a received game → `GameClient.view(gameId, me)`; the redacted `PlayerView`
  is adapted to the existing UI via `PlayerView.displayState(localID:)`.
- Each action → `GameClient.move(...)`; the new view re-renders and a gameId
  message is staged. Hands/deck never travel through Messages.

Verified live (`ios/Tools/netcheck`): create/view/move + redaction + turn
enforcement + the displayState adapter, against the deployed full-map server (76
routes). NOT yet device-tested in the Messages UI.

### To go live
1. Turn off Deployment Protection (above) — or set `AppConfig.bypassToken`.
2. Set `AppConfig.useServer = true`, rebuild the app.
3. Test on two devices / Apple IDs.
