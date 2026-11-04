import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Reads only a Finder file URL from the provider. PDF bytes always go through
/// AppModel's common importer, which captures and protects the original file.
@MainActor
final class PDFDropHandler: ObservableObject {
    @Published private(set) var isTargeted = false
    private let model: AppModel
    typealias URLLoader = @MainActor (NSItemProvider) async throws -> URL
    private let loadURL: URLLoader
    private var hoverRevision = 0
    private(set) var hoverTask: Task<Void, Never>?
    private(set) var dropTask: Task<Void, Never>?

    init(model: AppModel, loadURL: @escaping URLLoader = { try await PDFDropHandler.fileURL(from: $0) }) {
        self.model = model
        self.loadURL = loadURL
    }

    func entered(_ providers: [NSItemProvider]) {
        exited()
        guard providers.count == 1, let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return }
        let revision = hoverRevision
        hoverTask = Task {
            do {
                let url = try await loadURL(provider)
                let valid = try await Task.detached { try Self.isPDFCandidate(url) }.value
                guard !Task.isCancelled, revision == hoverRevision else { return }
                isTargeted = valid
            } catch {
                // Hovering never interrupts a reading with an alert. A failed drop
                // is reported when the user actually releases the file.
            }
        }
    }

    func exited() {
        hoverRevision += 1
        hoverTask?.cancel()
        hoverTask = nil
        isTargeted = false
    }

    @discardableResult
    func perform(_ providers: [NSItemProvider]) -> Bool {
        exited()
        guard providers.count == 1, let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            model.errorMessage = "Drop one PDF file from Finder at a time."
            return false
        }
        // Reserve ordering now, rather than when a slow provider finishes loading.
        let revision = model.beginOpenRequest()
        dropTask?.cancel()
        dropTask = Task {
            do {
                let url = try await loadURL(provider)
                try Task.checkCancellation()
                guard try await Task.detached(operation: { try Self.isPDFCandidate(url) }).value else {
                    model.failOpenRequest("Choose a PDF file. Folders and other file types cannot be imported.",
                                          revision: revision)
                    return
                }
                model.completeOpenRequest(url, revision: revision)
            } catch is CancellationError {
                // A later drop owns the import request now.
            } catch {
                model.failOpenRequest("Couldn’t read the dropped file. \(error.localizedDescription)", revision: revision)
            }
        }
        return true
    }

    nonisolated static func isPDFCandidate(_ url: URL) throws -> Bool {
        guard url.isFileURL else { return false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var target = url.resolvingSymlinksInPath()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isAliasFileKey]
        var values = try target.resourceValues(forKeys: keys)
        if values.isAliasFile == true {
            target = try URL(resolvingAliasFileAt: target, options: [.withoutUI, .withoutMounting])
            values = try target.resourceValues(forKeys: keys)
        }
        // Basic filesystem metadata works without Launch Services. Actual PDF
        // validity (including locked/invalid files) is checked only by the importer.
        return values.isRegularFile == true && target.pathExtension.lowercased() == "pdf"
    }

    static func fileURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                let url: URL?
                if let value = item as? URL { url = value }
                else if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let string = item as? String { url = URL(string: string) }
                else { url = nil }
                guard let url, url.isFileURL else {
                    continuation.resume(throwing: DropError.invalidFileURL)
                    return
                }
                continuation.resume(returning: url)
            }
        }
    }

    private enum DropError: LocalizedError {
        case invalidFileURL
        var errorDescription: String? { "Choose a local PDF file from Finder." }
    }
}

struct PDFDropDelegate: DropDelegate {
    let handler: PDFDropHandler

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.fileURL]) }
    func dropEntered(info: DropInfo) { handler.entered(info.itemProviders(for: [.fileURL])) }
    func dropExited(info: DropInfo) { handler.exited() }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .copy) }
    func performDrop(info: DropInfo) -> Bool { handler.perform(info.itemProviders(for: [.fileURL])) }
}
