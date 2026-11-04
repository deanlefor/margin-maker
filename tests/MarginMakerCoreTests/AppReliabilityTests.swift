import Testing
import AppKit
import PDFKit
import CoreText
@testable import MarginMakerCore
@testable import MarginMaker

struct AppTestFiles: Sendable {
    let directory: URL
    let old: URL
    let first: URL
    let second: URL
    let latest: URL
    let invalid: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        old = directory.appendingPathComponent("old.pdf")
        first = directory.appendingPathComponent("first.pdf")
        second = directory.appendingPathComponent("second.pdf")
        latest = directory.appendingPathComponent("latest.PDF")
        invalid = directory.appendingPathComponent("invalid.pdf")
        for (url, text) in [(old, "OLD"), (first, "FIRST"), (second, "SECOND"), (latest, "LATEST")] {
            try Self.pdf(text).write(to: url)
        }
        try Data("not a PDF".utf8).write(to: invalid)
    }

    static func pdf(_ text: String) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: PageLayout.letter)
        let context = try unwrap(CGContext(consumer: unwrap(CGDataConsumer(data: data)), mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.textPosition = CGPoint(x: 72, y: 700)
        let line = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 16, nil)
        ])
        CTLineDraw(CTLineCreateWithAttributedString(line), context)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }
}

/// Synchronous fake work blocks only its detached worker, never the main actor.
final class WorkGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var records: [String] = []
    private var released: Set<Int> = []
    private var releaseEverything = false
    private var active = 0
    private var maximumActive = 0

    var started: [String] {
        condition.lock(); defer { condition.unlock() }
        return records
    }
    var peak: Int {
        condition.lock(); defer { condition.unlock() }
        return maximumActive
    }

    func run(_ label: String) -> Int {
        condition.lock(); defer { condition.unlock() }
        records.append(label)
        let index = records.count
        active += 1
        maximumActive = max(maximumActive, active)
        while !releaseEverything && !released.contains(index) { condition.wait() }
        active -= 1
        return index
    }

    func release(_ index: Int) {
        condition.lock(); defer { condition.unlock() }
        released.insert(index)
        condition.broadcast()
    }

    func releaseAll() {
        condition.lock(); defer { condition.unlock() }
        releaseEverything = true
        condition.broadcast()
    }
}

@MainActor
func eventually(_ message: String, _ predicate: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !predicate() {
        if ContinuousClock.now >= deadline {
            Issue.record("Timed out: \(message)")
            throw WaitError.timeout
        }
        try await Task.sleep(for: .milliseconds(2))
    }
}

private enum WaitError: Error { case timeout }

@MainActor
func settled(_ model: AppModel) async throws {
    try await eventually("import and preview settled") { !model.isBusy && !model.previewIsBusy }
}

@MainActor
@Suite(.serialized)
struct AppReliabilityTests {
    @Test func testPreviewIsSerializedCoalescedAndRevisionGuarded() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let gate = WorkGate()
        defer { gate.releaseAll() }
        let stale = try AppTestFiles.pdf("STALE")
        let fresh = try AppTestFiles.pdf("FRESH")
        let model = AppModel(convertPreview: { _, layouts, orientation, index in
            let number = gate.run("\(layouts[index].scalePercent)/\(orientation.rawValue)/\(index)")
            // Deliberately ignore cancellation. The revision guard must still
            // prevent a completed obsolete conversion from reaching PDFView.
            return number == 1 ? stale : fresh
        }, previewDebounce: .zero)
        model.open(files.old)
        try await eventually("first conversion started") { gate.started.count == 1 }
        for scale in 50...100 { model.setScale(Double(scale)) }
        model.setPageOrientation(.landscape)
        model.setAnchor(horizontal: .right, vertical: .bottom)
        model.setScale(63)
        // Give competing work an opportunity to start while the old work is held.
        try await Task.sleep(for: .milliseconds(20))
        #expect(gate.started.count == 1)
        #expect(gate.peak == 1)
        #expect(model.layout.scalePercent == 63)
        #expect(model.pageOrientation == .landscape)
        #expect(model.preview == nil)
        gate.release(1)
        try await eventually("latest conversion started") { gate.started.count == 2 }
        #expect(gate.started == ["75/Portrait/0", "63/Landscape/0"])
        #expect(model.preview == nil)
        gate.release(2)
        try await settled(model)
        #expect(model.preview?.string?.contains("FRESH") == true)
        #expect(model.errorMessage == nil)
        #expect(gate.peak == 1)
    }

    @Test func testObsoletePreviewErrorCannotReplaceNewerResult() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let gate = WorkGate()
        defer { gate.releaseAll() }
        let fresh = try AppTestFiles.pdf("LATEST PREVIEW")
        let model = AppModel(convertPreview: { _, _, _, _ in
            if gate.run("preview") == 1 { throw PDFError.exportFailed }
            return fresh
        }, previewDebounce: .zero)
        model.open(files.old)
        try await eventually("held preview") { gate.started.count == 1 }
        model.setScale(64)
        gate.release(1)
        try await eventually("replacement preview") { gate.started.count == 2 }
        gate.release(2)
        try await settled(model)
        #expect(model.errorMessage == nil)
        #expect(model.preview?.string?.contains("LATEST PREVIEW") == true)
    }

    @Test func testLatestPreviewFailureStopsSpinnerAndKeepsSource() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(convertPreview: { _, _, _, _ in throw PDFError.exportFailed }, previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        #expect(model.sourceURL == files.old)
        #expect(model.errorMessage == PDFError.exportFailed.localizedDescription)
        #expect(model.canExport)
    }

    @Test func testLatestOpenDuringImportWinsAndMiddleRequestIsSkipped() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let gate = WorkGate()
        defer { gate.releaseAll() }
        let model = AppModel(loadSource: { url in
            if url == files.first { _ = gate.run("first") }
            if url == files.second { _ = gate.run("unexpected middle import") }
            return try PDFSource(contentsOf: url)
        }, previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        model.open(files.first)
        try await eventually("held import") { gate.started.count == 1 }
        model.open(files.second)
        model.open(files.latest)
        #expect(model.pendingOpenURL == files.latest)
        #expect(model.canChoosePDF)
        #expect(model.sourceURL == files.old)
        gate.releaseAll()
        try await settled(model)
        #expect(model.sourceURL == files.latest)
        #expect(model.preview?.string?.contains("LATEST") == true)
        #expect(model.pendingOpenURL == nil)
        #expect(model.errorMessage == nil)
        #expect(gate.started == ["first"])
    }

    @Test func testFailedLatestImportPreservesCurrentDocumentAndOverrides() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let gate = WorkGate()
        defer { gate.releaseAll() }
        let model = AppModel(loadSource: { url in
            if url == files.first { _ = gate.run("first") }
            return try PDFSource(contentsOf: url)
        }, previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        model.setScope(.currentPage)
        model.setScale(63)
        model.setAnchor(horizontal: .left, vertical: .top)
        model.setPageOrientation(.landscape)
        try await settled(model)
        let originalBytes = model.source?.data
        let oldPreview = model.preview
        let layouts = model.settings?.pages
        model.open(files.first)
        try await eventually("held import") { gate.started.count == 1 }
        model.open(files.invalid)
        gate.releaseAll()
        try await settled(model)
        #expect(model.sourceURL == files.old)
        #expect(model.source?.data == originalBytes)
        #expect(model.preview === oldPreview)
        #expect(model.settings?.pages == layouts)
        #expect(model.pageOrientation == .landscape)
        #expect(model.scope == .currentPage)
        #expect(model.errorMessage?.contains("invalid.pdf") == true)
        #expect(model.errorMessage?.contains("PDF") == true)
        #expect(try Data(contentsOf: files.old) == originalBytes)
    }

    @Test func testQueuedOpenDuringExportKeepsExportSnapshotAndSourceProtection() async throws {
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
        model.setPageOrientation(.landscape)
        let destination = files.directory.appendingPathComponent("export.pdf")
        model.export(to: destination)
        try await eventually("held export") { gate.started.count == 1 }
        model.open(files.first)
        model.open(files.latest)
        #expect(model.pendingOpenURL == files.latest)
        #expect(model.sourceURL == files.old)
        gate.releaseAll()
        try await settled(model)
        #expect(model.sourceURL == files.latest)
        let exported = try unwrap(PDFDocument(url: destination))
        #expect(exported.string?.contains("OLD") == true)
        #expect(exported.page(at: 0)?.bounds(for: .mediaBox).size == PageOrientation.landscape.pageSize)
        let moved = files.directory.appendingPathComponent("renamed-latest.pdf")
        let originalBytes = try Data(contentsOf: files.latest)
        try FileManager.default.moveItem(at: files.latest, to: moved)
        model.export(to: moved)
        try await settled(model)
        #expect(model.errorMessage == PDFError.originalFile.localizedDescription)
        #expect(try Data(contentsOf: moved) == originalBytes)
    }

    @Test func testExportFailureIsNotHiddenWhenQueuedImportStarts() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let gate = WorkGate()
        defer { gate.releaseAll() }
        let model = AppModel(writeExport: { _, _, _ in
            _ = gate.run("export")
            throw NSError(domain: "ExportTest", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The export could not be saved."])
        }, previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        model.export(to: files.directory.appendingPathComponent("output.pdf"))
        try await eventually("held failing export") { gate.started.count == 1 }
        model.open(files.latest)
        gate.releaseAll()
        try await settled(model)
        #expect(model.sourceURL == files.latest)
        #expect(model.errorMessage == "The export could not be saved.")
    }

    @Test func testSlowResolvedOpenCannotSupersedeNewerRequest() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        let oldTicket = model.beginOpenRequest()
        model.open(files.latest)
        model.completeOpenRequest(files.first, revision: oldTicket)
        model.failOpenRequest("stale failure", revision: oldTicket)
        try await settled(model)
        #expect(model.sourceURL == files.latest)
        #expect(model.errorMessage == nil)
    }

    @Test func testRemoteOpenIsRejectedWithoutDiscardingReading() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        model.open(try unwrap(URL(string: "https://example.invalid/reading.pdf")))
        #expect(model.sourceURL == files.old)
        #expect(!model.isBusy)
        #expect(model.errorMessage?.contains("local PDF") == true)
    }
}
