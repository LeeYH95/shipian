import Foundation
import Darwin

struct NotesStoreFile: Codable {
    var version: Int = 1
    var documents: [NoteDocument]
}

struct NotesStoreSnapshot: Sendable {
    let directory: URL
    let documents: [NoteDocument]
    static func read(directory: URL, readFile: @Sendable (URL) throws -> Data) throws -> NotesStoreSnapshot {
        guard directory.isFileURL else { throw NotesStoreError.unsafePath }
        let directory = directory.standardizedFileURL.resolvingSymlinksInPath()
        let files = FileManager.default
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let paths = NotesStorePaths(directory: directory)
        try paths.validateStoreRoot()
        let store = directory.appendingPathComponent("notes.json")
        try paths.rejectSymlink(at: store)
        var documents: [NoteDocument] = []
        if files.fileExists(atPath: store.path) {
            let data = try readFile(store)
            let decoded: NotesStoreFile
            do { decoded = try JSONDecoder().decode(NotesStoreFile.self, from: data) }
            catch { throw NotesStoreError.invalidStore }
            guard decoded.version == 1, Set(decoded.documents.map(\.id)).count == decoded.documents.count else { throw NotesStoreError.invalidStore }
            for document in decoded.documents { try paths.validate(document) }
            documents = decoded.documents
        }
        let attachments = directory.appendingPathComponent("attachments", isDirectory: true)
        try paths.rejectSymlink(at: attachments)
        if files.fileExists(atPath: attachments.path) {
            guard let info = try paths.metadata(at: attachments), info.st_mode & S_IFMT == S_IFDIR else { throw NotesStoreError.unsafePath }
        } else { try files.createDirectory(at: attachments, withIntermediateDirectories: false) }
        return NotesStoreSnapshot(directory: directory, documents: documents)
    }
}

struct NotesStorePaths {
    let directory: URL
    func validate(_ note: NoteDocument) throws {
        guard Set(note.attachments.map(\.id)).count == note.attachments.count,
              Set(note.blocks.map(\.id)).count == note.blocks.count else { throw NotesStoreError.invalidStore }
        for attachment in note.attachments { _ = try safeAttachmentURL(attachment.relativePath) }
    }

    func validateStoreRoot() throws {
        guard directory.resolvingSymlinksInPath().path == directory.path else { throw NotesStoreError.unsafePath }
        guard let info = try metadata(at: directory), info.st_mode & S_IFMT == S_IFDIR else { throw NotesStoreError.unsafePath }
    }

    /// lstat reads only inode metadata. FileManager.attributesOfItem also
    /// fetches unrelated extended attributes, which can block startup on a
    /// File Provider-backed folder. Never follow links for ownership checks.
    func metadata(at url: URL) throws -> stat? {
        var info = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return lstat(path, &info)
        }
        guard result == 0 else {
            let code = errno
            if code == ENOENT { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        return info
    }

    func rejectSymlink(at url: URL) throws {
        if let info = try metadata(at: url), info.st_mode & S_IFMT == S_IFLNK {
            throw NotesStoreError.unsafePath
        }
    }

    func safeAttachmentURL(_ relativePath: String) throws -> URL {
        try validateStoreRoot()
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.count >= 2, components.first == "attachments",
              !relativePath.contains("\\"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw NotesStoreError.unsafePath
        }
        var candidate = directory
        for component in components {
            candidate.appendPathComponent(component)
            try rejectSymlink(at: candidate)
        }
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path.hasPrefix(directory.path + "/attachments/") else { throw NotesStoreError.unsafePath }
        return candidate
    }

}
