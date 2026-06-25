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
    private lazy var client = GameClient(baseURL: AppConfig.serverBaseURL, bypassToken: AppConfig.bypassToken)

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
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

    // MARK: Identity / settings

    private func localID(_ c: MSConversation) -> String { c.localParticipantIdentifier.uuidString }
    private func localName() -> String? {
        let n = UserDefaults.standard.string(forKey: "playerName")?.trimmingCharacters(in: .whitespaces)
        return (n?.isEmpty == false) ? n : nil
    }
    private func localPlayerCount() -> Int {
        let n = UserDefaults.standard.integer(forKey: "playerCount")
        return n == 0 ? 2 : max(2, min(4, n))
    }

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
        if let url = c.selectedMessage?.url, let gid = gameId(from: url) {
            serverGameId = gid
            fetchView(gid, c)
        } else {
            serverGameId = nil
            displayState = nil
            render(for: c)
        }
    }
    private func fetchView(_ gid: String, _ c: MSConversation) {
        loading = true; render(for: c)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let view = try await self.client.view(gameId: gid, me: self.localID(c))
                self.displayState = view.displayState(localID: self.localID(c))
            } catch { self.serverError = "\(error)" }
            self.loading = false
            self.render(for: c)
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
                self.stage(self.displayState!, url: self.gameIdURL(gid), in: c)
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
                let resp = try await self.client.create(playerCount: self.localPlayerCount(),
                                                        hostId: self.localID(c), hostName: self.localName())
                self.serverGameId = resp.gameId
                self.displayState = resp.view.displayState(localID: self.localID(c))
                self.serverError = nil
                self.loading = false
                self.requestPresentationStyle(.expanded)
                self.render(for: c)
            } catch {
                self.serverError = "\(error)"; self.loading = false; self.render(for: c)
            }
        }
    }

    // MARK: Render

    private func render(for c: MSConversation) {
        let isExpanded = presentationStyle == .expanded

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
        let session = c.selectedMessage?.session ?? MSSession()
        let message = MSMessage(session: session)
        let layout = MSMessageTemplateLayout()
        layout.image = BoardSnapshot.render(state)
        let (caption, sub) = captionPair(state)
        layout.caption = caption
        layout.subcaption = sub
        message.layout = layout
        message.url = url
        message.summaryText = sub
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
        if let hosting { hosting.rootView = view; return }
        let host = UIHostingController(rootView: view)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hosting = host
    }
}
