import SwiftUI
import UIKit

/// Horizontal day-scrubber for the blip detail view. Nodes are sparse — one
/// per recorded hour plus the current hour — distributed evenly across the
/// track. With no past recordings the slider collapses to a single node (now).
/// Drag snaps to the nearest node by horizontal position.
struct HourSlider: View {

    // MARK: - Inputs

    let hours: [Int]                 // chronological order across the day
    let currentHour: Int
    @Binding var selectedHour: Int

    // MARK: - Constants

    private static let trackHeight: CGFloat = 2
    private static let knobSize: CGFloat = 14
    private static let nodeSize: CGFloat = 7
    private static let touchHeight: CGFloat = 44

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            track
                .frame(height: Self.touchHeight)

            Text(label(for: selectedHour))
                .font(BlipTypography.timeLabel)
                .foregroundStyle(BlipColor.textSecondary)
        }
    }

    // MARK: - Subviews

    private var track: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let count = hours.count
            let step: CGFloat = count > 1 ? width / CGFloat(count - 1) : 0
            let selectedIndex = hours.firstIndex(of: selectedHour) ?? 0
            let knobX = position(for: selectedIndex, width: width, step: step)
            let centerY = geo.size.height / 2

            ZStack(alignment: .leading) {
                if count > 1 {
                    Capsule()
                        .fill(BlipColor.progressTrack)
                        .frame(height: Self.trackHeight)
                        .position(x: width / 2, y: centerY)

                    Capsule()
                        .fill(BlipColor.accent.opacity(0.85))
                        .frame(width: knobX, height: Self.trackHeight)
                        .position(x: knobX / 2, y: centerY)
                }

                ForEach(Array(hours.enumerated()), id: \.offset) { idx, _ in
                    Circle()
                        .fill(BlipColor.accent)
                        .frame(width: Self.nodeSize, height: Self.nodeSize)
                        .position(x: position(for: idx, width: width, step: step), y: centerY)
                }

                Circle()
                    .fill(BlipColor.accent)
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .position(x: knobX, y: centerY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard count > 1, step > 0 else { return }
                        let clamped = max(0, min(width, value.location.x))
                        let idx = max(0, min(count - 1, Int((clamped / step).rounded())))
                        let snapped = hours[idx]
                        if snapped != selectedHour {
                            selectedHour = snapped
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
            )
        }
    }

    // MARK: - Helpers

    /// Single-node case lives at center; multi-node cases distribute 0…width.
    private func position(for index: Int, width: CGFloat, step: CGFloat) -> CGFloat {
        hours.count > 1 ? CGFloat(index) * step : width / 2
    }

    private func label(for hour: Int) -> String {
        if hour == currentHour { return "now" }
        var c = DateComponents()
        c.hour = hour
        let date = Calendar.current.date(from: c) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date).lowercased()
    }
}
