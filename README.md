# Ticket to Text

A turn-based train-route board game you play **inside iMessage** — GamePigeon-style —
built as a native iOS Messages app extension. A faithful *Ticket to Ride*-style
ruleset runs on a single game engine written once in TypeScript and ported 1:1 to
Swift, backed by an optional cheat-proof, server-authoritative online mode on Vercel.

You and your friends pass the game back and forth as message bubbles: each turn is a
move, the board snapshot renders right in the thread, and tapping a game's bubble drops
you straight back into it.

> **Not affiliated with or endorsed by Days of Wonder / Asmodee.** Game *mechanics*
> aren't copyrightable; the name, map, route network, and artwork in this project are
> all original.

---

## Highlights

- **Plays inside the Messages app** — a native `MSMessagesAppViewController` extension
  with a pan/zoom board, a real US/Canada map, card market, destination tickets, move
  log, last-move recap, and haptics. No separate app to open.
- **One engine, two languages** — the rules live in TypeScript (`src/`) as the source of
  truth, and are ported 1:1 to Swift (`ios/MessagesExtension/Engine/`). A headless
  cross-checker (`npm run ios:enginecheck`) proves the Swift port matches the spec, so
  the server and the device can never disagree about a game.
- **Cheat-proof online mode** — the message carries only a `gameId`. Each device fetches
  its **own redacted view** from the server; your opponents' hands and the draw deck
  never leave the backend. All turn and move validation is server-authoritative.
- **Offline mode too** — flip one flag and the entire game state rides inside the
  `MSMessage` URL payload, no server required.
- **Multiple concurrent games per chat** — each game is its own message thread, selected
  by which bubble you tap. End a game for everyone, or start a fresh one from the app
  toolbar.
- **Faithful ruleset** — 8 train colors + wild locomotives, gray (any-color) routes,
  double routes (only one side claimable), the standard route-length scoring table, 45
  train cars with the final-round trigger, secret destination tickets (scored or
  penalized at game end), and the longest-route bonus. 2–4 players.

## How it works

**The Messages extension.** iMessage games aren't web apps or bots — there's no API to
send messages from a server. The only sanctioned path is an app extension that Apple's
Messages app loads inside the conversation. Ticket to Text ships as a standalone
*messages application* (an icon-less host whose only job is to carry the extension), so
it installs and updates like any App Store app.

**The shared engine.** Writing the rules twice is a recipe for desync, so instead the
TypeScript engine is the spec and the Swift engine is a mechanical port. `enginecheck`
compiles the shipping Swift engine and runs the same invariant suite against it —
identical route ordering, scoring, longest-path search, and redaction. The server sends
route IDs and colors; the app submits route IDs; they line up because both come from the
same ordered map.

**Cheat-proof state.** In online mode the server holds the full game and hands each
player a `PlayerView` containing only their own secrets (`redactFor(state, seat)`). The
deck order and other players' hands are never serialized into anything a client receives,
so a curious player inspecting the payload learns nothing. A short-lived per-game lock in
Upstash Redis keeps concurrent readies/joins/moves from clobbering each other.

```
                 ┌─────────────────────────┐
   tap a bubble  │  Messages app extension │   submit move (gameId + move)
  ───────────────▶  (Swift engine + UI)    ├──────────────┐
                 └─────────────────────────┘              ▼
                              ▲                  ┌───────────────────┐
        redacted PlayerView   │                  │  Vercel (app.js)  │
        (your secrets only)   └──────────────────┤  authoritative    │
                                                 │  engine + redact  │
                                                 └─────────┬─────────┘
                                                           ▼
                                                  Upstash Redis (game:<id>)
```

## Repository layout

```
src/                     TypeScript engine — source of truth + tests
  types.ts map.ts rng.ts game.ts scoring.ts   game engine
  redact.ts server.ts                         authoritative server core
  *.test.ts                                    unit tests (node --test)
  fuzz.ts demo.ts livetest.ts                  harnesses
ios/
  App/                   host app shell (standalone messages-app stub)
  MessagesExtension/
    Engine/              Swift port of the engine (1:1 with src/)
    Net/                 GameClient, PlayerView, AppConfig, display adapter
    UI/                  board, game view, sheets, recap, scoring
  Tools/                 icon generator, headless engine/net checkers
server/
  app-entry.ts           HTTP server (bundled to app.js for Vercel)
  README.md              server architecture + deploy notes
app.js                   built server bundle (deploy artifact)
project.yml              XcodeGen project spec
RESEARCH.md              the original feasibility study + prototype plan
```

## Tech stack

Swift / SwiftUI · Apple Messages framework · TypeScript · Node.js · Vercel · Upstash
Redis · esbuild · XcodeGen.

## Build & run the app

Requires macOS + Xcode + [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
npm run ios:gen      # generate TicketToText.xcodeproj from project.yml
npm run ios:build    # build for the iOS Simulator
npm run ios:run      # install on the booted sim + open Messages
```

In the Simulator's Messages app: open a conversation → the apps row → Ticket to Text.

## Tests

```sh
npm test                  # engine + server + scoring unit tests (node --test)
npm run fuzz              # random full games (2-4p), invariant checks
npm run ios:enginecheck   # the shipping Swift engine, headless, vs. the spec
npm run livetest          # full games end-to-end against the live server
npm run demo             # auto-played sample game (console)
```

The TypeScript engine is the spec; the Swift engine is a 1:1 port verified by
`ios:enginecheck`. `livetest` exercises the deployed Vercel + Upstash stack.

## Server (online mode)

A single Node server deployed on Vercel; per-player redaction and turn validation are
authoritative. Games persist in Upstash Redis under `game:<id>` with a 7-day TTL.

```sh
npm run build:server      # bundle server/app-entry.ts -> app.js
vercel deploy --prod
```

To enable online mode in the app, set `AppConfig.useServer = true` (in
`ios/MessagesExtension/Net/AppConfig.swift`) and rebuild. See `server/README.md` for the
full architecture and deploy notes.

## License

Code is released under the [MIT License](LICENSE). The disclaimer above still applies:
this is an original implementation inspired by a genre of board game, not a copy of any
publisher's assets.
