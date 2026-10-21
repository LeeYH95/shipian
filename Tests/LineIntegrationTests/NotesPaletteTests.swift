import AppKit
import NotesCore
import XCTest
@testable import Tendedero

final class NotesPaletteTests: XCTestCase {
    @MainActor func testChoosingPaletteAppliesWithoutDismissAndKeyboardRestoresEditorFocus() throws {
        _ = NSApplication.shared
        let window = NotesWindow(contentRect: NSRect(x: 120, y: 120, width: 700, height: 500), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        let text = NSTextView(frame: NSRect(x: 20, y: 100, width: 500, height: 300))
        let anchor = NSView(frame: NSRect(x: 600, y: 20, width: 34, height: 34))
        content.addSubview(text); content.addSubview(anchor); window.contentView = content
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(text)
        let presenter = NotesMenuPresenter()
        defer { presenter.dismiss(animated: false); window.orderOut(nil) }
        var selected: [NotePaper] = []
        let menu = NotesPaperMenu(selected: .blue) { selected.append($0) }
        presenter.show(menu, from: anchor, alignment: .trailing)
        XCTAssertEqual(presenter.navigator?.selected, 1)
        presenter.choose(3)
        XCTAssertEqual(selected, [.rose])
        XCTAssertEqual(menu.selectedPaper, .rose)
        XCTAssertTrue(presenter.isPresented, "Keep the palette open for comparing paper colors")
        XCTAssertEqual(menu.items.filter { $0.state == .on }.map(\.title), [NotePaper.rose.chineseName])
        func key(_ code: UInt16) throws {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: presenter.panel?.windowNumber ?? 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
            XCTAssertNil(presenter.handleKey(event))
        }
        try key(115) // Home
        try key(125) // Down one grid row
        XCTAssertEqual(presenter.navigator?.selected, 3)
        try key(124)
        try key(36)
        XCTAssertEqual(selected, [.rose, .warm])
        XCTAssertTrue(presenter.isPresented)
        try key(53)
        XCTAssertFalse(presenter.isPresented)
        XCTAssertTrue(window.firstResponder === text)
        XCTAssertTrue(window.isVisible, "Esc dismisses the palette, not the note")
    }

    @MainActor func testPaletteAndActionMenuAreMutuallyExclusive() {
        _ = NSApplication.shared
        let window = NotesWindow(contentRect: NSRect(x: 100, y: 100, width: 700, height: 500), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 34, height: 34))
        window.contentView = anchor; window.orderFront(nil)
        let presenter = NotesMenuPresenter()
        defer { presenter.dismiss(animated: false); window.orderOut(nil) }
        presenter.show(NotesPaperMenu(selected: .plain) { _ in }, from: anchor)
        let firstPanel = presenter.panel
        let menu = NSMenu(); menu.addItem(ClosureMenuItem("粗体") {})
        presenter.show(menu, from: anchor)
        XCTAssertFalse(firstPanel?.isVisible ?? true)
        XCTAssertTrue(presenter.navigator?.menu === menu)
        XCTAssertTrue(presenter.isPresented)
    }

    func testTooltipStaysWithinSmallOrNegativeCoordinateDisplay() {
        let screen = NSRect(x: -1000, y: -400, width: 1000, height: 700)
        let frame = NotesTooltipGeometry.frame(anchor: NSRect(x: -20, y: -390, width: 34, height: 34), size: NSSize(width: 280, height: 32), visible: screen)
        XCTAssertTrue(screen.insetBy(dx: 8, dy: 8).contains(frame))
        XCTAssertGreaterThan(frame.minY, -356)
    }
}
