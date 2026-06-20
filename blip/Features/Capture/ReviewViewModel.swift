import Combine
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
    private var cancellables = Set<AnyCancellable>()

    init(blip: Blip) {
        self.primaryBlip = blip
        self.sendToBlipIds = [blip.id]
        // ClipUploader's published properties (isUploading, progress) live on a
        // separate ObservableObject. SwiftUI only re-renders when *this* VM's
        // objectWillChange fires, so we pipe the uploader's changes through here.
        uploader.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var canPost: Bool { !sendToBlipIds.isEmpty && !uploader.isUploading }
    var isUploading: Bool { uploader.isUploading }
    var uploadProgress: Double { uploader.progress }

    func toggleDestination(_ id: String) {
        if sendToBlipIds.contains(id) { sendToBlipIds.remove(id) }
        else { sendToBlipIds.insert(id) }
    }

    func post(uid: String, fileURL: URL, availableBlips: [Blip]) async {
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

            let blipsById = Dictionary(uniqueKeysWithValues: availableBlips.map { ($0.id, $0) })
            let destinations = sendToBlipIds.compactMap { id in
                id == primaryBlip.id ? primaryBlip : blipsById[id]
            }
            guard destinations.count == sendToBlipIds.count else {
                errorMessage = "one of those blips is no longer available."
                return
            }

            try await uploader.upload(
                fileURL: fileURL,
                uid: uid,
                primaryBlip: primaryBlip,
                destinations: destinations,
                caption: caption.isEmpty ? nil : caption
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
