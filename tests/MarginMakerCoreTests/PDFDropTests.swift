import Testing
import AppKit
import PDFKit
import UniformTypeIdentifiers
@testable import MarginMakerCore
@testable import MarginMaker

@MainActor
private final class DelayedURL {
    private var continuation: CheckedContinuation<URL, Error>?
    var waiting: Bool { continuation != nil }
    func load() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(_ url: URL) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: url)
    }
}

@MainActor
@Suite(.serialized)
struct PDFDropTests {
    private func provider(_ url: URL) -> NSItemProvider {
        NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)
    }

    @Test func testFileURLRepresentationsDecodeWithoutCopyingPDFData() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let url = files.directory.appendingPathComponent("A reading with spaces.pdf")
        let data = Data(url.absoluteString.utf8)
        let items: [NSSecureCoding] = [url as NSURL, data as NSData, url.absoluteString as NSString]
        for item in items {
            let itemProvider = NSItemProvider(item: item, typeIdentifier: UTType.fileURL.identifier)
            #expect(try await PDFDropHandler.fileURL(from: itemProvider) == url)
        }
        let remote = provider(try unwrap(URL(string: "https://example.invalid/reading.pdf")))
        do {
            _ = try await PDFDropHandler.fileURL(from: remote)
            Issue.record("Accepted a remote URL")
        } catch {
            #expect(error.localizedDescription.contains("local PDF"))
        }
    }

    @Test func testOnlyOnePDFCandidateHighlightsAndExitClearsFeedback() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        let handler = PDFDropHandler(model: model)
        handler.entered([provider(files.latest)])
        await handler.hoverTask?.value
        #expect(handler.isTargeted)
        handler.exited()
        #expect(!handler.isTargeted)
        let text = files.directory.appendingPathComponent("unsupported.txt")
        try Data("plain text".utf8).write(to: text)
        handler.entered([provider(text)])
        await handler.hoverTask?.value
        #expect(!handler.isTargeted)
        handler.entered([provider(files.first), provider(files.latest)])
        #expect(!handler.isTargeted)
        #expect(model.errorMessage == nil)
    }

    @Test func testLateHoverCompletionCannotRestoreExitedFeedback() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let delay = DelayedURL()
        let handler = PDFDropHandler(model: AppModel(), loadURL: { _ in try await delay.load() })
        handler.entered([provider(files.first)])
        let hover = handler.hoverTask
        try await eventually("hover provider waiting") { delay.waiting }
        handler.exited()
        delay.finish(files.first)
        await hover?.value
        #expect(!handler.isTargeted)
    }

    @Test func testDroppedPDFUsesProtectedImporter() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        let handler = PDFDropHandler(model: model)
        #expect(handler.perform([provider(files.latest)]))
        await handler.dropTask?.value
        try await settled(model)
        #expect(model.sourceURL == files.latest)
        #expect(model.preview?.string?.contains("LATEST") == true)
        let moved = files.directory.appendingPathComponent("moved.pdf")
        let bytes = try Data(contentsOf: files.latest)
        try FileManager.default.moveItem(at: files.latest, to: moved)
        model.export(to: moved)
        try await settled(model)
        #expect(model.errorMessage == PDFError.originalFile.localizedDescription)
        #expect(try Data(contentsOf: moved) == bytes)
    }

    @Test func testDropQueuesDuringExportAndLatestDropWins() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let gate = WorkGate()
        defer { gate.releaseAll() }
        let model = AppModel(writeExport: { data, destination, protection in
            _ = gate.run("export")
            try PDFExporter.write(data, to: destination, protecting: protection)
        }, previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        model.export(to: files.directory.appendingPathComponent("export.pdf"))
        try await eventually("export worker held") { gate.started.count == 1 }
        let handler = PDFDropHandler(model: model)
        #expect(handler.perform([provider(files.first)]))
        await handler.dropTask?.value
        #expect(handler.perform([provider(files.latest)]))
        await handler.dropTask?.value
        #expect(model.pendingOpenURL == files.latest)
        #expect(model.sourceURL == files.old)
        gate.releaseAll()
        try await settled(model)
        #expect(model.sourceURL == files.latest)
        #expect(model.errorMessage == nil)
    }

    @Test func testSlowDropCannotOverrideNewerFinderOpen() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        let delay = DelayedURL()
        let handler = PDFDropHandler(model: model, loadURL: { _ in try await delay.load() })
        #expect(handler.perform([provider(files.first)]))
        let slow = handler.dropTask
        try await eventually("drop provider waiting") { delay.waiting }
        model.open(files.latest)
        try await settled(model)
        delay.finish(files.first)
        await slow?.value
        try await settled(model)
        #expect(model.sourceURL == files.latest)
        #expect(model.errorMessage == nil)
    }

    @Test func testCorruptAndUnsupportedDropsKeepCurrentReading() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        let handler = PDFDropHandler(model: model)
        let originalPreview = model.preview
        #expect(handler.perform([provider(files.invalid)]))
        await handler.dropTask?.value
        try await settled(model)
        #expect(model.sourceURL == files.old)
        #expect(model.preview === originalPreview)
        #expect(model.errorMessage?.contains("invalid.pdf") == true)
        let text = files.directory.appendingPathComponent("notes.txt")
        try Data("plain text".utf8).write(to: text)
        #expect(handler.perform([provider(text)]))
        await handler.dropTask?.value
        #expect(model.sourceURL == files.old)
        #expect(model.errorMessage?.contains("Choose a PDF") == true)
        let folder = files.directory.appendingPathComponent("folder.pdf")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #expect(try PDFDropHandler.isPDFCandidate(folder) == false)
    }

    @Test func testMultipleFilesAndInvalidProvidersHaveActionableFeedback() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        let handler = PDFDropHandler(model: model)
        #expect(!handler.perform([provider(files.first), provider(files.second)]))
        #expect(model.errorMessage?.contains("one PDF") == true)
        #expect(!handler.perform([NSItemProvider(item: "text" as NSString, typeIdentifier: UTType.text.identifier)]))
        let broken = NSItemProvider(item: NSNumber(value: 17), typeIdentifier: UTType.fileURL.identifier)
        #expect(handler.perform([broken]))
        await handler.dropTask?.value
        #expect(model.errorMessage?.contains("Couldn’t read the dropped file") == true)
        #expect(model.source == nil)
        #expect(!model.isBusy)
    }

    @Test func testSymlinkAndFinderAliasPDFCandidatesUseRealFileMetadata() throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let symlink = files.directory.appendingPathComponent("symbolic link")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: files.latest)
        #expect(try PDFDropHandler.isPDFCandidate(symlink))
        let alias = files.directory.appendingPathComponent("Finder alias")
        let data = try files.latest.bookmarkData(options: .suitableForBookmarkFile,
                                                 includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(data, to: alias)
        #expect(try PDFDropHandler.isPDFCandidate(alias))
    }
}
