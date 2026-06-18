import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

@MainActor
final class UserRepository: ObservableObject, BlipUserMutating {
    @Published private(set) var profile: BlipUser?
    @Published private(set) var lastError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(for uid: String) {
        listener?.remove()
        listener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        return
                    }
                    guard let data = snapshot?.data() else {
                        self.profile = nil
                        return
                    }
                    self.profile = BlipUser(uid: uid, firestoreData: data)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        profile = nil
    }

    /// Sets the user's free-form school string. Pass `nil` (or an empty string)
    /// to clear it. Trimming/empty-collapse happens here so the field is either
    /// non-empty or absent — no whitespace-only values land in Firestore.
    func updateSchool(_ school: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = school?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: Any = (trimmed?.isEmpty ?? true) ? FieldValue.delete() : trimmed!
        try await db.collection("users").document(uid).setData([
            "school": value,
            "updatedAt": Timestamp(date: Date()),
        ], merge: true)
    }

    /// Persists a freshly-uploaded avatar URL to the user doc. The actual
    /// Storage write is owned by `ProfilePhotoUploader`; this only swaps the
    /// pointer so the listener-based `profile` re-publishes.
    func updatePhotoURL(_ url: URL) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData([
            "photoURL": url.absoluteString,
            "updatedAt": Timestamp(date: Date()),
        ], merge: true)
    }

    func updateQuietHours(start: Int, end: Int) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData([
            "quietHoursStart": start,
            "quietHoursEnd": end,
            "timezoneIdentifier": TimeZone.current.identifier,
            "updatedAt": Timestamp(date: Date()),
        ], merge: true)
    }

    /// Idempotently adds an FCM device token to the current user's profile.
    /// Called by AppDelegate when Firebase Messaging issues a token.
    func addFcmToken(_ token: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData([
            "fcmTokens": FieldValue.arrayUnion([token]),
            "timezoneIdentifier": TimeZone.current.identifier,
            "updatedAt": Timestamp(date: Date()),
        ], merge: true)
    }

    func removeFcmToken(_ token: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData([
            "fcmTokens": FieldValue.arrayRemove([token]),
            "updatedAt": Timestamp(date: Date()),
        ], merge: true)
    }

    /// First-sign-in baseline. Writes createdAt + zeroed stat fields only when the
    /// user doc doesn't already exist, so this is safe to call on every launch.
    /// Runs as a transaction so two devices first-signing-in concurrently don't
    /// double-write or clobber each other.
    ///
    /// `referredByUid` is the uid stashed by `DeepLinkRouter` from a
    /// `blip://invite?ref=UID` link that landed before signup. When non-nil
    /// and not equal to `uid`, it's baked into the doc on first create — the
    /// `onUserCreated` Cloud Function then atomically credits the referrer.
    func ensureUserDoc(uid: String, referredByUid: String? = nil) async throws {
        let ref = db.collection("users").document(uid)
        _ = try await db.runTransaction { txn, _ in
            let snap: DocumentSnapshot
            do { snap = try txn.getDocument(ref) } catch { return nil }
            if snap.exists { return nil }
            var data: [String: Any] = [
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "displayName": "",
                "fcmTokens": [],
                "blockedUsers": [],
                "totalClips": 0,
                "streakCurrent": 0,
                "streakBest": 0,
                "friendsCount": 0,
                "referralsCount": 0,
                "timezoneIdentifier": TimeZone.current.identifier,
                "quietHoursStart": 23,
                "quietHoursEnd": 7,
            ]
            // Self-loop guard at the client too — rules + Cloud Function are the
            // real defences, this just avoids a wasted write on the same device.
            if let ref = referredByUid, !ref.isEmpty, ref != uid {
                data["referredByUid"] = ref
            }
            txn.setData(data, forDocument: ref)
            return nil
        }
    }

    /// Atomically claims a handle for the current user. Releases the user's
    /// previous handle (if any) in the same transaction so the lookup index
    /// stays consistent. Throws `HandleError.invalidFormat` for bad input,
    /// `.alreadyTaken` when another uid owns it, and `.notSignedIn` if there's
    /// no current auth user.
    func claimHandle(_ raw: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw HandleError.notSignedIn }
        let normalized = Handle.normalize(raw)
        guard Handle.isValid(normalized) else { throw HandleError.invalidFormat }

        let userRef = db.collection("users").document(uid)
        let newHandleRef = db.collection("usernames").document(normalized)

        do {
            _ = try await db.runTransaction { txn, errPtr in
                let userSnap: DocumentSnapshot
                let newHandleSnap: DocumentSnapshot
                do {
                    userSnap = try txn.getDocument(userRef)
                    newHandleSnap = try txn.getDocument(newHandleRef)
                } catch {
                    errPtr?.pointee = error as NSError
                    return nil
                }

                if newHandleSnap.exists, (newHandleSnap.data()?["uid"] as? String) != uid {
                    errPtr?.pointee = NSError(
                        domain: "Handle",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "alreadyTaken"]
                    )
                    return nil
                }

                if let oldHandle = userSnap.data()?["handle"] as? String, oldHandle != normalized {
                    let oldRef = self.db.collection("usernames").document(oldHandle)
                    txn.deleteDocument(oldRef)
                }

                txn.setData(
                    ["uid": uid, "claimedAt": FieldValue.serverTimestamp()],
                    forDocument: newHandleRef
                )
                txn.setData(
                    ["handle": normalized, "updatedAt": FieldValue.serverTimestamp()],
                    forDocument: userRef,
                    merge: true
                )
                return nil
            }
        } catch let error as NSError where error.domain == "Handle" {
            throw HandleError.alreadyTaken
        }
    }

    /// Credits the referrer for a `blip://invite?ref=…` link tapped *after*
    /// the user already signed up. The first-sign-in path is handled by
    /// `ensureUserDoc` + the `onUserCreated` trigger; this is the cover for
    /// the after-sign-in case where that trigger never fires.
    ///
    /// Server-side guards (in `claimReferral`): self-loop, already-credited,
    /// referrer-doesn't-exist. Throws on any of those.
    func claimReferral(_ referrerUid: String) async throws {
        guard Auth.auth().currentUser != nil else { return }
        let functions = Functions.functions(region: "us-central1")
        _ = try await functions.httpsCallable("claimReferral").call(["ref": referrerUid])
    }
}
