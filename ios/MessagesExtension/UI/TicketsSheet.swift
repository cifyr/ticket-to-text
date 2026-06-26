import SwiftUI

// Your secret destination tickets, with a plain-language explainer.
struct TicketsSheet: View {
    let tickets: [Ticket]
    let myRoutes: [Route]
    let ticketsLeft: Int
    let canDraw: Bool
    let onDraw: () -> Void          // draw a fresh batch of destination tickets (uses your turn)
    let onShow: (Ticket) -> Void   // highlight this ticket on the map and close

    @Environment(\.dismiss) private var dismiss

    private var doneCount: Int {
        tickets.filter { Scoring.connected(myRoutes, from: $0.cityA, to: $0.cityB) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperFill()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionRule(title: "Destination Tickets")
                        Text("\(doneCount) of \(tickets.count) routes completed")
                            .font(.sans(12)).foregroundStyle(Palette.sepiaLight)

                        Text("Secret goals. Connect the two cities with routes you claim to earn the points. Any ticket you don't finish is SUBTRACTED at the end — keep only ones you can complete. Tap a ticket to see it on the map.")
                            .font(.sans(13)).foregroundStyle(Palette.sepia).multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(tickets) { t in
                            let done = Scoring.connected(myRoutes, from: t.cityA, to: t.cityB)
                            Button { onShow(t) } label: { ticketStub(t, done: done) }
                                .buttonStyle(.plain)
                        }

                        if ticketsLeft > 0 {
                            Button(action: onDraw) {
                                Label("Draw destination tickets", systemImage: "ticket.fill")
                            }
                            .buttonStyle(BrassButtonStyle()).disabled(!canDraw).opacity(canDraw ? 1 : 0.5)
                            Text(canDraw ? "Uses your whole turn. You keep all the tickets you draw."
                                         : "You can draw tickets on your turn.")
                                .font(.sans(11)).foregroundStyle(Palette.sepiaLight).multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Your Tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Palette.brass) } }
        }
    }

    private func ticketStub(_ t: Ticket, done: Bool) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(GameMap.cities[t.cityA].name).font(.slab(18, .bold)).foregroundStyle(Palette.ink)
                HStack(spacing: 8) {
                    Text("→").font(.slab(15, .bold)).foregroundStyle(Palette.brass)
                    DashedRule()
                }
                Text(GameMap.cities[t.cityB].name).font(.slab(18, .bold)).foregroundStyle(Palette.ink)
                Text(done ? "Route completed" : "In progress")
                    .font(.sans(10.5, .bold)).tracking(0.8).textCase(.uppercase)
                    .foregroundStyle(done ? Palette.success : Palette.sepiaLight)
                    .padding(.top, 3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                DashedLine().stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .foregroundStyle(Palette.hairline)
                    .frame(width: 1).rotationEffect(.degrees(90)).frame(width: 2)
                PointStamp(points: t.points, size: 52)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy)).foregroundStyle(Color(hex: 0xEAF6EF))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(RadialGradient(colors: [Color(hex: 0x3E9C72), Color(hex: 0x1F6B4C)],
                                                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 18)))
                        .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1))
                        .rotationEffect(.degrees(-12))
                        .offset(x: 14, y: -18)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .frame(width: 84)
        }
        .stub(done ? Color(hex: 0xD7E8D5) : Palette.parchmentDeep, corner: 12, padding: 0,
              stroke: done ? Palette.success.opacity(0.55) : Palette.hairline)
    }
}

// Parchment background for sheets.
struct PaperFill: View {
    var body: some View {
        ZStack {
            Palette.parchment
            Paper.grain.resizable(resizingMode: .tile).opacity(0.5).blendMode(.multiply)
        }
        .ignoresSafeArea()
    }
}
