import SwiftUI

/// Reusable sheet for filing a report against a clip.
/// Attach to clip cells once Phase B renders them — call site:
///
///     .sheet(item: $clipToReport) { ctx in
///         ReportClipSheet(context: ctx)
///     }
struct ReportClipContext: Identifiable {
    let id = UUID()
    let clipPath: String   // full Firestore path, e.g. "blips/abc/days/2026-04-28/clips/xyz"
    let clipId: String
    let authorId: String
}

struct ReportClipSheet: View {
    let context: ReportClipContext

    @EnvironmentObject private var moderation: ModerationService
    @Environment(\.dismiss) private var dismiss

    @State private var selected: ModerationService.ReportCategory?
    @State private var isSending = false
    @State private var error: String?
    @State private var sentToast = false

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("report this clip")
                    .font(BlipTypography.title)
                    .tracking(BlipTypography.titleTracking)
                    .foregroundStyle(BlipColor.textPrimary)
                Text("we'll review within 24 hours.")
                    .font(.footnote)
                    .foregroundStyle(BlipColor.textTertiary)

                VStack(spacing: 0) {
                    ForEach(ModerationService.ReportCategory.allCases) { cat in
                        Button {
                            selected = cat
                        } label: {
                            HStack {
                                Text(cat.label)
                                    .foregroundStyle(BlipColor.textPrimary)
                                Spacer()
                                if selected == cat {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(BlipColor.textPrimary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        if cat != ModerationService.ReportCategory.allCases.last {
                            Divider().background(BlipColor.surfaceElevated)
                        }
                    }
                }
                .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 12))

                Spacer()

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(BlipColor.error)
                }

                Button {
                    Task { await send() }
                } label: {
                    Text(isSending ? "sending…" : "submit report")
                        .font(BlipTypography.body)
                        .tracking(BlipTypography.titleTracking)
                        .foregroundStyle(selected == nil ? BlipColor.textTertiary : BlipColor.accentNeutralOn)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            selected == nil ? BlipColor.surfaceElevated : BlipColor.accentNeutral,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
                .disabled(selected == nil || isSending)
            }
            .padding(20)

            if sentToast {
                Text("thanks. we'll review.")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.accentNeutralOn)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        BlipColor.accentNeutral,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .transition(.opacity)
            }
        }
    }

    private func send() async {
        guard let cat = selected else { return }
        isSending = true
        error = nil
        do {
            try await moderation.report(
                clipPath: context.clipPath,
                clipId: context.clipId,
                authorId: context.authorId,
                category: cat
            )
            sentToast = true
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
    }
}
