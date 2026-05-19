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
                    CreateHeader(onDismiss: { dismiss() }, onConfirm: submit)
                    content
                        .padding(.top, BlipSpacing.xxl)
                    Spacer()
                    footer
                }
            }
            .navigationDestination(item: $vm.createdBlip) { blip in
                BlipCreatedView(blip: blip) { dismiss() }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { nameFocused = true }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: BlipSpacing.xxl) {
            BlipTextField(
                label: "blip name",
                placeholder: "summer squad, study crew…",
                text: $vm.name,
                isFocused: $nameFocused
            )

            sizePicker
            timezonePicker
        }
        .padding(.horizontal, BlipSpacing.xl)
    }

    // MARK: - Size picker

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: BlipSpacing.md) {
            HStack {
                Text("group size")
                    .font(.blip(size: 11, weight: .semibold))
                    .foregroundStyle(BlipColor.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(vm.sizeDescription(vm.size))
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textPrimary)
                    .animation(BlipMotion.spring, value: vm.size)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: BlipSpacing.sm), count: 6),
                spacing: BlipSpacing.sm
            ) {
                ForEach(vm.sizeOptions, id: \.self) { n in
                    Button {
                        withAnimation(BlipMotion.spring) { vm.size = n }
                    } label: {
                        Text("\(n)")
                            .font(.blip(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: BlipSpacing.tapTarget)
                            .background(
                                vm.size == n ? BlipColor.textPrimary : BlipColor.surface,
                                in: RoundedRectangle(cornerRadius: BlipRadius.sm, style: .continuous)
                            )
                            .foregroundStyle(vm.size == n ? BlipColor.background : BlipColor.textSecondary)
                            .scaleEffect(vm.size == n ? 1.05 : 1)
                            .animation(BlipMotion.spring, value: vm.size)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Timezone picker

    private var timezonePicker: some View {
        VStack(alignment: .leading, spacing: BlipSpacing.md) {
            HStack {
                Text("day starts 4am")
                    .font(.blip(size: 11, weight: .semibold))
                    .foregroundStyle(BlipColor.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(vm.timezoneShortName(vm.timezoneIdentifier))
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textPrimary)
                    .animation(BlipMotion.spring, value: vm.timezoneIdentifier)
            }

            Menu {
                Picker("timezone", selection: $vm.timezoneIdentifier) {
                    ForEach(vm.timezoneOptions, id: \.self) { tz in
                        Text(vm.timezoneShortName(tz)).tag(tz)
                    }
                }
            } label: {
                HStack {
                    Text(vm.timezoneIdentifier.replacingOccurrences(of: "_", with: " "))
                        .font(.blip(size: 15, weight: .medium))
                        .foregroundStyle(BlipColor.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(BlipColor.textTertiary)
                }
                .frame(minHeight: BlipSpacing.tapTarget)
                .padding(.horizontal, BlipSpacing.lg)
                .background(
                    BlipColor.surface,
                    in: RoundedRectangle(cornerRadius: BlipRadius.sm, style: .continuous)
                )
            }
            .accessibilityLabel("change timezone")
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: BlipSpacing.md) {
            ErrorText(message: vm.errorMessage)

            Button("create blip", action: submit)
                .blipPrimary(isLoading: vm.isSubmitting)
                .disabled(!vm.isFormValid || vm.isSubmitting)
                .opacity(vm.isFormValid ? 1 : 0.4)
                .padding(.horizontal, BlipSpacing.xl)
        }
        .padding(.bottom, BlipSpacing.xxl)
    }

    // MARK: - Actions

    private func submit() {
        nameFocused = false
        guard case .signedIn(let uid) = auth.state else { return }
        vm.submit(uid: uid, repo: repo)
    }
}

#Preview {
    CreateBlipView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}
