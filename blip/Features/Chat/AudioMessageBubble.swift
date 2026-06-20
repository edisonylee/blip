import AVFoundation
import SwiftUI

// MARK: - Waveform bar view

/// 30-bar animated spectrum.  Bars to the left of `progress` are coloured
/// with `activeColor`; the rest use `inactiveColor`.  When `isAnimating`
/// is true every bar oscillates independently (used while recording).
struct AudioWaveformView: View {
    /// Normalised bar heights 0…1.  Exactly 30 expected.
    let bars: [CGFloat]
    /// Playback progress 0…1. Set to 0 when idle.
    var progress: Double = 0
    /// Colour for "played" / "live" bars.
    var activeColor: Color = BlipColor.accentNeutral
    /// Colour for "unplayed" bars.
    var inactiveColor: Color = Color.black.opacity(0.18)
    /// When true the bars animate independently (recording mode).
    var isAnimating: Bool = false

    @State private var phases: [Double] = (0..<30).map { Double($0) * 0.4 }
    @State private var tick = false

    private let barW: CGFloat = 3
    private let barSpacing: CGFloat = 2.5
    private let maxH: CGFloat = 28

    var body: some View {
        HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<bars.count, id: \.self) { i in
                let fraction = bars[i]
                let isActive = Double(i) / Double(bars.count) < progress || isAnimating
                let h: CGFloat = isAnimating
                    ? max(4, fraction * maxH * CGFloat(0.6 + 0.4 * sin(phases[i])))
                    : max(4, fraction * maxH)

                RoundedRectangle(cornerRadius: barW / 2)
                    .fill(isActive ? activeColor : inactiveColor)
                    .frame(width: barW, height: h)
                    .animation(
                        isAnimating
                            ? .easeInOut(duration: 0.18)
                            : .spring(response: 0.25, dampingFraction: 0.7),
                        value: h
                    )
            }
        }
        .frame(height: maxH)
        .onAppear  { if isAnimating { startOscillating() } }
        .onDisappear { tick = false }
        .onChange(of: isAnimating) { _, on in
            if on { startOscillating() } else { tick = false }
        }
    }

    private func startOscillating() {
        tick = true
        func step() {
            guard tick else { return }
            for i in 0..<phases.count {
                phases[i] += Double.random(in: 0.08...0.22)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { step() }
        }
        step()
    }
}

// MARK: - AVPlayer state (per-message)

@MainActor
final class AudioPlayerState: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0    // 0…1
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVPlayer?
    private var observer: Any?
    private var endObserver: Any?

    func toggle(url: URL, expectedDuration: Double) {
        if player == nil { setup(url: url, expectedDuration: expectedDuration) }
        if isPlaying { pause() } else { play() }
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        let t = fraction * duration
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600))
        progress = fraction
        currentTime = t
    }

    // MARK: - Private

    private func setup(url: URL, expectedDuration: Double) {
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        self.player = p
        self.duration = expectedDuration

        observer = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let t = time.seconds
            Task { @MainActor in
                self.currentTime = t
                if self.duration > 0 { self.progress = t / self.duration }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.progress = 0
                self?.currentTime = 0
                self?.player?.seek(to: .zero)
            }
        }

        do {
            try AVAudioSession.sharedInstance()
                .setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }

    private func play() {
        player?.play()
        isPlaying = true
    }

    private func pause() {
        player?.pause()
        isPlaying = false
    }

    deinit {
        if let obs = observer { player?.removeTimeObserver(obs) }
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
    }
}

// MARK: - Audio message bubble

/// Rendered inside MessageRow for `.audio` type messages.
struct AudioMessageBubble: View {
    let message: BlipMessage
    let isMe: Bool
    let senderLabel: String

    @StateObject private var playerState = AudioPlayerState()

    private var bars: [CGFloat] {
        // Use stored waveform or fall back to deterministic pseudo-random.
        if !message.waveform.isEmpty {
            return message.waveform.map { CGFloat($0) }
        }
        return deterministicBars(for: message.id)
    }

    private var durationText: String {
        let secs = Int(message.audioDuration ?? 0)
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private var bubbleBg: Color { isMe ? BlipColor.accentNeutral : Color.white.opacity(0.90) }
    private var fgPrimary: Color { isMe ? .white : BlipColor.textPrimary }
    private var fgSecondary: Color { isMe ? .white.opacity(0.75) : BlipColor.textSecondary }
    private var activeWave: Color { isMe ? .white : BlipColor.accentNeutral }
    private var inactiveWave: Color {
        isMe ? .white.opacity(0.35) : Color.black.opacity(0.15)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                if !isMe {
                    Text(senderLabel)
                        .font(.blip(size: 11, weight: .medium))
                        .foregroundStyle(BlipColor.textTertiary)
                        .padding(.horizontal, 4)
                }

                // Bubble
                HStack(spacing: 10) {
                    // Play / pause button
                    Button {
                        guard let url = message.audioUrl else { return }
                        playerState.toggle(url: url, expectedDuration: message.audioDuration ?? 0)
                    } label: {
                        Image(systemName: playerState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(fgPrimary)
                            .frame(width: 34, height: 34)
                            .background(fgPrimary.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(message.audioUrl == nil)

                    VStack(alignment: .leading, spacing: 4) {
                        // Waveform with playback progress
                        AudioWaveformView(
                            bars: bars,
                            progress: playerState.progress,
                            activeColor: activeWave,
                            inactiveColor: inactiveWave
                        )
                        .frame(width: 140)
                        .onTapGesture { loc in } // future: scrubbing

                        // Duration / current time
                        Text(playerState.isPlaying
                             ? formatTime(playerState.currentTime)
                             : durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(fgSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(bubbleBg)
                .clipShape(BubbleShape(myMessage: isMe))
                .shadow(color: .black.opacity(isMe ? 0.10 : 0.06), radius: 4, x: 0, y: 2)
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // Deterministic pseudo-random bars seeded by message id
    private func deterministicBars(for id: String) -> [CGFloat] {
        var h = 0
        for c in id.unicodeScalars { h = h &* 31 &+ Int(c.value) }
        var seed = UInt64(bitPattern: Int64(h))
        return (0..<30).map { _ in
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let val = CGFloat(seed >> 33) / CGFloat(UInt32.max)
            return 0.15 + val * 0.85
        }
    }
}

// MARK: - Recording preview bar (shown in input area after recording)

struct AudioPreviewBar: View {
    let bars: [CGFloat]
    let duration: TimeInterval
    let onDelete: () -> Void
    let onSend: () -> Void
    var isSending: Bool = false

    @StateObject private var player = AudioPlayerState()
    @State private var previewURL: URL?

    init(
        bars: [CGFloat], duration: TimeInterval,
        previewURL: URL? = nil,
        onDelete: @escaping () -> Void,
        onSend: @escaping () -> Void,
        isSending: Bool = false
    ) {
        self.bars = bars
        self.duration = duration
        self._previewURL = State(initialValue: previewURL)
        self.onDelete = onDelete
        self.onSend = onSend
        self.isSending = isSending
    }

    private var durationText: String {
        let s = Int(duration)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Delete
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BlipColor.error)
                    .frame(width: 36, height: 36)
                    .background(BlipColor.error.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSending)

            // Play preview + waveform
            HStack(spacing: 8) {
                Button {
                    guard let url = previewURL else { return }
                    player.toggle(url: url, expectedDuration: duration)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BlipColor.accentNeutral)
                        .frame(width: 30, height: 30)
                        .background(BlipColor.accentNeutral.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(previewURL == nil)

                VStack(alignment: .leading, spacing: 3) {
                    AudioWaveformView(
                        bars: bars,
                        progress: player.progress,
                        activeColor: BlipColor.accentNeutral,
                        inactiveColor: Color.black.opacity(0.12)
                    )
                    .frame(maxWidth: .infinity)

                    Text(player.isPlaying
                         ? String(format: "%d:%02d", Int(player.currentTime) / 60, Int(player.currentTime) % 60)
                         : durationText)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(BlipColor.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.05), in: Capsule())

            // Send
            Button(action: onSend) {
                if isSending {
                    ProgressView().scaleEffect(0.7).tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 36, height: 36)
            .background(BlipColor.accentNeutral, in: Circle())
            .buttonStyle(.plain)
            .disabled(isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.9))
    }
}
