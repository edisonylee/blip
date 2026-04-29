import SwiftUI

/// Priority-1 screen — design lands once Setlog's actual export/TikTok handoff is documented
/// (parallel research track per the plan).
struct ExportView: View {
    let logId: String
    let dateKey: String

    var body: some View {
        Text("export \(dateKey) — design pending Setlog research")
            .foregroundStyle(BlipColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlipColor.background)
    }
}
