import Testing
import PDFKit
@testable import MarginMakerCore

@Suite(.serialized)
struct PDFCancellationTests {
    @Test func testAlreadyCancelledExportDoesNotReturnPDFData() async throws {
        let source = try PDFSource(data: AppTestFiles.pdf("CANCELLED"))
        let gate = WorkGate()
        defer { gate.releaseAll() }
        let worker = Task.detached {
            _ = gate.run("before export")
            return try PDFExporter.export(source: source, layouts: [PageLayout()])
        }
        // Cancellation is recorded even if the detached task has not started yet.
        worker.cancel()
        gate.releaseAll()
        do {
            _ = try await worker.value
            Issue.record("Cancelled export returned PDF data")
        } catch is CancellationError { }
    }

    @Test func testSinglePageExportCancelledDuringDrawingDoesNotReturnPDFData() async throws {
        // One complex page is important: checking only at the next page boundary
        // allowed cancelled previews to finish and return a complete result.
        let source = try PDFSource(data: complexPage())
        let (started, continuation) = AsyncStream<Void>.makeStream()
        let worker = Task.detached {
            continuation.yield(())
            continuation.finish()
            return try PDFExporter.export(source: source, layouts: [PageLayout()], orientation: .landscape)
        }
        for await _ in started { break }
        try await Task.sleep(for: .milliseconds(20))
        worker.cancel()
        do {
            _ = try await worker.value
            Issue.record("In-flight cancelled single-page export returned PDF data")
        } catch is CancellationError { }
    }

    private func complexPage() -> Data {
        var content = Data("0.1 0.7 0.6 rg\n".utf8)
        for index in 0..<300_000 {
            content.append(Data("\(index % 600) \((index / 600) % 780) 1 1 re f\n".utf8))
        }
        var bytes = Data("%PDF-1.4\n".utf8)
        var offsets: [Int] = []
        func object(_ data: Data) {
            offsets.append(bytes.count)
            bytes.append(Data("\(offsets.count) 0 obj\n".utf8))
            bytes.append(data)
            bytes.append(Data("\nendobj\n".utf8))
        }
        object(Data("<< /Type /Catalog /Pages 2 0 R >>".utf8))
        object(Data("<< /Type /Pages /Kids [3 0 R] /Count 1 >>".utf8))
        object(Data("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << >> /Contents 4 0 R >>".utf8))
        var stream = Data("<< /Length \(content.count) >>\nstream\n".utf8)
        stream.append(content)
        stream.append(Data("endstream".utf8))
        object(stream)
        let xref = bytes.count
        bytes.append(Data("xref\n0 5\n0000000000 65535 f \n".utf8))
        for offset in offsets { bytes.append(Data(String(format: "%010d 00000 n \n", offset).utf8)) }
        bytes.append(Data("trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n".utf8))
        return bytes
    }
}
