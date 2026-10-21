import AppKit
import SwiftUI
import NotesCore

/// A menu action model with a palette surface. Keeping it in the existing
/// presenter shares click-away, IME protection and source responder restoration.
@MainActor final class NotesPaperMenu: NSMenu {
    let papers = NotePaper.allCases
    private(set) var selectedPaper: NotePaper
    private let selectPaper: (NotePaper) -> Void
    init(selected: NotePaper, select: @escaping (NotePaper) -> Void) {
        selectedPaper = selected; selectPaper = select
        super.init(title: "便笺背景")
        for paper in papers {
            let item = ClosureMenuItem(paper.chineseName) { [weak self] in self?.select(paper) }
            item.state = paper == selected ? .on : .off
            addItem(item)
        }
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    private func select(_ paper: NotePaper) {
        selectedPaper = paper
        for (index, item) in items.enumerated() { item.state = papers[index] == paper ? .on : .off }
        selectPaper(paper)
    }
}

struct NotesPaperPalette: View {
    @ObservedObject var navigator: NotesMenuNavigator
    let menu: NotesPaperMenu
    let presenter: NotesMenuPresenter
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("便笺背景").font(.system(size: 12, weight: .medium)).padding(.horizontal, 6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(menu.papers.enumerated()), id: \.element) { index, paper in
                    let active = menu.selectedPaper == paper
                    Button { presenter.choose(index) } label: {
                        VStack(spacing: 9) {
                            Circle().fill(NotesTheme.editorSwatch(paper))
                                .overlay(Circle().stroke(NotesTheme.border, lineWidth: 0.8))
                                .frame(width: 24, height: 24)
                                .overlay { Circle().stroke(active ? NotesTheme.accent : .clear, lineWidth: 1.3).padding(-4) }
                            Text(paper.chineseName).font(.system(size: 10)).foregroundStyle(active ? NotesTheme.accent : NotesTheme.muted)
                        }.frame(maxWidth: .infinity).frame(height: 61)
                            .background(NotesTheme.accent.opacity(navigator.selected == index ? 0.065 : 0), in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(NotesPressStyle(hoverFill: false))
                        .accessibilityLabel("选择" + paper.chineseName + "背景")
                        .accessibilityValue(active ? "已选中" : "")
                        .accessibilityAddTraits(active ? [.isSelected] : [])
                        .onHover { if $0 { navigator.selected = index } }
                }
            }
        }.padding(14).foregroundStyle(NotesTheme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NotesTheme.shell, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(NotesTheme.border, lineWidth: 1) }
            .accessibilityElement(children: .contain).accessibilityLabel("便笺背景配色")
    }
}

struct NotesPaperButton: View {
    @ObservedObject var session: NotesEditorSession
    @State private var anchor: NSView?
    private var paper: NotePaper { session.note.effectiveEditorPaper }
    var body: some View {
        Button {
            guard let anchor else { return }
            NotesMenuPresenter.shared.toggle(NotesPaperMenu(selected: paper, select: session.setPaper), from: anchor, alignment: .trailing)
        } label: {
            Circle().fill(NotesTheme.editorSwatch(paper))
                .overlay(Circle().stroke(NotesTheme.muted, lineWidth: 0.8))
                .frame(width: 18, height: 18).frame(width: 34, height: 34).contentShape(Rectangle())
        }.buttonStyle(NotesPressStyle())
            .accessibilityLabel("更换便笺背景，当前：" + paper.chineseName)
            .notesTooltip("便笺背景：" + paper.chineseName + " · 点击更换")
            .background(NotesMenuAnchor { anchor = $0 })
    }
}
