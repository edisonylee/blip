import SwiftUI

struct JoinBlipView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = JoinBlipViewModel()
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 6) {
                        Text("got a code?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(BlipColor.textPrimary)
                        Text("your friend sent you a blip join code")
                            .font(.system(size: 14))
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)

                    Spacer()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("join code")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BlipColor.textSecondary)
                        TextField("c9kz6il", text: $vm.code)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .keyboardType(.asciiCapable)
                            .textContentType(.oneTimeCode)
                            .submitLabel(.go)
                            .focused($codeFocused)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(BlipColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(BlipColor.border, lineWidth: 1)
                            )
                            .onSubmit { submit() }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    VStack(spacing: 12) {
                        ErrorText(message: vm.errorMessage)

                        Button("join blip") { submit() }
                            .blipPrimary(isLoading: vm.isSubmitting)
                            .disabled(!vm.canSubmit || vm.isSubmitting)
                            .opacity(vm.canSubmit ? 1 : 0.4)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(BlipColor.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
        }
        .onAppear { codeFocused = true }
        .onChange(of: vm.didJoin) { _, joined in
            if joined { dismiss() }
        }
    }

    private func submit() {
        guard case .signedIn(let uid) = auth.state else { return }
        vm.submit(uid: uid, repo: repo)
    }
}

#Preview {
    JoinBlipView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}

