import Cocoa
import CoreGraphics

class StampStore: ObservableObject {
    @Published var stamps: [StampItem] = []

    private let stampsDirectory: URL
    private let metadataURL: URL
    private let expirationDays: Int = 10
    private var imageCache: [UUID: NSImage] = [:]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("StampIt", isDirectory: true)
        stampsDirectory = appDir.appendingPathComponent("stamps", isDirectory: true)
        metadataURL = appDir.appendingPathComponent("stamps.json")

        try? FileManager.default.createDirectory(at: stampsDirectory, withIntermediateDirectories: true)
        loadMetadata()
        purgeExpired()
    }

    func saveStamp(image: CGImage) {
        let item = StampItem()
        let fileURL = stampsDirectory.appendingPathComponent(item.filename)

        guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return }

        stamps.insert(item, at: 0)
        saveMetadata()

        copyToClipboard(item)
        ToastWindow.show("Copied to clipboard")
    }

    func toggleStar(_ stamp: StampItem) {
        guard let index = stamps.firstIndex(where: { $0.id == stamp.id }) else { return }
        stamps[index].isStarred.toggle()
        saveMetadata()
    }

    func loadImage(for stamp: StampItem) -> NSImage? {
        if let cached = imageCache[stamp.id] { return cached }
        let fileURL = stampsDirectory.appendingPathComponent(stamp.filename)
        guard let image = NSImage(contentsOf: fileURL) else { return nil }
        imageCache[stamp.id] = image
        return image
    }

    func copyToClipboard(_ stamp: StampItem) {
        guard let image = loadImage(for: stamp) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    func clearAll() {
        for stamp in stamps {
            let fileURL = stampsDirectory.appendingPathComponent(stamp.filename)
            try? FileManager.default.removeItem(at: fileURL)
        }
        stamps.removeAll()
        imageCache.removeAll()
        saveMetadata()
    }

    /// Remove unstarred stamps older than expirationDays.
    private func purgeExpired() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -expirationDays, to: Date()) ?? Date()
        let expired = stamps.filter { !$0.isStarred && $0.timestamp < cutoff }

        for stamp in expired {
            let fileURL = stampsDirectory.appendingPathComponent(stamp.filename)
            try? FileManager.default.removeItem(at: fileURL)
        }

        if !expired.isEmpty {
            stamps.removeAll { stamp in expired.contains { $0.id == stamp.id } }
            saveMetadata()
        }
    }

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        stamps = (try? decoder.decode([StampItem].self, from: data)) ?? []
    }

    private func saveMetadata() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(stamps) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
}
