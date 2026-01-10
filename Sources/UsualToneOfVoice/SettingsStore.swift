import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var language: String { didSet { defaults.set(language, forKey: Keys.language) } }
    @Published var initialPrompt: String { didSet { defaults.set(initialPrompt, forKey: Keys.initialPrompt) } }
    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) } }

    private let defaults = UserDefaults.standard

    init() {
        self.language = defaults.string(forKey: Keys.language) ?? Defaults.language
        self.initialPrompt = defaults.string(forKey: Keys.initialPrompt) ?? Defaults.initialPrompt
        self.autoPaste = defaults.object(forKey: Keys.autoPaste) as? Bool ?? Defaults.autoPaste
    }

    private enum Defaults {
        static let language = "ja"
        static let initialPrompt = "日本語で正確に書き起こしてください。プログラミング関連の用語、関数名、クラス名、ファイルパス、コマンド、コード断片は原文のまま保持し、勝手に言い換えないでください。英数字や記号は省略せず、必要なら記号も含めて書き起こしてください。"
        static let autoPaste = true
    }

    private enum Keys {
        static let language = "whisperLanguage"
        static let initialPrompt = "whisperInitialPrompt"
        static let autoPaste = "autoPaste"
    }
}
