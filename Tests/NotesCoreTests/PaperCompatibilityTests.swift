import XCTest
@testable import NotesCore

final class PaperCompatibilityTests: XCTestCase {
    func testSixPaperOptionsKeepExistingSerializedValues() throws {
        XCTAssertEqual(Set(NotePaper.allCases.map(\.rawValue)), Set(["plain", "blue", "lavender", "rose", "warm", "gray"]))
        for value in ["plain", "blue", "lavender", "warm", "gray"] {
            XCTAssertEqual(try JSONDecoder().decode(NotePaper.self, from: Data("\"\(value)\"".utf8)).rawValue, value)
        }
    }
    func testEditorPaperRoundTripDoesNotChangeLegacyThumbnailPaper() throws {
        let original = NoteDocument(title: "old note", paper: .lavender)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object["editorPaper"] = "rose"
        let decoded = try JSONDecoder().decode(NoteDocument.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.paper, .lavender)
        let roundTrip = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
        XCTAssertEqual(roundTrip["editorPaper"] as? String, "rose")
    }
    @MainActor func testEditorPaperSurvivesStoreRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paper-compatibility-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try NotesStore(directory: root)
        let original = try store.create(paper: .gray)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object["editorPaper"] = "warm"
        let edited = try JSONDecoder().decode(NoteDocument.self, from: JSONSerialization.data(withJSONObject: object))
        try store.update(edited)
        let reopened = try XCTUnwrap(NotesStore(directory: root).document(id: original.id))
        let persisted = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(reopened)) as? [String: Any])
        XCTAssertEqual(reopened.paper, .gray)
        XCTAssertEqual(persisted["editorPaper"] as? String, "warm")
    }
}
