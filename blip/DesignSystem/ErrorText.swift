import SwiftUI

/// Inline error label. Shows nothing when `message` is nil.
struct ErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .transition(.opacity)
        }
    }
}
