import Foundation
import AVFoundation

struct AudioSilenceAnalysis {
    let totalDuration: TimeInterval
    let activeDuration: TimeInterval
}

enum AudioSilenceAnalyzer {
    static func analyze(url: URL, silenceThresholdDB: Float) throws -> AudioSilenceAnalysis {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let chunkSize: AVAudioFrameCount = 4_096
        let amplitudeThreshold = pow(10, silenceThresholdDB / 20)

        var totalFrames: Int64 = 0
        var activeFrames: Int64 = 0

        while file.framePosition < file.length {
            let remainingFrames = AVAudioFrameCount(file.length - file.framePosition)
            let frameCount = min(chunkSize, remainingFrames)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw AudioSilenceAnalyzerError.failedToCreateBuffer
            }

            try file.read(into: buffer, frameCount: frameCount)

            let framesRead = Int(buffer.frameLength)
            guard framesRead > 0 else { break }
            guard let channelData = buffer.floatChannelData else {
                throw AudioSilenceAnalyzerError.unsupportedFormat
            }

            for frameIndex in 0..<framesRead {
                var peak: Float = 0
                for channelIndex in 0..<channelCount {
                    let sample = channelData[channelIndex][frameIndex]
                    let magnitude = abs(sample)
                    if magnitude > peak {
                        peak = magnitude
                    }
                }

                if peak >= amplitudeThreshold {
                    activeFrames += 1
                }
            }

            totalFrames += Int64(framesRead)
        }

        let totalDuration = sampleRate > 0 ? Double(totalFrames) / sampleRate : 0
        let activeDuration = sampleRate > 0 ? Double(activeFrames) / sampleRate : 0
        return AudioSilenceAnalysis(totalDuration: totalDuration, activeDuration: activeDuration)
    }
}

enum AudioSilenceAnalyzerError: LocalizedError {
    case failedToCreateBuffer
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .failedToCreateBuffer:
            return "Failed to allocate audio buffer"
        case .unsupportedFormat:
            return "Unsupported audio format"
        }
    }
}
