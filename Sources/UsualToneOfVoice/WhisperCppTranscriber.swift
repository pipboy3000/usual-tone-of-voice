import Foundation
import AVFoundation
import whisper

final class WhisperCppTranscriber {
    func transcribe(
        audioURL: URL,
        modelPath: String,
        language: String?,
        initialPrompt: String,
        chunkDuration: TimeInterval,
        bestOf: Int,
        beamSize: Int,
        temperature: Double,
        temperatureIncrement: Double,
        noFallback: Bool
    ) throws -> String {
        if chunkDuration > 0 {
            return try transcribeInChunks(
                audioURL: audioURL,
                modelPath: modelPath,
                language: language,
                initialPrompt: initialPrompt,
                chunkDuration: chunkDuration,
                bestOf: bestOf,
                beamSize: beamSize,
                temperature: temperature,
                temperatureIncrement: temperatureIncrement,
                noFallback: noFallback
            )
        }

        return try transcribeSingle(
            audioURL: audioURL,
            modelPath: modelPath,
            language: language,
            initialPrompt: initialPrompt,
            bestOf: bestOf,
            beamSize: beamSize,
            temperature: temperature,
            temperatureIncrement: temperatureIncrement,
            noFallback: noFallback
        )
    }

    private func transcribeInChunks(
        audioURL: URL,
        modelPath: String,
        language: String?,
        initialPrompt: String,
        chunkDuration: TimeInterval,
        bestOf: Int,
        beamSize: Int,
        temperature: Double,
        temperatureIncrement: Double,
        noFallback: Bool
    ) throws -> String {
        let chunkDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: chunkDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: chunkDir) }

        let chunkURLs = try splitAudio(audioURL: audioURL, chunkDuration: chunkDuration, outputDir: chunkDir)

        var parts: [String] = []
        for chunkURL in chunkURLs {
            let text = try transcribeSingle(
                audioURL: chunkURL,
                modelPath: modelPath,
                language: language,
                initialPrompt: initialPrompt,
                bestOf: bestOf,
                beamSize: beamSize,
                temperature: temperature,
                temperatureIncrement: temperatureIncrement,
                noFallback: noFallback
            )
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                parts.append(trimmed)
            }
        }

        return parts.joined(separator: "\n")
    }

    private func transcribeSingle(
        audioURL: URL,
        modelPath: String,
        language: String?,
        initialPrompt: String,
        bestOf: Int,
        beamSize: Int,
        temperature: Double,
        temperatureIncrement: Double,
        noFallback: Bool
    ) throws -> String {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperCppError.missingModel(path: modelPath)
        }

        let samples = try loadAudioSamples(audioURL: audioURL)
        if samples.isEmpty {
            return ""
        }

        let contextParams = whisper_context_default_params()
        guard let ctx = whisper_init_from_file_with_params(modelPath, contextParams) else {
            throw WhisperCppError.whisperFailed(stderr: "Failed to load whisper.cpp model")
        }
        defer { whisper_free(ctx) }

        let strategy: whisper_sampling_strategy = beamSize > 0 ? WHISPER_SAMPLING_BEAM_SEARCH : WHISPER_SAMPLING_GREEDY
        var params = whisper_full_default_params(strategy)
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = false
        params.single_segment = false
        params.token_timestamps = false
        params.n_threads = max(1, min(8, Int32(ProcessInfo.processInfo.activeProcessorCount)))

        if bestOf > 0 {
            params.greedy.best_of = Int32(bestOf)
        }
        if beamSize > 0 {
            params.beam_search.beam_size = Int32(beamSize)
        }

        params.temperature = Float(temperature)
        params.temperature_inc = Float(temperatureIncrement)
        _ = noFallback

        var promptPointer: UnsafeMutablePointer<CChar>? = nil
        if !initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptPointer = strdup(initialPrompt)
            if let promptPointer {
                params.initial_prompt = UnsafePointer(promptPointer)
            } else {
                params.initial_prompt = nil
            }
        } else {
            params.initial_prompt = nil
        }

        var languagePointer: UnsafeMutablePointer<CChar>? = nil
        if let language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            languagePointer = strdup(language)
            if let languagePointer {
                params.language = UnsafePointer(languagePointer)
            } else {
                params.language = nil
            }
            params.detect_language = false
        } else {
            params.language = nil
            params.detect_language = true
        }

        defer {
            if let promptPointer {
                free(promptPointer)
            }
            if let languagePointer {
                free(languagePointer)
            }
        }

        let result: Int32 = samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return -1 }
            return whisper_full(ctx, params, baseAddress, Int32(buffer.count))
        }

        guard result == 0 else {
            throw WhisperCppError.whisperFailed(stderr: "whisper.cpp failed with code \(result)")
        }

        let segmentCount = whisper_full_n_segments(ctx)
        var output = ""
        if segmentCount > 0 {
            for index in 0..<Int(segmentCount) {
                let segment = whisper_full_get_segment_text(ctx, Int32(index))
                if let segment {
                    output += String(cString: segment)
                }
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadAudioSamples(audioURL: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: audioURL)
        let inputFormat = file.processingFormat
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw WhisperCppError.audioConversionFailed
        }

        var samples: [Float] = []
        let bufferSize: AVAudioFrameCount = 8192

        while file.framePosition < file.length {
            let remaining = AVAudioFrameCount(file.length - file.framePosition)
            let frameCount = min(bufferSize, remaining)
            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
                break
            }
            try file.read(into: inputBuffer, frameCount: frameCount)

            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
                break
            }

            var error: NSError?
            var didProvideInput = false
            converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                if didProvideInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                didProvideInput = true
                outStatus.pointee = .haveData
                return inputBuffer
            }
            if let error {
                throw error
            }

            guard let channelData = outputBuffer.floatChannelData?[0] else {
                continue
            }
            let frameLength = Int(outputBuffer.frameLength)
            samples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: frameLength))
        }

        return samples
    }

    private func splitAudio(audioURL: URL, chunkDuration: TimeInterval, outputDir: URL) throws -> [URL] {
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let totalFrames = file.length

        let framesPerChunk = AVAudioFrameCount(sampleRate * chunkDuration)
        guard framesPerChunk > 0 else {
            return [audioURL]
        }

        var remainingFrames = totalFrames
        var chunkIndex = 0
        var chunkURLs: [URL] = []

        while remainingFrames > 0 {
            let framesToRead = min(remainingFrames, AVAudioFramePosition(framesPerChunk))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(framesToRead)) else {
                break
            }

            try file.read(into: buffer, frameCount: AVAudioFrameCount(framesToRead))

            let chunkURL = outputDir.appendingPathComponent("chunk_\(chunkIndex).wav")
            let chunkFile = try AVAudioFile(forWriting: chunkURL, settings: file.fileFormat.settings)
            try chunkFile.write(from: buffer)

            chunkURLs.append(chunkURL)
            remainingFrames -= AVAudioFramePosition(framesToRead)
            chunkIndex += 1
        }

        return chunkURLs
    }
}

enum WhisperCppError: LocalizedError {
    case missingModel(path: String)
    case whisperFailed(stderr: String)
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .missingModel(let path):
            return "whisper.cpp model not found at \(path)"
        case .whisperFailed(let stderr):
            return stderr.isEmpty ? "whisper.cpp failed" : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        case .audioConversionFailed:
            return "Failed to convert audio for transcription"
        }
    }
}
