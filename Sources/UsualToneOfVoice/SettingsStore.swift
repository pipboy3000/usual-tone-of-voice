import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var language: String { didSet { defaults.set(language, forKey: Keys.language) } }
    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) } }
    @Published var recordingHotKey: RecordingHotKey {
        didSet { defaults.set(recordingHotKey.rawValue, forKey: Keys.recordingHotKey) }
    }
    @Published var silenceDetectionSensitivity: SilenceDetectionSensitivity {
        didSet { defaults.set(silenceDetectionSensitivity.rawValue, forKey: Keys.silenceDetectionSensitivity) }
    }
    @Published var openAIEnabled: Bool { didSet { defaults.set(openAIEnabled, forKey: Keys.openAIEnabled) } }
    @Published var openAIModel: String { didSet { defaults.set(openAIModel, forKey: Keys.openAIModel) } }
    @Published var openAIUserPrompt: String { didSet { defaults.set(openAIUserPrompt, forKey: Keys.openAIUserPrompt) } }
    @Published var openAIKey: String { didSet { saveOpenAIKey() } }
    @Published private(set) var openAIKeyError: String? = nil

    private let defaults = UserDefaults.standard
    private let openAIKeyStore: KeychainStore

    init() {
        self.openAIKeyStore = KeychainStore(service: SettingsStore.keychainService, account: "openai_api_key")
        self.language = defaults.string(forKey: Keys.language) ?? Defaults.language
        self.autoPaste = defaults.object(forKey: Keys.autoPaste) as? Bool ?? Defaults.autoPaste
        let storedRecordingHotKey = defaults.string(forKey: Keys.recordingHotKey) ?? Defaults.recordingHotKey
        self.recordingHotKey = RecordingHotKey(rawValue: storedRecordingHotKey) ?? .doubleCommand
        let storedSensitivity = defaults.string(forKey: Keys.silenceDetectionSensitivity) ?? Defaults.silenceDetectionSensitivity
        self.silenceDetectionSensitivity = SilenceDetectionSensitivity(rawValue: storedSensitivity) ?? .balanced
        self.openAIEnabled = defaults.object(forKey: Keys.openAIEnabled) as? Bool ?? Defaults.openAIEnabled
        let storedModel = defaults.string(forKey: Keys.openAIModel) ?? Defaults.openAIModel
        self.openAIModel = OpenAIModel(rawValue: storedModel)?.rawValue ?? Defaults.openAIModel
        self.openAIUserPrompt = defaults.string(forKey: Keys.openAIUserPrompt) ?? Defaults.openAIUserPrompt
        self.openAIKey = (try? openAIKeyStore.read()) ?? ""
    }

    private enum Defaults {
        static let language = "ja"
        static let autoPaste = true
        static let recordingHotKey = RecordingHotKey.doubleCommand.rawValue
        static let silenceDetectionSensitivity = SilenceDetectionSensitivity.balanced.rawValue
        static let openAIEnabled = false
        static let openAIModel = OpenAIClient.defaultModel
        static let openAIUserPrompt = "日本語で正確に書き起こしてください。プログラミング関連の用語、関数名、クラス名、ファイルパス、コマンド、コード断片は原文のまま保持し、勝手に言い換えないでください。英数字や記号は省略せず、必要なら記号も含めて書き起こしてください。"
    }

    private enum Keys {
        static let language = "whisperLanguage"
        static let autoPaste = "autoPaste"
        static let recordingHotKey = "recordingHotKey"
        static let silenceDetectionSensitivity = "silenceDetectionSensitivity"
        static let openAIEnabled = "openAIEnabled"
        static let openAIModel = "openAIModel"
        static let openAIUserPrompt = "openAIUserPrompt"
    }

    private static var keychainService: String {
        Bundle.main.bundleIdentifier ?? "local.UsualToneOfVoice"
    }

    func resetOpenAIUserPrompt() {
        openAIUserPrompt = Defaults.openAIUserPrompt
    }

    private func saveOpenAIKey() {
        openAIKeyError = nil
        let trimmed = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try openAIKeyStore.delete()
            } else {
                try openAIKeyStore.save(trimmed)
            }
        } catch {
            openAIKeyError = error.localizedDescription
        }
    }
}

enum RecordingHotKey: String, CaseIterable, Identifiable {
    case doubleCommand
    case doubleOption
    case doubleControl
    case doubleShift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .doubleCommand:
            return "Double Command"
        case .doubleOption:
            return "Double Option"
        case .doubleControl:
            return "Double Control"
        case .doubleShift:
            return "Double Shift"
        }
    }
}

enum SilenceDetectionSensitivity: String, CaseIterable, Identifiable {
    case relaxed
    case balanced
    case strict
    case veryStrict

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relaxed:
            return "Relaxed"
        case .balanced:
            return "Balanced"
        case .strict:
            return "Strict"
        case .veryStrict:
            return "Very Strict"
        }
    }

    var thresholdDB: Float {
        switch self {
        case .relaxed:
            return -50
        case .balanced:
            return -45
        case .strict:
            return -40
        case .veryStrict:
            return -35
        }
    }

    var helperText: String {
        switch self {
        case .relaxed:
            return "Picks quieter voices, but may include more background sound."
        case .balanced:
            return "Good default for mixed environments."
        case .strict:
            return "Reduces background TV/noise, may miss quiet speech."
        case .veryStrict:
            return "Strongest filtering for noisy rooms."
        }
    }
}

enum OpenAIModel: String, CaseIterable, Identifiable {
    case gpt5Mini = "gpt-5-mini"
    case gpt4oMini = "gpt-4o-mini"
    case gpt41Mini = "gpt-4.1-mini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt5Mini:
            return "GPT-5 mini"
        case .gpt4oMini:
            return "GPT-4o mini"
        case .gpt41Mini:
            return "GPT-4.1 mini"
        }
    }
}
