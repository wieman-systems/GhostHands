import XCTest
@testable import GhostHandsCore

final class YouTubeTests: XCTestCase {
    func testSupportedLinksAndTimestamp() {
        for url in ["https://youtube.com/watch?v=M7lc1UVf-VE", "https://youtu.be/M7lc1UVf-VE", "https://www.youtube.com/shorts/M7lc1UVf-VE", "https://www.youtube.com/embed/M7lc1UVf-VE"] {
            XCTAssertEqual(YouTubeLink(url)?.videoID,"M7lc1UVf-VE")
        }
        XCTAssertEqual(YouTubeLink("https://youtu.be/M7lc1UVf-VE?t=1m30s")?.startSeconds,90)
        XCTAssertEqual(YouTubeLink("youtube.com/watch?v=M7lc1UVf-VE&start=42")?.startSeconds,42)
    }
    func testRejectsLookalikeHostsCredentialsAndInjection() {
        for url in ["https://youtube.com.attacker.com/watch?v=M7lc1UVf-VE", "https://youtube.com@attacker.com/M7lc1UVf-VE", "https://person:password@youtube.com/watch?v=M7lc1UVf-VE", "javascript:alert(1)", "https://youtube.com/watch?v=hello", "https://youtube.com/watch?v=M7lc1UVf-VE%27", "https://youtube.com:9999/watch?v=M7lc1UVf-VE"] {
            XCTAssertNil(YouTubeLink(url),url)
        }
    }
    func testCanonicalEmbedIgnoresUntrustedQueryFields() {
        let link = YouTubeLink("https://youtube.com/watch?v=M7lc1UVf-VE&origin=https://attacker.com&autoplay=1")!
        XCTAssertEqual(link.embedURL.host,"www.youtube.com")
        XCTAssertFalse(link.embedURL.absoluteString.contains("attacker"))
        XCTAssertTrue(link.embedURL.absoluteString.contains("autoplay=0"))
    }
}
