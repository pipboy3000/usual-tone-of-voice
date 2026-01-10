import Foundation
import AVFoundation

final class WhisperCppTranscriber {
    func transcribe(
        audioURL: URL,
        whisperCppPath: String,
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
                whisperCppPath: whisperCppPath,
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
            whisperCppPath: whisperCppPath,
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
        whisperCppPath: String,
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
                whisperCppPath: whisperCppPath,
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
        whisperCppPath: String,
        modelPath: String,
        language: String?,
        initialPrompt: String,
        bestOf: Int,
        beamSize: Int,
        temperature: Double,
        temperatureIncrement: Double,
        noFallback: Bool
    ) throws -> String {
        guard let resolvedPath = resolveWhisperCppPath(whisperCppPath) else {
            throw WhisperCppError.missingBinary(path: whisperCppPath)
        }
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperCppError.missingModel(path: modelPath)
        }

        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let outputBase = outputDir.appendingPathComponent("output")
        let stderrURL = outputDir.appendingPathComponent("stderr.log")

        var arguments = [
            "-m", modelPath,
            "-f", audioURL.path,
            "-otxt",
            "-of", outputBase.path
        ]

        if let language, !language.isEmpty {
            arguments += ["-l", language]
        }

        if !initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments += ["--prompt", initialPrompt]
        }

        if bestOf > 0 {
            arguments += ["--best-of", String(bestOf)]
        }

        if beamSize > 0 {
            arguments += ["--beam-size", String(beamSize)]
        }

        arguments += ["--temperature", String(format: "%.1f", temperature)]
        arguments += ["--temperature-inc", String(format: "%.1f", temperatureIncrement)]

        if noFallback {
            arguments += ["--no-fallback"]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedPath)
        process.arguments = arguments

        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        process.standardError = stderrHandle

        try process.run()
        process.waitUntilExit()
        try? stderrHandle.close()

        if process.terminationStatus != 0 {
            let stderrData = (try? Data(contentsOf: stderrURL)) ?? Data()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            throw WhisperCppError.whisperFailed(stderr: stderr)
        }

        let outputFile = URL(fileURLWithPath: outputBase.path + ".txt")
        let text = try String(contentsOf: outputFile, encoding: .utf8)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveWhisperCppPath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return FileManager.default.isExecutableFile(atPath: trimmed) ? trimmed : nil
        }

        if let bundled = bundledWhisperCliPath(), FileManager.default.isExecutableFile(atPath: bundled) {
            return bundled
        }

        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cpp",
            "/usr/local/bin/whisper-cli",
            "/usr/local/bin/whisper-cpp"
        ]

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    private func bundledWhisperCliPath() -> String? {
        if let url = Bundle.main.url(forResource: "whisper-cli", withExtension: nil) {
            return url.path
        }
        if let url = Bundle.main.resourceURL?.appendingPathComponent("whisper-cli") {
            return url.path
        }
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "whisper-cli", withExtension: nil) {
            return url.path
        }
        #endif
        return nil
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
    case missingBinary(path: String)
    case missingModel(path: String)
    case whisperFailed(stderr: String)

    var errorDescription: String? {
        switch self {
        case .missingBinary(let path):
            return path.isEmpty ? "whisper.cpp binary not found" : "whisper.cpp binary not found at \(path)"
        case .missingModel(let path):
            return "whisper.cpp model not found at \(path)"
        case .whisperFailed(let stderr):
            return stderr.isEmpty ? "whisper.cpp failed" : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
