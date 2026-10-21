import AppKit
import XCTest
@testable import Tendedero

final class NotesAppIconTests: XCTestCase {
    @MainActor func testExplicitAppearanceOverridesSystemAndAutomaticTracksSystem() {
        XCTAssertEqual(NotesAppIcon.resourceName(theme: "light", systemDark: true), "ShipianIconLight")
        XCTAssertEqual(NotesAppIcon.resourceName(theme: "dark", systemDark: false), "ShipianIconDark")
        XCTAssertEqual(NotesAppIcon.resourceName(theme: "system", systemDark: true), "ShipianIconDark")
        XCTAssertEqual(NotesAppIcon.resourceName(theme: "system", systemDark: false), "ShipianIconLight")
        XCTAssertEqual(NotesAppIcon.resourceName(theme: "old-or-unknown", systemDark: true), "ShipianIconDark")
    }
    @MainActor func testMissingDarkAssetFallsBackToLightAndMissingBrandKeepsOriginalIcon() {
        let light = NSImage(size: NSSize(width: 32, height: 32))
        var requested: [String] = []
        let image = NotesAppIcon.resolve(theme: "dark", systemDark: false) { name in
            requested.append(name)
            return name == "ShipianIconLight" ? light : nil
        }
        XCTAssertTrue(image === light)
        XCTAssertEqual(requested, ["ShipianIconDark", "ShipianIconLight"])
        XCTAssertNil(NotesAppIcon.resolve(theme: "light", systemDark: false) { _ in nil })
    }
}
