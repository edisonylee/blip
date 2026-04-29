import FirebaseFunctions
import Foundation

/// Calls the `exportStitch` Cloud Function for a given blip's current day.
@MainActor
final class ExportService: ObservableObject {
    enum Status: Equatable {
        case idle
        case stitching
        case ready(url: URL, dateKey: String, hours: Int)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private let functions = Functions.functions(region: "us-central1")

    func stitch(blipId: String) async {
        status = .stitching
        do {
            let result = try await functions.httpsCallable("exportStitch")
                .call(["blipId": blipId])
            guard let dict = result.data as? [String: Any],
                  let urlString = dict["url"] as? String,
                  let url = URL(string: urlString),
                  let dateKey = dict["dateKey"] as? String,
                  let hours = dict["hours"] as? Int else {
                status = .failed("invalid response from exportStitch")
                return
            }
            status = .ready(url: url, dateKey: dateKey, hours: hours)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func reset() { status = .idle }
}
