import SwiftUI

// Full move history so a player can review what happened (newest first).
struct LogSheet: View {
    let log: [LogEntry]
    let name: (Int) -> String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if log.isEmpty {
                    Text("No moves yet.").foregroundStyle(.secondary)
                } else {
                    List(Array(log.enumerated()).reversed(), id: \.offset) { _, entry in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(ownerColor(entry.actor)).frame(width: 8, height: 8).padding(.top, 6)
                            Text("\(name(entry.actor)) \(entry.text)").font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Game log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
