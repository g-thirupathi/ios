import CryptoKit
import Foundation
import OSLog

protocol ChatAttachmentLocalDataSource {
    func store(_ data: Data, fileName: String, maxSize: Int) async throws -> StoredAttachmentFile
    func importFile(at url: URL, fileName: String, maxSize: Int) async throws -> StoredAttachmentFile
    func data(at url: URL) async throws -> Data
    func remove(_ url: URL) async
    /// Deletes the stored files of earlier launches that none of `urls` is in, e.g. the last tray, removed messages
    /// and purged history. Files stored since this launch are never touched.
    func removeFiles(except urls: Set<URL>) async
    func resolvedLocalUri(_ uri: String) -> String?
}

/// Copies picked files into Caches so they can be uploaded later and shown as previews after sending. Like the chat
/// history, they can only be read while the device is unlocked.
struct FileChatAttachmentLocalDataSource: ChatAttachmentLocalDataSource {
    private nonisolated static let logger = Logger(category: "ChatAttachmentLocalDataSource")

    private static let directoryName = "ChatAttachments"

    private let directory: URL
    private let launchedAt = Date()

    init(fileManager: FileManager = .default) {
        directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    func store(_ data: Data, fileName: String, maxSize: Int) async throws -> StoredAttachmentFile {
        try await Self.write(data, fileName: fileName, maxSize: maxSize, in: directory)
    }

    func importFile(at url: URL, fileName: String, maxSize: Int) async throws -> StoredAttachmentFile {
        try await Self.copy(url, fileName: fileName, maxSize: maxSize, in: directory)
    }

    func data(at url: URL) async throws -> Data {
        try await Self.read(url)
    }

    /// Each file lives in a folder of its own, which is what gets deleted, so only folders of this directory qualify.
    func remove(_ url: URL) async {
        let folder = url.deletingLastPathComponent()
        guard isStoredFolder(folder) else {
            Self.logger.error("Not removing \(url.lastPathComponent): it is not in the attachments directory")
            return
        }
        await Self.delete(folder)
    }

    func removeFiles(except urls: Set<URL>) async {
        let keptFolders = urls.map { $0.deletingLastPathComponent() }.filter(isStoredFolder)
        await Self.deleteFolders(
            in: directory,
            except: Set(keptFolders.map(\.lastPathComponent)),
            createdBefore: launchedAt
        )
    }

    /// Saved file paths are absolute, and the app container path changes on reinstall or update.
    func resolvedLocalUri(_ uri: String) -> String? {
        guard let url = URL(string: uri), url.isFileURL else { return uri }
        if FileManager.default.fileExists(atPath: url.path) {
            return uri
        }
        let components = url.pathComponents
        guard let index = components.lastIndex(of: directory.lastPathComponent), index < components.count - 1
        else { return nil }
        let relocated = components[(index + 1)...].reduce(directory) { $0.appendingPathComponent($1) }
        return FileManager.default.fileExists(atPath: relocated.path) ? relocated.absoluteString : nil
    }

    private func isStoredFolder(_ folder: URL) -> Bool {
        folder.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path
    }

    @concurrent
    private static func copy(
        _ source: URL,
        fileName: String,
        maxSize: Int,
        in directory: URL
    ) async throws -> StoredAttachmentFile {
        let isScoped = source.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                source.stopAccessingSecurityScopedResource()
            }
        }
        if let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxSize {
            throw ChatAttachmentFileError.tooLarge
        }
        return try await write(Data(contentsOf: source), fileName: fileName, maxSize: maxSize, in: directory)
    }

    @concurrent
    private static func write(
        _ data: Data,
        fileName: String,
        maxSize: Int,
        in directory: URL
    ) async throws -> StoredAttachmentFile {
        guard !data.isEmpty else { throw ChatAttachmentFileError.empty }
        guard data.count <= maxSize else { throw ChatAttachmentFileError.tooLarge }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return StoredAttachmentFile(url: url, size: data.count, digest: digest)
    }

    @concurrent
    private static func read(_ url: URL) async throws -> Data {
        try Data(contentsOf: url)
    }

    @concurrent
    private static func deleteFolders(in directory: URL, except kept: Set<String>, createdBefore cutoff: Date) async {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let folders: [URL]
        do {
            folders = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey]
            )
        } catch {
            logger.error("List attachments failed: \(error)")
            return
        }
        for folder in folders where !kept.contains(folder.lastPathComponent) {
            let created = try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate
            if let created, created < cutoff {
                await delete(folder)
            }
        }
    }

    @concurrent
    private static func delete(_ url: URL) async {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Delete \(url.lastPathComponent) failed: \(error)")
        }
    }
}
