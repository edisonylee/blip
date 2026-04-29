import SwiftUI

/// Screen-07 parity placeholder — vertical hour-slot stack.
struct LogDetailView: View {
    let logId: String

    var body: some View {
        Text("log \(logId) — Phase B")
            .foregroundStyle(BlipColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlipColor.background)
    }
}
