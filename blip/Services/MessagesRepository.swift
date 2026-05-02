import FirebaseAuth
import FirebaseDatabase
import Foundation

struct ReceiptEntry {
    let lastDelivered: Date?
    let lastSeen: Date?
}

enum TickStatus {
    case sent       // single gray  — written to RTDB
    case delivered  // double gray  — recipient device received
    case seen       // double blue  — recipient opened chat
}

/// Realtime chat for a blip group using Firebase RTDB.
///
/// RTDB path layout:
///   /chats/{blipId}/messages/{pushId}          — message nodes
///   /chats/{blipId}/typing/{uid}               — ephemeral typing presence
///   /chats/{blipId}/receipts/{uid}             — lastDelivered / lastSeen ms timestamps
///   /chats/{blipId}/hiddenBy/{uid}/{msgId}     — "delete for me" tombstones
@MainActor
final class MessagesRepository: ObservableObject {
    @Published private(set) var messages: [BlipMessage] = []
    @Published private(set) var typingUids: [String] = []
    @Published private(set) var receipts: [String: ReceiptEntry] = [:]
    @Published private(set) var hiddenMessageIds: Set<String> = []
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false

    /// Raw messages from RTDB before block filtering; kept so we can re-derive
    /// `messages` when the blocklist changes without re-listening.
    private var rawMessages: [BlipMessage] = []
    private var blockedUsers: Set<String> = []

    /// Push the current blocklist in. Owning view should call from
    /// `.onReceive(moderation.$blockedUsers)`.
    func setBlocklist(_ uids: Set<String>) {
        blockedUsers = uids
        messages = rawMessages.filter { !blockedUsers.contains($0.uid) }
    }

    private var messagesQuery: DatabaseQuery?
    private var typingRef: DatabaseReference?
    private var receiptsRef: DatabaseReference?
    private var hiddenRef: DatabaseReference?
    private var messagesHandle: DatabaseHandle?
    private var messagesChangedHandle: DatabaseHandle?
    private var typingHandle: DatabaseHandle?
    private var receiptsHandle: DatabaseHandle?
    private var hiddenHandle: DatabaseHandle?
    private var typingTimer: Timer?
    private(set) var blipId: String?

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    func clearError() { lastError = nil }

    deinit {
        if let messagesQuery, let handle = messagesHandle {
            messagesQuery.removeObserver(withHandle: handle)
        }
        if let messagesQuery, let handle = messagesChangedHandle {
            messagesQuery.removeObserver(withHandle: handle)
        }
        if let typingRef, let handle = typingHandle {
            typingRef.removeObserver(withHandle: handle)
        }
        if let receiptsRef, let handle = receiptsHandle {
            receiptsRef.removeObserver(withHandle: handle)
        }
        if let hiddenRef, let handle = hiddenHandle {
            hiddenRef.removeObserver(withHandle: handle)
        }
        if let blipId, let uid = Auth.auth().currentUser?.uid {
            Database.database().reference()
                .child("chats").child(blipId).child("typing").child(uid)
                .removeValue()
        }
    }

    // MARK: - Listen

    func startListening(blipId: String) {
        stopListening()
        self.blipId = blipId
        isLoading = true
        let chatRef = Database.database().reference().child("chats").child(blipId)

        // Stream last 200 messages (childAdded for new, childChanged for edits/deletions).
        let mRef = chatRef.child("messages").queryLimited(toLast: 200)
        messagesQuery = mRef

        messagesHandle = mRef.observe(.childAdded, with: { [weak self] snap in
            guard let self,
                  let data = snap.value as? [String: Any],
                  let msg = BlipMessage(id: snap.key, data: data)
            else { return }
            Task { @MainActor in
                self.lastError = nil
                self.isLoading = false
                guard !self.rawMessages.contains(where: { $0.id == msg.id }) else { return }
                self.rawMessages.append(msg)
                if !self.blockedUsers.contains(msg.uid) {
                    self.messages.append(msg)
                }
            }
        }, withCancel: { [weak self] error in
            Task { @MainActor in
                self?.lastError = "Chat listen failed: \(error.localizedDescription)"
                self?.isLoading = false
            }
        })

        messagesChangedHandle = mRef.observe(.childChanged, with: { [weak self] snap in
            guard let self,
                  let data = snap.value as? [String: Any],
                  let msg = BlipMessage(id: snap.key, data: data)
            else { return }
            Task { @MainActor in
                if let idx = self.rawMessages.firstIndex(where: { $0.id == msg.id }) {
                    self.rawMessages[idx] = msg
                }
                if let idx = self.messages.firstIndex(where: { $0.id == msg.id }) {
                    self.messages[idx] = msg
                }
            }
        })

        mRef.observeSingleEvent(of: .value, with: { [weak self] _ in
            Task { @MainActor in self?.isLoading = false }
        }, withCancel: { [weak self] error in
            Task { @MainActor in
                self?.lastError = "Chat load failed: \(error.localizedDescription)"
                self?.isLoading = false
            }
        })

        // Typing presence.
        let tRef = chatRef.child("typing")
        typingRef = tRef
        typingHandle = tRef.observe(.value, with: { [weak self] snap in
            guard let self else { return }
            Task { @MainActor in
                guard let myUid = self.currentUid else { return }
                var uids: [String] = []
                if let dict = snap.value as? [String: Any] {
                    let nowMs = Date().timeIntervalSince1970 * 1000
                    for (uid, val) in dict {
                        guard uid != myUid,
                              let entry = val as? [String: Any],
                              let isTyping = entry["isTyping"] as? Bool, isTyping,
                              let ts = entry["ts"] as? Double,
                              nowMs - ts < 6_000
                        else { continue }
                        uids.append(uid)
                    }
                }
                self.typingUids = uids
            }
        }, withCancel: { [weak self] error in
            Task { @MainActor in
                self?.lastError = "Typing listen failed: \(error.localizedDescription)"
            }
        })

        // Read receipts for tick status.
        let rRef = chatRef.child("receipts")
        receiptsRef = rRef
        receiptsHandle = rRef.observe(.value, with: { [weak self] snap in
            guard let self else { return }
            Task { @MainActor in
                guard let dict = snap.value as? [String: Any] else { self.receipts = [:]; return }
                var entries: [String: ReceiptEntry] = [:]
                for (uid, val) in dict {
                    guard let data = val as? [String: Any] else { continue }
                    entries[uid] = ReceiptEntry(
                        lastDelivered: Self.tsToDate(data["lastDelivered"]),
                        lastSeen: Self.tsToDate(data["lastSeen"])
                    )
                }
                self.receipts = entries
            }
        }, withCancel: { [weak self] error in
            Task { @MainActor in
                self?.lastError = "Receipts listen failed: \(error.localizedDescription)"
            }
        })

        // "Delete for me" tombstones for the current user.
        if let uid = currentUid {
            let hRef = chatRef.child("hiddenBy").child(uid)
            hiddenRef = hRef
            hiddenHandle = hRef.observe(.value, with: { [weak self] snap in
                Task { @MainActor in
                    guard let self else { return }
                    var ids = Set<String>()
                    if let dict = snap.value as? [String: Any] {
                        ids = Set(dict.keys)
                    }
                    self.hiddenMessageIds = ids
                }
            })
        }
    }

    func stopListening() {
        if let messagesQuery, let handle = messagesHandle {
            messagesQuery.removeObserver(withHandle: handle)
        }
        if let messagesQuery, let handle = messagesChangedHandle {
            messagesQuery.removeObserver(withHandle: handle)
        }
        if let typingRef, let handle = typingHandle {
            typingRef.removeObserver(withHandle: handle)
        }
        if let receiptsRef, let handle = receiptsHandle {
            receiptsRef.removeObserver(withHandle: handle)
        }
        if let hiddenRef, let handle = hiddenHandle {
            hiddenRef.removeObserver(withHandle: handle)
        }
        messagesQuery = nil
        typingRef = nil
        receiptsRef = nil
        hiddenRef = nil
        messagesHandle = nil
        messagesChangedHandle = nil
        typingHandle = nil
        receiptsHandle = nil
        hiddenHandle = nil
        rawMessages = []
        messages = []
        typingUids = []
        receipts = [:]
        hiddenMessageIds = []
        isLoading = false
        blipId = nil
    }

    // MARK: - Send text

    func send(text: String, blipName: String, senderName: String) async throws {
        guard let blipId else { lastError = "Chat is not connected yet."; return }
        guard let uid = currentUid else { lastError = "You are not signed in."; return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let ref = Database.database().reference()
            .child("chats").child(blipId).child("messages").childByAutoId()
        let payload: [String: Any] = [
            "uid": uid, "blipId": blipId, "blipName": blipName,
            "senderName": senderName, "type": "text", "text": trimmed,
            "ts": ServerValue.timestamp(),
        ]
        do {
            try await ref.setValue(payload)
            lastError = nil
            updateTyping(isTyping: false)
        } catch {
            lastError = "Message send failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Post clip card

    static func postClipMessage(
        blipId: String, blipName: String?, senderName: String?,
        uid: String, thumbnailUrl: String?, videoUrl: String,
        caption: String?, clipId: String
    ) {
        let ref = Database.database().reference()
            .child("chats").child(blipId).child("messages").childByAutoId()
        var payload: [String: Any] = [
            "uid": uid, "blipId": blipId, "type": "clip",
            "videoUrl": videoUrl, "clipId": clipId, "ts": ServerValue.timestamp(),
        ]
        if let blipName { payload["blipName"] = blipName }
        if let senderName { payload["senderName"] = senderName }
        if let thumbnailUrl { payload["thumbnailUrl"] = thumbnailUrl }
        if let caption { payload["caption"] = caption }
        ref.setValue(payload) { error, _ in
            if let error { print("Clip chat message failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Post image message

    static func postImageMessage(
        blipId: String, blipName: String?, senderName: String?,
        uid: String, imageUrls: [String], caption: String? = nil
    ) async throws {
        let ref = Database.database().reference()
            .child("chats").child(blipId).child("messages").childByAutoId()
        var payload: [String: Any] = [
            "uid": uid, "blipId": blipId, "type": "image",
            "imageUrls": imageUrls, "ts": ServerValue.timestamp(),
        ]
        if let firstImageUrl = imageUrls.first { payload["imageUrl"] = firstImageUrl }
        if let blipName { payload["blipName"] = blipName }
        if let senderName { payload["senderName"] = senderName }
        if let caption { payload["caption"] = caption }
        try await ref.setValue(payload)
    }

    // MARK: - Delete

    /// Hides this message only for the current user (local tombstone in RTDB).
    func deleteForMe(messageId: String) {
        guard let blipId, let uid = currentUid else { return }
        Database.database().reference()
            .child("chats/\(blipId)/hiddenBy/\(uid)/\(messageId)")
            .setValue(true)
    }

    /// Marks the message as deleted for everyone. The node stays in RTDB but
    /// is rendered as a "This message was deleted" placeholder.
    func deleteForEveryone(messageId: String) {
        guard let blipId, let uid = currentUid else { return }
        Database.database().reference()
            .child("chats/\(blipId)/messages/\(messageId)")
            .updateChildValues(["deleted": true, "deletedBy": uid])
    }

    // MARK: - Typing indicator

    func updateTyping(isTyping: Bool) {
        guard let blipId, let uid = currentUid else { return }
        typingTimer?.invalidate()
        let ref = Database.database().reference()
            .child("chats").child(blipId).child("typing").child(uid)
        if isTyping {
            ref.setValue(["isTyping": true, "ts": ServerValue.timestamp()]) { [weak self] error, _ in
                guard let error else { return }
                Task { @MainActor in self?.lastError = "Typing update failed: \(error.localizedDescription)" }
            }
            typingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                self?.updateTyping(isTyping: false)
            }
        } else {
            ref.removeValue { [weak self] error, _ in
                guard let error else { return }
                Task { @MainActor in self?.lastError = "Typing clear failed: \(error.localizedDescription)" }
            }
        }
    }

    // MARK: - Receipts

    func markSeen() {
        guard let blipId, let uid = currentUid else { return }
        let nowMs = Date().timeIntervalSince1970 * 1000
        Database.database().reference()
            .child("chats/\(blipId)/receipts/\(uid)")
            .setValue(["lastDelivered": nowMs, "lastSeen": nowMs])
    }

    func tickStatus(for message: BlipMessage, currentUid: String, members: [String]) -> TickStatus {
        let others = members.filter { $0 != currentUid }
        guard !others.isEmpty else { return .sent }
        let msgTs = message.createdAt
        for uid in others {
            if let ts = receipts[uid]?.lastSeen, ts >= msgTs { return .seen }
        }
        for uid in others {
            if let ts = receipts[uid]?.lastDelivered, ts >= msgTs { return .delivered }
        }
        return .sent
    }

    // MARK: - Private helpers

    private static func tsToDate(_ value: Any?) -> Date? {
        switch value {
        case let n as NSNumber: return Date(timeIntervalSince1970: n.doubleValue / 1000)
        case let d as Double:   return Date(timeIntervalSince1970: d / 1000)
        case let i as Int:      return Date(timeIntervalSince1970: Double(i) / 1000)
        default: return nil
        }
    }
}
