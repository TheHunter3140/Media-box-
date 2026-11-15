import XCTest
@testable import MediaBox

final class ServiceTests: XCTestCase {
    func testRouterRecognizesAllServices() {
        let cases: [(String, MediaService)] = [
            ("https://www.youtube.com/watch?v=x", .youtube), ("https://youtu.be/x", .youtube),
            ("https://soundcloud.com/a/b", .soundcloud), ("https://open.spotify.com/track/1", .spotify),
            ("https://vimeo.com/12345", .vimeo), ("https://www.dailymotion.com/video/x", .dailymotion),
            ("https://www.tiktok.com/@a/video/1", .tiktok), ("https://www.twitch.tv/abc", .twitch)
        ]
        for (u, s) in cases { XCTAssertEqual(ServiceRouter.service(for: URL(string: u)!), s, u) }
        XCTAssertNil(ServiceRouter.service(for: URL(string: "https://example.com/x.mp3")!))
        XCTAssertNil(ServiceRouter.service(for: URL(string: "https://notyoutube.com")!))
    }

    func testDownloadPolicies() {
        for s in MediaService.allCases {
            switch s {
            case .soundcloud, .vimeo: XCTAssertTrue(s.supportsAPIDownload)
            default: XCTAssertFalse(s.supportsAPIDownload, s.name)
            }
        }
    }

    func testProtectedPlatformsAreRefused() {
        for s in [MediaService.youtube, .spotify, .tiktok, .twitch, .dailymotion] {
            if case .refused = SourceAdapters.resolve(s.homeURL) {} else { XCTFail("\(s.name) doit être refusé") }
        }
    }

    func testAppearanceSchemes() {
        XCTAssertNil(Appearance.system.scheme)
        XCTAssertEqual(Appearance.dark.scheme, .dark)
        XCTAssertEqual(Appearance.light.scheme, .light)
    }
}
