import SwiftUI

struct PhoneAuthView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var country: CountryCode = .default
    @State private var localNumber = ""
    @State private var otpCode = ""
    @State private var verificationID: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCountryPicker = false

    private var isOTPStep: Bool { verificationID != nil }

    // Assembled E.164: "+12125550123"
    private var e164: String {
        let digits = localNumber.filter(\.isNumber)
        return country.dialCode + digits
    }

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()
            DoodleBackground(intensity: 0.7)

            VStack(spacing: 0) {
                navBar
                Spacer()
                if isOTPStep { otpContent } else { phoneContent }
                Spacer()
                actionSection
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selection: $country)
        }
        .animation(.easeOut(duration: 0.2), value: isOTPStep)
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack {
            Button(action: handleBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(width: 36, height: 36)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Phone step

    private var phoneContent: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("what's your number?")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(BlipColor.textPrimary)
                Text("we'll send a one-time code to verify it's you")
                    .font(.system(size: 14))
                    .foregroundStyle(BlipColor.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            // Country + number row
            HStack(spacing: 10) {
                // Country code button
                Button { showCountryPicker = true } label: {
                    HStack(spacing: 6) {
                        Text(country.flag)
                            .font(.system(size: 22))
                        Text(country.dialCode)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(BlipColor.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BlipColor.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Phone number field
                TextField("555 000 0000", text: $localNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(height: 52)
                    .padding(.horizontal, 14)
                    .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BlipColor.border, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - OTP step

    private var otpContent: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("check your texts")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(BlipColor.textPrimary)
                Text("we sent a 6-digit code to\n\(country.dialCode) \(localNumber)")
                    .font(.system(size: 14))
                    .foregroundStyle(BlipColor.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            // OTP digit field
            TextField("000000", text: $otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(BlipColor.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
                .onChange(of: otpCode) { _, v in
                    if v.count > 6 { otpCode = String(v.prefix(6)) }
                }
        }
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(spacing: 14) {
            ErrorText(message: errorMessage)

            Button(isOTPStep ? "Verify" : "Send code") {
                Task { await handlePrimary() }
            }
            .blipPrimary(isLoading: isLoading)
            .disabled(isLoading || primaryDisabled)
            .opacity(primaryDisabled ? 0.4 : 1)
            .padding(.horizontal, 24)

            if isOTPStep {
                Button("Resend code") { Task { await sendCode() } }
                    .blipGhost()
            }
        }
        .padding(.bottom, 36)
    }

    private var primaryDisabled: Bool {
        isOTPStep
            ? otpCode.count < 6
            : localNumber.filter(\.isNumber).count < 6
    }

    // MARK: - Logic

    private func handleBack() {
        if isOTPStep {
            verificationID = nil
            otpCode = ""
            errorMessage = nil
        } else {
            dismiss()
        }
    }

    private func handlePrimary() async {
        isOTPStep ? await verifyCode() : await sendCode()
    }

    private func sendCode() async {
        isLoading = true
        errorMessage = nil
        do {
            verificationID = try await auth.startPhoneVerification(phoneE164: e164)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func verifyCode() async {
        guard let vid = verificationID else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await auth.confirmPhoneCode(verificationID: vid, code: otpCode)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Country Picker Sheet

private struct CountryPickerSheet: View {
    @Binding var selection: CountryCode
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [CountryCode] {
        let q = search.lowercased()
        guard !q.isEmpty else { return CountryCode.all }
        return CountryCode.all.filter {
            $0.name.lowercased().contains(q) || $0.dialCode.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selection = country
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(country.flag).font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.name)
                                .font(.system(size: 15))
                                .foregroundStyle(BlipColor.textPrimary)
                            Text(country.dialCode)
                                .font(.system(size: 12))
                                .foregroundStyle(BlipColor.textTertiary)
                        }
                        Spacer()
                        if country == selection {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BlipColor.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(BlipColor.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BlipColor.background)
            .searchable(text: $search, prompt: "Search country or code")
            .navigationTitle("Select country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BlipColor.accent)
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
        }
    }
}
