import AppKit
import XCTest
@testable import Tendedero

final class NotesImageCacheTests: XCTestCase {
    @MainActor func testSlowAttachmentReadDoesNotBlockUIAndLoadsOnlyOnce() async throws {
        let image = NSImage(size: NSSize(width: 40, height: 30))
        let calls = LockedReads()
        let cache = NotesImageCache { _ in
            calls.record(main: Thread.isMainThread)
            Thread.sleep(forTimeInterval: 0.2)
            return image
        }
        let url = URL(fileURLWithPath: "/fixture/slow-provider.png")
        let start = ProcessInfo.processInfo.systemUptime
        XCTAssertNil(cache.image(at: url), "The UI should return a loading state immediately")
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 0.1, "A slow file provider must not hold the main actor")
        _ = cache.image(at: url)
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertTrue(cache.image(at: url) === image)
        XCTAssertEqual(calls.values.count, 1, "Typing and color changes must reuse a decoded attachment")
        XCTAssertEqual(calls.values, [false], "Read and decode attachments outside the main thread")
    }
    @MainActor func testUnavailableImageStopsRetryingUntilUserRequestsRetry() async throws {
        let calls = LockedReads()
        let image = NSImage(size: NSSize(width: 20, height: 20))
        let cache = NotesImageCache { _ in
            calls.record(main: Thread.isMainThread)
            return calls.values.count == 1 ? nil : image
        }
        let url = URL(fileURLWithPath: "/fixture/retry.png")
        XCTAssertNil(cache.image(at: url))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(cache.hasFailed(url))
        for _ in 0..<5 { XCTAssertNil(cache.image(at: url)) }
        XCTAssertEqual(calls.values.count, 1)
        cache.retry(url)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(cache.image(at: url) === image)
        XCTAssertFalse(cache.hasFailed(url))
        XCTAssertEqual(calls.values, [false, false])
    }

}
private final class LockedReads: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Bool] = []
    func record(main: Bool) { lock.lock(); recorded.append(main); lock.unlock() }
    var values: [Bool] { lock.lock(); defer { lock.unlock() }; return recorded }
}
