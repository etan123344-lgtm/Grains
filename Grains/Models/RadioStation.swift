import Foundation

struct RadioStation: Identifiable, Codable {
    let stationuuid: String
    let name: String
    let country: String
    let tags: String
    let url_resolved: String
    let favicon: String
    let codec: String
    let bitrate: Int

    var id: String { stationuuid }

    var displayTags: String {
        tags.split(separator: ",")
            .prefix(3)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .joined(separator: " · ")
    }

    var bitrateLabel: String {
        bitrate > 0 ? "\(bitrate) KBPS" : ""
    }
}
