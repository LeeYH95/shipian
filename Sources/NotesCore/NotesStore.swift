import Combine
import Foundation
import Darwin
import UniformTypeIdentifiers

public enum SaveState: Equatable { case saved, saving, failed(String) }

public enum NotesStoreError: LocalizedError, Equatable {
    case noteNotFound
    case attachmentNotFound
    case unsafePath
    case invalidStore
    case invalidSource
    case noteMustBeInTrash
    case noteIsInTrash

    public var errorDescription: String? {
        switch self {
        case .noteNotFound: return "未找到这篇笔记。"
        case .attachmentNotFound: return "未找到这个附件。"
        case .unsafePath: return "附件路径不安全，已停止操作。"
        case .invalidStore: return "笔记资料库已损坏或版本不受支持，原文件已保留。"
        case .invalidSource: return "请选择一个可读取的文件。"
        case .noteMustBeInTrash: return "请先将笔记移入回收站。"
        case .noteIsInTrash: return "请先从回收站恢复这篇笔记。"
        }
    }
}

@MainActor
public final class NotesStore: ObservableObject {
    @Published public private(set) var documents: [NoteDocument] = []
    @Published public private(set) var saveState: SaveState = .saved
    public let directory: URL
    private let fileManager = FileManager.default
    private var pendingCleanup: Set<String> = []
    private var storeURL: URL { directory.appendingPathComponent("notes.json") }
    public convenience init(directory: URL) throws {
        let snapshot = try NotesStoreSnapshot.read(directory: directory, readFile: { try Data(contentsOf: $0) })
        self.init(snapshot: snapshot)
    }
    private init(snapshot: NotesStoreSnapshot) {
        directory = snapshot.directory
        documents = snapshot.documents
    }
    public static func open(directory: URL) async throws -> NotesStore {
        try await open(directory: directory, readFile: { try Data(contentsOf: $0) })
    }
    static func open(directory: URL, readFile: @escaping @Sendable (URL) throws -> Data) async throws -> NotesStore {
        let snapshot = try await Task.detached(priority: .userInitiated) {
            try NotesStoreSnapshot.read(directory: directory, readFile: readFile)
        }.value
        return NotesStore(snapshot: snapshot)
    }

    public func document(id: UUID) -> NoteDocument? { documents.first { $0.id == id } }

    public func create(template: NoteTemplate = .text, paper: NotePaper = .blue) throws -> NoteDocument {
        let block = NoteBlock(kind: template == .checklist ? .checklist : .paragraph)
        let note = NoteDocument(blocks: [block], paper: paper)
        documents.insert(note, at: 0)
        try flush()
        return note
    }

    public func update(_ document: NoteDocument) throws {
        let index = try index(of: document.id)
        try validate(document)
        let removed = Set(documents[index].attachments.map(\.relativePath))
            .subtracting(document.attachments.map(\.relativePath))
        for path in removed { _ = try safeAttachmentURL(path) }
        var edited = document
        edited.updatedAt = Date()
        // Deleted notes never participate in the hanging line.
        if edited.deletedAt != nil { edited.onLine = false }
        documents[index] = edited
        pendingCleanup.formUnion(removed)
        try flush()
    }

    public func setOnLine(_ id: UUID, _ value: Bool) throws {
        var note = try requireNote(id)
        guard note.deletedAt == nil else { throw NotesStoreError.noteIsInTrash }
        note.onLine = value
        if value { note.draft = false }
        try update(note)
    }

    public func trash(_ id: UUID) throws {
        var note = try requireNote(id)
        if note.deletedAt == nil {
            note.wasOnLine = note.onLine
            note.onLine = false
            note.deletedAt = Date()
        }
        try update(note)
    }

    public func restore(_ id: UUID) throws {
        var note = try requireNote(id)
        if note.deletedAt != nil {
            note.deletedAt = nil
            note.onLine = note.wasOnLine
            note.wasOnLine = false
        }
        try update(note)
    }

    public func permanentlyDelete(_ id: UUID) throws {
        let index = try index(of: id)
        let note = documents[index]
        guard note.deletedAt != nil else { throw NotesStoreError.noteMustBeInTrash }
        for attachment in note.attachments { _ = try url(for: attachment) }
        documents.remove(at: index)
        pendingCleanup.formUnion(note.attachments.map(\.relativePath))
        try flush()
    }

    public func duplicate(_ id: UUID) throws -> NoteDocument {
        let original = try requireNote(id)
        var copy = original
        copy.id = UUID()
        copy.createdAt = Date()
        copy.updatedAt = copy.createdAt
        copy.deletedAt = nil
        copy.wasOnLine = false
        copy.onLine = false
        copy.draft = true
        var attachmentIDs: [UUID: UUID] = [:]
        var copiedAttachments: [NoteAttachment] = []
        do {
            for attachment in original.attachments {
                let source = try url(for: attachment)
                try requireRegularFile(source)
                let duplicated = try copyAttachment(from: source, name: attachment.name, kind: attachment.kind)
                copiedAttachments.append(duplicated)
                attachmentIDs[attachment.id] = duplicated.id
            }
        } catch {
            // No document references these new internal files yet.
            for attachment in copiedAttachments {
                pendingCleanup.insert(attachment.relativePath)
            }
            throw error
        }
        copy.attachments = copiedAttachments
        copy.blocks = original.blocks.map { block in
            var duplicated = block
            duplicated.id = UUID()
            duplicated.attachmentID = block.attachmentID.flatMap { attachmentIDs[$0] }
            return duplicated
        }
        documents.insert(copy, at: 0)
        try flush()
        return copy
    }

    public func search(_ query: String, scope: NoteScope = .all) -> [NoteDocument] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return documents.filter { note in
            switch scope {
            case .all: guard note.deletedAt == nil else { return false }
            case .onLine: guard note.deletedAt == nil && note.onLine else { return false }
            case .offLine: guard note.deletedAt == nil && !note.onLine else { return false }
            case .trash: guard note.deletedAt != nil else { return false }
            }
            let searchable = ([note.title, note.plainText] + note.attachments.map(\.name)).joined(separator: "\n")
            return search.isEmpty || searchable.range(of: search, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public func importAttachment(from source: URL, to noteID: UUID, at position: Int? = nil) throws -> NoteAttachment {
        var note = try requireNote(noteID)
        guard note.deletedAt == nil else { throw NotesStoreError.noteIsInTrash }
        try requireRegularFile(source)
        let type = UTType(filenameExtension: source.pathExtension)
        let kind: NoteAttachment.Kind = type?.conforms(to: .image) == true ? .image : .file
        let attachment = try copyAttachment(from: source, name: source.lastPathComponent, kind: kind)
        note.attachments.append(attachment)
        let block = NoteBlock(kind: kind == .image ? .image : .file, text: attachment.name, attachmentID: attachment.id)
        let insertion = max(0, min(position ?? note.blocks.count, note.blocks.count))
        note.blocks.insert(block, at: insertion)
        try update(note)
        return attachment
    }

    public func removeAttachment(_ attachmentID: UUID, from noteID: UUID) throws {
        var note = try requireNote(noteID)
        guard let attachment = note.attachments.first(where: { $0.id == attachmentID }) else {
            throw NotesStoreError.attachmentNotFound
        }
        _ = try url(for: attachment)
        note.attachments.removeAll { $0.id == attachmentID }
        note.blocks.removeAll { $0.attachmentID == attachmentID }
        try update(note)
    }

    public func url(for attachment: NoteAttachment) throws -> URL {
        try safeAttachmentURL(attachment.relativePath)
    }

    public func exportMarkdown(_ id: UUID, to destination: URL) throws {
        let note = try requireNote(id)
        try validate(note)
        guard destination.isFileURL else { throw NotesStoreError.unsafePath }
        try rejectSymlink(at: destination)
        let parent = destination.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
        let target = parent.appendingPathComponent(destination.lastPathComponent)
        // Export must never overwrite a live store or its internal attachments.
        let canonical = target.resolvingSymlinksInPath().path
        guard canonical != directory.path, !canonical.hasPrefix(directory.path + "/") else {
            throw NotesStoreError.unsafePath
        }
        let folderName = target.deletingPathExtension().lastPathComponent + "-attachments-" + UUID().uuidString
        let exportDirectory = parent.appendingPathComponent(folderName, isDirectory: true)
        var links: [UUID: String] = [:]
        var createdExportDirectory = false
        do {
            if !note.attachments.isEmpty {
                try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: false)
                createdExportDirectory = true
                for attachment in note.attachments {
                    let source = try url(for: attachment)
                    try requireRegularFile(source)
                    let filename = internalFilename(id: attachment.id, originalName: attachment.name)
                    let target = exportDirectory.appendingPathComponent(filename)
                    try fileManager.copyItem(at: source, to: target)
                    let relative = folderName + "/" + filename
                    let linkCharacters = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "()[]?#"))
                    links[attachment.id] = relative.addingPercentEncoding(withAllowedCharacters: linkCharacters) ?? relative
                }
            }
            var sections = ["# " + escapeMarkdown(note.displayTitle)]
            for block in note.blocks {
                switch block.kind {
                case .paragraph: sections.append(block.markdown ?? escapeMarkdown(block.text))
                case .checklist: sections.append("- [\(block.isChecked ? "x" : " ")] " + escapeMarkdown(block.text))
                case .image, .file:
                    guard let id = block.attachmentID,
                          let attachment = note.attachments.first(where: { $0.id == id }),
                          let relative = links[id] else { throw NotesStoreError.attachmentNotFound }
                    let label = escapeMarkdown(attachment.name)
                    sections.append("\(block.kind == .image ? "!" : "")[\(label)](\(relative))")
                }
            }
            // Attachments without a corresponding block remain portable, too.
            let referenced = Set(note.blocks.compactMap(\.attachmentID))
            for attachment in note.attachments where !referenced.contains(attachment.id) {
                if let relative = links[attachment.id] {
                    sections.append("[\(escapeMarkdown(attachment.name))](\(relative))")
                }
            }
            try Data((sections.joined(separator: "\n\n") + "\n").utf8).write(to: target, options: .atomic)
        } catch {
            if createdExportDirectory {
                // This unique directory was created entirely by this export operation.
                try? fileManager.removeItem(at: exportDirectory)
            }
            throw error
        }
    }

    public func flush() throws {
        saveState = .saving
        do {
            try validateStoreRoot()
            try rejectSymlink(at: storeURL)
            for document in documents { try validate(document) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(NotesStoreFile(documents: documents))
            // Atomic replacement leaves the previous JSON intact if a write fails.
            try data.write(to: storeURL, options: .atomic)
            try cleanUnreferencedAttachments()
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    private func index(of id: UUID) throws -> Int {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { throw NotesStoreError.noteNotFound }
        return index
    }

    private func requireNote(_ id: UUID) throws -> NoteDocument { documents[try index(of: id)] }

    private var paths: NotesStorePaths { NotesStorePaths(directory: directory) }
    private func validate(_ note: NoteDocument) throws { try paths.validate(note) }
    private func validateStoreRoot() throws { try paths.validateStoreRoot() }
    private func metadata(at url: URL) throws -> stat? { try paths.metadata(at: url) }
    private func rejectSymlink(at url: URL) throws { try paths.rejectSymlink(at: url) }
    private func safeAttachmentURL(_ relativePath: String) throws -> URL { try paths.safeAttachmentURL(relativePath) }

    private func requireRegularFile(_ source: URL) throws {
        guard source.isFileURL else { throw NotesStoreError.invalidSource }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { throw NotesStoreError.invalidSource }
    }

    private func internalFilename(id: UUID, originalName: String) -> String {
        let ext = URL(fileURLWithPath: originalName).pathExtension.lowercased()
        let safeExtension = !ext.isEmpty && ext.count <= 20 && ext.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
        return id.uuidString + (safeExtension ? "." + ext : "")
    }

    private func copyAttachment(from source: URL, name: String, kind: NoteAttachment.Kind) throws -> NoteAttachment {
        let id = UUID()
        let path = "attachments/" + internalFilename(id: id, originalName: name)
        let destination = try safeAttachmentURL(path)
        try fileManager.copyItem(at: source, to: destination)
        guard let info = try metadata(at: destination) else { throw NotesStoreError.attachmentNotFound }
        return NoteAttachment(id: id, name: name, relativePath: path, kind: kind, byteCount: Int(info.st_size))
    }

    private func cleanUnreferencedAttachments() throws {
        guard !pendingCleanup.isEmpty else { return }
        let referenced = documents.flatMap(\.attachments)
        let referencedPaths = Set(referenced.map { conservativePathKey($0.relativePath) })
        var referencedIdentities: Set<AttachmentFileIdentity> = []
        for attachment in referenced {
            if let identity = try fileIdentity(at: url(for: attachment)) {
                referencedIdentities.insert(identity)
            }
        }
        for path in Array(pendingCleanup) {
            // APFS can resolve differently cased or Unicode-normalized spellings
            // to the same file. A raw string comparison is unsafe for ownership.
            if referencedPaths.contains(conservativePathKey(path)) { continue }
            let url = try safeAttachmentURL(path)
            if let identity = try fileIdentity(at: url) {
                if referencedIdentities.contains(identity) { continue }
                guard let info = try metadata(at: url), info.st_mode & S_IFMT == S_IFREG else { throw NotesStoreError.unsafePath }
                try fileManager.removeItem(at: url)
            }
            pendingCleanup.remove(path)
        }
    }

    private struct AttachmentFileIdentity: Hashable {
        let device: UInt64
        let inode: UInt64
    }

    private func fileIdentity(at url: URL) throws -> AttachmentFileIdentity? {
        guard let info = try metadata(at: url) else { return nil }
        return AttachmentFileIdentity(device: UInt64(info.st_dev), inode: UInt64(info.st_ino))
    }

    private func conservativePathKey(_ path: String) -> String {
        // On a case-sensitive volume this can retain an extra file, which is
        // safer than deleting a live attachment when identity is unavailable.
        path.precomposedStringWithCanonicalMapping.lowercased()
    }

    private func escapeMarkdown(_ text: String) -> String {
        var escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
        for character in ["`", "*", "_", "[", "]", "<", ">", "#"] {
            escaped = escaped.replacingOccurrences(of: character, with: "\\" + character)
        }
        return escaped
    }
}
