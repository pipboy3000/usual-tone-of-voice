import Foundation
import Darwin

struct UserDictionaryEntry {
    let from: String
    let to: String
}

enum UserDictionary {
    private static let filename = "dictionary.txt"

    static func dictionaryURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("UsualToneOfVoice", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename)
    }

    static func ensureDefaultFile() {
        let url = dictionaryURL()
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        let sample = """
# Format: source -> replacement
# Lines starting with # are comments.
# Example:
# シーピーユー -> CPU
# ジーピーユー -> GPU
# エーピーアイ -> API
"""
        try? sample.write(to: url, atomically: true, encoding: .utf8)
    }

    static func loadEntries() -> [UserDictionaryEntry] {
        ensureDefaultFile()
        let url = dictionaryURL()
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseEntries(contents: contents)
    }

    static func parseEntries(contents: String) -> [UserDictionaryEntry] {
        var entries: [UserDictionaryEntry] = []
        for line in contents.split(separator: "\n") {
            let raw = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty || raw.hasPrefix("#") { continue }
            guard let range = raw.range(of: "->") else { continue }
            let from = raw[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let to = raw[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !from.isEmpty {
                entries.append(UserDictionaryEntry(from: String(from), to: String(to)))
            }
        }
        return entries
    }
}

final class UserDictionaryStore {
    static let shared = UserDictionaryStore()

    private let queue = DispatchQueue(label: "UserDictionaryStore.queue")
    private var entries: [UserDictionaryEntry] = []
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    private init() {
        UserDictionary.ensureDefaultFile()
        reloadInternal()
        startMonitoring()
    }

    func currentEntries() -> [UserDictionaryEntry] {
        queue.sync { entries }
    }

    private func reloadInternal() {
        entries = UserDictionary.loadEntries()
    }

    private func startMonitoring() {
        stopMonitoring()

        let url = UserDictionary.dictionaryURL()
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                self.stopMonitoring()
                UserDictionary.ensureDefaultFile()
                self.reloadInternal()
                self.startMonitoring()
            } else {
                self.reloadInternal()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = source
        source.resume()
    }

    private func stopMonitoring() {
        source?.cancel()
        source = nil
    }
}
