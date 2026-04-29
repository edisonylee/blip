import SwiftUI

/// Join via code (parity) or via Universal Link (deep-link plumbing in Phase B).
struct JoinLogView: View {
    var body: some View {
        Text("join a log — Phase B")
            .foregroundStyle(BlipColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlipColor.background)
    }
}
