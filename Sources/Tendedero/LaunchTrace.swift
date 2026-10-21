import AppKit

/// Opt-in launch instrumentation for local acceptance. No file is written
/// unless a report path is explicitly supplied by the test runner.
@MainActor enum LaunchTrace {
    private static let began = ProcessInfo.processInfo.systemUptime
    private static var events: [[String: Any]] = []
    private static var destination: URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--startup-report"), args.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: args[index + 1])
    }
    static func mark(_ phase: String) {
        guard let destination else { return }
        events.append(["phase": phase, "seconds": max(0, ProcessInfo.processInfo.systemUptime - began)])
        let record: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier, "events": events]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: destination, options: .atomic)
        }
    }
}
