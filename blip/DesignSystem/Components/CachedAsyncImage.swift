import SwiftUI
import UIKit

// MARK: - CachedAsyncImage

/// Drop-in replacement for `AsyncImage` that aggressively caches responses on
/// disk so the same image is never downloaded twice per install.
///
/// Why not plain `AsyncImage`?
///   Firebase Storage CDN serves `Cache-Control: no-cache` by default, which
///   tells `URLSession` to re-validate on every request even when the byte
///   payload hasn't changed. `CachedAsyncImage` overrides the caching policy
///   to `.returnCacheDataElseLoad` so a cached image is served from
///   `URLCache.shared` instantly without a network round-trip.
///
/// Usage — identical to `AsyncImage`:
/// ```swift
/// CachedAsyncImage(url: photoURL) { phase in
///     switch phase {
///     case .success(let img): img.resizable().scaledToFill()
///     default: Color.gray
///     }
/// }
/// ```
///
/// Startup:  call `CachedAsyncImage.configureSharedCache()` once in
///           `blipApp.init()` (or `AppDelegate.application(_:didFinish:)`)
///           to set the memory + disk budget for `URLCache.shared`.
struct CachedAsyncImage<Content: View>: View {

    private let url: URL?
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url?.absoluteString) { await load() }
    }

    // MARK: - Load

    private func load() async {
        guard let url else { phase = .empty; return }

        var request = URLRequest(url: url)
        // Always serve from cache first; fetch from network only on cache miss.
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let ui = UIImage(data: data) {
                phase = .success(Image(uiImage: ui))
            } else {
                phase = .failure(URLError(.cannotDecodeContentData))
            }
        } catch {
            phase = .failure(error)
        }
    }

    // MARK: - Cache configuration

    /// Call once at app startup to give `URLCache.shared` a generous budget.
    /// 100 MB memory + 500 MB disk covers hundreds of profile photos and
    /// thumbnails without touching the network on repeat visits.
    static func configureSharedCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024,   // 100 MB
            diskCapacity:   500 * 1024 * 1024,   // 500 MB
            diskPath: "blip.image-cache"
        )
    }
}
