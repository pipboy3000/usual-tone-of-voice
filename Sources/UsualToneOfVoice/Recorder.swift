import Foundation
import AVFoundation

final class Recorder {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?

    func start() throws {
        let url = try nextRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()

        if !recorder.record() {
            throw RecorderError.failedToStart
        }

        self.recorder = recorder
        self.currentURL = url
    }

    func stop() -> URL? {
        recorder?.stop()
        let url = currentURL
        recorder = nil
        currentURL = nil
        return url
    }

    private func nextRecordingURL() throws -> URL {
        let base = try recordingDirectory()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "recording_\(formatter.string(from: Date())).wav"
        return base.appendingPathComponent(filename)
    }

    private func recordingDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("UsualToneOfVoice/Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

enum RecorderError: LocalizedError {
    case failedToStart

    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Unable to start recording"
        }
    }
}
