import AppKit
import XCTest
@testable import Tendedero

final class LineStartupTests: XCTestCase {
    @MainActor func testSlowRestoredScreenshotsKeepMainActorResponsiveAndPreserveCapacity() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let urls = ["first.png", "second.png"].map { folder.appendingPathComponent($0) }
        for url in urls { try Data([0]).write(to: url) }
        let line = Line(restoring: false, gusts: false)
        line.maxItems = 1
        let reads = StartupReads()
        var responsive = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            responsive = true
        }
        await line.restorePhotos(paths: [urls[0].path, urls[0].path, folder.appendingPathComponent("missing.png").path, urls[1].path]) { _ in
            reads.record()
            Thread.sleep(forTimeInterval: 0.15)
            return NSImage(size: NSSize(width: 40, height: 30))
        }
        XCTAssertTrue(responsive, "A slow restored screenshot must not prevent UI events during startup")
        XCTAssertEqual(reads.onMainThread, [false, false])
        XCTAssertEqual(line.items.map(\.url), urls, "Skip duplicate and missing paths while preserving saved order")
        XCTAssertEqual(line.liveCount, 2, "Restoring a wide screen must not evict old screenshots")
    }
}

private final class StartupReads: @unchecked Sendable {
    private let lock = NSLock()
    private var reads: [Bool] = []
    func record() { lock.lock(); reads.append(Thread.isMainThread); lock.unlock() }
    var onMainThread: [Bool] { lock.lock(); defer { lock.unlock() }; return reads }
}
