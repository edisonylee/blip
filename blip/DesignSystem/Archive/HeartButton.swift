import SwiftUI

/// Reusable like / heart toggle. Surfaces:
///   - `Archive` rows (compact, count to the right)
///   - `Export` ready-state (next to share)
///
/// The button owns no state of its own — pass `liked` + `count` from a
/// `DayLikesRepository` and a closure that calls `toggle()`. Plays a small
/// scale spring on every transition so the tap feels alive without resorting
/// to haptics inside a reusable view.
struct HeartButton: View {
    let liked: Bool
    let count: Int
    let isWriting: Bool
    let onTap: () -> Void

    @State private var pulse: Bool = false

    var body: some View {
        Button {
            // Trigger the spring before the toggle so liked → unliked still
            // animates the press.
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                pulse.toggle()
            }
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.blip(size: 16, weight: .semibold))
                    .foregroundStyle(liked ? BlipColor.accent : BlipColor.textTertiary)
                    .scaleEffect(pulse ? 1.18 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.55), value: pulse)

                if count > 0 {
                    Text("\(count)")
                        .font(.blip(size: 13, weight: .semibold))
                        .foregroundStyle(liked ? BlipColor.textPrimary : BlipColor.textTertiary)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.15), value: count)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isWriting)
        .accessibilityLabel(liked ? "unlike" : "like")
        .accessibilityValue("\(count)")
    }
}
