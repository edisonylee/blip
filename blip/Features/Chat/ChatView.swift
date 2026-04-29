import SwiftUI

/// Screen-11 parity placeholder.
struct ChatView: View {
    let blipId: String

    var body: some View {
        Text("chat — Phase C")
            .foregroundStyle(BlipColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlipColor.background)
    }
}
