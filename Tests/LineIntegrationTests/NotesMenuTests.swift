import AppKit
import XCTest
@testable import Tendedero

final class NotesMenuTests: XCTestCase {
    @MainActor func testNavigationSkipsDisabledAndSeparatorsAndWraps() {
        _ = NSApplication.shared
        let menu = NSMenu()
        let disabled = ClosureMenuItem("不可用") {}
        disabled.isEnabled = false
        menu.addItem(disabled)
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("打开") {})
        menu.addItem(ClosureMenuItem("导出") {})
        let navigator = NotesMenuNavigator(menu)
        XCTAssertEqual(navigator.selected, 2)
        navigator.move(1)
        XCTAssertEqual(navigator.selected, 3)
        navigator.move(1)
        XCTAssertEqual(navigator.selected, 2)
        navigator.move(-1)
        XCTAssertEqual(navigator.selected, 3)
        XCTAssertNil(navigator.activate(0), "A disabled action cannot be invoked")
    }

    @MainActor func testNestedNavigationRetainsActionsAndBackSelection() {
        _ = NSApplication.shared
        var calls = 0
        let root = NSMenu(title: "设置")
        let child = NSMenu(title: "纸张")
        let action = ClosureMenuItem("浅蓝") { calls += 1 }
        action.state = .on
        child.addItem(action)
        let parent = NSMenuItem(title: "纸张", action: nil, keyEquivalent: "")
        parent.submenu = child
        root.addItem(parent)
        let navigator = NotesMenuNavigator(root)
        XCTAssertNil(navigator.activate(0))
        XCTAssertEqual(navigator.depth, 1)
        XCTAssertEqual(navigator.items.first?.state, .on)
        let selected = navigator.activate(0)
        XCTAssertTrue(selected === action)
        if let selected { NotesMenuPresenter.dispatch(selected) }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(navigator.back())
        XCTAssertEqual(navigator.depth, 0)
        XCTAssertEqual(navigator.selected, 0)
        XCTAssertFalse(navigator.back())
    }

    @MainActor func testMenuPlacementFlipsAboveToolbarAndClampsToScreen() {
        let screen = NSRect(x: -1440, y: 0, width: 1440, height: 900)
        let lowAnchor = NSRect(x: -80, y: 10, width: 36, height: 36)
        let frame = NotesMenuGeometry.frame(anchor: lowAnchor, size: NSSize(width: 280, height: 240), visible: screen, alignment: .trailing)
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX + 8)
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX - 8)
        XCTAssertGreaterThan(frame.minY, lowAnchor.maxY)
        let highAnchor = NSRect(x: -1420, y: 860, width: 36, height: 30)
        let below = NotesMenuGeometry.frame(anchor: highAnchor, size: NSSize(width: 280, height: 240), visible: screen, alignment: .leading)
        XCTAssertLessThan(below.maxY, highAnchor.minY)
    }

    @MainActor func testTypeAheadOnlyChoosesAvailableRows() {
        _ = NSApplication.shared
        let menu = NSMenu()
        let disabled = ClosureMenuItem("Export blocked") {}; disabled.isEnabled = false
        menu.addItem(disabled)
        menu.addItem(ClosureMenuItem("Open") {})
        menu.addItem(ClosureMenuItem("Export Markdown") {})
        let navigator = NotesMenuNavigator(menu)
        navigator.select(prefix: "ex")
        XCTAssertEqual(navigator.selected, 2)
        navigator.select(prefix: "no match")
        XCTAssertEqual(navigator.selected, 2)
    }

    @MainActor func testSelectedSettingGetsInitialKeyboardFocus() {
        _ = NSApplication.shared
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("18") {})
        let selected = ClosureMenuItem("23") {}; selected.state = .on; menu.addItem(selected)
        XCTAssertEqual(NotesMenuNavigator(menu).selected, 1)
    }

    @MainActor func testGroupedActionMenuStartsAtFirstActionRatherThanCheckedSetting() {
        _ = NSApplication.shared
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("新建") {})
        menu.addItem(.separator())
        let sound = ClosureMenuItem("声音") {}; sound.state = .on; menu.addItem(sound)
        XCTAssertEqual(NotesMenuNavigator(menu).selected, 0)
    }

    @MainActor func testContextHitTestingRejectsScrolledOutAttachment() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        let clip = NSClipView(frame: NSRect(x: 0, y: 80, width: 500, height: 240))
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 1000))
        root.addSubview(clip); clip.documentView = content
        let image = NSView(frame: NSRect(x: 20, y: 300, width: 300, height: 220))
        content.addSubview(image); clip.scroll(to: NSPoint(x: 0, y: 450))
        let clipped = NSPoint(x: 20, y: 40)
        XCTAssertTrue(image.bounds.contains(clipped), "The old bounds check wrongly accepted this point")
        XCTAssertFalse(NotesMenuGeometry.containsVisiblePoint(clipped, in: image))
        XCTAssertTrue(NotesMenuGeometry.containsVisiblePoint(NSPoint(x: 20, y: 200), in: image))
    }

    @MainActor func testRestoredWindowDestinationFitsCurrentScreen() {
        let window = NotesWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 500), styleMask: [.borderless], backing: .buffered, defer: false)
        window.minSize = NSSize(width: 650, height: 390)
        let oldDisplay = NSRect(x: 50000, y: -50000, width: 1000, height: 600)
        let result = NotesWorkspace.clampedFrame(oldDisplay, for: window)
        XCTAssertTrue(NSScreen.screens.contains { $0.visibleFrame.contains(result) })
    }
}
