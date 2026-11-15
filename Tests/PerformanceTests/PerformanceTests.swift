import XCTest
@testable import MediaBox

final class PerformanceTests: XCTestCase {
    func testDuplicateGroupingOn1000Items() {
        var items = makeItems(1000)
        for i in 0..<100 { var d = items[i]; d.id += "-copy"; d.locator.path += "-copy"; items.append(d) }
        measure { _ = DuplicateDetector.candidateGroups(items) }
        XCTAssertEqual(DuplicateDetector.candidateGroups(items).count, 100)
    }

    func testShuffleOf1000Items() {
        let items = makeItems(1000)
        measure {
            var q = PlaybackQueue()
            q.set(items: items, startIndex: 0, shuffle: true)
        }
    }

    func testPartialHashDetectsIdenticalFiles() throws {
        let dir = FileManager.default.temporaryDirectory
        let a = dir.appendingPathComponent("a-\(UUID().uuidString).bin"), b = dir.appendingPathComponent("b-\(UUID().uuidString).bin")
        let data = Data((0..<300_000).map { UInt8($0 % 251) })
        try data.write(to: a); try data.write(to: b)
        XCTAssertEqual(DuplicateDetector.partialHash(url: a, size: Int64(data.count)), DuplicateDetector.partialHash(url: b, size: Int64(data.count)))
        try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b)
    }
}
