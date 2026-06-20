import SwiftUI

// MARK: - Invite sheet (3-option bottom sheet)
//
// Shown from BlipDetailView when the user taps an empty invite seat.
//
// Three options:
//   1. Share link — share the blip's join URL / code.
//   2. Scan QR    — scan another user's PROFILE QR (blip://user/{handle})
//                   and DIRECTLY add them to the group (no request needed).
//   3. QR code    — show THIS GROUP's join-code QR so the invitee can scan
//                   it themselves to join.
//
// Profile QR  = encodes blip://user/{handle}  → identifies a person.
// Group QR    = encodes blip://join/{joinCode} → joins a specific blip.

struct InviteSheet: View {
    let blip: Blip
    let currentUid: String
    let currentHandle: String?

    @Environment(\.dismiss) private var dismiss
    @State private var tab: InviteTab = .share
    @State private var showShareSheet = false
    @State private var showScanner = false
    @State private var scannedHandle: String?

    // 3-D flip success overlay
    @State private var successHandle: String?
    @State private var showSuccess = false

    enum InviteTab: CaseIterable, Hashable {
        case share, scan, qrcode
        var label: String {
            switch self {
            case .share:  return "Link"
            case .scan:   return "Scan"
            case .qrcode: return "Group QR"
            }
        }
        var icon: String {
            switch self {
            case .share:  return "link"
            case .scan:   return "qrcode.viewfinder"
            case .qrcode: return "qrcode"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabPicker
                    switch tab {
                    case .share:  shareTab
                    case .scan:   scanTab
                    case .qrcode: groupQRTab
                    }
                }

                // 3-D flip success overlay
                if showSuccess, let h = successHandle {
                    QRScanSuccessView(handle: h) {
                        showSuccess = false
                        successHandle = nil
                        dismiss()
                    }
                    .zIndex(10)
                }
            }
            .navigationTitle("invite to \(blip.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BlipColor.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(BlipColor.surface, in: Circle())
                    }
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [inviteText])
        }
        // QR scanner — full-screen cover to avoid sheet-in-sheet crash
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerSheet(onScanned: handleScanResult, onCancel: { showScanner = false })
        }
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(InviteTab.allCases, id: \.self) { t in
                let on = tab == t
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { tab = t }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: t.icon)
                            .font(.system(size: 18, weight: on ? .bold : .medium))
                            .foregroundStyle(on ? BlipColor.accentNeutral : BlipColor.textTertiary)
                            .scaleEffect(on ? 1.06 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: on)
                        Text(t.label)
                            .font(.blip(size: 10, weight: on ? .bold : .medium))
                            .foregroundStyle(on ? BlipColor.accentNeutral : BlipColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        on ? BlipColor.accentNeutral.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 0)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(BlipColor.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(BlipColor.border).frame(height: 0.5)
        }
    }

    // MARK: - Share link tab

    private var shareTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Join code pill
                VStack(spacing: 6) {
                    Text("join code")
                        .font(.blip(size: 11, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                    Text(blip.joinCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(BlipColor.textPrimary)
                        .kerning(4)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(BlipColor.surface,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: BlipColor.accent.opacity(0.08), radius: 8, x: 0, y: 3)
                }

                Button { showShareSheet = true } label: {
                    Label("share invite link", systemImage: "square.and.arrow.up")
                }
                .blipPrimary()
                .padding(.horizontal, 20)
            }
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Scan tab (direct add — no request needed)

    private var scanTab: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("scan their profile QR")
                    .font(.blip(size: 16, weight: .bold))
                    .foregroundStyle(BlipColor.textPrimary)
                Text("ask your friend to open their profile → tap the QR card.\nScanning adds them directly — no request needed.")
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            Button { showScanner = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(BlipColor.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )
                                .foregroundStyle(BlipColor.accent.opacity(0.4))
                        )

                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 46, weight: .light))
                            .foregroundStyle(BlipColor.accentNeutral)
                        Text("tap to open scanner")
                            .font(.blip(size: 14, weight: .semibold))
                            .foregroundStyle(BlipColor.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Group QR tab

    private var groupQRTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("group QR code")
                        .font(.blip(size: 16, weight: .bold))
                        .foregroundStyle(BlipColor.textPrimary)
                    Text("show this to someone — they scan it to join \(blip.name).")
                        .font(.blip(size: 13))
                        .foregroundStyle(BlipColor.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Group QR — encodes the join code
                QRCodeImageView(
                    data: "blip://join/\(blip.joinCode)",
                    centerURL: nil,
                    size: 210
                )
                .shadow(color: BlipColor.accent.opacity(0.12), radius: 12, x: 0, y: 4)

                Text("blip://join/\(blip.joinCode)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BlipColor.textTertiary)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Scan result handler (direct add)

    private func handleScanResult(_ raw: String) {
        showScanner = false
        guard let handle = QRScannerView.extractHandle(from: raw) else { return }
        scannedHandle = handle

        // Directly add user to the group (write auto-approve invite)
        Task {
            let service = BlipInviteService()
            do {
                try await service.sendDirectAdd(
                    handle: handle,
                    blip: blip,
                    inviterUid: currentUid,
                    inviterHandle: currentHandle
                )
                successHandle = handle
                withAnimation { showSuccess = true }
            } catch {
                // Fall back to showing the handle-entry tab with pre-fill
                tab = .scan
            }
        }
    }

    private var inviteText: String {
        InviteShare.text(blipName: blip.name, joinCode: blip.joinCode, referrerUid: currentUid)
    }
}

// MARK: - Scanner full-screen sheet

private struct QRScannerSheet: View {
    let onScanned: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            QRScannerView(onScanned: onScanned, onCancel: onCancel)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("cancel", action: onCancel).foregroundStyle(.white)
                    }
                }
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
    }
}
