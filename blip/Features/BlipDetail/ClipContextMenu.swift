import Photos
import SwiftUI

/// Screen-10 parity — long-press menu on a posted clip: delete / edit caption / save.
/// Author-only operations (delete, edit caption) gate on the clip's uid matching the current user.
struct ClipContextMenu: ViewModifier {
    let clip: BlipClip
    let isAuthor: Bool
    let onDelete: () -> Void
    let onEditCaption: () -> Void
    let onReRecord: (() -> Void)?

    func body(content: Content) -> some View {
        content.contextMenu {
            if isAuthor {
                if let onReRecord {
                    Button { onReRecord() } label: {
                        Label("re-record", systemImage: "arrow.counterclockwise")
                    }
                }
                Button { onEditCaption() } label: {
                    Label("edit caption", systemImage: "textformat")
                }
                Button(role: .destructive) { onDelete() } label: {
                    Label("delete", systemImage: "trash")
                }
            }
            Button { Task { await ClipSaver.save(clip: clip) } } label: {
                Label("save", systemImage: "square.and.arrow.down")
            }
        }
    }
}

extension View {
    func clipContextMenu(
        clip: BlipClip,
        isAuthor: Bool,
        onDelete: @escaping () -> Void,
        onEditCaption: @escaping () -> Void,
        onReRecord: (() -> Void)? = nil
    ) -> some View {
        modifier(ClipContextMenu(
            clip: clip,
            isAuthor: isAuthor,
            onDelete: onDelete,
            onEditCaption: onEditCaption,
            onReRecord: onReRecord
        ))
    }
}

/// Downloads the clip MP4 to a temp file and writes it to the user's Photos library.
enum ClipSaver {
    static func save(clip: BlipClip) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: clip.videoUrl)
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("blip-save-\(clip.id).mov")
            try data.write(to: tmp)

            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { return }

            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmp)
            }
        } catch {
            // Surface in a toast next pass; silent for now.
        }
    }
}
