import Foundation

final class ModelManager: NSObject, URLSessionDownloadDelegate {
    static let shared = ModelManager()

    enum Status {
        case idle
        case downloading(progress: Double)
        case ready(path: String)
        case failed(message: String)
    }

    private var downloadSession: URLSession?
    private var task: URLSessionDownloadTask?
    private var targetURL: URL?

    var onStatus: ((Status) -> Void)?

    static let defaultModelFilename = "ggml-large-v3-turbo-q8_0.bin"
    static let defaultModelURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin?download=true")!

    override init() {
        super.init()
    }

    static func modelsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("UsualToneOfVoice/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func defaultModelPath() -> URL {
        modelsDirectory().appendingPathComponent(defaultModelFilename)
    }

    static func isDefaultModelPath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return url.standardizedFileURL == defaultModelPath().standardizedFileURL
    }

    func ensureModel(at path: URL, downloadURL: URL) {
        if FileManager.default.fileExists(atPath: path.path) {
            onStatus?(.ready(path: path.path))
            return
        }

        startDownload(to: path, from: downloadURL)
    }

    func startDownload(to path: URL, from url: URL) {
        task?.cancel()
        targetURL = path

        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.downloadSession = session
        self.task = session.downloadTask(with: url)
        onStatus?(.downloading(progress: 0.0))
        task?.resume()
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let targetURL else { return }
        if let response = downloadTask.response as? HTTPURLResponse {
            guard (200...299).contains(response.statusCode) else {
                onStatus?(.failed(message: "Download failed (HTTP \(response.statusCode))"))
                return
            }
        }
        do {
            let dir = targetURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.moveItem(at: location, to: targetURL)
            onStatus?(.ready(path: targetURL.path))
        } catch {
            onStatus?(.failed(message: error.localizedDescription))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onStatus?(.downloading(progress: progress))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                return
            }
            onStatus?(.failed(message: error.localizedDescription))
        }
    }
}
