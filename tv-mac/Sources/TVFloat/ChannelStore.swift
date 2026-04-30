import Foundation

final class ChannelStore: ObservableObject {

    @Published var channels: [Channel] = []

    private static var saveURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TVFloat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("channels.json")
    }()

    init() { load() }

    func load() {
        if let data    = try? Data(contentsOf: Self.saveURL),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            channels = decoded
        } else {
            channels = defaultChannels
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(channels) {
            try? data.write(to: Self.saveURL, options: .atomic)
        }
    }

    func reset() {
        channels = defaultChannels
        save()
    }
}
