import AppKit
import SwiftUI
import NotesCore

struct NoteEditorView: View {
    @ObservedObject var session: NotesEditorSession
    let workspace: NotesWorkspace
    var expand: () -> Void
    @AppStorage("notesFontSize") private var configuredFont = 23.0
    @State private var heights: [UUID: CGFloat] = [:]
    @State private var preview: NoteAttachment?
    @ObservedObject private var images = NotesImageCache.shared
    private var fontSize: Double { configuredFont >= 14 ? configuredFont : 23 }
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 30).frame(height: 64)
            VStack(spacing: 0) {
                NotesEditorScroll {
                    VStack(alignment: .leading, spacing: 14) {
                        NotesTitleTextField(session: session).frame(height: 48).padding(.bottom, 2)
                        ForEach(session.note.blocks) { block in blockView(block) }
                        if session.note.blocks.allSatisfy({ $0.kind != .paragraph }) {
                            Button { session.addBlock(.paragraph) } label: { Label("继续写一点", systemImage: "text.cursor").font(.system(size: 13)) }.buttonStyle(NotesPressStyle()).notesTooltip("添加正文段落").foregroundStyle(NotesTheme.muted).padding(.top, 12)
                        }
                        if session.note.attachments.isEmpty && session.note.blocks.allSatisfy({ $0.text.isEmpty }) {
                            Button { session.chooseAttachment(imagesOnly: true) } label: { Label("添加或拖入图片", systemImage: "photo.badge.plus").font(.system(size: 14)).padding(.vertical, 16) }.buttonStyle(NotesPressStyle()).notesTooltip("添加图片，也可以直接拖入").foregroundStyle(NotesTheme.muted)
                        }
                        if let failure = session.attachmentFailure {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.circle")
                                Text(failure).textSelection(.enabled)
                                Spacer(minLength: 0)
                                if let label = session.attachmentRetryLabel { Button(label) { session.retryAttachments() } }
                            }.font(.system(size: 12)).foregroundStyle(NotesTheme.danger).padding(12).background(NotesTheme.danger.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }
                        Spacer(minLength: 12)
                    }.padding(.horizontal, 34).padding(.top, 24).padding(.bottom, 28).frame(maxWidth: .infinity, alignment: .leading)

                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                toolbar.padding(.horizontal, 26).frame(height: 52)
                if let failure = session.failure {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.circle")
                        VStack(alignment: .leading, spacing: 3) {
                            Text("更改还没有保存，内容仍在此窗口中").fontWeight(.medium)
                            Text(failure).font(.system(size: 11)).textSelection(.enabled)
                        }
                        Spacer(minLength: 0)
                        Button("重试") { retry() }.notesTooltip("重新保存便笺").buttonStyle(NotesPressStyle())
                        Button("复制备份") { session.copyBackup() }.notesTooltip("复制当前内容，保留一份备份").buttonStyle(NotesPressStyle())
                    }.font(.system(size: 12)).foregroundStyle(NotesTheme.danger).padding(14).background(NotesTheme.danger.opacity(0.08))
                }
            }.background {
                RoundedRectangle(cornerRadius: 24).fill(.white.opacity(0.08))
            }.clipShape(RoundedRectangle(cornerRadius: 24)).padding(.horizontal, 18).padding(.bottom, 16)
        }.background { NotesEditorPaper(paper: session.note.effectiveEditorPaper) }
            .foregroundStyle(NotesTheme.text).clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .onDrop(of: [.fileURL, .image], isTargeted: nil, perform: drop)
            .sheet(item: $preview) { attachment in imagePreview(attachment) }
            .onReceive(session.store.$saveState) { state in if case .failed(let reason) = state { session.failure = reason } }
    }
    private var header: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                NotesWindowDragRegion()
                HStack(spacing: 13) {
                    Image(systemName: "doc.text").foregroundStyle(NotesTheme.accent).font(.system(size: 21))
                    Text("图文便笺").font(.system(size: 15, weight: .medium)).foregroundStyle(NotesTheme.muted)
                    Text(session.failure != nil ? "保存失败" : (session.dirty ? "正在保存…" : "已保存"))
                        .font(.system(size: 10)).foregroundStyle(session.failure == nil ? NotesTheme.muted : NotesTheme.danger)
                        .notesTooltip(saveLabel).accessibilityLabel(saveLabel)
                    Spacer()
                }.allowsHitTesting(false)
            }
            NotesIconButton(symbol: session.note.pinned ? "pin.fill" : "pin", label: session.note.pinned ? "取消窗口置顶" : "窗口置顶", selected: session.note.pinned) { session.togglePin() }
            NotesIconButton(symbol: "arrow.up.left.and.arrow.down.right", label: "展开或恢复窗口", action: expand)
            NotesIconButton(symbol: "arrow.up.to.line", label: session.note.onLine ? "收回挂绳，保留正文与附件 · Esc" : "收起到便笺库，保留草稿 · Esc") { workspace.closeEditor(session.note.id) }
            NotesMenuButton("更多操作", alignment: .trailing, menu: editorMenu) {
                Image(systemName: "ellipsis").font(.system(size: 18)).frame(width: 34, height: 34).foregroundStyle(NotesTheme.muted)
            }.fixedSize()
        }
    }
    private func editorMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("复制内容") { workspace.copy(session.note.id) }.notesSymbol("doc.on.doc"))
        menu.addItem(ClosureMenuItem("制作副本") { workspace.duplicate(session.note.id) }.notesSymbol("plus.square.on.square"))
        menu.addItem(ClosureMenuItem("导出 Markdown 及附件…") { workspace.export(session.note.id) }.notesSymbol("square.and.arrow.up"))
        menu.addItem(.separator())
        if session.note.onLine {
            menu.addItem(ClosureMenuItem("从绳上取下") { _ = workspace.takeOff(session.note.id) }.notesSymbol("arrow.down.to.line"))
        } else {
            menu.addItem(ClosureMenuItem("挂上去") { workspace.hang(session.note.id, hide: true) }.notesSymbol("arrow.up.to.line"))
        }
        let trash = ClosureMenuItem("移到最近删除…") { workspace.requestTrash(session.note.id) }.notesSymbol("trash")
        trash.notesDestructive = true
        menu.addItem(trash)
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("全部便笺") { workspace.showLibrary() }.notesSymbol("square.grid.2x2"))
        menu.addItem(ClosureMenuItem("偏好设置…") { workspace.showSettings() }.notesSymbol("gearshape"))
        return menu
    }
    @ViewBuilder private func blockView(_ block: NoteBlock) -> some View {
        switch block.kind {
        case .paragraph, .checklist:
            HStack(alignment: .top, spacing: 12) {
                if block.kind == .checklist {
                    Toggle("完成待办", isOn: Binding(get: { block.isChecked }, set: { _ in session.toggle(block.id) }))
                        .toggleStyle(.checkbox).labelsHidden().controlSize(.large).tint(NotesTheme.accent).padding(.top, 9)
                        .accessibilityLabel(block.text.isEmpty ? "待办事项" : block.text)
                        .animation(NotesMotion.quick, value: block.isChecked).notesTooltip(block.isChecked ? "标记为未完成" : "标记为已完成")
                }
                RichNoteTextView(block: block, session: session, fontSize: fontSize) { height in
                    if abs((heights[block.id] ?? 0) - height) > 1 { heights[block.id] = height }
                }.frame(minHeight: max(fontSize * 1.7, heights[block.id] ?? 40))
            }.id(block.id)
        case .image, .file:
            if let id = block.attachmentID, let attachment = session.note.attachments.first(where: { $0.id == id }) {
                attachmentView(attachment)
            } else {
                Label("附件记录缺失，请复制备份后重试", systemImage: "exclamationmark.triangle").foregroundStyle(NotesTheme.danger).font(.system(size: 13))
            }
        }
    }
    private func attachmentView(_ attachment: NoteAttachment) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if attachment.kind == .image {
                Button {
                    if let url = try? session.localURL(for: attachment), images.hasFailed(url) { images.retry(url) }
                    else { preview = attachment }
                } label: {
                    if let result = attachmentImage(attachment) {
                        Image(nsImage: result).resizable().scaledToFit().frame(maxWidth: 380, maxHeight: 220, alignment: .leading).clipShape(RoundedRectangle(cornerRadius: 15))
                    } else {
                        VStack(spacing: 10) {
                            if let url = try? session.localURL(for: attachment), images.hasFailed(url) {
                                Image(systemName: "photo.badge.exclamationmark")
                                Text("图片暂时无法读取，点击重试").font(.system(size: 12))
                            } else {
                                ProgressView().controlSize(.small)
                                Text("正在读取图片…").font(.system(size: 12))
                            }
                        }.foregroundStyle(NotesTheme.muted).frame(width: 380, height: 220)
                            .background(NotesTheme.muted.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                    }
                }.buttonStyle(NotesPressStyle()).accessibilityLabel("放大图片：" + attachment.name).notesTooltip("放大图片：" + attachment.name)
                    .notesContextMenu { attachmentMenu(attachment) }
                    .overlay(alignment: .bottomTrailing) {
                        NotesMenuButton("图片更多操作：" + attachment.name, alignment: .trailing, menu: { attachmentMenu(attachment) }) {
                            Image(systemName: "ellipsis").font(.system(size: 12, weight: .semibold)).frame(width: 26, height: 24).background(NotesTheme.shell.opacity(0.94), in: RoundedRectangle(cornerRadius: 7))
                        }.fixedSize().padding(8)
                    }
            } else {
                Button { session.openAttachment(attachment) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: attachment.kind == .image ? "photo" : "doc.fill").font(.system(size: 25)).foregroundStyle(NotesTheme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(attachment.name).font(.system(size: 15, weight: .medium)).lineLimit(2)
                            Text(attachmentMetadata(attachment)).font(.system(size: 12)).foregroundStyle(NotesTheme.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right.square").foregroundStyle(NotesTheme.muted)
                    }.padding(15).frame(maxWidth: 470).background(NotesTheme.shell.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(NotesPressStyle()).accessibilityLabel("打开附件：" + attachment.name).notesTooltip("打开附件：" + attachment.name)
            }
            if attachment.kind == .file {
                HStack(spacing: 14) {
                    Button("打开") { session.openAttachment(attachment) }.notesTooltip("打开附件副本")
                    Button("导出…") { session.exportAttachment(attachment) }.notesTooltip("导出附件副本")
                    Button("移除") { session.removeAttachment(attachment) }.notesTooltip("从便笺中移除附件").foregroundStyle(NotesTheme.danger)
                }.font(.system(size: 11)).buttonStyle(NotesPressStyle())
            }
        }.padding(.vertical, 3)
    }
    private func attachmentMenu(_ attachment: NoteAttachment) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("打开图片") { session.openAttachment(attachment) }.notesSymbol("arrow.up.forward.app"))
        menu.addItem(ClosureMenuItem("导出图片…") { session.exportAttachment(attachment) }.notesSymbol("square.and.arrow.up"))
        menu.addItem(.separator())
        let remove = ClosureMenuItem("移除图片") { session.removeAttachment(attachment) }.notesSymbol("trash")
        remove.notesDestructive = true
        menu.addItem(remove)
        return menu
    }
    private var toolbar: some View {
        HStack(spacing: 18) {
            HStack(spacing: 4) {
                NotesMenuButton("文字格式 · 粗体 / 斜体 / 下划线", menu: formatMenu) {
                    Text("Aa").font(.system(size: 15)).frame(width: 34, height: 34).foregroundStyle(NotesTheme.muted)
                }.fixedSize()
                NotesIconButton(symbol: "checkmark.square", label: "添加待办") { session.addBlock(.checklist) }
                NotesIconButton(symbol: "photo", label: "添加图片") { session.chooseAttachment(imagesOnly: true) }
                NotesIconButton(symbol: "paperclip", label: "添加附件") { session.chooseAttachment(imagesOnly: false) }
            }
            Spacer(minLength: 14)
            HStack(spacing: 4) {
                NotesIconButton(symbol: "arrow.uturn.backward", label: session.undoManager.canUndo ? "撤销 · ⌘Z" : "暂无可撤销的更改 · ⌘Z") { session.undo() }
                    .disabled(!session.undoManager.canUndo).opacity(session.undoManager.canUndo ? 1 : 0.45)
                NotesIconButton(symbol: "arrow.uturn.forward", label: session.undoManager.canRedo ? "重做 · ⇧⌘Z" : "暂无可重做的更改 · ⇧⌘Z") { session.redo() }
                    .disabled(!session.undoManager.canRedo).opacity(session.undoManager.canRedo ? 1 : 0.45)
                NotesPaperButton(session: session).padding(.leading, 8)
            }
        }.accessibilityElement(children: .contain).accessibilityLabel("便笺底部工具区")
    }
    private func formatMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("粗体", key: "b") { session.format(.bold) }.notesSymbol("bold"))
        menu.addItem(ClosureMenuItem("斜体", key: "i") { session.format(.italic) }.notesSymbol("italic"))
        menu.addItem(ClosureMenuItem("下划线", key: "u") { session.format(.underline) }.notesSymbol("underline"))
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("项目列表") { session.format(.bullets) }.notesSymbol("list.bullet"))
        return menu
    }
    private var saveLabel: String { session.failure != nil ? "保存失败 · 可在下方重试" : (session.dirty ? "正在保存…" : "已自动保存到本机") }
    private func retry() { do { try session.commit() } catch { session.failure = error.localizedDescription } }
    private func attachmentImage(_ attachment: NoteAttachment) -> NSImage? {
        do { return images.image(at: try session.localURL(for: attachment)) } catch { return nil }
    }
    private func attachmentMetadata(_ attachment: NoteAttachment) -> String {
        let ext = URL(fileURLWithPath: attachment.name).pathExtension.uppercased()
        return (ext.isEmpty ? "文件" : ext) + " · " + ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file)
    }
    private func imagePreview(_ attachment: NoteAttachment) -> some View {
        VStack(spacing: 16) {
            HStack { Text(attachment.name).font(.headline); Spacer(); Button("完成") { preview = nil }.keyboardShortcut(.cancelAction).notesTooltip("关闭图片预览 · Esc") }
            if let image = attachmentImage(attachment) { Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity) }
            else { Label("图片无法读取，可尝试打开或导出附件", systemImage: "exclamationmark.circle") }
            HStack { Button("打开原尺寸副本") { session.openAttachment(attachment) }.notesTooltip("打开原尺寸附件副本"); Button("导出…") { session.exportAttachment(attachment) }.notesTooltip("导出附件副本"); Spacer() }
        }.padding(24).frame(minWidth: 500, idealWidth: 760, minHeight: 350, idealHeight: 560).background(NotesTheme.shell)
    }
    private func drop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                accepted = true
                _ = provider.loadObject(ofClass: NSURL.self) { object, error in
                    DispatchQueue.main.async {
                        if let error { session.reportAttachmentFailure(error.localizedDescription) }
                        else if let url = object as? URL { session.importURLs([url]) }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                accepted = true
                _ = provider.loadObject(ofClass: NSImage.self) { object, error in DispatchQueue.main.async { if let image = object as? NSImage { session.pasteImage(image) } else if let error { session.reportAttachmentFailure(error.localizedDescription) } } }
            }
        }
        return accepted
    }
}
