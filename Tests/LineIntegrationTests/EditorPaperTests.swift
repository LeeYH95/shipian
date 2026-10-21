import AppKit
import XCTest
import NotesCore
@testable import Tendedero

final class EditorPaperTests: XCTestCase {
    @MainActor func testChangingEditorTintPreservesHangingAppearanceAndUndoHistory() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("editor-paper-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try NotesStore(directory: root)
        let session = NotesEditorSession(note: try store.create(paper: .lavender), store: store)
        session.undoManager.groupsByEvent = false
        session.undoManager.beginUndoGrouping(); session.setPaper(.blue); session.undoManager.endUndoGrouping()
        XCTAssertEqual(session.note.paper, .lavender, "Editor background must not recolor an existing hanging thumbnail")
        try session.commit()
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session.note)) as? [String: Any])
        XCTAssertEqual(saved["editorPaper"] as? String, "blue")
        session.undo(); XCTAssertEqual(session.note.paper, .lavender)
        session.redo(); XCTAssertEqual(session.note.paper, .lavender)
        let redone = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session.note)) as? [String: Any])
        XCTAssertEqual(redone["editorPaper"] as? String, "blue")
    }
}
