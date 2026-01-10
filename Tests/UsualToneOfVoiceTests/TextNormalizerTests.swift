import XCTest
@testable import UsualToneOfVoice

final class TextNormalizerTests: XCTestCase {
    func testFixedReplacements() {
        let input = "シーピーユーとジーピーユーとエーピーアイ"
        let output = TextNormalizer.normalize(input, userEntries: [])
        XCTAssertEqual(output, "CPUとGPUとAPI")
    }

    func testUserDictionaryOverrides() {
        let input = "シーピーユー"
        let user = [UserDictionaryEntry(from: "CPU", to: "CentralProcessingUnit")]
        let output = TextNormalizer.normalize(input, userEntries: user)
        XCTAssertEqual(output, "CentralProcessingUnit")
    }
}
