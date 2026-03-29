import Foundation

struct StampItem: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let filename: String
    var isStarred: Bool

    init(id: UUID = UUID(), timestamp: Date = Date(), filename: String? = nil, isStarred: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.filename = filename ?? "stamp-\(id.uuidString).png"
        self.isStarred = isStarred
    }
}
