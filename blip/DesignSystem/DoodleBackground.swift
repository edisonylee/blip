import SwiftUI

/// Decorative Gen-Z doodle layer. Place as a ZStack background — it never intercepts touches.
/// All positions are deterministic (seeded), so it never shifts on re-render.
struct DoodleBackground: View {
    /// Overall opacity multiplier. Default 1.0 — individual shapes are already very faint.
    var intensity: Double = 1.0

    @Environment(\.colorScheme) private var scheme

    private static let elements: [DoodleElement] = buildElements()

    var body: some View {
        let tint: Color = scheme == .dark ? .white : Color(red: 0.17, green: 0.14, blue: 0.11)

        Canvas { ctx, size in
            for el in Self.elements {
                let pos = CGPoint(x: el.xFrac * size.width, y: el.yFrac * size.height)
                let alpha = el.opacity * intensity
                let color = tint.opacity(alpha)

                switch el.kind {
                case .star(let r):
                    ctx.fill(starPath(center: pos, outerR: r, points: 4), with: .color(color))

                case .circle(let r):
                    let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                    ctx.stroke(Path(ellipseIn: rect), with: .color(color),
                               style: StrokeStyle(lineWidth: 1.2))

                case .plus(let r):
                    var p = Path()
                    p.move(to: CGPoint(x: pos.x, y: pos.y - r))
                    p.addLine(to: CGPoint(x: pos.x, y: pos.y + r))
                    p.move(to: CGPoint(x: pos.x - r, y: pos.y))
                    p.addLine(to: CGPoint(x: pos.x + r, y: pos.y))
                    ctx.stroke(p, with: .color(color),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

                case .squiggle(let w):
                    var p = Path()
                    p.move(to: CGPoint(x: pos.x - w / 2, y: pos.y))
                    p.addCurve(
                        to: CGPoint(x: pos.x + w / 2, y: pos.y),
                        control1: CGPoint(x: pos.x - w / 4, y: pos.y - w / 3),
                        control2: CGPoint(x: pos.x + w / 4, y: pos.y + w / 3)
                    )
                    ctx.stroke(p, with: .color(color),
                               style: StrokeStyle(lineWidth: 1.3, lineCap: .round))

                case .diamond(let r):
                    var p = Path()
                    p.move(to: CGPoint(x: pos.x, y: pos.y - r))
                    p.addLine(to: CGPoint(x: pos.x + r * 0.6, y: pos.y))
                    p.addLine(to: CGPoint(x: pos.x, y: pos.y + r))
                    p.addLine(to: CGPoint(x: pos.x - r * 0.6, y: pos.y))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - Path helpers

    private func starPath(center: CGPoint, outerR: CGFloat, points: Int) -> Path {
        var path = Path()
        let innerR = outerR * 0.42
        let total = points * 2
        for i in 0..<total {
            let angle = (Double(i) / Double(total)) * .pi * 2 - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let cosA = CGFloat(Darwin.cos(angle))
            let sinA = CGFloat(Darwin.sin(angle))
            let pt = CGPoint(x: center.x + r * cosA, y: center.y + r * sinA)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Data model

private struct DoodleElement {
    enum Kind {
        case star(CGFloat)
        case circle(CGFloat)
        case plus(CGFloat)
        case squiggle(CGFloat)
        case diamond(CGFloat)
    }
    let xFrac: Double
    let yFrac: Double
    let opacity: Double
    let kind: Kind
}

// MARK: - Deterministic layout

private func buildElements() -> [DoodleElement] {
    // Seeded pseudo-random so positions are always identical.
    var rng = SeededRNG(seed: 0xB11)
    var result: [DoodleElement] = []

    let kinds: [() -> DoodleElement.Kind] = [
        { .star(CGFloat.random(in: 5...10, using: &rng)) },
        { .circle(CGFloat.random(in: 6...14, using: &rng)) },
        { .plus(CGFloat.random(in: 5...9, using: &rng)) },
        { .squiggle(CGFloat.random(in: 20...40, using: &rng)) },
        { .diamond(CGFloat.random(in: 4...8, using: &rng)) },
    ]

    for _ in 0..<38 {
        let kindFn = kinds[Int.random(in: 0..<kinds.count, using: &rng)]
        result.append(DoodleElement(
            xFrac: Double.random(in: 0.03...0.97, using: &rng),
            yFrac: Double.random(in: 0.03...0.97, using: &rng),
            opacity: Double.random(in: 0.04...0.09, using: &rng),
            kind: kindFn()
        ))
    }
    return result
}

// MARK: - Seeded RNG (deterministic, no Foundation dependency)

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

#Preview {
    ZStack {
        Color(red: 0.04, green: 0.035, blue: 0.03).ignoresSafeArea()
        DoodleBackground()
    }
}
