import SwiftUI

/// Screen-11 parity — text-only message thread alongside the visual blip.
struct ChatView: View {
    let blipId: String

    @EnvironmentObject private var auth: AuthService
    @StateObject private var repo = MessagesRepository()

    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(repo.messages) { msg in
                                MessageRow(message: msg, isMe: isMe(msg))
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: repo.messages.count) { _, _ in
                        if let last = repo.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                inputBar
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("chat")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: blipId) { repo.startListening(blipId: blipId) }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(
                "message",
                text: $draft,
                prompt: Text("message").foregroundStyle(BlipColor.textTertiary)
            )
            .focused($inputFocused)
            .submitLabel(.send)
            .onSubmit(send)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BlipColor.surface, in: Capsule())
            .foregroundStyle(BlipColor.textPrimary)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canSend ? .black : BlipColor.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(canSend ? BlipColor.accent : BlipColor.surface, in: Circle())
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BlipColor.background)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isMe(_ msg: BlipMessage) -> Bool {
        guard case .signedIn(let uid) = auth.state else { return false }
        return msg.uid == uid
    }

    private func send() {
        let text = draft
        draft = ""
        Task { try? await repo.send(text: text) }
    }
}

private struct MessageRow: View {
    let message: BlipMessage
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer() }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                if let text = message.text {
                    Text(text)
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isMe ? BlipColor.accent.opacity(0.9) : BlipColor.surface,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(isMe ? .black : BlipColor.textPrimary)
                }
            }
            if !isMe { Spacer() }
        }
    }
}
