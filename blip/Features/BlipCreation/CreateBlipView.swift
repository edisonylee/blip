import SwiftUI

struct CreateBlipView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = CreateBlipViewModel()
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    Spacer()
                    content
                    Spacer()
                    footer
                }
            }
            .navigationDestination(item: $vm.createdBlip) { blip in
                BlipCreatedView(blip: blip) { dismiss() }
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
        .onAppear { nameFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("name your crew")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(BlipColor.textPrimary)
            Text("pick a name and how many people can join")
                .font(.system(size: 14))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    // MARK: - Name + size

    private var content: some View {
        VStack(spacing: 28) {
            // Name field
            BlipTextField(
                label: "blip name",
                placeholder: "summer squad, study crew…",
                text: $vm.name,
                isFocused: $nameFocused
            )

            // Size picker
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("group size")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Text(vm.sizeDescription(vm.size))
                        .font(.system(size: 13))
                        .foregroundStyle(BlipColor.accent)
                        .animation(.easeOut(duration: 0.15), value: vm.size)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(vm.sizeOptions, id: \.self) { n in
                        Button {
                            withAnimation(.spring(duration: 0.2)) { vm.size = n }
                        } label: {
                            Text("\(n)")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    vm.size == n ? BlipColor.accent : BlipColor.surface,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .foregroundStyle(vm.size == n ? .black : BlipColor.textSecondary)
                                .scaleEffect(vm.size == n ? 1.05 : 1)
                                .animation(.spring(duration: 0.2), value: vm.size)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            ErrorText(message: vm.errorMessage)

            Button("create blip") {
                nameFocused = false
                guard case .signedIn(let uid) = auth.state else { return }
                vm.submit(uid: uid, repo: repo)
            }
            .blipPrimary(isLoading: vm.isSubmitting)
            .disabled(!vm.isFormValid || vm.isSubmitting)
            .opacity(vm.isFormValid ? 1 : 0.4)
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 32)
    }
}

#Preview {
    CreateBlipView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}
