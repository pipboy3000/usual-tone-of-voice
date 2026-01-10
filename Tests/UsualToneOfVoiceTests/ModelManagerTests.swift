import XCTest
@testable import UsualToneOfVoice

final class ModelManagerTests: XCTestCase {
    func testDefaultModelPathEndsWithFilename() {
        let url = ModelManager.defaultModelPath()
        XCTAssertTrue(url.lastPathComponent == ModelManager.defaultModelFilename)
    }

    func testIsDefaultModelPath() {
        let defaultPath = ModelManager.defaultModelPath().path
        XCTAssertTrue(ModelManager.isDefaultModelPath(defaultPath))

        let otherPath = ModelManager.modelsDirectory().appendingPathComponent("other.bin").path
        XCTAssertFalse(ModelManager.isDefaultModelPath(otherPath))
    }
}
