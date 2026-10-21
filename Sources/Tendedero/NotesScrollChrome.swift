import SwiftUI

/// A local, transient position hint. SwiftUI's system indicator can remain
/// permanently visible under macOS's “Always” preference; this one never
/// changes that preference or covers the text's layout column.
struct NotesEditorScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var contentFrame = CGRect.zero
    @State private var showingHint = false
    @State private var hideTask: Task<Void, Never>?
    @State private var coordinateID = UUID()

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                content().background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: NotesScrollFrame.self,
                            value: geometry.frame(in: .named(coordinateID)))
                    }
                }
            }.scrollIndicators(.never)
                .coordinateSpace(name: coordinateID)
                .onPreferenceChange(NotesScrollFrame.self) { frame in
                    let moved = abs(frame.minY - contentFrame.minY) > 0.5
                    contentFrame = frame
                    guard moved else { return }
                    hideTask?.cancel()
                    showingHint = true
                    hideTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(650))
                        guard !Task.isCancelled else { return }
                        showingHint = false
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if contentFrame.height > viewport.size.height + 1 {
                        let track = max(0, viewport.size.height - 16)
                        let height = min(track, max(24, track * viewport.size.height / contentFrame.height))
                        let progress = min(1, max(0, -contentFrame.minY / (contentFrame.height - viewport.size.height)))
                        Capsule().fill(NotesTheme.muted.opacity(0.25))
                            .frame(width: 3, height: height)
                            .offset(x: -5, y: 8 + (track - height) * progress)
                            .opacity(showingHint ? 1 : 0)
                            .animation(NotesMotion.reduced ? nil : .easeOut(duration: 0.18), value: showingHint)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
        }.onDisappear { hideTask?.cancel() }
    }
}

private struct NotesScrollFrame: PreferenceKey {
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
