import Foundation
import XCTest
@testable import NotesCore

final class AsyncStoreTests: XCTestCase {
    @MainActor func testOpeningSlowStoreKeepsMainActorResponsiveAndPreservesDocuments() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LineNotes-async-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try NotesStore(directory: root)
        var note = try original.create()
        note.title = "后台加载验收"; note.editorPaper = .rose
        try original.update(note)
        let expected = original.documents
        let reads = StoreReadProbe()
        var mainActorRan = false
        let pulse = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            mainActorRan = true
        }
        let opened = try await NotesStore.open(directory: root) { url in
            reads.record(Thread.isMainThread)
            Thread.sleep(forTimeInterval: 0.2)
            return try Data(contentsOf: url)
        }
        XCTAssertEqual(reads.values, [false], "All startup store I/O must run outside the main thread")
        XCTAssertTrue(mainActorRan, "The UI event loop must run while the store waits for its file provider")
        XCTAssertEqual(opened.documents, expected)
        _ = await pulse.value
    }
}
private final class StoreReadProbe: @unchecked Sendable {
    private let lock = NSLock(); private var reads: [Bool] = []
    func record(_ main: Bool) { lock.lock(); reads.append(main); lock.unlock() }
    var values: [Bool] { lock.lock(); defer { lock.unlock() }; return reads }
}
