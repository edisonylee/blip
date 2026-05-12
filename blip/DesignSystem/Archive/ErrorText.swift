import SwiftUI

/// Inline error label. Shows nothing when `message` is nil.
struct ErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.blip(size: 13))
                .foregroundStyle(BlipColor.error)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .transition(.opacity)
        }
    }
}
