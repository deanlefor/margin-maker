import Foundation
import Darwin

private struct FileIdentity: Equatable, Sendable {
    let device: dev_t
    let inode: ino_t

    init(_ attributes: stat) {
        device = attributes.st_dev
        inode = attributes.st_ino
    }
}

/// Captured while importing, rather than reconstructed from a possibly stale URL.
public final class SourceFileProtection: Sendable {
    private let importedURL: URL
    private let resolvedURL: URL
    private let identity: FileIdentity
    // Keeping the read handle open also prevents reuse of a deleted source's inode.
    private let handle: FileHandle

    init(sourceURL: URL) throws {
        importedURL = sourceURL.standardizedFileURL
        resolvedURL = try Self.resolvingAlias(sourceURL).standardizedFileURL.resolvingSymlinksInPath()
        handle = try FileHandle(forReadingFrom: resolvedURL)
        var attributes = stat()
        guard fstat(handle.fileDescriptor, &attributes) == 0 else { throw posixError() }
        identity = FileIdentity(attributes)
    }

    func readData() throws -> Data {
        try handle.readToEnd() ?? Data()
    }

    private static func resolvingAlias(_ url: URL) throws -> URL {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        if try resolved.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true {
            return try URL(resolvingAliasFileAt: resolved, options: [.withoutUI, .withoutMounting])
        }
        return resolved
    }

    func validateDestination(_ destination: URL, directory: Int32) throws {
        let target = destination.standardizedFileURL
        let resolved = target.resolvingSymlinksInPath()
        guard target != importedURL, target != resolvedURL,
              resolved != importedURL, resolved != resolvedURL else { throw PDFError.originalFile }

        // A Finder alias is a bookmark file, not a POSIX symlink. Resolve it too.
        // Missing destinations are allowed; other inspection failures must propagate.
        var entry = stat()
        if fstatat(directory, target.lastPathComponent, &entry, AT_SYMLINK_NOFOLLOW) == 0 {
            if entry.st_mode & S_IFMT == S_IFREG {
                var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
                guard fcntl(directory, F_GETPATH, &path) == 0 else { throw posixError() }
                let directoryPath = String(decoding: path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
                let entryURL = URL(fileURLWithPath: directoryPath)
                    .appendingPathComponent(target.lastPathComponent)
                let aliasTarget = try Self.resolvingAlias(entryURL)
                if aliasTarget != entryURL.standardizedFileURL.resolvingSymlinksInPath() {
                    var attributes = stat()
                    guard stat(aliasTarget.path, &attributes) == 0 else { throw posixError() }
                    guard FileIdentity(attributes) != identity else { throw PDFError.originalFile }
                }
            }
        } else if errno != ENOENT {
            throw posixError()
        }

        // This is the final filesystem lookup before renameat in commit(). It uses
        // the pinned directory, so parent symlink changes cannot redirect the write.
        var attributes = stat()
        if fstatat(directory, target.lastPathComponent, &attributes, 0) == 0 {
            guard FileIdentity(attributes) != identity else { throw PDFError.originalFile }
        } else if errno != ENOENT {
            throw posixError()
        }
    }
}

private func posixError() -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
}

/// Owns a temporary sibling of the destination until an atomic replacement succeeds.
/// Directory-relative operations keep staging, validation, replacement, and cleanup
/// in the same directory even if that directory is renamed while exporting.
final class StagedPDFWrite {
    private let destination: URL
    private let directory: Int32
    private let temporaryName: String
    private var committed = false

    init(data: Data, destination: URL) throws {
        let destination = destination.standardizedFileURL
        let directory = open(destination.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directory >= 0 else { throw posixError() }
        let temporaryName = ".margin-maker-\(UUID().uuidString).tmp"
        let descriptor = openat(directory, temporaryName, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            let error = posixError()
            close(directory)
            throw error
        }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try file.write(contentsOf: data)
            try file.synchronize()
            try file.close()
        } catch {
            try? file.close()
            unlinkat(directory, temporaryName, 0)
            close(directory)
            throw error
        }
        self.destination = destination
        self.directory = directory
        self.temporaryName = temporaryName
    }

    func commit(protecting source: SourceFileProtection) throws {
        try withExtendedLifetime(source) {
            try source.validateDestination(destination, directory: directory)
            guard renameat(directory, temporaryName, directory, destination.lastPathComponent) == 0 else {
                throw posixError()
            }
            committed = true
        }
    }

    deinit {
        if !committed { unlinkat(directory, temporaryName, 0) }
        close(directory)
    }
}
