import SwiftUI
import UIKit

// Renders the live BoardView to a UIImage for the message bubble, so the bubble
// thumbnail matches exactly what players see in the extension.
enum BoardSnapshot {
    @MainActor
    static func render(_ state: GameState, size: CGSize = CGSize(width: 340, height: 240)) -> UIImage {
        let content = BoardView(state: state, selectedRouteId: nil, highlightTicket: nil, canAct: false,
                                claimable: { _ in false }, onSelect: { _ in })
            .frame(width: size.width, height: size.height)
            .background(Color(UIColor.secondarySystemBackground))

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}
