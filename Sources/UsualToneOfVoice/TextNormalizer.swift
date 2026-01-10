import Foundation

enum TextNormalizer {
    private static let replacements: [(String, String)] = [
        // CPU / GPU
        ("シーピーユー", "CPU"),
        ("シーピーユ", "CPU"),
        ("しーぴーゆー", "CPU"),
        ("しーぴーゆ", "CPU"),
        ("ジーピーユー", "GPU"),
        ("ジーピーユ", "GPU"),
        ("じーぴーゆー", "GPU"),
        ("じーぴーゆ", "GPU"),

        // API / CLI / IDE / OS
        ("エーピーアイ", "API"),
        ("エイピーアイ", "API"),
        ("えーぴーあい", "API"),
        ("えいぴーあい", "API"),
        ("シーエルアイ", "CLI"),
        ("しーえるあい", "CLI"),
        ("アイディーイー", "IDE"),
        ("アイデーイー", "IDE"),
        ("あいでぃーいー", "IDE"),
        ("あいでーいー", "IDE"),
        ("オーエス", "OS"),
        ("おーえす", "OS"),

        // JSON / YAML
        ("ジェイソン", "JSON"),
        ("じぇいそん", "JSON"),
        ("ヤムル", "YAML"),
        ("ヤメル", "YAML"),
        ("やむる", "YAML"),
        ("やめる", "YAML"),

        // HTTP / HTTPS
        ("エッチティーティーピー", "HTTP"),
        ("エイチティーティーピー", "HTTP"),
        ("えっちてぃーてぃーぴー", "HTTP"),
        ("えいちてぃーてぃーぴー", "HTTP"),
        ("エッチティーティーピーエス", "HTTPS"),
        ("エイチティーティーピーエス", "HTTPS"),
        ("えっちてぃーてぃーぴーえす", "HTTPS"),
        ("えいちてぃーてぃーぴーえす", "HTTPS"),

        // URL / URI
        ("ユーアールエル", "URL"),
        ("ゆーあーるえる", "URL"),
        ("ユーアールアイ", "URI"),
        ("ゆーあーるあい", "URI"),

        // SQL / NoSQL
        ("エスキューエル", "SQL"),
        ("えすきゅーえる", "SQL"),
        ("ノーエスキューエル", "NoSQL"),
        ("のーえすきゅーえる", "NoSQL"),

        // HTML / CSS
        ("エイチティーエムエル", "HTML"),
        ("えいちてぃーえむえる", "HTML"),
        ("シーエスエス", "CSS"),
        ("しーえすえす", "CSS"),

        // Git / GitHub
        ("ギットハブ", "GitHub"),
        ("ぎっとはぶ", "GitHub"),
        ("ギット", "Git"),
        ("ジット", "Git"),
        ("ぎっと", "Git"),
        ("じっと", "Git"),

        // Languages
        ("シープラスプラス", "C++"),
        ("シープラプラ", "C++"),
        ("しーぷらすぷらす", "C++"),
        ("しーぷらぷら", "C++"),
        ("シーシャープ", "C#"),
        ("しーしゃーぷ", "C#"),
        ("ジャバスクリプト", "JavaScript"),
        ("じゃばすくりぷと", "JavaScript"),
        ("タイプスクリプト", "TypeScript"),
        ("たいぷすくりぷと", "TypeScript")
    ]

    static func normalize(_ text: String, userEntries: [UserDictionaryEntry] = UserDictionaryStore.shared.currentEntries()) -> String {
        var result = text
        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to)
        }

        if !userEntries.isEmpty {
            for entry in userEntries {
                result = result.replacingOccurrences(of: entry.from, with: entry.to)
            }
        }

        return result
    }
}
