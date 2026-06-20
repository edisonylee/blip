import SwiftUI

/// Static privacy policy screen. In production, swap the text blocks for a
/// WKWebView pointing at your hosted policy URL.
struct PrivacyPolicyView: View {

    private let sections: [(title: String, body: String)] = [
        (
            "what we collect",
            "We collect your phone number (for sign-in), @handle, profile photo, and the 2-second video clips you record and post to blip groups. We also collect standard device identifiers and usage analytics."
        ),
        (
            "how we use it",
            "Your phone number is used solely for authentication. Clips are stored in Firebase Storage and shared only with the blip group members you choose. We never sell your personal data to third parties."
        ),
        (
            "who can see your clips",
            "Only members of the blip groups you post to can view your clips. Public discovery of clips is not supported — blips are private, invite-only circles."
        ),
        (
            "data retention",
            "You can delete your account at any time from Settings → Delete account. All your clips, profile data, and group memberships are permanently erased within 30 days of deletion."
        ),
        (
            "third-party services",
            "We use Firebase (Google) for authentication, database, and storage; and Firebase Cloud Messaging for push notifications. Both services are governed by Google's Privacy Policy."
        ),
        (
            "contact",
            "Questions? Email us at privacy@blip.app — we'll respond within 72 hours."
        ),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                Text("Last updated: June 2025")
                    .font(.blip(size: 12))
                    .foregroundStyle(BlipColor.textTertiary)
                    .padding(.top, 8)

                ForEach(sections, id: \.title) { sec in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sec.title)
                            .font(.blip(size: 15, weight: .bold))
                            .foregroundStyle(BlipColor.textPrimary)

                        Text(sec.body)
                            .font(.blip(size: 14))
                            .foregroundStyle(BlipColor.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BlipColor.surface,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(BlipColor.backgroundGradient.ignoresSafeArea())
        .navigationTitle("privacy policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BlipColor.background, for: .navigationBar)
    }
}
