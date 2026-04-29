import SwiftUI

/// Screen-03 parity — name input + blip size picker (2–12, default 4).
struct CreateBlipView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var size: Int = 4
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var createdBlip: Blip?
    @FocusState private var nameFocused: Bool

    private let sizes = Array(2...12)

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    Text("→ create a blip")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)

                    nameField
                    sizePicker

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationDestination(item: $createdBlip) { blip in
                BlipCreatedView(blip: blip) { dismiss() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("new blip")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: submit) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(isFormValid ? BlipColor.accent : BlipColor.textTertiary)
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear { nameFocused = true }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Rectangle()
                    .fill(BlipColor.accent)
                    .frame(width: 8, height: 18)
                TextField(
                    "blip name",
                    text: $name,
                    prompt: Text("blip name").foregroundStyle(BlipColor.textSecondary)
                )
                .focused($nameFocused)
                .submitLabel(.done)
                .foregroundStyle(BlipColor.textPrimary)
                .font(BlipTypography.body)
                .autocorrectionDisabled()
            }
        }
    }

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("blip size")
                .foregroundStyle(BlipColor.textPrimary)
                .font(BlipTypography.body)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(sizes, id: \.self) { n in
                    Button { size = n } label: {
                        Text("\(n)")
                            .font(BlipTypography.body)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(
                                size == n ? BlipColor.accent : BlipColor.surface,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .foregroundStyle(size == n ? Color.black : BlipColor.textPrimary)
                    }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard case .signedIn(let uid) = auth.state else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let blip = try await repo.createBlip(
                    name: name,
                    size: size,
                    ownerUid: uid,
                    timezoneIdentifier: TimeZone.current.identifier
                )
                createdBlip = blip
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    CreateBlipView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}
