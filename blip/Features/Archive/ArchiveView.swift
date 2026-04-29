import SwiftUI

/// Past logs — list view per group, tap into a past day's stitched vlog (per §6 open item).
struct ArchiveView: View {
    let logId: String

    var body: some View {
        Text("archive — Phase C")
            .foregroundStyle(BlipColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlipColor.background)
    }
}
