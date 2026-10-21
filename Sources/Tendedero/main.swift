import AppKit

MainActor.assumeIsolated {
    LaunchTrace.mark("process-start")
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
