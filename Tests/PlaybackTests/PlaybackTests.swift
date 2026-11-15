import XCTest
@testable import MediaBox

func makeItems(_ n: Int) -> [MediaItem] {
    (0..<n).map { i in
        let loc = Locator(rootID: "app", path: "t\(i).mp3")
        return MediaItem(id: MediaItem.makeID(loc), locator: loc, kind: .audio, title: "T\(i)", artist: nil, album: nil,
                         duration: 100 + Double(i), fileSize: Int64(1000 + i), modified: nil, addedAt: Date())
    }
}

final class PlaybackTests: XCTestCase {
    func testSequentialAdvanceAndEnd() {
        var q = PlaybackQueue()
        q.set(items: makeItems(3), startIndex: 0, shuffle: false)
        XCTAssertEqual(q.current?.title, "T0")
        XCTAssertEqual(q.advance(auto: true)?.title, "T1")
        XCTAssertEqual(q.advance(auto: true)?.title, "T2")
        XCTAssertTrue(q.wouldEndAfterCurrent)
        XCTAssertNil(q.advance(auto: true))
    }

    func testRepeatAllWraps() {
        var q = PlaybackQueue()
        q.set(items: makeItems(2), startIndex: 1, shuffle: false)
        q.repeatMode = .all
        XCTAssertEqual(q.advance(auto: true)?.title, "T0")
    }

    func testRepeatOneOnlyOnAuto() {
        var q = PlaybackQueue()
        q.set(items: makeItems(3), startIndex: 0, shuffle: false)
        q.repeatMode = .one
        XCTAssertEqual(q.advance(auto: true)?.title, "T0")
        XCTAssertEqual(q.advance(auto: false)?.title, "T1")
    }

    func testShuffleKeepsCurrentFirstAndAllItems() {
        var q = PlaybackQueue()
        q.set(items: makeItems(20), startIndex: 5, shuffle: true)
        XCTAssertEqual(q.current?.title, "T5")
        XCTAssertEqual(Set(q.order).count, 20)
    }

    func testBackStopsAtStart() {
        var q = PlaybackQueue()
        q.set(items: makeItems(2), startIndex: 0, shuffle: false)
        XCTAssertNil(q.back())
    }

    func testSleepFireDates() {
        let now = Date()
        XCTAssertEqual(SleepTimer.fireDate(for: .duration(600), now: now), now.addingTimeInterval(600))
        let past = now.addingTimeInterval(-3600)
        let next = SleepTimer.fireDate(for: .atTime(past), now: now)!
        XCTAssertGreaterThan(next, now)
        XCTAssertNil(SleepTimer.fireDate(for: .afterTrack, now: now))
    }

    func testEQPresetsHaveTenBands() {
        for p in EQPreset.allCases { XCTAssertEqual(p.gains.count, 10) }
    }
}
