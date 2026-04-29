import FirebaseFirestore
import Foundation

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var sendToBlipIds: Set<String>
    @Published var caption: String = ""
    @Published var errorMessage: String?

    private let uploader = ClipUploader()
    private let db = Firestore.firestore()
    let primaryBlip: Blip

    init(blip: Blip) {
        self.primaryBlip = blip
        self.sendToBlipIds = [blip.id]
    }

    var canPost: Bool { !sendToBlipIds.isEmpty && !uploader.isUploading }
    var isUploading: Bool { uploader.isUploading }
    var uploadProgress: Double { uploader.progress }

    func toggleDestination(_ id: String) {
        if sendToBlipIds.contains(id) { sendToBlipIds.remove(id) }
        else { sendToBlipIds.insert(id) }
    }

    func post(uid: String, fileURL: URL) async {
        errorMessage = nil
        do {
            // Pre-flight membership check guards against a stale local blip snapshot.
            let snapshot = try await db.collection("blips").document(primaryBlip.id).getDocument()
            let liveMembers = (snapshot.data()?["members"] as? [String]) ?? []

            #if DEBUG
            print("[blip-diag] uid=\(uid) liveMembers=\(liveMembers) match=\(liveMembers.contains(uid))")
            #endif

            guard liveMembers.contains(uid) else {
                errorMessage = "you're not a member of this blip — try the join code."
                return
            }

            try await uploader.upload(
                fileURL: fileURL,
                uid: uid,
                primaryBlipId: primaryBlip.id,
                sharedToBlipIds: Array(sendToBlipIds),
                caption: caption.isEmpty ? nil : caption
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
