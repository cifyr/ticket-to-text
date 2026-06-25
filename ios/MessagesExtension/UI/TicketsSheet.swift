import SwiftUI

// Your secret destination tickets, with a plain-language explainer.
struct TicketsSheet: View {
    let tickets: [Ticket]
    let myRoutes: [Route]
    let ticketsLeft: Int
    let canDraw: Bool
    let onDraw: () -> Void
    let onShow: (Ticket) -> Void   // highlight this ticket on the map and close

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Destination tickets are secret goals. Connect the two cities with routes you claim to earn the points. Any ticket you don't finish is SUBTRACTED at the end — so only keep ones you can complete. Tap a ticket to see it on the map.")
                        .font(.subheadline).foregroundStyle(.secondary)

                    ForEach(tickets) { t in
                        let done = Scoring.connected(myRoutes, from: t.cityA, to: t.cityB)
                        Button { onShow(t) } label: {
                            HStack {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(GameMap.ticketLabel(t)).font(.subheadline.weight(.medium))
                                    Text(done ? "Connected" : "Not connected yet")
                                        .font(.caption).foregroundStyle(done ? .green : .secondary)
                                }
                                Spacer()
                                Text("\(t.points) pts").font(.subheadline.bold().monospacedDigit())
                                Image(systemName: "map").font(.caption).foregroundStyle(Color.brand)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                    }

                    if ticketsLeft > 0 {
                        Button(action: onDraw) {
                            Label("Draw \(min(3, ticketsLeft)) more tickets (uses your turn)", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(Color.brand).disabled(!canDraw)
                        if !canDraw { Text("You can draw tickets on your turn.").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Your tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
