import SwiftUI

private let kOnboardingKey = "blip.hasSeenOnboarding.v1"

/// Three swipeable welcome screens shown once on first launch (after splash,
/// before phone auth). Completion writes a UserDefaults flag so it never
/// appears again.
struct OnboardingSlides: View {
    let onFinished: () -> Void

    @State private var page = 0

    private let slides: [Slide] = [
        Slide(
            icon: "camera.fill",
            gradient: [Color(hex: 0xA78BFA), Color(hex: 0x7C3AED)],
            title: "capture your day",
            body: "hit record once an hour.\n2 seconds. raw. real. no filters."
        ),
        Slide(
            icon: "person.2.fill",
            gradient: [Color(hex: 0xF472B6), Color(hex: 0xDB2777)],
            title: "share with your crew",
            body: "build a blip group with up to 12 friends.\nwatch each other's hours unfold."
        ),
        Slide(
            icon: "sparkles",
            gradient: [Color(hex: 0x34D399), Color(hex: 0x059669)],
            title: "stay in the moment",
            body: "scroll your day at midnight.\nexport a movie. relive everything."
        ),
    ]

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Swipeable slides
                TabView(selection: $page) {
                    ForEach(slides.indices, id: \.self) { i in
                        SlideView(slide: slides[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: page)

                // Dots + CTA
                VStack(spacing: 28) {
                    pageDots
                    ctaButton
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    // MARK: Page indicator

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(slides.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? BlipColor.accentNeutral : BlipColor.border)
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)
            }
        }
    }

    // MARK: CTA

    private var ctaButton: some View {
        Button {
            if page < slides.count - 1 {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { page += 1 }
            } else {
                UserDefaults.standard.set(true, forKey: kOnboardingKey)
                onFinished()
            }
        } label: {
            Text(page < slides.count - 1 ? "next" : "let's go →")
        }
        .blipPrimary()
    }
}

// MARK: - Static helpers

extension OnboardingSlides {
    static var hasBeenSeen: Bool {
        UserDefaults.standard.bool(forKey: kOnboardingKey)
    }
}

// MARK: - Slide model + view

private struct Slide {
    let icon: String
    let gradient: [Color]
    let title: String
    let body: String
}

private struct SlideView: View {
    let slide: Slide

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon card
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: slide.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: slide.gradient.last?.opacity(0.4) ?? .clear,
                            radius: 24, x: 0, y: 10)

                Image(systemName: slide.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 40)

            VStack(spacing: 14) {
                Text(slide.title)
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(slide.body)
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 12)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
