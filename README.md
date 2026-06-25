# Ticket to Text

A turn-based train-route game playable inside iMessage (GamePigeon-style), built
as a native iOS Messages app extension. A faithful Ticket to Ride-style ruleset
runs on a shared TypeScript/Swift engine, with an optional cheat-proof
server-authoritative backend deployed on Vercel.

> Original route network, map data, and art — not affiliated with or endorsed by
> Days of Wonder / Asmodee. Game *mechanics* are not copyrightable; the name,
> board, and artwork here are original.

## What's inside

- **Full US/Canada map** — 36 cities, ~76 route segments, 30 destination tickets.
- **Faithful rules** — 8 colors + wild locomotives, gray (any-color) routes, the
  standard route-length scoring table, 45 train cars with a final-round trigger,
  secret destination tickets (scored/penalized at game end), and the
  longest-route bonus. 2–4 players.
- **iMessage extension** — a pan/zoom board with tap-a-route-to-see-its-cost,
  card market draw flow, tickets sheet, move log, last-move recap, editable
  player names, haptics/sounds.
- **Two networking modes** (`ios/MessagesExtension/Net/AppConfig.swift`):
  - *Offline* — the full game state rides inside the `MSMessage` payload.
  - *Online* — the message carries only a `gameId`; each device fetches its own
    **redacted view** from the server and submits moves there, so hands and the
    deck never leave the server (cheat-proof).

## Layout

```
src/                     TypeScript engine (source of truth + tests)
  types.ts, map.ts, rng.ts, game.ts, scoring.ts   game engine
  redact.ts, server.ts                            authoritative server core
  *.test.ts                                        unit tests (node --test)
  fuzz.ts, demo.ts, livetest.ts                    harnesses
ios/
  App/                   host app shell (SwiftUI)
  MessagesExtension/
    Engine/              Swift port of the engine (1:1 with src/)
    Net/                 GameClient, PlayerView, AppConfig, display adapter
    UI/                  board, game view, sheets, recap, scoring
  Tools/                 icon generator, headless engine/net checks
server/
  app-entry.ts           HTTP server (bundled to app.js for Vercel)
  README.md              server architecture + deploy notes
app.js                   built server bundle (deploy artifact)
project.yml              XcodeGen project spec
RESEARCH.md              feasibility study + prototype plan
```

## Build & run the app

Requires macOS + Xcode + [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
npm run ios:gen      # generate TicketToText.xcodeproj from project.yml
npm run ios:build    # build for the iOS Simulator
npm run ios:run      # install on the booted sim + open Messages
```

In the Simulator's Messages app: open a conversation → apps row → Ticket to Text.

## Tests

```sh
npm test             # engine + server + scoring unit tests (node --test)
npm run fuzz         # random full games (2-4p), invariant checks
npm run ios:enginecheck   # the shipping Swift engine, headless
npm run livetest     # full games end-to-end against the live server
npm run demo         # auto-played sample game (console)
```

The TypeScript engine is the spec; the Swift engine is a 1:1 port verified by
`ios:enginecheck`. `livetest` exercises the deployed Vercel + Upstash stack.

## Server (online mode)

Deployed on Vercel as a single Node server; per-player redaction and turn
validation are authoritative. Games persist in Upstash Redis under `game:<id>`.

```sh
npm run build:server      # bundle server/app-entry.ts -> app.js
vercel deploy --prod
```

To enable online mode in the app: set `AppConfig.useServer = true`, ensure the
Vercel project has Deployment Protection off (or set `AppConfig.bypassToken`),
then rebuild. See `server/README.md` for details.

## Status

Engine, server, redaction, persistence, and the Swift client are verified by the
test suites above. The only path exercised by hand (not automated) is the literal
two-Apple-ID Messages handoff on physical devices.
