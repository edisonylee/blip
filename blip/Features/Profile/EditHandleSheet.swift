import FirebaseFirestore
import SwiftUI

// MARK: - Edit handle sheet

/// Modal for claiming or editing the signed-in user's @handle.
/// Reads/writes solely through `UserRepository`.
/// Real-time availability check: queries `usernames/{normalized}` with a
/// 600 ms debounce and renders a colour-coded indicator beside the field.
struct EditHandleSheet: View {
    @EnvironmentObject private var users: UserRepository
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var input: String = ""
    @State private var availability: HandleAvailability = .idle
    @State private var checkTask: Task<Void, Never>?
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var isFieldFocused: Bool

    private let db = Firestore.firestore()

    // MARK: - Availability

    enum HandleAvailability: Equatable {
        case idle, checking, available, taken
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {

                    // Field
                    VStack(alignment: .leading, spacing: 10) {
                        Text("handle")
                            .font(.blip(size: 12, weight: .semibold))
                            .foregroundStyle(BlipColor.textTertiary)
                            .padding(.horizontal, 4)

                        HStack(spacing: 10) {
                            Text("@")
                                .font(.blip(size: 18, weight: .semibold))
                                .foregroundStyle(BlipColor.textTertiary)

                            TextField("yourhandle", text: $input)
                                .font(.blip(size: 18, weight: .semibold))
                                .foregroundStyle(BlipColor.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .submitLabel(.done)
                                .focused($isFieldFocused)
                                .onChange(of: input) { _, _ in scheduleCheck() }
                                .onSubmit { Task { await save() } }

                            availabilityIndicator
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(indicatorBorderColor, lineWidth: 1.5)
                        )
                        .animation(.spring(response: 0.28), value: availability)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // Hint / error
                    Group {
                        if let saveError {
                            Label(saveError, systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(BlipColor.error)
                        } else {
                            availabilityCaption
                        }
                    }
                    .font(.blip(size: 12, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .animation(.spring(response: 0.28), value: availability)

                    Spacer()
                }
            }
            .toolbar { toolbarContent }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            input = users.profile?.handle ?? ""
            isFieldFocused = true
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("cancel") { dismiss() }
                .foregroundStyle(BlipColor.textSecondary)
        }
        ToolbarItem(placement: .principal) {
            Text("your handle")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isSaving {
                ProgressView().tint(BlipColor.textPrimary)
            } else {
                Button("save") { Task { await save() } }
                    .font(.blip(size: 16, weight: .semibold))
                    .foregroundStyle(canSave ? BlipColor.textPrimary : BlipColor.textTertiary)
                    .disabled(!canSave)
            }
        }
    }

    // MARK: - Availability indicator (trailing of field)

    @ViewBuilder
    private var availabilityIndicator: some View {
        switch availability {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
                .scaleEffect(0.75)
                .tint(BlipColor.textTertiary)
                .frame(width: 20, height: 20)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
                .font(.system(size: 18))
                .transition(.scale.combined(with: .opacity))
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(BlipColor.error)
                .font(.system(size: 18))
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var availabilityCaption: some View {
        switch availability {
        case .idle:
            Text("3–15 chars · lowercase · must start with a letter")
                .foregroundStyle(BlipColor.textTertiary)
        case .checking:
            Text("checking…")
                .foregroundStyle(BlipColor.textTertiary)
        case .available:
            Label("available", systemImage: "checkmark")
                .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
        case .taken:
            Label("already taken", systemImage: "xmark")
                .foregroundStyle(BlipColor.error)
        }
    }

    private var indicatorBorderColor: Color {
        switch availability {
        case .available: return Color(red: 0.2, green: 0.78, blue: 0.45).opacity(0.55)
        case .taken:     return BlipColor.error.opacity(0.55)
        default:         return BlipColor.border
        }
    }

    // MARK: - Derived

    private var canSave: Bool {
        let n = Handle.normalize(input)
        guard Handle.isValid(n) else { return false }
        if let cur = users.profile?.handle, cur == n { return false }
        return availability == .available
    }

    // MARK: - Availability check

    private func scheduleCheck() {
        checkTask?.cancel()
        let n = Handle.normalize(input)
        // Same as current handle → no-op (no need to check, we can save freely)
        if let cur = users.profile?.handle, cur == n {
            availability = .available
            return
        }
        guard Handle.isValid(n) else {
            availability = .idle
            return
        }
        availability = .checking
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 s debounce
            guard !Task.isCancelled else { return }
            let doc = try? await db.collection("usernames").document(n).getDocument()
            guard !Task.isCancelled else { return }
            let existingUid = doc?.data()?["uid"] as? String
            let myUid = users.profile?.id
            // Taken if the doc exists AND it belongs to a different user.
            let taken = doc?.exists == true && existingUid != myUid
            await MainActor.run { self.availability = taken ? .taken : .available }
        }
    }

    // MARK: - Save

    private func save() async {
        guard canSave else { return }
        isSaving = true
        saveError = nil
        do {
            try await users.claimHandle(input)
            dismiss()
        } catch HandleError.alreadyTaken {
            saveError = "handle was just taken — try another."
            availability = .taken
        } catch HandleError.invalidFormat {
            saveError = "3–15 chars, lowercase, must start with a letter."
        } catch HandleError.notSignedIn {
            saveError = "you need to be signed in."
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    EditHandleSheet()
        .environmentObject(UserRepository())
        .preferredColorScheme(.dark)
}
