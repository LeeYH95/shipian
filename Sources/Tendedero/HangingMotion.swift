import AppKit

/// Screenshots and notes share PeggedView and CaptureFlight, including their
/// original spring constants. Accessibility only suppresses movement explicitly.
enum HangingMotion {
    static var reduced: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || UserDefaults.standard.bool(forKey: "notesReduceMotion")
    }
}
