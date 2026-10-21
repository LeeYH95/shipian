import AppKit
import SwiftUI
import XCTest
@testable import Tendedero

final class LineControlTests: XCTestCase {
    @MainActor func testPaperLibraryRetainsNativePressAndHitTarget() throws {
        _ = NSApplication.shared
        let line = Line(restoring: false, gusts: false)
        var opened = 0
        line.onShowNotes = { opened += 1 }
        let host = NSHostingView(rootView: LineControl(line: line, isNew: false))
        host.frame = NSRect(x: 0, y: 0, width: 40, height: LineControl.hangingHeight)
        host.layoutSubtreeIfNeeded()
        let button = try XCTUnwrap(buttons(in: host).first)
        XCTAssertEqual(button.accessibilityLabel(), "全部便笺")
        XCTAssertEqual(button.accessibilityHelp(), "全部便笺")
        XCTAssertNil(button.toolTip, "Use the immediate custom tooltip rather than the system tooltip")
        XCTAssertEqual(button.frame.size, LineControl.targetSize)
        XCTAssertTrue(button.hitTest(NSPoint(x: button.bounds.midX, y: button.bounds.midY)) === button,
                      "The paper artwork must pass clicks to its native button")
        XCTAssertTrue(button.accessibilityPerformPress())
        XCTAssertEqual(opened, 1)
    }

    @MainActor func testPaperNewEntryPreservesAllTemplateActions() {
        _ = NSApplication.shared
        let line = Line(restoring: false, gusts: false)
        var created: [String] = []
        line.onNewNote = { created.append($0) }
        let menu = LineControl.templateMenu(for: line)
        XCTAssertEqual(menu.items.map(\.title), ["文字便笺", "待办清单", "图文便笺"])
        for item in menu.items { NotesMenuPresenter.dispatch(item) }
        XCTAssertEqual(created, ["text", "checklist", "image"])
    }

    @MainActor private func buttons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }
}
