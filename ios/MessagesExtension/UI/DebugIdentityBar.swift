import SwiftUI

#if DEBUG
// Small floating capsule (test builds only) showing which account this device is
// currently acting as. Tap to cycle You -> Alt A -> Alt B and reload the room.
struct DebugIdentityBar: View {
    let label: String
    let onSwitch: () -> Void

    var body: some View {
        Button(action: onSwitch) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 12, weight: .bold))
                Text("acting: \(label)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.72)))
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.leading, 8).padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .allowsHitTesting(true)
    }
}
#endif
