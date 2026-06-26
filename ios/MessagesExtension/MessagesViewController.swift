import UIKit
import SwiftUI
import Messages

// Entry point Apple loads inside a Messages conversation. Two modes:
//  - Offline (AppConfig.useServer == false): full GameState rides in the message.
//  - Online (true): the message carries only a gameId; each device fetches its
//    own redacted PlayerView from the server and submits moves there (cheat-proof).
class MessagesViewController: MSMessagesAppViewController {

    private var hosting: UIHostingController<AnyView>?
    private var displayState: GameState?
    private var serverGameId: String?
    private var serverError: String?
    private var loading = false
    private var lobby: LobbyView?
    private var session: MSSession?   // shared so invite -> game is one bubble
    private var pollTask: Task<Void, Never>?

    // TEMP on-screen diagnostics (visible in TestFlight) to trace the join flow.
    private var diagLog: [String] = []
    private func diag(_ s: String) {
        diagLog.append(s)
        if diagLog.count > 6 { diagLog.removeFirst(diagLog.count - 6) }
    }

    private func currentSession(_ c: MSConversation) -> MSSession {
        let s = c.selectedMessage?.session ?? session ?? MSSession()
        session = s
        return s
    }
    private lazy var client = GameClient(baseURL: AppConfig.serverBaseURL, bypassToken: AppConfig.bypassToken)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Restore a name saved on a previous install (keychain survives reinstalls).
        if (UserDefaults.standard.string(forKey: "playerName") ?? "").isEmpty, let n = NameStore.load() {
            UserDefaults.standard.set(n, forKey: "playerName")
        }
        let parchment = UIColor(red: 0xF2 / 255, green: 0xE8 / 255, blue: 0xD5 / 255, alpha: 1) // matches Palette.parchment
        view.backgroundColor = parchment
        let host = UIHostingController(rootView: AnyView(Color.clear))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = parchment
        view.addSubview(host.view)
        host.didMove(toParent: self)
        hosting = host
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        let sel = conversation.selectedMessage
        diag("WBA sel=\(sel != nil) url=\(sel?.url?.absoluteString ?? "nil") remote=\(conversation.remoteParticipantIdentifiers.count)")
        if AppConfig.useServer {
            loadServer(conversation)
        } else {
            displayState = decodedLocal(from: conversation)
            render(for: conversation)
        }
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        if let conversation = activeConversation { render(for: conversation) }
    }

    // Fires when the user taps a bubble while the extension is ALREADY active
    // (willBecomeActive only fires on a cold activation). Without this, a player
    // sitting in their own lobby who taps someone else's invite never switches to
    // it — they stay host of their own room and the two can't join each other.
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        diag("didSelect url=\(message.url?.absoluteString ?? "nil")")
        guard AppConfig.useServer else {
            if let url = message.url, let state = Serialize.decode(from: url) {
                displayState = state
                render(for: conversation)
            }
            return
        }
        guard let url = message.url, let gid = gameId(from: url) else { return }
        if gid == serverGameId, lobby != nil || displayState != nil { return } // already here
        serverGameId = gid
        rememberGame(gid)
        stopPolling()
        lobby = nil
        displayState = nil
        fetchRoom(gid, conversation) // tapped invite always wins over a stale local room
    }

    override func willResignActive(with conversation: MSConversation) {
        super.willResignActive(with: conversation)
        stopPolling()
    }

    // Live lobby without sending messages: poll the server while the lobby is
    // open so joins/readies (and the host starting) appear automatically.
    private func startLobbyPolling(_ gid: String, _ c: MSConversation) {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled, let self, self.serverGameId == gid, self.lobby != nil else { return }
                do {
                    switch try await self.client.room(gameId: gid, me: self.localID(c)) {
                    case .lobby(let lv):
                        self.lobby = lv; self.render(for: c)
                    case .game(let pv): // host started — drop into the game
                        self.lobby = nil
                        self.displayState = pv.displayState(localID: self.localID(c))
                        self.render(for: c)
                        return
                    }
                } catch { /* transient network error; keep polling */ }
            }
        }
    }
    private func stopPolling() { pollTask?.cancel(); pollTask = nil }

    // MARK: Identity / settings

    private func localID(_ c: MSConversation) -> String {
        #if DEBUG
        if let alt = DebugIdentity.overrideID() { return alt }
        #endif
        return c.localParticipantIdentifier.uuidString
    }
    private func localName() -> String? {
        #if DEBUG
        if let alt = DebugIdentity.overrideName() { return alt } // don't touch the real saved name
        #endif
        let n = UserDefaults.standard.string(forKey: "playerName")?.trimmingCharacters(in: .whitespaces)
        let name = (n?.isEmpty == false) ? n : nil
        if let name, name != NameStore.load() { NameStore.save(name) } // mirror to keychain
        return name
    }

    #if DEBUG
    // Test-only: become the next account and reload the current room as them.
    private func switchIdentity() {
        DebugIdentity.cycle()
        guard let c = activeConversation else { return }
        if AppConfig.useServer { loadServer(c) } else { render(for: c) }
    }
    #endif
    private func localPlayerCount() -> Int {
        let n = UserDefaults.standard.integer(forKey: "playerCount")
        return n == 0 ? 2 : max(2, min(4, n))
    }

    // Remember the room so the host can reopen their own invite even when
    // Messages doesn't hand us back a selectedMessage on tap.
    private func rememberGame(_ gid: String) { UserDefaults.standard.set(gid, forKey: "lastGameId") }
    private func recallGame() -> String? { UserDefaults.standard.string(forKey: "lastGameId") }

    // MARK: Offline (local) mode

    private func decodedLocal(from c: MSConversation) -> GameState {
        if let url = c.selectedMessage?.url, let state = Serialize.decode(from: url) { return state }
        return freshLocal(c)
    }
    private func freshLocal(_ c: MSConversation) -> GameState {
        var g = Game.newGame(playerCount: localPlayerCount())
        g.playerIDs[0] = localID(c)
        if let nm = localName() { g.playerNames[0] = nm }
        return g
    }
    private func onMoveLocal(_ move: Move, in c: MSConversation) {
        guard let state = displayState else { return }
        let enforce = !c.remoteParticipantIdentifiers.isEmpty
        let seat = Game.actingIndex(state, participantID: localID(c)) ?? state.currentPlayer
        do {
            var next = enforce ? try Game.applyMove(state, move, by: localID(c)) : try Game.applyMove(state, move)
            if let nm = localName() { next.playerNames[seat] = nm }
            displayState = next
            stage(next, url: Serialize.encodedURL(next), in: c)
        } catch { print("local move failed:", error) }
    }
    private func onNewGameLocal(_ c: MSConversation) {
        displayState = freshLocal(c)
        requestPresentationStyle(.expanded)
        render(for: c)
    }

    // MARK: Online (server) mode

    private func loadServer(_ c: MSConversation) {
        serverError = nil
        // Resolve the game id in priority order: the tapped invite/game bubble,
        // the room we already hold this session, or — only when the user tapped
        // one of our bubbles — the last room we persisted (covers the host
        // reopening their own invite, where Messages leaves selectedMessage nil).
        // Opening fresh from the app drawer falls through to the start screen.
        let tapped = c.selectedMessage?.url.flatMap { gameId(from: $0) }
        let gid = tapped ?? serverGameId ?? (c.selectedMessage != nil ? recallGame() : nil)
        diag("resolve tap=\(tapped ?? "nil") sgid=\(serverGameId ?? "nil") recall=\(recallGame() ?? "nil") -> \(gid ?? "START")")
        if let gid {
            serverGameId = gid
            rememberGame(gid)
            fetchRoom(gid, c) // keeps any current lobby/game visible while it refreshes
        } else {
            lobby = nil; displayState = nil; serverGameId = nil
            render(for: c) // no game yet -> start screen
        }
    }
    private func fetchRoom(_ gid: String, _ c: MSConversation) {
        loading = true; render(for: c)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let room = try await self.client.room(gameId: gid, me: self.localID(c))
                switch room {
                case .lobby(let lv):
                    // No auto-join: you only enter a game by readying up (which
                    // joins you). Opening an invite just shows you the lobby.
                    self.lobby = lv
                    self.displayState = nil
                    self.diag("room \(gid) = lobby you=\(lv.you.map(String.init) ?? "nil") mem=\(lv.members.count) me=\(self.localID(c).prefix(6))")
                case .game(let pv):
                    self.lobby = nil
                    self.displayState = pv.displayState(localID: self.localID(c))
                    self.diag("room \(gid) = game")
                }
            } catch { self.serverError = "\(error)"; self.diag("room \(gid) ERR \(error)") }
            self.loading = false
            self.render(for: c)
            if self.lobby != nil { self.startLobbyPolling(gid, c) } else { self.stopPolling() }
        }
    }
    private func onMoveServer(_ move: Move, in c: MSConversation) {
        guard let gid = serverGameId else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let view = try await self.client.move(gameId: gid, participantId: self.localID(c),
                                                      move: move, name: self.localName())
                self.displayState = view.displayState(localID: self.localID(c))
                switch move {
                case .drawTickets:
                    // Turn isn't over yet — show the keep/discard chooser, don't post.
                    self.render(for: c)
                case .drawCards:
                    // Let the player privately see what they drew, then post.
                    self.render(for: c)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { [weak self] in
                        guard let self, let ds = self.displayState else { return }
                        self.stage(ds, url: self.gameIdURL(gid), in: c)
                    }
                default: // claim, keepTickets — the turn is done, post now
                    self.stage(self.displayState!, url: self.gameIdURL(gid), in: c)
                }
            } catch {
                self.serverError = "\(error)"
                self.render(for: c)
            }
        }
    }
    private func onNewGameServer(_ c: MSConversation) {
        loading = true; render(for: c)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // Lobby always allows up to 4; it sizes to whoever actually joins.
                let resp = try await self.client.createLobby(hostId: self.localID(c), hostName: self.localName(),
                                                             maxPlayers: 4)
                self.serverGameId = resp.gameId
                self.rememberGame(resp.gameId)
                self.lobby = resp.view
                self.displayState = nil
                self.serverError = nil
                self.loading = false
                self.requestPresentationStyle(.expanded)
                self.render(for: c) // host taps "Send invite" when ready to invite
                self.startLobbyPolling(resp.gameId, c)

            } catch {
                self.serverError = "\(error)"; self.loading = false; self.render(for: c)
            }
        }
    }
    private func onReadyServer(_ ready: Bool, _ c: MSConversation) {
        guard let gid = serverGameId else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // Ready is server-only (no message sent) and also joins you.
                self.lobby = try await self.client.ready(gameId: gid, participantId: self.localID(c),
                                                         ready: ready, name: self.localName())
                self.render(for: c)
            } catch { self.serverError = "\(error)"; self.render(for: c) }
        }
    }
    private func onRefreshServer(_ c: MSConversation) {
        guard let gid = serverGameId else { return }
        fetchRoom(gid, c)
    }
    private func onInviteServer(_ c: MSConversation) {
        guard let gid = serverGameId, let lobby else { return }
        stageLobby(gid, lobby, in: c) // puts the invite in the input to send
    }
    private func onSetNameServer(_ name: String, _ c: MSConversation) {
        guard let gid = serverGameId else { return }
        // Only push a name update if you're already in the lobby; otherwise it
        // just lives in @AppStorage and rides along when you ready up (join).
        guard lobby?.you != nil else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                self.lobby = try await self.client.join(gameId: gid, participantId: self.localID(c),
                                                        name: trimmed.isEmpty ? nil : trimmed)
                self.render(for: c)
            } catch { self.serverError = "\(error)"; self.render(for: c) }
        }
    }
    private func onLeaveServer(_ c: MSConversation) {
        guard let gid = serverGameId else { return }
        let me = localID(c)
        stopPolling()
        // Quit back to the start screen; tell the server so we leave the lobby.
        lobby = nil; displayState = nil; serverGameId = nil
        UserDefaults.standard.removeObject(forKey: "lastGameId")
        render(for: c)
        Task { [weak self] in _ = try? await self?.client.leave(gameId: gid, participantId: me) }
    }
    private func onStartServer(_ c: MSConversation) {
        guard let gid = serverGameId else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let pv = try await self.client.start(gameId: gid, participantId: self.localID(c))
                self.stopPolling()
                self.lobby = nil
                self.displayState = pv.displayState(localID: self.localID(c))
                self.render(for: c) // host now plays P1; their first move sends the game bubble
            } catch { self.serverError = "\(error)"; self.render(for: c) }
        }
    }

    // MARK: Render

    private func render(for c: MSConversation) {
        let isExpanded = presentationStyle == .expanded

        if AppConfig.useServer, let lobby {
            setRoot(AnyView(LobbyScreen(
                lobby: lobby, isExpanded: isExpanded,
                onReady: { [weak self] r in self?.onReadyServer(r, c) },
                onStart: { [weak self] in self?.onStartServer(c) },
                onRefresh: { [weak self] in self?.onRefreshServer(c) },
                onInvite: { [weak self] in self?.onInviteServer(c) },
                onSetName: { [weak self] n in self?.onSetNameServer(n, c) },
                onLeave: { [weak self] in self?.onLeaveServer(c) },
                onExpand: { [weak self] in self?.requestPresentationStyle(.expanded) })))
            return
        }

        if AppConfig.useServer && displayState == nil {
            setRoot(AnyView(ServerStatusView(
                error: serverError, loading: loading, isExpanded: isExpanded,
                onNewGame: { [weak self] in self?.onNewGameServer(c) },
                onExpand: { [weak self] in self?.requestPresentationStyle(.expanded) })))
            return
        }

        let state = displayState ?? freshLocal(c)
        let id = localID(c)
        let enforce = AppConfig.useServer ? true : !c.remoteParticipantIdentifiers.isEmpty
        let canActNow: Bool = AppConfig.useServer
            ? Game.canAct(state, participantID: id)
            : (enforce ? Game.canAct(state, participantID: id) : !Game.isGameOver(state))

        let view = GameView(
            state: state, isExpanded: isExpanded, localParticipantID: id,
            canAct: canActNow, enforceTurns: enforce,
            onMove: { [weak self] move, _ in
                if AppConfig.useServer { self?.onMoveServer(move, in: c) } else { self?.onMoveLocal(move, in: c) }
            },
            onRequestExpand: { [weak self] in self?.requestPresentationStyle(.expanded) },
            onNewGame: { [weak self] in
                if AppConfig.useServer { self?.onNewGameServer(c) } else { self?.onNewGameLocal(c) }
            })
        setRoot(AnyView(view))
    }

    // MARK: Messaging

    private func stage(_ state: GameState, url: URL, in c: MSConversation) {
        let s = currentSession(c)
        let message = MSMessage(session: s)
        let layout = MSMessageTemplateLayout()
        let (caption, sub) = captionPair(state)
        layout.image = BoardSnapshot.render(state, caption: sub)
        layout.caption = caption
        layout.subcaption = sub
        message.layout = layout
        message.url = url
        message.summaryText = sub
        c.insert(message) { if let e = $0 { print("insert failed:", e) } }
        requestPresentationStyle(.compact)
    }

    private func stageLobby(_ gid: String, _ lobby: LobbyView, in c: MSConversation) {
        let s = currentSession(c)
        let message = MSMessage(session: s)
        let layout = MSMessageTemplateLayout()
        let ready = lobby.members.filter { $0.ready }.count
        layout.image = LobbySnapshot.render(joined: lobby.members.count, max: lobby.maxPlayers, ready: ready)
        layout.caption = "Ticket to Text — Lobby"
        layout.subcaption = "\(lobby.members.count)/\(lobby.maxPlayers) joined · \(ready) ready — tap to join"
        message.layout = layout
        message.url = gameIdURL(gid)
        message.summaryText = "Join the game"
        c.insert(message) { if let e = $0 { print("insert failed:", e) } }
        requestPresentationStyle(.compact)
    }

    private func captionPair(_ state: GameState) -> (String, String) {
        let action = "\(name(state.lastActor ?? 0, state)) \(state.lastSummary ?? "")"
        if Game.isGameOver(state) { return (winnerLine(state), action) }
        return ("\(name(state.currentPlayer, state))'s turn", action)
    }
    private func name(_ seat: Int, _ state: GameState) -> String {
        (state.playerNames[safe: seat] ?? nil) ?? "Player \(seat + 1)"
    }
    private func winnerLine(_ state: GameState) -> String {
        switch Scoring.finalWinner(state) {
        case nil: return "Tie game"
        case let w?: return "\(name(w, state)) wins"
        }
    }

    private func gameIdURL(_ gid: String) -> URL {
        var comps = URLComponents()
        comps.scheme = "tickettotext"; comps.host = "game"
        comps.queryItems = [URLQueryItem(name: "g", value: gid)]
        return comps.url!
    }
    private func gameId(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "g" })?.value
    }

    // MARK: Hosting

    private func setRoot(_ view: AnyView) {
        // TEMP: diagnostic banner shown in ALL builds (incl. TestFlight) to trace joins.
        let withDiag = AnyView(
            VStack(spacing: 0) {
                if !diagLog.isEmpty {
                    Text(diagLog.joined(separator: "\n"))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .background(Color.red.opacity(0.9))
                        .textSelection(.enabled)
                }
                view
            }
        )
        #if DEBUG
        hosting?.rootView = AnyView(withDiag.overlay(
            DebugIdentityBar(label: DebugIdentity.label, onSwitch: { [weak self] in self?.switchIdentity() })
        ))
        #else
        hosting?.rootView = withDiag
        #endif
    }
}
