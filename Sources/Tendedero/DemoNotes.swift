import AppKit
import NotesCore

@MainActor enum DemoNotes {
    static func seed(_ store: NotesStore) throws {
        // Seed only a genuinely new demo store, never recreate a user's deleted notes.
        let marker = store.directory.appendingPathComponent(".demo-seeded")
        guard !FileManager.default.fileExists(atPath: marker.path), store.documents.isEmpty else { return }
        var inspiration = try store.create(template: .image)
        inspiration.title = "把灵感留下来"
        inspiration.blocks = [NoteBlock(text: "看到喜欢的画面时，顺手记下为什么喜欢。")]
        try store.update(inspiration)
        if let gallery = Bundle.main.url(forResource: "DemoGallery", withExtension: "png") {
            _ = try store.importAttachment(from: gallery, to: inspiration.id)
        }
        inspiration = store.document(id: inspiration.id)!
        inspiration.blocks += [NoteBlock(kind: .checklist, text: "留下这张参考图", isChecked: true),
                               NoteBlock(kind: .checklist, text: "补充自己的想法")]
        try store.update(inspiration)
        try store.setOnLine(inspiration.id, true)
        var list = try store.create(template: .checklist, paper: .plain)
        list.title = "今天，留一点空白"
        list.blocks = [NoteBlock(kind: .checklist, text: "整理桌面上的灵感", isChecked: true),
                       NoteBlock(kind: .checklist, text: "把一个小想法做出来"),
                       NoteBlock(kind: .checklist, text: "去散步，不带任务")]
        try store.update(list)
        try store.setOnLine(list.id, true)
        var text = try store.create(template: .text, paper: .lavender)
        text.title = "慢慢想，也很好"
        text.blocks = [NoteBlock(text: "不用急着给每个想法下结论。先记下来，让它在这里待一会儿。")]
        try store.update(text)
        try store.setOnLine(text.id, true)
        try Data("seeded".utf8).write(to: marker, options: .atomic)
    }
}
