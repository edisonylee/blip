import FirebaseStorage
import PhotosUI
import SwiftUI

// MARK: - Emoji data

private struct EmojiCategory: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let emojis: [String]
}

private let emojiCategories: [EmojiCategory] = [
    EmojiCategory(icon: "😀", name: "Smileys", emojis: [
        "😀","😃","😄","😁","😆","😅","🤣","😂","🙂","🙃","😉","😊","😇","🥰","😍","🤩",
        "😘","😗","☺️","😚","😙","🥲","😋","😛","😜","🤪","😝","🤑","🤗","🤭","🤫","🤔",
        "🤐","🤨","😐","😑","😶","😏","😒","🙄","😬","🤥","😌","😔","😪","🤤","😴","😷",
        "🤒","🤕","🤢","🤮","🤧","🥵","🥶","🥴","😵","🤯","🤠","🥳","😎","🤓","🧐",
        "😕","😟","🙁","☹️","😮","😯","😲","😳","🥺","😦","😧","😨","😰","😥","😢",
        "😭","😱","😖","😣","😞","😓","😩","😫","🥱","😤","😡","😠","🤬","😈","👿","💀",
        "☠️","💩","🤡","👹","👺","👻","👽","👾","🤖","😺","😸","😹","😻","😼","😽","🙀","😿","😾",
    ]),
    EmojiCategory(icon: "👋", name: "People", emojis: [
        "👋","🤚","🖐️","✋","🖖","👌","🤌","🤏","✌️","🤞","🤟","🤘","🤙",
        "👈","👉","👆","🖕","👇","☝️","👍","👎","✊","👊","🤛","🤜","👏",
        "🙌","👐","🤲","🤝","🙏","✍️","💅","🤳","💪","🦾","👂","🦻","👃",
        "👀","👅","👄","💋","👶","🧒","👦","👧","🧑","👱","👨","🧔","👩",
        "🧓","👴","👵","🙍","🙎","🙅","🙆","💁","🙋","🧏","🙇","🤦","🤷",
        "👮","👷","💂","🕵️","👩‍⚕️","👨‍⚕️","👩‍🌾","👨‍🌾","👩‍🍳","👨‍🍳",
        "👩‍🎓","👨‍🎓","👩‍🎤","👨‍🎤","👩‍🏫","👨‍🏫","🧙","🧚","🧛","🧜",
        "🦸","🦹","🧝","🧞","🧟","💆","💇","🚶","🧍","🧎","🏃",
    ]),
    EmojiCategory(icon: "🐶", name: "Animals", emojis: [
        "🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐨","🐯","🦁","🐮","🐷","🐸","🐵",
        "🙈","🙉","🙊","🐒","🐔","🐧","🐦","🦅","🦆","🦉","🦇","🐺","🐗","🐴","🦄",
        "🐝","🪱","🐛","🦋","🐌","🐞","🐜","🦟","🦗","🕷️","🦂","🐢","🐍","🦎",
        "🐙","🦑","🦐","🦞","🦀","🐡","🐠","🐟","🐬","🐳","🐋","🦈","🐊","🐅","🐆",
        "🦓","🦍","🦣","🐘","🦛","🦏","🐪","🐫","🦒","🦘","🦬","🐃","🐂","🐄","🐎",
        "🐖","🐏","🐑","🦙","🐐","🦌","🐕","🐩","🐈","🐓","🦃","🦚","🦜","🕊️",
        "🐇","🦝","🦨","🦡","🦦","🦥","🐁","🐀","🐿️","🦔","🐾","🐉","🐲","🌵","🌲",
    ]),
    EmojiCategory(icon: "🍕", name: "Food", emojis: [
        "🍕","🍔","🍟","🌭","🍿","🥓","🥚","🍳","🧇","🥞","🍞","🥐","🥨","🧀",
        "🥗","🥙","🥪","🌮","🌯","🧆","🍱","🍙","🍚","🍛","🍜","🍝","🍣","🍤",
        "🍥","🥮","🍡","🥟","🥠","🥡","🦪","🍦","🍧","🍨","🍩","🍪","🎂","🍰",
        "🧁","🥧","🍫","🍬","🍭","🍮","🍯","☕","🫖","🍵","🧃","🥤","🧋","🍺",
        "🍻","🥂","🍷","🥃","🍸","🍹","🧉","🍾","🍼","🥛","🫙","🧊","🍓","🍒",
        "🍑","🥭","🍍","🥥","🍈","🍇","🍉","🍊","🍋","🍌","🍎","🍏","🍐","🍠","🥦",
    ]),
    EmojiCategory(icon: "✈️", name: "Travel", emojis: [
        "✈️","🚀","🛸","🚁","🛩️","⛵","🚢","🛳️","🚂","🚄","🚇","🏎️","🚓","🚑","🚒",
        "🛻","🚚","🚛","🏍️","🛵","🚲","🛴","🛹","🛺","⛽","🗺️","🧭","🏔️","⛰️","🌋",
        "🏕️","🏖️","🏜️","🏝️","🏟️","🏛️","🏗️","🏠","🏡","🏢","🏥","🏦","🏨","🏪",
        "🏫","🏬","🏭","🏯","🏰","💒","🗼","🗽","⛪","🕌","🛕","⛩️","🕋","⛲","⛺",
        "🌁","🌃","🏙️","🌄","🌅","🌆","🌇","🌉","🌌","🌠","🎇","🎆","🗿","⛱️",
    ]),
    EmojiCategory(icon: "⚽", name: "Activity", emojis: [
        "⚽","🏀","🏈","⚾","🥎","🎾","🏐","🏉","🥏","🎱","🏓","🏸","🏒","🥍","🏏",
        "🪃","🥅","⛳","🪁","🎣","🤿","🎽","🎿","🛷","🥌","🎯","🪄","🎮","🕹️",
        "🎲","🧩","🧸","🎭","🎨","🎬","🎤","🎧","🎼","🎹","🥁","🪘","🎷","🎺","🎸",
        "🪗","🎻","♟️","🏹","🥊","🥋","🛹","🤸","⛷️","🏂","🏋️","🤼","🤾","🏌️","🏄",
        "🧗","🚴","🏇","🤺","⛹️","🤽","🎪","🤹","🎠","🎡","🎢","🎑","🎃","🎄","🎆","🎇",
    ]),
    EmojiCategory(icon: "💡", name: "Objects", emojis: [
        "💡","🔦","🕯️","🧯","💰","💵","💸","💳","🪙","💎","⚖️","🔑","🗝️","🔐","🔒",
        "📦","📫","📬","✏️","✒️","🖊️","🖌️","🖍️","📝","💼","📁","📂","📅","📆","📊",
        "📈","📉","📋","📌","📍","📎","📏","📐","✂️","🗑️","📔","📒","📕","📗","📘","📚",
        "📖","🔖","🏷️","💉","💊","🩺","🔬","🔭","📡","📱","💻","🖥️","🖨️","⌨️","🖱️",
        "📷","📸","📹","🎥","📽️","🎞️","📞","☎️","📟","📠","📺","📻","🎙️","🎚️","🎛️",
        "🧭","⏱️","⏰","⌚","🕰️","📡","🔋","🔌","💡","🔦","🕯️","🪔","🧱","🪞","🛋️",
    ]),
    EmojiCategory(icon: "❤️", name: "Symbols", emojis: [
        "❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔","❤️‍🔥","❤️‍🩹","❣️",
        "💕","💞","💓","💗","💖","💘","💝","💟","☮️","✝️","☪️","🕉️","☸️","✡️","☯️",
        "🔱","⚜️","🔰","♻️","✅","❌","⭕","🛑","⛔","📛","🚫","💯","💢","♨️",
        "❗","❕","❓","❔","‼️","⁉️","🔅","🔆","🎵","🎶","➕","➖","➗","✖️","♾️",
        "💲","💱","™️","©️","®️","💬","💭","🗯️","♠️","♣️","♥️","♦️","🔴","🟠","🟡",
        "🟢","🔵","🟣","⚫","⚪","🟤","🔺","🔻","🔷","🔶","🔹","🔸","▶️","⏸️","⏹️",
        "⏭️","⏮️","⏩","⏪","🔀","🔁","🔂","🔄","🔃","✔️","🎯","⭐","🌟","💫","✨",
        "🔥","💥","🌈","🌊","⚡","❄️","🌀","🌸","🌺","🌻","🌹","🌷","🍀","🎋","🎍",
    ]),
]

// MARK: - Recent emoji helpers

private func recentEmojis() -> [String] {
    let raw = UserDefaults.standard.string(forKey: "blip.recentEmojis") ?? ""
    return raw.isEmpty ? [] : raw.components(separatedBy: "||")
}

private func trackEmoji(_ emoji: String) {
    var recent = recentEmojis()
    recent.removeAll { $0 == emoji }
    recent.insert(emoji, at: 0)
    UserDefaults.standard.set(Array(recent.prefix(32)).joined(separator: "||"),
                              forKey: "blip.recentEmojis")
}

// MARK: - ChatView

struct ChatView: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var moderation: ModerationService
    @StateObject private var repo = MessagesRepository()
    @StateObject private var userProfiles = UserProfilesRepository()

    @State private var draft = ""
    @State private var showCapture = false
    @State private var showEmojiSheet = false
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var previewImages: [UIImage] = []
    @State private var showImagePreview = false
    @State private var isLoadingImages = false
    @State private var isSendingImages = false
    @State private var imageSendError: String?
    @State private var isMemberStripExpanded = false
    @State private var pendingImageGroups: [PendingImageGroup] = []
    @State private var galleryImages: [URL] = []
    @State private var showImageGallery = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                memberStrip

                Rectangle()
                    .fill(BlipColor.border)
                    .frame(height: 0.5)

                messageList

                chatErrorBanner

                inputBar
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("chat")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                    if !memberSubtitle.isEmpty {
                        Text(memberSubtitle)
                            .font(.blip(size: 11))
                            .foregroundStyle(BlipColor.textTertiary)
                            .lineLimit(1)
                    }
                }
                .multilineTextAlignment(.center)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .task(id: blip.id) {
            repo.startListening(blipId: blip.id)
            repo.setBlocklist(moderation.blockedUsers)
            userProfiles.observe(uids: blip.members)
            userProfiles.setBlocklist(moderation.blockedUsers)
            repo.markSeen()
        }
        .onReceive(moderation.$blockedUsers) { uids in
            repo.setBlocklist(uids)
            userProfiles.setBlocklist(uids)
        }
        .onChange(of: repo.messages.count) { _, count in
            if count > 0 { repo.markSeen() }
        }
        // Emoji sheet — medium + large detent, like WhatsApp
        .sheet(isPresented: $showEmojiSheet) {
            EmojiSheet { emoji in
                draft += emoji
                trackEmoji(emoji)
                showEmojiSheet = false
                inputFocused = true
            }
            .presentationDetents([.fraction(0.52), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(sheetBg)
        }
        // Load images then show preview
        .onChange(of: pickedPhotos) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadImages(from: items) }
        }
        // Image preview modal (full screen, dark)
        .fullScreenCover(isPresented: $showImagePreview) {
            ImagePreviewModal(
                images: previewImages,
                isSending: isSendingImages,
                onSend: { images, caption in
                    Task { await uploadImages(images, caption: caption) }
                },
                onCancel: {
                    showImagePreview = false
                    previewImages = []
                    pickedPhotos = []
                }
            )
        }
        .fullScreenCover(isPresented: $showCapture) {
            NavigationStack {
                CaptureView(blip: blip, onPosted: { showCapture = false })
            }
        }
        .fullScreenCover(isPresented: $showImageGallery) {
            ImageGalleryModal(urls: galleryImages) {
                showImageGallery = false
            }
        }
    }

    private var sheetBg: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.07, alpha: 1)
                : UIColor(white: 0.97, alpha: 1)
        })
    }

    // MARK: - Member strip

    private var memberStrip: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(collapsedMemberIds, id: \.self) { uid in
                            MemberNameLink(
                                uid: uid,
                                label: userProfiles.chatLabel(for: uid)
                            )
                        }

                        if !isMemberStripExpanded && blip.members.count > collapsedMemberIds.count {
                            Text("+\(blip.members.count - collapsedMemberIds.count)")
                                .font(.blip(size: 12, weight: .medium))
                                .foregroundStyle(BlipColor.textTertiary)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                        }
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isMemberStripExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.blip(size: 11, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(isMemberStripExpanded ? 180 : 0))
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(height: 34)
        }
        .background(BlipColor.surface)
    }

    private var collapsedMemberIds: [String] {
        isMemberStripExpanded ? blip.members : Array(blip.members.prefix(3))
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if repo.isLoading && repo.messages.isEmpty {
                        ChatLoadingRow()
                            .id("chat-loading")
                    }

                    ForEach(Array(visibleMessages.enumerated()), id: \.element.id) { index, msg in
                        if shouldShowDateChip(at: index) {
                            DateChip(text: dateChipText(for: msg.createdAt))
                                .id("date-\(dateChipText(for: msg.createdAt))-\(msg.id)")
                        }

                        MessageRow(
                            message: msg,
                            isMe: isMe(msg),
                            isAdmin: isChatAdmin,
                            senderLabel: userProfiles.chatLabel(for: msg.uid),
                            tick: isMe(msg) ? msgTickStatus(msg) : nil,
                            onCaptureSimilar: { showCapture = true },
                            onOpenImages: { urls in
                                galleryImages = urls
                                showImageGallery = true
                            },
                            onDeleteForMe: { repo.deleteForMe(messageId: msg.id) },
                            onDeleteForEveryone: { repo.deleteForEveryone(messageId: msg.id) }
                        )
                        .id(msg.id)
                    }
                    ForEach(pendingImageGroups) { pending in
                        PendingImageRow(group: pending)
                            .id(pending.id)
                    }
                    if !repo.typingUids.isEmpty {
                        TypingIndicatorRow(
                            uids: repo.typingUids,
                            nameFor: { uid in userProfiles.chatLabel(for: uid) }
                        )
                        .id("typing-indicator")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .onChange(of: repo.messages.count) { _, _ in
                if let last = visibleMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: pendingImageGroups.count) { _, _ in
                if let last = pendingImageGroups.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: repo.typingUids.isEmpty) { _, empty in
                if !empty { withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) } }
            }
        }
    }

    private var visibleMessages: [BlipMessage] {
        repo.messages.filter { !repo.hiddenMessageIds.contains($0.id) }
    }

    private var isChatAdmin: Bool {
        guard case .signedIn(let uid) = auth.state else { return false }
        return blip.isAdmin(uid)
    }

    private func shouldShowDateChip(at index: Int) -> Bool {
        guard visibleMessages.indices.contains(index) else { return false }
        guard index > 0 else { return true }
        return !Calendar.current.isDate(
            visibleMessages[index].createdAt,
            inSameDayAs: visibleMessages[index - 1].createdAt
        )
    }

    private func dateChipText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(BlipColor.border).frame(height: 0.5)

            HStack(spacing: 6) {
                // Emoji button
                Button {
                    inputFocused = false
                    showEmojiSheet = true
                } label: {
                    Text("😊")
                        .font(.system(size: 24))
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel("emoji keyboard")

                // Photo picker (max 10)
                PhotosPicker(
                    selection: $pickedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(chatSurface)
                            .frame(width: 38, height: 38)
                        if isLoadingImages {
                            ProgressView().scaleEffect(0.7).tint(BlipColor.textSecondary)
                        } else {
                            Image(systemName: "photo")
                                .font(.blip(size: 17, weight: .medium))
                                .foregroundStyle(BlipColor.textSecondary)
                        }
                        if !pickedPhotos.isEmpty {
                            Text("\(pickedPhotos.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 14, minHeight: 14)
                                .padding(.horizontal, 2)
                                .background(BlipColor.accentNeutral, in: Capsule())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .disabled(isLoadingImages)
                .accessibilityLabel("attach photos, max 10")

                // Text field
                TextField(
                    "",
                    text: $draft,
                    prompt: Text("message…").foregroundStyle(BlipColor.textTertiary),
                    axis: .vertical
                )
                .lineLimit(1...5)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { if canSend { send() } }
                .onChange(of: draft) { _, new in
                    repo.updateTyping(isTyping: !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(chatSurface, in: Capsule())
                .foregroundStyle(chatFg)
                .tint(BlipColor.accentNeutral)

                // Send button
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.blip(size: 16, weight: .semibold))
                        .foregroundStyle(canSend ? sendIconFg : BlipColor.textTertiary)
                        .frame(width: 38, height: 38)
                        .background(canSend ? BlipColor.accentNeutral : chatSurface, in: Circle())
                        .animation(.easeInOut(duration: 0.15), value: canSend)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BlipColor.background)
        }
    }

    @ViewBuilder
    private var chatErrorBanner: some View {
        let message = repo.lastError ?? imageSendError
        if let message {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.blip(size: 13, weight: .semibold))
                Text(message)
                    .font(.blip(size: 12))
                    .lineLimit(3)
                Spacer(minLength: 8)
                Button {
                    repo.clearError()
                    imageSendError = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.blip(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(BlipColor.error)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(BlipColor.error.opacity(0.10))
            .overlay(alignment: .top) {
                Rectangle().fill(BlipColor.error.opacity(0.25)).frame(height: 0.5)
            }
        }
    }

    // MARK: - Adaptive colors

    private var chatSurface: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.13, alpha: 1)
                : UIColor(white: 0.88, alpha: 1)
        })
    }

    private var chatFg: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.95, alpha: 1) : UIColor(white: 0.08, alpha: 1)
        })
    }

    private var sendIconFg: Color {
        Color(uiColor: UIColor { t in t.userInterfaceStyle == .dark ? .black : .white })
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var memberSubtitle: String {
        let loaded = blip.members.compactMap { uid -> String? in
            userProfiles.profiles[uid] != nil ? userProfiles.chatLabel(for: uid) : nil
        }
        guard !loaded.isEmpty else { return "\(blip.members.count) members" }
        let shown = loaded.prefix(4)
        var s = shown.joined(separator: ", ")
        if blip.members.count > shown.count { s += " +\(blip.members.count - shown.count)" }
        return s
    }

    private func isMe(_ msg: BlipMessage) -> Bool {
        guard case .signedIn(let uid) = auth.state else { return false }
        return msg.uid == uid
    }

    private func msgTickStatus(_ message: BlipMessage) -> TickStatus {
        guard case .signedIn(let uid) = auth.state else { return .sent }
        return repo.tickStatus(for: message, currentUid: uid, members: blip.members)
    }

    private func send() {
        guard canSend else { return }
        guard case .signedIn(let uid) = auth.state else { return }
        let text = draft; draft = ""
        Task {
            do {
                let senderName = userProfiles.chatLabel(for: uid)
                try await repo.send(text: text, blipName: blip.name, senderName: senderName)
            } catch {
                draft = text
            }
        }
    }

    // MARK: - Image loading

    private func loadImages(from items: [PhotosPickerItem]) async {
        isLoadingImages = true
        imageSendError = nil
        defer { isLoadingImages = false }
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        guard !loaded.isEmpty else { pickedPhotos = []; return }
        previewImages = loaded
        showImagePreview = true
    }

    // MARK: - Image upload (called from ImagePreviewModal)

    private func uploadImages(_ images: [UIImage], caption: String) async {
        guard !isSendingImages else { return }
        guard case .signedIn(let uid) = auth.state else {
            imageSendError = "You are not signed in to Firebase Auth."
            return
        }
        isSendingImages = true
        showImagePreview = false
        imageSendError = nil
        var failedMessages: [String] = []
        let pending = PendingImageGroup(
            images: images,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        pendingImageGroups.append(pending)
        defer {
            isSendingImages = false
            previewImages = []
            pickedPhotos = []
            imageSendError = failedMessages.first
            pendingImageGroups.removeAll { $0.id == pending.id }
        }

        var urlStrings: [String] = []
        for image in images {
            guard let jpeg = image.jpegData(compressionQuality: 0.82) else { continue }
            let msgId = UUID().uuidString
            let ref = Storage.storage().reference()
                .child("chat-images/\(blip.id)/\(uid)/\(msgId).jpg")
            let meta = StorageMetadata(); meta.contentType = "image/jpeg"
            do {
	                let urlString: String = try await withCheckedThrowingContinuation { cont in
	                    ref.putData(jpeg, metadata: meta) { _, err in
	                        if let err { cont.resume(throwing: err); return }
	                        Task {
	                            do { cont.resume(returning: try await ref.downloadURL().absoluteString) }
	                            catch { cont.resume(throwing: error) }
	                        }
	                    }
	                }
                urlStrings.append(urlString)
            } catch {
                failedMessages.append("Image upload failed: \(error.localizedDescription)")
            }
        }

        do {
            guard !urlStrings.isEmpty else { return }
            try await MessagesRepository.postImageMessage(
                blipId: blip.id,
                blipName: blip.name,
                senderName: userProfiles.chatLabel(for: uid),
                uid: uid,
                imageUrls: urlStrings,
                caption: pending.caption.isEmpty ? nil : pending.caption
            )
        } catch {
            failedMessages.append("Image message failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Emoji sheet (WhatsApp-style)

private struct EmojiSheet: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategoryIndex = 0

    private var recent: [String] { recentEmojis() }

    private var displayCategories: [EmojiCategory] {
        let recentCategory = EmojiCategory(icon: "🕐", name: "Recent", emojis: recent)
        return [recentCategory] + emojiCategories
    }

    private var filteredEmojis: [String] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return displayCategories[selectedCategoryIndex].emojis }
        return emojiCategories.flatMap(\.emojis).filter { emoji in
            emoji.contains(q)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 8)

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.blip(size: 14))
                    .foregroundStyle(BlipColor.textTertiary)
                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("search").foregroundStyle(BlipColor.textTertiary)
                )
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
                .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.blip(size: 14))
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                    .accessibilityLabel("clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Color(uiColor: UIColor { t in
                    t.userInterfaceStyle == .dark
                        ? UIColor(white: 0.14, alpha: 1)
                        : UIColor(white: 0.89, alpha: 1)
                }),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Emoji grid
            if filteredEmojis.isEmpty && !searchText.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("🤷").font(.system(size: 40))
                    Text("no emoji found")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textTertiary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(filteredEmojis, id: \.self) { emoji in
                                Button {
                                    onSelect(emoji)
                                    dismiss()
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 30))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .id("grid-top")
                    }
                    .onChange(of: selectedCategoryIndex) { _, _ in
                        withAnimation { proxy.scrollTo("grid-top", anchor: .top) }
                    }
                }
            }

            // Category tab bar (only when not searching)
            if searchText.isEmpty {
                categoryBar
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(displayCategories.enumerated()), id: \.offset) { index, cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategoryIndex = index
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(cat.icon)
                                .font(.system(size: 22))
                            Rectangle()
                                .fill(selectedCategoryIndex == index
                                      ? BlipColor.accentNeutral
                                      : Color.clear)
                                .frame(height: 2)
                                .cornerRadius(1)
                        }
                        .frame(width: 46, height: 46)
                        .opacity(selectedCategoryIndex == index ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .background(
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(white: 0.06, alpha: 1)
                    : UIColor(white: 0.94, alpha: 1)
            })
        )
        .overlay(alignment: .top) {
            Rectangle().fill(BlipColor.border).frame(height: 0.5)
        }
    }
}

// MARK: - Image preview modal (WhatsApp-style)

struct ImagePreviewModal: View {
    let images: [UIImage]
    let isSending: Bool
    let onSend: ([UIImage], String) -> Void
    let onCancel: () -> Void

    @State private var currentIndex = 0
    @State private var caption = ""
    @State private var removedIndices: Set<Int> = []
    @FocusState private var captionFocused: Bool

    private var remaining: [(Int, UIImage)] {
        images.enumerated().filter { !removedIndices.contains($0.offset) }.map { ($0.offset, $0.element) }
    }

    private var remainingIds: [Int] {
        remaining.map { $0.0 }
    }

    private var currentPosition: Int {
        remaining.firstIndex(where: { $0.0 == currentIndex }) ?? 0
    }

    private var currentImage: (Int, UIImage)? {
        remaining.first(where: { $0.0 == currentIndex }) ?? remaining.first
    }

    var body: some View {
        ZStack {
            BlipColor.mediaBackdrop.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                imageViewer
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            currentIndex = remaining.first?.0 ?? 0
        }
        .onChange(of: remainingIds) { _, ids in
            guard let first = ids.first else {
                onCancel()
                return
            }
            if !ids.contains(currentIndex) {
                currentIndex = first
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.blip(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            if remaining.count > 1 {
                Text("\(currentPosition + 1) of \(remaining.count)")
                    .font(BlipTypography.body)
                    .foregroundStyle(.white)
            }
            Spacer()
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(BlipColor.mediaBackdrop)
    }

    // MARK: Image viewer (swipeable)

    private var imageViewer: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentIndex) {
                ForEach(remaining, id: \.0) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .contentShape(Rectangle())
            .onTapGesture { captionFocused = false }

            if let currentImage {
                Button {
                    removeImage(at: currentImage.0)
                } label: {
                    Image(systemName: "trash")
                        .font(.blip(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(BlipColor.mediaBackdrop.opacity(0.58), in: Circle())
                        .overlay(Circle().stroke(BlipColor.onMedia.opacity(0.18), lineWidth: 1))
                }
                .padding(.top, 14)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .disabled(isSending)
            }

            if remaining.count > 1 {
                thumbnailStrip
                    .padding(.bottom, 10)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 10)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Caption + send
            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $caption,
                    prompt: Text("add a caption…").foregroundStyle(BlipColor.onMedia.opacity(0.5)),
                    axis: .vertical
                )
                .lineLimit(1...3)
                .focused($captionFocused)
                .font(BlipTypography.body)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(BlipColor.onMedia.opacity(0.12), in: Capsule())

                // Bottom send button
                Button { sendImages() } label: {
                    ZStack {
                        Circle()
                            .fill(BlipColor.onMedia)
                            .frame(width: 46, height: 46)
                        if isSending {
                            ProgressView().scaleEffect(0.8).tint(.black)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.blip(size: 18, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .disabled(isSending || remaining.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [BlipColor.mediaBackdrop.opacity(0), BlipColor.mediaBackdrop.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(remaining, id: \.0) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: currentIndex == index ? 62 : 54, height: currentIndex == index ? 62 : 54)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(currentIndex == index ? BlipColor.onMedia : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture { currentIndex = index }

                        // Remove button
                        Button {
                            removeImage(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .background(Circle().fill(BlipColor.mediaBackdrop.opacity(0.6)).padding(2))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 28)
    }

    private func sendImages() {
        guard !remaining.isEmpty else { return }
        onSend(remaining.map { $0.1 }, caption)
    }

    private func removeImage(at index: Int) {
        guard remaining.count > 1 else {
            onCancel()
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            if currentIndex == index {
                currentIndex = remaining.first(where: { $0.0 != index })?.0 ?? 0
            }
            removedIndices.insert(index)
        }
    }
}

// MARK: - Member chip

private struct MemberNameLink: View {
    let uid: String
    let label: String

    var body: some View {
        NavigationLink {
            UserProfileView(uid: uid)
        } label: {
            Text(label)
                .font(.blip(size: 12, weight: .medium))
                .foregroundStyle(BlipColor.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    Color(uiColor: UIColor { t in
                        t.userInterfaceStyle == .dark
                            ? UIColor(white: 0.16, alpha: 1)
                            : UIColor(white: 0.91, alpha: 1)
                    }),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("open profile for \(label)")
    }
}

// MARK: - Message row

private struct MessageRow: View {
    let message: BlipMessage
    let isMe: Bool
    let isAdmin: Bool
    let senderLabel: String
    let tick: TickStatus?
    let onCaptureSimilar: () -> Void
    let onOpenImages: ([URL]) -> Void
    let onDeleteForMe: () -> Void
    let onDeleteForEveryone: () -> Void

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

                if message.deleted {
                    DeletedMessageBubble(isMe: isMe)
                } else {
                    switch message.type {
                    case .text:
                        if let text = message.text {
                            TextBubble(text: text, isMe: isMe)
                        }
                    case .clip:
                        TailedBubble(isMe: isMe, fill: chatBubbleFill(isMe: isMe)) {
                            ClipMessageCard(message: message, onCaptureSimilar: onCaptureSimilar)
                        }
                    case .image:
                        if !message.imageUrls.isEmpty {
                            ImageBubble(urls: message.imageUrls, caption: message.caption, isMe: isMe) {
                                onOpenImages(message.imageUrls)
                            }
                        }
                    }
                }

                if let tick, isMe {
                    TickMark(status: tick)
                        .padding(.trailing, 6)
                        .padding(.top, -1)
                }
            }
            .contextMenu {
                if !message.deleted {
                    Button(role: .destructive) {
                        onDeleteForMe()
                    } label: {
                        Label("hide for me", systemImage: "eye.slash")
                    }
                    if isMe || isAdmin {
                        Button(role: .destructive) {
                            onDeleteForEveryone()
                        } label: {
                            Label("delete for everyone", systemImage: "trash.fill")
                        }
                    }
                }
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }
}

private struct DeletedMessageBubble: View {
    let isMe: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "trash")
                .font(.system(size: 11))
            Text("This message was deleted")
                .font(.blip(size: 13))
                .italic()
        }
        .foregroundStyle(BlipColor.textTertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(white: 0.14, alpha: 1)
                    : UIColor(white: 0.92, alpha: 1)
            }),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct TickMark: View {
    let status: TickStatus

    private var tint: Color {
        status == .seen
            ? Color(red: 0.18, green: 0.55, blue: 1.0)
            : Color(uiColor: UIColor(white: 0.55, alpha: 1))
    }

    var body: some View {
        HStack(spacing: -5) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            if status != .sent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
    }
}

private struct DateChip: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.blip(size: 11, weight: .medium))
                .foregroundStyle(BlipColor.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Color(uiColor: UIColor { t in
                        t.userInterfaceStyle == .dark
                            ? UIColor(white: 0.16, alpha: 1)
                            : UIColor(white: 0.90, alpha: 1)
                    }),
                    in: Capsule()
                )
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

private struct ChatLoadingRow: View {
    @State private var phase: CGFloat = 0

    private let layout: [(CGFloat, Bool)] = [
        (0.52, false),
        (0.65, true),
        (0.38, false),
        (0.70, true),
        (0.45, false),
        (0.58, true),
        (0.36, false),
        (0.62, true),
        (0.50, false),
        (0.68, true),
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(layout.enumerated()), id: \.offset) { _, item in
                SkeletonBubbleRow(fraction: item.0, isMe: item.1, phase: phase)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

private struct SkeletonBubbleRow: View {
    let fraction: CGFloat
    let isMe: Bool
    let phase: CGFloat

    private var baseColor: Color {
        Color(uiColor: UIColor { t in
            if isMe {
                return t.userInterfaceStyle == .dark
                    ? UIColor(white: 0.22, alpha: 1)
                    : UIColor(white: 0.18, alpha: 1)
            } else {
                return t.userInterfaceStyle == .dark
                    ? UIColor(white: 0.20, alpha: 1)
                    : UIColor(white: 0.80, alpha: 1)
            }
        })
    }

    var body: some View {
        let bubbleWidth = UIScreen.main.bounds.width * fraction
        HStack(spacing: 0) {
            if isMe { Spacer(minLength: 48) }
            ZStack {
                baseColor
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.22), location: 0.5),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: UnitPoint(x: phase - 0.6, y: 0),
                    endPoint: UnitPoint(x: phase + 0.6, y: 0)
                )
            }
            .clipShape(BubbleShape(myMessage: isMe))
            .frame(width: bubbleWidth, height: 36)
            if !isMe { Spacer(minLength: 48) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Text bubble

private struct TextBubble: View {
    let text: String
    let isMe: Bool

    private var bg: Color {
        Color(uiColor: UIColor { t in
            if isMe {
                return t.userInterfaceStyle == .dark
                    ? UIColor(white: 0.96, alpha: 1)
                    : UIColor(white: 0.10, alpha: 1)
            } else {
                return t.userInterfaceStyle == .dark
                    ? UIColor(white: 0.18, alpha: 1)
                    : UIColor(white: 0.84, alpha: 1)
            }
        })
    }

    private var fg: Color {
        Color(uiColor: UIColor { t in
            if isMe {
                return t.userInterfaceStyle == .dark ? UIColor(white: 0.06, alpha: 1) : UIColor(white: 0.95, alpha: 1)
            } else {
                return t.userInterfaceStyle == .dark ? UIColor(white: 0.94, alpha: 1) : UIColor(white: 0.08, alpha: 1)
            }
        })
    }

    var body: some View {
        TailedBubble(isMe: isMe, fill: bg) {
            Text(text)
                .font(BlipTypography.body)
                .foregroundStyle(fg)
                .padding(.leading, isMe ? 13 : 18)
                .padding(.trailing, isMe ? 18 : 13)
                .padding(.vertical, 9)
        }
    }
}

private struct TailedBubble<Content: View>: View {
    let isMe: Bool
    let fill: Color
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(fill)
            .clipShape(BubbleShape(myMessage: isMe))
    }
}

private struct BubbleShape: Shape {
    var myMessage: Bool

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let bezierPath = UIBezierPath()

        if !myMessage {
            bezierPath.move(to: CGPoint(x: 20, y: height))
            bezierPath.addLine(to: CGPoint(x: width - 15, y: height))
            bezierPath.addCurve(
                to: CGPoint(x: width, y: height - 15),
                controlPoint1: CGPoint(x: width - 8, y: height),
                controlPoint2: CGPoint(x: width, y: height - 8)
            )
            bezierPath.addLine(to: CGPoint(x: width, y: 15))
            bezierPath.addCurve(
                to: CGPoint(x: width - 15, y: 0),
                controlPoint1: CGPoint(x: width, y: 8),
                controlPoint2: CGPoint(x: width - 8, y: 0)
            )
            bezierPath.addLine(to: CGPoint(x: 20, y: 0))
            bezierPath.addCurve(
                to: CGPoint(x: 5, y: 15),
                controlPoint1: CGPoint(x: 12, y: 0),
                controlPoint2: CGPoint(x: 5, y: 8)
            )
            bezierPath.addLine(to: CGPoint(x: 5, y: height - 10))
            bezierPath.addCurve(
                to: CGPoint(x: 0, y: height),
                controlPoint1: CGPoint(x: 5, y: height - 1),
                controlPoint2: CGPoint(x: 0, y: height)
            )
            bezierPath.addLine(to: CGPoint(x: -1, y: height))
            bezierPath.addCurve(
                to: CGPoint(x: 12, y: height - 4),
                controlPoint1: CGPoint(x: 4, y: height + 1),
                controlPoint2: CGPoint(x: 8, y: height - 1)
            )
            bezierPath.addCurve(
                to: CGPoint(x: 20, y: height),
                controlPoint1: CGPoint(x: 15, y: height),
                controlPoint2: CGPoint(x: 20, y: height)
            )
        } else {
            bezierPath.move(to: CGPoint(x: width - 20, y: height))
            bezierPath.addLine(to: CGPoint(x: 15, y: height))
            bezierPath.addCurve(
                to: CGPoint(x: 0, y: height - 15),
                controlPoint1: CGPoint(x: 8, y: height),
                controlPoint2: CGPoint(x: 0, y: height - 8)
            )
            bezierPath.addLine(to: CGPoint(x: 0, y: 15))
            bezierPath.addCurve(
                to: CGPoint(x: 15, y: 0),
                controlPoint1: CGPoint(x: 0, y: 8),
                controlPoint2: CGPoint(x: 8, y: 0)
            )
            bezierPath.addLine(to: CGPoint(x: width - 20, y: 0))
            bezierPath.addCurve(
                to: CGPoint(x: width - 5, y: 15),
                controlPoint1: CGPoint(x: width - 12, y: 0),
                controlPoint2: CGPoint(x: width - 5, y: 8)
            )
            bezierPath.addLine(to: CGPoint(x: width - 5, y: height - 12))
            bezierPath.addCurve(
                to: CGPoint(x: width, y: height),
                controlPoint1: CGPoint(x: width - 5, y: height - 1),
                controlPoint2: CGPoint(x: width, y: height)
            )
            bezierPath.addLine(to: CGPoint(x: width + 1, y: height))
            bezierPath.addCurve(
                to: CGPoint(x: width - 12, y: height - 4),
                controlPoint1: CGPoint(x: width - 4, y: height + 1),
                controlPoint2: CGPoint(x: width - 8, y: height - 1)
            )
            bezierPath.addCurve(
                to: CGPoint(x: width - 20, y: height),
                controlPoint1: CGPoint(x: width - 15, y: height),
                controlPoint2: CGPoint(x: width - 20, y: height)
            )
        }

        return Path(bezierPath.cgPath)
    }
}

// MARK: - Image bubbles

private struct PendingImageGroup: Identifiable {
    let id = UUID().uuidString
    let images: [UIImage]
    let caption: String
}

private struct PendingImageRow: View {
    let group: PendingImageGroup

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 60)
            LocalImageBubble(images: group.images, caption: group.caption, isUploading: true, isMe: true)
        }
    }
}

private struct ImageBubble: View {
    let urls: [URL]
    let caption: String?
    let isMe: Bool
    let onTap: () -> Void

    var body: some View {
        TailedBubble(isMe: isMe, fill: chatBubbleFill(isMe: isMe)) {
            VStack(alignment: .leading, spacing: 0) {
                RemoteImageGrid(urls: urls)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture(perform: onTap)

                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.blip(size: 13))
                        .foregroundStyle(chatSecondaryText(isMe: isMe))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
            }
            .padding(.leading, isMe ? 5 : 10)
            .padding(.trailing, isMe ? 10 : 5)
            .padding(.vertical, 5)
        }
    }
}

private struct LocalImageBubble: View {
    let images: [UIImage]
    let caption: String
    let isUploading: Bool
    let isMe: Bool

    var body: some View {
        TailedBubble(isMe: isMe, fill: chatBubbleFill(isMe: isMe)) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    LocalImageGrid(images: images)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .opacity(isUploading ? 0.74 : 1)
                    if isUploading {
                        ProgressView()
                            .tint(.white)
                            .padding(12)
                            .background(BlipColor.mediaBackdrop.opacity(0.45), in: Circle())
                    }
                }

                if !caption.isEmpty {
                    Text(caption)
                        .font(.blip(size: 13))
                        .foregroundStyle(chatSecondaryText(isMe: isMe))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
            }
            .padding(.leading, isMe ? 5 : 10)
            .padding(.trailing, isMe ? 10 : 5)
            .padding(.vertical, 5)
        }
    }
}

private struct RemoteImageGrid: View {
    let urls: [URL]

    var body: some View {
        ImageGridShell(count: urls.count) { index in
            CachedAsyncImage(url: urls[index]) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    imageFailureView
                default:
                    imageLoadingView
                }
            }
        }
    }
}

private struct LocalImageGrid: View {
    let images: [UIImage]

    var body: some View {
        ImageGridShell(count: images.count) { index in
            Image(uiImage: images[index])
                .resizable()
                .scaledToFill()
        }
    }
}

private struct ImageGridShell<Cell: View>: View {
    let count: Int
    private let cell: (Int) -> Cell

    private let width: CGFloat = 220
    private let gap: CGFloat = 3
    private var extraCount: Int { max(0, count - 3) }

    init(count: Int, @ViewBuilder cell: @escaping (Int) -> Cell) {
        self.count = count
        self.cell = cell
    }

    var body: some View {
        Group {
            switch count {
            case 0:
                imageFailureView.frame(width: width, height: 120)
            case 1:
                clippedCell(0)
                    .frame(width: width, height: 166)
            case 2:
                HStack(spacing: gap) {
                    clippedCell(0)
                    clippedCell(1)
                }
                .frame(width: width, height: 132)
            case 3:
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        clippedCell(0)
                        clippedCell(1)
                    }
                    clippedCell(2)
                        .frame(width: width, height: 108)
                }
                .frame(width: width, height: 220)
            case 4:
                grid2x2(showCountOverlay: false)
            default:
                grid2x2(showCountOverlay: true)
            }
        }
        .clipped()
    }

    private func grid2x2(showCountOverlay: Bool) -> some View {
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                clippedCell(0)
                clippedCell(1)
            }
            HStack(spacing: gap) {
                clippedCell(2)
                if showCountOverlay {
                    ZStack {
                        Color(uiColor: UIColor(white: 0.08, alpha: 1))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text("+\(extraCount)")
                            .font(.blip(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(BlipColor.mediaBackdrop.opacity(0.55), in: Circle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                } else {
                    clippedCell(3)
                }
            }
        }
        .frame(width: width, height: 220)
    }

    private func clippedCell(_ index: Int) -> some View {
        cell(index)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

private var imageLoadingView: some View {
    Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : UIColor(white: 0.84, alpha: 1)
    })
    .overlay(ProgressView().tint(BlipColor.textTertiary))
}

private var imageFailureView: some View {
    ZStack {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : UIColor(white: 0.84, alpha: 1)
        })
        VStack(spacing: 5) {
            Image(systemName: "photo")
            Text("couldn't load")
        }
        .font(.blip(size: 13))
        .foregroundStyle(BlipColor.textTertiary)
    }
}

private func chatBubbleFill(isMe: Bool) -> Color {
    Color(uiColor: UIColor { t in
        if isMe {
            return t.userInterfaceStyle == .dark
                ? UIColor(white: 0.96, alpha: 1)
                : UIColor(white: 0.10, alpha: 1)
        } else {
            return t.userInterfaceStyle == .dark
                ? UIColor(white: 0.18, alpha: 1)
                : UIColor(white: 0.84, alpha: 1)
        }
    })
}

private func chatSecondaryText(isMe: Bool) -> Color {
    Color(uiColor: UIColor { t in
        if isMe {
            return t.userInterfaceStyle == .dark
                ? UIColor(white: 0.18, alpha: 1)
                : UIColor(white: 0.82, alpha: 1)
        } else {
            return t.userInterfaceStyle == .dark
                ? UIColor(white: 0.78, alpha: 1)
                : UIColor(white: 0.30, alpha: 1)
        }
    })
}

private struct ImageGalleryModal: View {
    let urls: [URL]
    let onClose: () -> Void
    @State private var currentIndex = 0

    var body: some View {
        ZStack(alignment: .top) {
            BlipColor.mediaBackdrop.ignoresSafeArea()
            TabView(selection: $currentIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            imageFailureView
                        default:
                            ProgressView().tint(.white)
                        }
                    }
                    .padding(.horizontal, 8)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.blip(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                if urls.count > 1 {
                    Text("\(currentIndex + 1) of \(urls.count)")
                        .font(BlipTypography.body)
                        .foregroundStyle(.white)
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Clip message card

private struct ClipMessageCard: View {
    let message: BlipMessage
    let onCaptureSimilar: () -> Void
    private static let cardWidth: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailView.frame(width: Self.cardWidth, height: 130).clipped()

            if let caption = message.caption, !caption.isEmpty {
                Text(caption)
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textSecondary)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            Button(action: onCaptureSimilar) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill").font(.blip(size: 12, weight: .semibold))
                    Text("create similar").font(.blip(size: 13, weight: .semibold))
                }
                .foregroundStyle(BlipColor.accentNeutralOn)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(BlipColor.accentNeutral, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .frame(width: Self.cardWidth)
    }

    @ViewBuilder private var thumbnailView: some View {
        if let url = message.thumbnailUrl {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill().overlay(playOverlay)
                default: placeholderThumb
                }
            }
        } else { placeholderThumb }
    }

    private var playOverlay: some View {
        ZStack {
            BlipColor.mediaBackdrop.opacity(0.25)
            Image(systemName: "video.fill").font(.blip(size: 22)).foregroundStyle(.white.opacity(0.9)).shadow(radius: 4)
        }
    }
    private var placeholderThumb: some View {
        ZStack {
            BlipColor.mediaBackdrop
            Image(systemName: "video.fill").font(.blip(size: 22)).foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicatorRow: View {
    let uids: [String]
    let nameFor: (String) -> String
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    private var bubbleBg: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : UIColor(white: 0.84, alpha: 1)
        })
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(BlipColor.textTertiary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.4 : 1.0)
                        .animation(.easeInOut(duration: 0.28), value: phase)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(bubbleBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(typingLabel)
                .font(.blip(size: 12))
                .foregroundStyle(BlipColor.textTertiary)
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }

    private var typingLabel: String {
        let names = uids.prefix(2).map { nameFor($0) }
        return names.count == 1 ? "\(names[0]) is typing" : "\(names.joined(separator: " & ")) are typing"
    }
}
