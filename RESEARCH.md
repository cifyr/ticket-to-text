# Ticket to Text — Feasibility & Prototype Plan

A turn-based "claim train routes" game playable inside iMessage, GamePigeon-style.

---

## 1. The core technical reality (read this first)

A GamePigeon-style game is **not** a web app and **not** a chatbot. It is a native
**iOS app with an iMessage app extension target**, written in **Swift**, using Apple's
**Messages framework** (`Messages.framework`). GamePigeon itself was built exactly this
way (single developer, Vitalii Zlotskii, shipped Sept 2016 alongside iOS 10).

There is no API to "send iMessages programmatically" from a server. The only sanctioned
way to put interactive game bubbles into a real iMessage thread is an app extension that
Apple's Messages app loads inside the conversation. This has hard requirements:

- A **Mac** running **Xcode** (you have macOS — good).
- **Swift** (+ a little SwiftUI/UIKit). This is the main gap: your stack is Node/Python/Bash.
- **Apple Developer Program** membership (**$99/year**) to ship to the App Store. You can
  build and run on *your own* device for free with a personal team, but provisioning
  profiles expire every 7 days and you can't distribute.
- Distribution is App Store only (plus TestFlight for beta testers, up to ~100 internal /
  10,000 external). No sideloading for real users.

**Bottom line:** this is feasible for one person — GamePigeon proves it — but the prototype
is a Swift/Xcode project, not a JS project. Budget time to learn enough Swift, or treat the
Swift starter in §7 as scaffolding to extend.

---

## 2. Why Ticket to Ride is actually a *great* fit

Ticket to Ride is **asynchronous turn-based** with a small, serializable state. That maps
perfectly onto how iMessage games work:

- `MSSession` links a series of messages into **one updating bubble** — each turn replaces
  the prior bubble instead of spamming the thread. This is the mechanic every GamePigeon
  game uses.
- `MSMessage` carries a **`URL` payload** — you encode the entire game state into URL query
  parameters (`URLComponents`). The opponent's extension decodes it, shows the board, lets
  them move, re-encodes, and sends it back.
- No game server required for v1. The **state travels inside the message**. Two phones pass
  a baton. (You'd only need a backend for anti-cheat, large state, or matchmaking — not for
  a prototype.)

The fit is strong enough that the main risk is **scope**, not architecture (see §4).

---

## 3. Legal note — do not literally clone Ticket to Ride

"Ticket to Ride" is a trademark of **Days of Wonder / Asmodee**, and the specific board,
art, and name are protected. Game *mechanics* (claiming routes, drawing colored cards,
secret destination tickets, longest-route bonus) are **not** copyrightable, but the name,
map, and artwork are.

For a shippable prototype: keep the mechanics, **rename it** (working title here:
"Ticket to Text" / "Railbaron" / "Track Stars"), draw an **original map** (a fictional or
public-domain real geography), and make original art. This is the same line every "inspired
by" board game app walks.

---

## 4. Scope the prototype HARD (this is the real challenge)

Full Ticket to Ride is heavy: ~30 cities, ~78 routes, destination tickets, 5 card colors +
locomotives, longest-path scoring. Building all of that *and* learning Swift *and* the
Messages framework at once will stall. Cut to a **minimum playable loop** first:

**Prototype v0 ("does the loop work?")** — prove state round-trips through iMessage:
- A tiny map: ~6 cities, ~8 routes (a graph you can draw with lines + circles).
- One resource: a hand of colored train cards (4 colors, no locomotives yet).
- Turn = either *draw 2 cards* or *claim 1 route* (if you hold enough matching cards).
- Score = sum of claimed route lengths. No destination tickets yet.
- Win when the route deck/board is exhausted or a player passes a points threshold.

If v0's bubble correctly updates back and forth between two devices, the hard part is done.

**v1 adds the flavor:** destination tickets (secret goals), locomotive wildcards, longest-
route bonus, a real ~15-city map, art, sounds, end-game scoring screen.

---

## 5. Architecture of the prototype

```
TicketToText.xcodeproj
├─ TicketToText/                (host app — minimal; just an App Store shell + how-to)
└─ MessagesExtension/           (the actual game)
   ├─ MessagesViewController    (MSMessagesAppViewController subclass — entry point)
   ├─ Game/
   │  ├─ GameState.swift        (Codable model: board, hands, scores, whose turn)
   │  ├─ GameState+URL.swift    (encode/decode state <-> URL query items)
   │  ├─ Map.swift              (cities + routes graph, static for v0)
   │  └─ Rules.swift            (legal moves, claim validation, scoring)
   └─ UI/
      ├─ BoardView.swift        (draw map; tap a route to claim)
      └─ HandView.swift         (the player's cards + draw/claim buttons)
```

**The turn loop:**
1. Player A opens the extension, taps a route or "draw", `Rules` validates + mutates `GameState`.
2. `GameState` is encoded into a `URL`; an `MSMessage(session:)` is built with that URL,
   a caption ("Caden claimed Denver→Omaha"), and a rendered board snapshot as the bubble image.
3. `conversation.insert(message)` drops it in the thread; A sends it.
4. Player B taps the bubble → extension opens in expanded mode → decode URL → render board →
   B moves → encode → send. Same `MSSession`, so the bubble updates in place.

**State encoding (v0, simplest thing that works):** JSON-encode `GameState` (it's small),
base64 it, stuff it in one query param. URLs in messages can hold a few KB comfortably;
keep the model lean (ints/enums, not strings) so you never approach limits. Optimize the
encoding only if you hit a size wall.

**Key Messages-framework pieces to learn (in order):**
- `MSMessagesAppViewController` lifecycle: `willBecomeActive(with:)`, `didTransition(to:)`
  (compact vs expanded presentation), `didSelect(_ message:)`.
- `MSConversation` — `insert(_:)`, `selectedMessage`, `send(_:)`.
- `MSMessage` + `MSSession` — `init(session:)`, the `.url`, `.layout` (`MSMessageTemplateLayout`
  for caption + image), `.summaryText`.

---

## 6. Step-by-step path to a working prototype

1. **Install Xcode** (Mac App Store). Open it once, accept the license, install components.
2. **Learn just-enough Swift** (~1–2 days if you know TS): optionals, enums with associated
   values, `struct` + `Codable`, `protocol`. Skip the rest for now.
3. **New project → iMessage Application** template. This gives you the host app + extension
   targets pre-wired. Run the empty template on the **Simulator** (it has a Messages app with
   two fake conversations for testing both sides) — confirm it loads.
4. **Build v0 game logic in pure Swift first** (`GameState`, `Map`, `Rules`) with unit tests,
   *before* touching any UI. This part is just data structures and is testable headlessly —
   the part of the project closest to skills you already have.
5. **Wire the URL encode/decode** and round-trip a `GameState` through a `URL` in a test.
6. **Build `BoardView` / `HandView`** (UIKit or SwiftUI). Tap a route → call `Rules` → update.
7. **Hook up the message send/receive** in `MessagesViewController`. Test the full loop in
   the Simulator's two-sided Messages conversation.
8. **Test on two real devices** (free personal provisioning works for 7-day builds; enough
   to prove it). Then enroll in the Developer Program when you want TestFlight/App Store.

**Definition of done for the prototype:** two people on two iPhones can play a full short
game to a winner, each turn updating one shared bubble, with no crashes and no shared server.

---

## 7. Starter Swift skeleton (drop into the MessagesExtension target)

This is enough scaffolding to compile against and extend — the v0 model, URL round-trip,
and the controller hook. UI is stubbed.

```swift
// GameState.swift
import Foundation

enum CardColor: Int, Codable, CaseIterable { case red, blue, green, yellow }

struct Route: Codable, Equatable {
    let id: Int
    let cityA: Int
    let cityB: Int
    let length: Int          // also the points value
    let color: CardColor
    var claimedBy: Int?      // player index, nil = open
}

struct PlayerState: Codable {
    var hand: [CardColor]    // train cards held
    var score: Int
}

struct GameState: Codable {
    var routes: [Route]
    var players: [PlayerState]   // [0] = host, [1] = opponent
    var currentPlayer: Int
    var deckSeed: UInt64         // deterministic draw so both sides agree

    static func newGame() -> GameState {
        GameState(routes: Map.v0Routes(),
                  players: [PlayerState(hand: [], score: 0),
                            PlayerState(hand: [], score: 0)],
                  currentPlayer: 0,
                  deckSeed: 0xC0FFEE)
    }
}
```

```swift
// GameState+URL.swift
import Foundation

extension GameState {
    func encodedURL() -> URL {
        var comps = URLComponents()
        comps.scheme = "data"
        comps.host = "tickettotext"
        let json = try! JSONEncoder().encode(self)
        comps.queryItems = [URLQueryItem(name: "s",
                            value: json.base64EncodedString())]
        return comps.url!
    }

    static func decode(from url: URL) -> GameState? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = comps.queryItems?.first(where: { $0.name == "s" })?.value,
              let data = Data(base64Encoded: raw) else { return nil }
        return try? JSONDecoder().decode(GameState.self, from: data)
    }
}
```

```swift
// Rules.swift
import Foundation

enum Rules {
    static func canClaim(_ route: Route, player: PlayerState) -> Bool {
        guard route.claimedBy == nil else { return false }
        let matching = player.hand.filter { $0 == route.color }.count
        return matching >= route.length
    }

    static func claim(routeID: Int, in state: inout GameState) -> Bool {
        let p = state.currentPlayer
        guard let idx = state.routes.firstIndex(where: { $0.id == routeID }),
              canClaim(state.routes[idx], player: state.players[p]) else { return false }
        let route = state.routes[idx]
        // spend cards
        var removed = 0
        state.players[p].hand.removeAll {
            if $0 == route.color && removed < route.length { removed += 1; return true }
            return false
        }
        state.routes[idx].claimedBy = p
        state.players[p].score += route.length
        state.currentPlayer = 1 - p
        return true
    }
}
```

```swift
// MessagesViewController.swift
import Messages

class MessagesViewController: MSMessagesAppViewController {

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        let state = conversation.selectedMessage?.url
            .flatMap(GameState.decode(from:)) ?? GameState.newGame()
        presentGame(state, in: conversation)
    }

    private func presentGame(_ state: GameState, in conversation: MSConversation) {
        // TODO: instantiate BoardView/HandView with `state`; on a completed move,
        // call sendMove(newState:in:) below.
    }

    func sendMove(newState: GameState, in conversation: MSConversation) {
        let session = conversation.selectedMessage?.session ?? MSSession()
        let message = MSMessage(session: session)
        let layout = MSMessageTemplateLayout()
        layout.caption = "Your move"             // TODO: describe the actual move
        // layout.image = renderedBoardSnapshot(newState)
        message.layout = layout
        message.url = newState.encodedURL()
        message.summaryText = "Ticket to Text"
        conversation.insert(message) { error in
            if let error { print("insert failed:", error) }
        }
    }
}
```

```swift
// Map.swift — v0 tiny board
enum Map {
    static func v0Routes() -> [Route] {
        [ Route(id: 0, cityA: 0, cityB: 1, length: 2, color: .red,    claimedBy: nil),
          Route(id: 1, cityA: 1, cityB: 2, length: 3, color: .blue,   claimedBy: nil),
          Route(id: 2, cityA: 2, cityB: 3, length: 2, color: .green,  claimedBy: nil),
          Route(id: 3, cityA: 3, cityB: 4, length: 4, color: .yellow, claimedBy: nil),
          Route(id: 4, cityA: 4, cityB: 5, length: 2, color: .red,    claimedBy: nil),
          Route(id: 5, cityA: 5, cityB: 0, length: 3, color: .blue,   claimedBy: nil),
          Route(id: 6, cityA: 0, cityB: 3, length: 5, color: .green,  claimedBy: nil),
          Route(id: 7, cityA: 1, cityB: 4, length: 3, color: .yellow, claimedBy: nil) ]
    }
}
```

---

## 8. Effort & cost summary

| Item | Cost / Time |
|------|-------------|
| Mac + Xcode | You have the Mac; Xcode is free |
| Learn enough Swift | ~1–2 days (you know TS) |
| Apple Developer Program | $99/year (only needed to ship/TestFlight) |
| v0 playable loop | ~1–2 weeks part-time |
| v1 (tickets, art, full map) | another few weeks |
| Backend (matchmaking/anti-cheat) | **not needed for prototype** |

---

## 9. Alternatives if you want to avoid Swift (worse, but honest)

- **Web game shared via link in Messages.** Build the game in Next.js/React (your stack),
  host on Vercel, share a URL in the chat. You get a Messages *link preview*, not an
  in-thread interactive bubble. No app-store gatekeeping, fast to build, but it's "a website
  you texted," not a GamePigeon experience. Good for prototyping *game logic* you later port.
- **Hire/learn split.** Build and unit-test the game engine in TypeScript now (logic is
  portable), then port the model to Swift for the extension. Lets you validate the *game*
  before committing to Swift.

There is no third option that produces real interactive iMessage bubbles without a native
Messages extension. Apple does not expose iMessage to web or server code.

---

## Sources
- [How To Make An iMessage Game (And Why) — GameAnalytics](https://www.gameanalytics.com/blog/how-to-make-an-imessage-game)
- [A Deep Dive Into iOS Messages Extensions — twocentstudios](https://twocentstudios.com/2016/06/24/a-deep-dive-into-ios-messages-extensions/)
- [Building an interactive iMessage application in Swift — Bartłomiej Kozal](https://medium.com/@bartkozal/building-an-interactive-imessage-application-for-ios-10-in-swift-7da4a18bdeed)
- [Inside iMessage Extensions — Jan Kammerath](https://medium.com/@jankammerath/inside-imessage-extensions-the-quirky-world-of-apples-niche-development-tools-32520fc1f5a7)
- [Creating iMessages Apps — CODE Magazine](https://www.codemag.com/article/1703081/Creating-iMessages-Apps)
- [GamePigeon — official site](https://gamepigeonapp.com/)
- [GamePigeon — Grokipedia (history/architecture)](https://grokipedia.com/page/GamePigeon)
