import SwiftUI

@main
struct TicketToTextApp: App {
    var body: some Scene {
        WindowGroup {
            HostView()
        }
    }
}

// The host app is just a shell — the game lives in the iMessage extension.
// This screen explains how to start a game so the app isn't empty in review.
struct HostView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Ticket to Text")
                .font(.largeTitle.bold())
            Text("Open a conversation in Messages, tap the apps button next to the text field, choose Ticket to Text, and send a game to a friend.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}
