import SwiftUI

// MARK: - Invite sheet (3-tab bottom sheet)

/// Presented from BlipDetailView when the user taps an empty invite seat.
/// Three tabs:
///   1. Share  — shows the blip's join-code QR + share link button.
///   2. Scan   — opens a VisionKit QR scanner; scanned handle auto-fills the
///               confirmation flow.
///   3. Handle — manual handle entry with real-time lookup + send invite.
struct InviteSheet: View {
    let blip: Blip
    let currentUid: String
    let currentHandle: String?

    @Environment(\.dismiss) private var dismiss
    @State private var tab: InviteTab = .share
    @State private var showShareSheet = false
    @State private var scannedHandle: String?
    @State private var showScanner = false

    enum InviteTab: CaseIterable, Hashable {
        case share, scan, handle
        var label: String {
            switch self {
            case .share:  return "Share"
            case .scan:   return "Scan QR"
            case .handle: return "By Handle"
            }
        }
        var icon: String {
            switch self {
            case .share:  return "square.and.arrow.up"
            case .scan:   return "qrcode.viewfinder"
            case .handle: return "at"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabPicker

                    switch tab {
                    case .share:
                        shareTab
                    case .scan:
                        scanTab
                    case .handle:
                        handleTab
                    }
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
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [inviteText])
        }
        // Use fullScreenCover instead of .sheet so we never nest two sheets
        // (sheet-in-sheet crashes on iOS < 16.4).
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerSheet(onScanned: { raw in
                showScanner = false
                if let handle = QRScannerView.extractHandle(from: raw) {
                    scannedHandle = handle
                    tab = .handle
                }
            }, onCancel: { showScanner = false })
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
                            .font(.system(size: 19, weight: on ? .bold : .medium))
                            .foregroundStyle(on ? .white : Color.white.opacity(0.38))
                            .scaleEffect(on ? 1.07 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: on)
                        Text(t.label)
                            .font(.blip(size: 10, weight: on ? .bold : .medium))
                            .foregroundStyle(on ? .white : Color.white.opacity(0.38))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(on ? BlipColor.surfaceElevated : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(BlipColor.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(BlipColor.border).frame(height: 0.5)
        }
    }

    // MARK: - Share tab

    private var shareTab: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Blip join-code QR
                VStack(spacing: 14) {
                    QRCodeImageView(
                        data: "blip://join/\(blip.joinCode)",
                        centerURL: nil,
                        size: 200
                    )
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)

                    VStack(spacing: 3) {
                        Text("join code")
                            .font(.blip(size: 11, weight: .semibold))
                            .foregroundStyle(BlipColor.textTertiary)
                        Text(blip.joinCode)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(BlipColor.textPrimary)
                            .kerning(3)
                    }
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

    // MARK: - Scan tab

    private var scanTab: some View {
        VStack(spacing: 20) {
            Text("scan a friend's profile QR code to invite them")
                .font(.blip(size: 14))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 24)

            Button {
                showScanner = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BlipColor.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                                .foregroundStyle(BlipColor.border)
                        )

                    VStack(spacing: 10) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(BlipColor.textPrimary)
                        Text("tap to open camera")
                            .font(.blip(size: 14, weight: .medium))
                            .foregroundStyle(BlipColor.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Handle tab

    private var handleTab: some View {
        HandleInviteView(
            blip: blip,
            currentUid: currentUid,
            currentHandle: currentHandle,
            prefillHandle: scannedHandle
        )
    }

    // MARK: - Helpers

    private var inviteText: String {
        InviteShare.text(blipName: blip.name, joinCode: blip.joinCode, referrerUid: currentUid)
    }
}

// MARK: - Full-screen scanner sheet wrapper

private struct QRScannerSheet: View {
    let onScanned: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            QRScannerView(onScanned: onScanned, onCancel: onCancel)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("cancel", action: onCancel)
                            .foregroundStyle(.white)
                    }
                }
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
    }
}
