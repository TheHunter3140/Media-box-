import XCTest
@testable import MediaBox

final class StabilityTests: XCTestCase {
    func testEcoDerivationMatrix() {
        typealias E = EcoCore
        XCTAssertEqual(E.derive(lowPower: false, thermal: .nominal, memoryPressure: false, playing: false).0, .normal)
        XCTAssertEqual(E.derive(lowPower: false, thermal: .serious, memoryPressure: false, playing: true).0, .thermiqueCritique)
        XCTAssertEqual(E.derive(lowPower: true, thermal: .nominal, memoryPressure: false, playing: false).0, .economique)
        XCTAssertEqual(E.derive(lowPower: true, thermal: .nominal, memoryPressure: false, playing: true).0, .ultra)
        XCTAssertEqual(E.derive(lowPower: false, thermal: .nominal, memoryPressure: true, playing: false).0, .economique)
        XCTAssertEqual(E.derive(lowPower: false, thermal: .fair, memoryPressure: false, playing: false).0, .economique)
    }

    func testPolicyIsMonotonic() {
        XCTAssertGreaterThan(EcoPolicy.make(for: .normal).maxDownloads, EcoPolicy.make(for: .economique).maxDownloads)
        XCTAssertEqual(EcoPolicy.make(for: .thermiqueCritique).maxDownloads, 0)
        XCTAssertFalse(EcoPolicy.make(for: .ultra).indexing)
    }

    func testMediaItemCodableRoundTrip() throws {
        let items = makeItems(50)
        let data = try JSONEncoder().encode(items)
        let back = try JSONDecoder().decode([MediaItem].self, from: data)
        XCTAssertEqual(items, back)
    }

    func testFormats() {
        XCTAssertEqual(MediaFormats.kind(forExtension: "FLAC"), .audio)
        XCTAssertEqual(MediaFormats.kind(forExtension: "mov"), .video)
        XCTAssertNil(MediaFormats.kind(forExtension: "mkv"))
        XCTAssertEqual(Format.time(3725), "1:02:05")
    }
}
