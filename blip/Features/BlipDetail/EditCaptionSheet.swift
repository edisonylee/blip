import SwiftUI

/// Tiny sheet for editing a clip's caption. Submits via the parent's repo binding.
struct EditCaptionSheet: View {
    let clip: BlipClip
    let onSave: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @State private var isSaving = false
    @FocusState private var focused: Bool

    init(clip: BlipClip, onSave: @escaping (String) async -> Void) {
        self.clip = clip
        self.onSave = onSave
        _draft = State(initialValue: clip.caption ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("caption")
                        .font(BlipTypography.caption)
                        .foregroundStyle(BlipColor.textSecondary)
                    TextField(
                        "say something",
                        text: $draft,
                        prompt: Text("say something").foregroundStyle(BlipColor.textSecondary),
                        axis: .vertical
                    )
                    .focused($focused)
                    .lineLimit(2...5)
                    .padding(12)
                    .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(BlipColor.textPrimary)
                    Spacer()
                }
                .padding(16)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundStyle(BlipColor.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        isSaving = true
                        Task {
                            await onSave(draft)
                            dismiss()
                        }
                    }
                    .foregroundStyle(BlipColor.accent)
                    .disabled(isSaving)
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }
}
