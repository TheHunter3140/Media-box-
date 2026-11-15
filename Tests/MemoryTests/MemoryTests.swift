import XCTest
@testable import MediaBox

@MainActor
final class MemoryTests: XCTestCase {
    func testFootprintIsPositive() {
        XCTAssertGreaterThan(MemoryFootprint.currentBytes(), 0)
    }

    func testPeakNeverDecreases() {
        let mm = MemoryManager()
        var value: UInt64 = 50_000_000
        mm.footprintProvider = { value }
        mm.sample()
        let p1 = mm.peakBytes
        value = 10_000_000
        mm.sample()
        XCTAssertGreaterThanOrEqual(mm.peakBytes, p1)
    }

    func testShedStepsRunInOrderAndStopUnderBudget() {
        let mm = MemoryManager()
        mm.budget = 100
        var value: UInt64 = 500
        mm.footprintProvider = { value }
        var order: [String] = []
        mm.registerShedStep(.reduceCaches, name: "c") { order.append("c"); value = 50 }
        mm.registerShedStep(.releaseImages, name: "i") { order.append("i") }
        mm.registerShedStep(.suspendIndexing, name: "x") { order.append("x") }
        mm.shed(upTo: .freeInactiveModules, reason: "test", stopWhenUnderBudget: true)
        XCTAssertEqual(order, ["i", "c"])
    }

    func testCacheTrimRespectsLimit() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString)")
        let cache = CacheManager(directory: dir)
        for i in 0..<10 { try Data(count: 1000).write(to: dir.appendingPathComponent("f\(i).jpg")) }
        cache.trimDisk(to: 3500)
        XCTAssertLessThanOrEqual(cache.diskSize(), 3500)
        try? FileManager.default.removeItem(at: dir)
    }
}
