import SwiftUI
import UIKit

// MARK: - CachedAsyncImage

/// Drop-in replacement for `AsyncImage` that aggressively caches responses on
/// disk so the same image is never downloaded twice per install.
///
/// Why not plain `AsyncImage`?
///   Firebase Storage CDN serves `Cache-Control: no-cache` by default, which
///   forces URLSession to re-validate on every request even when the byte
///   payload hasn't changed.  CachedAsyncImage overrides the caching policy
///   to `.returnCacheDataElseLoad` so a cached image is served from
///   URLCache.shared instantly without a network round-trip.
///
/// Usage — identical to AsyncImage:
///   CachedAsyncImage(url: photoURL) { phase in
///       switch phase {
///       case .success(let img): img.resizable().scaledToFill()
///       default: Color.gray
///       }
///   }
///
/// The struct is intentionally non-generic: the generic constraint lives on
/// the init so the compiler never needs to resolve `Content: View` as a
/// top-level type name (which confuses older toolchain versions).
struct CachedAsyncImage: View {

    private let url: URL?
    // Type-erased so the struct itself carries no generic parameter.
    private let buildContent: (AsyncImagePhase) -> AnyView

    @State private var phase: AsyncImagePhase = .empty

    /// `content` accepts any View-returning closure — identical usage to AsyncImage.
    init<C: View>(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> C) {
        self.url = url
        self.buildContent = { phase in AnyView(erasing: content(phase)) }
    }

    var body: some View {
        // ZStack gives a stable container identity so .task() doesn't race
        // with content identity changes when the phase updates.
        ZStack { buildContent(phase) }
            .task(id: url?.absoluteString) { await load() }
    }

    // MARK: - Load

    private func load() async {
        guard let url else { phase = .empty; return }

        var request = URLRequest(url: url)
        // Serve from URLCache.shared first; hit network only on cache miss.
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

    /// Call once at app startup (blipApp.init) to allocate the on-disk budget.
    /// 100 MB memory + 500 MB disk covers hundreds of photos/thumbnails.
    static func configureSharedCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity:   500 * 1024 * 1024,
            diskPath: "blip.image-cache"
        )
    }
}
