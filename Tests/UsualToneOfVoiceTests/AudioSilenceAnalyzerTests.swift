import XCTest
import AVFoundation
@testable import UsualToneOfVoice

final class AudioSilenceAnalyzerTests: XCTestCase {
    func testAnalyzeSilenceFileReturnsNoActiveDuration() throws {
        let sampleRate = 16_000
        let samples = Array(repeating: Float(0), count: sampleRate * 2)
        let audioURL = try makeWAVFile(samples: samples, sampleRate: Double(sampleRate))
        defer { cleanup(audioURL: audioURL) }

        let analysis = try AudioSilenceAnalyzer.analyze(url: audioURL, silenceThresholdDB: -45)

        XCTAssertGreaterThan(analysis.totalDuration, 1.9)
        XCTAssertLessThan(analysis.activeDuration, 0.01)
    }

    func testAnalyzeVoiceLikeSignalReturnsActiveDuration() throws {
        let sampleRate = 16_000
        var samples = Array(repeating: Float(0), count: sampleRate * 2)
        for index in (sampleRate / 2)..<(sampleRate + sampleRate / 2) {
            samples[index] = 0.1
        }
        let audioURL = try makeWAVFile(samples: samples, sampleRate: Double(sampleRate))
        defer { cleanup(audioURL: audioURL) }

        let analysis = try AudioSilenceAnalyzer.analyze(url: audioURL, silenceThresholdDB: -45)

        XCTAssertGreaterThan(analysis.totalDuration, 1.9)
        XCTAssertGreaterThan(analysis.activeDuration, 0.9)
    }

    private func makeWAVFile(samples: [Float], sampleRate: Double) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("test.wav")

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioSilenceAnalyzerTests", code: 1)
        }

        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else {
            throw NSError(domain: "AudioSilenceAnalyzerTests", code: 2)
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }
        try audioFile.write(from: buffer)
        return url
    }

    private func cleanup(audioURL: URL) {
        try? FileManager.default.removeItem(at: audioURL.deletingLastPathComponent())
    }
}
