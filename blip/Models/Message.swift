import Foundation

enum MessageType: String {
    case text
    case clip
    case image
    case audio
}

struct BlipMessage: Identifiable, Hashable {
    let id: String
    var uid: String
    var blipId: String?
    var blipName: String?
    var senderName: String?
    var type: MessageType
    var text: String?
    var thumbnailUrl: URL?
    var videoUrl: URL?
    var imageUrl: URL?
    var imageUrls: [URL]
    var caption: String?
    var clipId: String?
    // Audio fields
    var audioUrl: URL?
    var audioDuration: Double?   // seconds
    var waveform: [Float]        // 30 normalised bars 0-1, stored in RTDB
    var createdAt: Date
    var deleted: Bool
    var deletedBy: String?

    // Decode from Firebase RTDB snapshot dictionary.
    // `ts` is milliseconds since epoch. Firebase may bridge it back as Int,
    // Int64, Double, or NSNumber depending on platform/runtime.
    init?(id: String, data: [String: Any]) {
        guard
            let uid = data["uid"] as? String,
            let ts = Self.timestampMilliseconds(from: data["ts"])
        else { return nil }
        self.id = id
        self.uid = uid
        self.blipId = data["blipId"] as? String
        self.blipName = data["blipName"] as? String
        self.senderName = data["senderName"] as? String
        self.type = MessageType(rawValue: data["type"] as? String ?? "text") ?? .text
        self.text = data["text"] as? String
        self.thumbnailUrl = (data["thumbnailUrl"] as? String).flatMap(URL.init(string:))
        self.videoUrl = (data["videoUrl"] as? String).flatMap(URL.init(string:))
        self.imageUrl = (data["imageUrl"] as? String).flatMap(URL.init(string:))
        let urlStrings: [String]
        if let arr = data["imageUrls"] as? [String] {
            urlStrings = arr
        } else if let nsArr = data["imageUrls"] as? NSArray {
            urlStrings = nsArr.compactMap { $0 as? String }
        } else if let dict = data["imageUrls"] as? [String: Any] {
            // RTDB returns arrays as numbered dicts when written via server SDK
            urlStrings = dict.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
                .compactMap { dict[$0] as? String }
        } else {
            urlStrings = []
        }
        self.imageUrls = urlStrings.compactMap(URL.init(string:))
        if let imageUrl, self.imageUrls.isEmpty {
            self.imageUrls = [imageUrl]
        }
        self.caption = data["caption"] as? String
        self.clipId = data["clipId"] as? String
        self.audioUrl = (data["audioUrl"] as? String).flatMap(URL.init(string:))
        self.audioDuration = data["audioDuration"] as? Double
        // waveform stored as array of NSNumber / Double
        if let arr = data["waveform"] as? [NSNumber] {
            self.waveform = arr.map { Float($0.doubleValue) }
        } else if let arr = data["waveform"] as? [Double] {
            self.waveform = arr.map(Float.init)
        } else {
            self.waveform = []
        }
        self.createdAt = Date(timeIntervalSince1970: ts / 1000.0)
        self.deleted = data["deleted"] as? Bool ?? false
        self.deletedBy = data["deletedBy"] as? String
    }

    private static func timestampMilliseconds(from value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let int64 as Int64:
            return Double(int64)
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }
}
