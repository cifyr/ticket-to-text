import SwiftUI

// Full move history so a player can review what happened (newest first).
struct LogSheet: View {
    let log: [LogEntry]
    let name: (Int) -> String
    var routeId: (LogEntry) -> Int? = { _ in nil }   // claim entries resolve to a route
    var onShowRoute: (Int) -> Void = { _ in }        // tap a claim to center it on the map
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PaperFill()
                ScrollView {
                    if log.isEmpty {
                        Text("No moves yet.").font(.sans(14)).foregroundStyle(Palette.sepia)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(log.enumerated()).reversed(), id: \.offset) { _, entry in
                                let rid = routeId(entry)
                                Button {
                                    if let rid { onShowRoute(rid) }
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        EnamelToken(color: ownerColor(entry.actor),
                                                    label: String(name(entry.actor).prefix(1)).uppercased(), size: 22)
                                        Text("\(name(entry.actor)) \(entry.text)").font(.sans(13)).foregroundStyle(Palette.ink)
                                        Spacer(minLength: 0)
                                        if rid != nil {
                                            Image(systemName: "scope").font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Palette.brass)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .stub(Palette.parchmentDeep, corner: 10, padding: 10)
                                }
                                .buttonStyle(.plain)
                                .disabled(rid == nil)
                            }
                        }
                        .padding(16)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Game Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Palette.brass) } }
        }
    }
}
