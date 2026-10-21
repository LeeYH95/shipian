import AppKit
import SwiftUI
import NotesCore

struct NotesLibraryView: View {
    let workspace: NotesWorkspace
    @ObservedObject var store: NotesStore
    @State private var scope = NoteScope.all
    @State private var query = ""
    @State private var sortTitle = false
    @FocusState private var searching: Bool
    @Namespace private var tabSelection

    private struct Membership: Equatable {
        let id: UUID
        let deleted: Bool
        let onLine: Bool
    }
    private var membership: [Membership] {
        store.documents.map { Membership(id: $0.id, deleted: $0.deletedAt != nil, onLine: $0.onLine) }
    }
    private var notes: [NoteDocument] {
        let result = store.search(query, scope: scope)
        return sortTitle ? result.sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending } : result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 28) {
                    tabs.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    searchField.frame(width: 238)
                }
                VStack(alignment: .leading, spacing: 16) {
                    tabs
                    searchField.frame(maxWidth: .infinity)
                }
            }.padding(.horizontal, 34).padding(.bottom, 16)
            Rectangle().fill(NotesTheme.border).frame(height: 1)
            HStack {
                Text("\(notes.count) 条便笺").font(.system(size: 12)).foregroundStyle(NotesTheme.muted)
                Spacer()
                NotesMenuButton("排序", alignment: .trailing, menu: sortMenu) {
                    HStack(spacing: 7) {
                        Text(sortTitle ? "标题" : "最近编辑")
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }.font(.system(size: 12)).foregroundStyle(NotesTheme.muted).padding(.horizontal, 10).frame(height: 30)
                }.fixedSize()
            }.padding(.horizontal, 34).padding(.vertical, 10)
            Group {
                if notes.isEmpty { empty.frame(maxWidth: .infinity, maxHeight: .infinity).transition(.opacity) }
                else {
                    NotesEditorScroll {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 270, maximum: 360), spacing: 18)], alignment: .leading, spacing: 18) {
                            ForEach(notes) { note in
                                NotesLibraryCard(note: note, workspace: workspace, store: store)
                                    .transition(.opacity.combined(with: .offset(y: NotesMotion.reduced ? 0 : 4)))
                            }
                        }.padding(.horizontal, 34).padding(.top, 3).padding(.bottom, 30)
                    }.transition(.opacity)
                }
            }.animation(NotesMotion.standard, value: membership)
        }.foregroundStyle(NotesTheme.text).background(NotesTheme.shell).clipShape(RoundedRectangle(cornerRadius: 30))
            .onReceive(NotificationCenter.default.publisher(for: .notesFocusSearch)) { _ in searching = true }
            .background(Button("") { searching = true }.keyboardShortcut("f", modifiers: .command).hidden().accessibilityHidden(true))
    }
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("全部便笺").font(.system(size: 27, weight: .semibold))
                Text("挂在眼前，也收进记忆里。").font(.system(size: 13)).foregroundStyle(NotesTheme.muted)
            }
            Spacer(minLength: 20)
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 0) {
                    Button { workspace.newNote() } label: {
                        Label("新建便笺", systemImage: "plus").font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 15).frame(height: 40).contentShape(Rectangle())
                    }.buttonStyle(NotesPressStyle()).accessibilityLabel("新建便笺").notesTooltip("新建文字便笺")
                    Rectangle().fill(NotesTheme.onAccent.opacity(0.26)).frame(width: 1, height: 18)
                    NotesMenuButton("选择新建模板", alignment: .trailing, menu: newNoteMenu) {
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).frame(width: 34, height: 40)
                    }
                }.foregroundStyle(NotesTheme.onAccent).background(NotesTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)).fixedSize()
                NotesIconButton(symbol: "gearshape", label: "便笺偏好设置", size: 40) { workspace.showSettings() }
                NotesCloseWindowButton()
            }.fixedSize()
        }.padding(.horizontal, 34).padding(.top, 30).padding(.bottom, 24)
            .background(alignment: .top) { NotesWindowDragRegion().frame(height: 24) }
    }
    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(NoteScope.allCases, id: \.self) { item in
                Button { withAnimation(NotesMotion.selection) { scope = item } } label: {
                    HStack(spacing: 5) {
                        Text(title(item))
                        Text("\(store.search("", scope: item).count)").font(.system(size: 11)).monospacedDigit()
                    }.font(.system(size: 13, weight: scope == item ? .semibold : .regular))
                        .foregroundStyle(scope == item ? NotesTheme.accent : NotesTheme.muted)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(alignment: .bottom) {
                            if scope == item {
                                Capsule().fill(NotesTheme.accent).frame(height: 2)
                                    .matchedGeometryEffect(id: "scopeUnderline", in: tabSelection)
                                    .padding(.horizontal, 12)
                            }
                        }
                }.buttonStyle(NotesPressStyle()).accessibilityAddTraits(scope == item ? [.isSelected] : [])
                    .notesTooltip(scopeHelp(item))
            }
        }
    }
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").frame(width: 16).foregroundStyle(NotesTheme.muted)
            TextField("搜索标题或正文", text: $query).textFieldStyle(.plain).focused($searching).accessibilityLabel("搜索标题或正文").notesTextContextMenu()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(NotesTheme.muted).frame(width: 24, height: 26)
                }.buttonStyle(NotesPressStyle()).accessibilityLabel("清除搜索").notesTooltip("清除搜索")
            }
        }.font(.system(size: 13)).padding(.leading, 12).padding(.trailing, query.isEmpty ? 12 : 6).frame(height: 38)
            .background(NotesTheme.paper(.blue), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(searching ? NotesTheme.accent.opacity(0.55) : .clear, lineWidth: 1))
            .animation(NotesMotion.quick, value: searching)
    }
    private func newNoteMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("文字便笺") { workspace.newNote() }.notesSymbol("doc.text"))
        menu.addItem(ClosureMenuItem("待办清单") { workspace.newNote(template: .checklist) }.notesSymbol("checklist"))
        menu.addItem(ClosureMenuItem("图文便笺") { workspace.newNote(template: .image) }.notesSymbol("photo"))
        return menu
    }
    private func sortMenu() -> NSMenu {
        let menu = NSMenu()
        let recent = ClosureMenuItem("最近编辑") { withAnimation(NotesMotion.selection) { sortTitle = false } }
        recent.state = sortTitle ? .off : .on
        menu.addItem(recent)
        let title = ClosureMenuItem("标题") { withAnimation(NotesMotion.selection) { sortTitle = true } }
        title.state = sortTitle ? .on : .off
        menu.addItem(title)
        return menu
    }
    private func title(_ scope: NoteScope) -> String { switch scope { case .all: return "全部便笺"; case .onLine: return "挂绳上"; case .offLine: return "已取下"; case .trash: return "最近删除" } }
    private func scopeHelp(_ scope: NoteScope) -> String { switch scope { case .all: return "查看全部便笺"; case .onLine: return "只看挂绳上的便笺"; case .offLine: return "查看已取下的便笺"; case .trash: return "恢复或永久删除便笺" } }
    private var empty: some View {
        VStack(spacing: 16) {
            Image(systemName: query.isEmpty ? (scope == .trash ? "trash" : "doc.text") : "magnifyingglass").font(.system(size: 32, weight: .light)).foregroundStyle(NotesTheme.accent)
            Text(query.isEmpty ? (scope == .trash ? "最近删除里没有便笺" : "留下一点想法") : "没有找到相关便笺").font(.system(size: 21, weight: .semibold))
            Text(query.isEmpty ? (scope == .trash ? "移到这里的便笺可以恢复。" : "写一点 → 挂上去 → 随时找回") : "试试其他关键词，或开始一条新便笺。").font(.system(size: 14)).foregroundStyle(NotesTheme.muted)
            HStack(spacing: 16) {
                if !query.isEmpty { Button("清除搜索") { query = "" }.buttonStyle(NotesPressStyle()).notesTooltip("清除搜索，显示当前分类中的便笺") }
                if scope != .trash {
                    Button { workspace.newNote() } label: {
                        Text("新建便笺").font(.system(size: 13, weight: .medium)).padding(.horizontal, 18).frame(height: 36)
                            .foregroundStyle(NotesTheme.onAccent).background(NotesTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(NotesPressStyle()).notesTooltip("新建文字便笺")
                }
            }
        }.padding(40)
    }
}

private struct NotesLibraryCard: View {
    let note: NoteDocument
    let workspace: NotesWorkspace
    let store: NotesStore
    @State private var hovered = false
    @ObservedObject private var images = NotesImageCache.shared
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    @AppStorage("notesReduceMotion") private var appReduced = false
    private var reduced: Bool { systemReduced || appReduced }
    private var hasImage: Bool { note.attachments.contains { $0.kind == .image } }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if note.deletedAt == nil { workspace.open(note.id) }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 7) {
                        Image(systemName: note.blocks.contains(where: { $0.kind == .checklist }) ? "checklist" : "doc.text")
                        Text(note.deletedAt != nil ? "最近删除" : (note.onLine ? "挂绳上" : (note.draft ? "草稿" : "已取下")))
                        Spacer()
                        if note.pinned { Image(systemName: "pin.fill") }
                    }.font(.system(size: 11)).foregroundStyle(NotesTheme.muted)
                    Text(note.displayTitle).font(.system(size: 18, weight: .semibold)).lineLimit(2)
                    if let attachment = note.attachments.first(where: { $0.kind == .image }) {
                        Group {
                            if let image = image(attachment) { Image(nsImage: image).resizable().scaledToFill() }
                            else { RoundedRectangle(cornerRadius: 10).fill(NotesTheme.muted.opacity(0.05)).overlay(Image(systemName: "photo").foregroundStyle(NotesTheme.muted)) }
                        }.frame(height: 82).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(note.blocks.filter { $0.kind == .paragraph || $0.kind == .checklist }.prefix(hasImage ? 2 : 3))) { block in
                            HStack(alignment: .top, spacing: 5) {
                                if block.kind == .checklist { Image(systemName: block.isChecked ? "checkmark.square.fill" : "square").foregroundStyle(block.isChecked ? NotesTheme.accent : NotesTheme.muted) }
                                Text(block.text).lineLimit(hasImage ? 1 : 2)
                            }
                        }
                    }.font(.system(size: 13)).foregroundStyle(NotesTheme.muted)
                    Spacer(minLength: 0)
                }.padding(20).frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260, alignment: .topLeading).clipped().contentShape(Rectangle())
            }.buttonStyle(NotesPressStyle(hoverFill: false))
                .accessibilityLabel("\(note.displayTitle)，\(note.onLine ? "挂绳上" : (note.draft ? "草稿" : "已取下"))")
                .notesTooltip(note.deletedAt == nil ? "打开便笺：" + note.displayTitle : "请使用下方操作恢复这条便笺")
            HStack(spacing: 10) {
                Text(note.updatedAt, style: .date).font(.system(size: 11)).foregroundStyle(NotesTheme.muted)
                Spacer(minLength: 2)
                if note.deletedAt != nil {
                    Button("恢复") { workspace.restore(note.id) }.foregroundStyle(NotesTheme.accent).notesTooltip("恢复便笺")
                    Button { workspace.permanentlyDelete(note.id) } label: { Image(systemName: "trash.slash").frame(width: 26, height: 30) }.foregroundStyle(NotesTheme.danger).notesTooltip("永久删除").accessibilityLabel("永久删除：" + note.displayTitle)
                } else {
                    Button(note.onLine ? "取下" : "挂上") {
                        if note.onLine { _ = workspace.takeOff(note.id) } else { workspace.hang(note.id) }
                    }.foregroundStyle(NotesTheme.accent).notesTooltip(note.onLine ? "从挂绳取下，仍保留在便笺库" : "挂回晾衣绳")
                    NotesMenuButton("便笺更多操作", alignment: .trailing, menu: moreMenu) {
                        Image(systemName: "ellipsis").frame(width: 26, height: 30).foregroundStyle(NotesTheme.muted)
                    }.fixedSize()
                    Button { workspace.requestTrash(note.id) } label: { Image(systemName: "trash").frame(width: 26, height: 30) }.foregroundStyle(NotesTheme.muted).notesTooltip("移到最近删除").accessibilityLabel("移到最近删除：" + note.displayTitle)
                }
            }.font(.system(size: 12)).buttonStyle(NotesPressStyle())
                .padding(.horizontal, 15).padding(.bottom, 4).frame(height: 48)
        }.background(NotesTheme.paper(note.paper), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(hovered ? NotesTheme.accent.opacity(0.28) : NotesTheme.border, lineWidth: 1))
            .shadow(color: NotesTheme.accent.opacity(hovered ? 0.08 : 0), radius: hovered ? 10 : 4, x: 0, y: hovered ? 5 : 2)
            .offset(y: hovered && !reduced ? -2 : 0)
            .onHover { hovered = $0 }
            .animation(reduced ? nil : .easeOut(duration: 0.14), value: hovered)
    }
    private func moreMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("打开") { workspace.open(note.id) }.notesSymbol("arrow.up.forward.app"))
        menu.addItem(ClosureMenuItem("复制内容") { workspace.copy(note.id) }.notesSymbol("doc.on.doc"))
        menu.addItem(ClosureMenuItem("制作副本") { workspace.duplicate(note.id) }.notesSymbol("plus.square.on.square"))
        menu.addItem(ClosureMenuItem("导出 Markdown 及附件…") { workspace.export(note.id) }.notesSymbol("square.and.arrow.up"))
        return menu
    }
    private func image(_ attachment: NoteAttachment) -> NSImage? { do { return images.image(at: try store.url(for: attachment)) } catch { return nil } }
}

extension Notification.Name { static let notesFocusSearch = Notification.Name("LineNotes.focusSearch") }

struct NotesCloseWindowButton: View {
    var size: CGFloat = 40
    @State private var target = NotesCloseWindowReference()
    var body: some View {
        Button { target.window?.performClose(nil) } label: {
            Image(systemName: "xmark").font(.system(size: 16)).foregroundStyle(NotesTheme.muted).frame(width: size, height: size)
        }.buttonStyle(NotesPressStyle()).accessibilityLabel("关闭窗口").notesTooltip("关闭窗口")
            .background(NotesCloseWindowAnchor { target.window = $0 })
    }
}

private final class NotesCloseWindowReference {
    weak var window: NSWindow?
}

private struct NotesCloseWindowAnchor: NSViewRepresentable {
    let receive: (NSWindow?) -> Void
    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.receive = receive
        return view
    }
    func updateNSView(_ nsView: AnchorView, context: Context) {
        nsView.receive = receive
        receive(nsView.window)
    }
    final class AnchorView: NSView {
        var receive: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            receive?(window)
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
