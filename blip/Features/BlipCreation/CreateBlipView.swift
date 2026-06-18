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
                    ScrollView {
                        content
                            .padding(.vertical, 28)
                    }
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
                            .font(.blip(size: 16, weight: .medium))
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
                .font(.blip(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(BlipColor.textPrimary)
            Text("pick a name, crew size, and daily blip window")
                .font(.blip(size: 14))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    // MARK: - Name + size + schedule

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
                        .font(.blip(size: 11, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Text(vm.sizeDescription(vm.size))
                        .font(.blip(size: 13))
                        .foregroundStyle(BlipColor.textPrimary)
                        .animation(.easeOut(duration: 0.15), value: vm.size)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(vm.sizeOptions, id: \.self) { n in
                        Button {
                            withAnimation(.spring(duration: 0.2)) { vm.size = n }
                        } label: {
                            Text("\(n)")
                                .font(.blip(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    vm.size == n ? BlipColor.accentNeutral : BlipColor.surface,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .foregroundStyle(vm.size == n ? BlipColor.accentNeutralOn : BlipColor.textSecondary)
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

    private var schedulePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("daily window")
                    .font(.blip(size: 11, weight: .semibold))
                    .foregroundStyle(BlipColor.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(vm.scheduleDescription)
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textPrimary)
            }

            HStack(spacing: 10) {
                hourMenu(title: "from", selection: $vm.activeStartHour)
                Image(systemName: "arrow.right")
                    .font(.blip(size: 13, weight: .semibold))
                    .foregroundStyle(BlipColor.textTertiary)
                hourMenu(title: "to", selection: $vm.activeEndHour)
            }

            Text("everyone records on \(timezoneLabel). the end hour is when recording closes.")
                .font(.blip(size: 12))
                .foregroundStyle(BlipColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hourMenu(title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.blip(size: 10, weight: .semibold))
                .foregroundStyle(BlipColor.textTertiary)
                .textCase(.uppercase)
            Picker(title, selection: selection) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(BlipHour.hourLabel(hour)).tag(hour)
                }
            }
            .pickerStyle(.menu)
            .tint(BlipColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private var timezoneLabel: String {
        TimeZone.current.identifier.replacingOccurrences(of: "_", with: " ")
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
