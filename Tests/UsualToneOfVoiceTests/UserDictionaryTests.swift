import XCTest
@testable import UsualToneOfVoice

final class UserDictionaryTests: XCTestCase {
    func testParseEntries() {
        let contents = """
# comment
シーピーユー -> CPU

 ジーピーユー->GPU
invalid line
"""
        let entries = UserDictionary.parseEntries(contents: contents)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].from, "シーピーユー")
        XCTAssertEqual(entries[0].to, "CPU")
        XCTAssertEqual(entries[1].from, "ジーピーユー")
        XCTAssertEqual(entries[1].to, "GPU")
    }
}
