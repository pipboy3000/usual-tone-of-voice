import Foundation

@MainActor
final class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []

    private let maxEntries = 200
    private let logURL: URL
    private let dateFormatter: DateFormatter

    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.dateFormatter = formatter

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("UsualToneOfVoice/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.logURL = dir.appendingPathComponent("app.log")
    }

    func add(_ message: String) {
        let entry = LogEntry(date: Date(), message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        appendToFile(entry)
    }

    func logFileURL() -> URL {
        logURL
    }

    private func appendToFile(_ entry: LogEntry) {
        let line = "[\(dateFormatter.string(from: entry.date))] \(entry.message)\n"
        guard let data = line.data(using: .utf8) else { return }
        do {
            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            // Ignore logging failures to avoid recursion.
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let message: String
}
