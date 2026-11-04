import Testing
import CoreGraphics
import CoreText
import PDFKit
@testable import MarginMakerCore

@Suite(.serialized)
struct PDFCompatibilityTests {
    private func table(_ entries: [String], lineEnding: String = "\n", trailer: String = "") -> (Data, Int) {
        let body = "%PDF-1.3\n1 0 obj\n<< /Type /Catalog >>\nendobj\n"
        let offset = body.utf8.count
        let tail = "xref\(lineEnding)0 \(entries.count)\(lineEnding)" + entries.joined()
            + "trailer\(lineEnding)<< /Size \(entries.count) /Root 1 0 R \(trailer)>>\nstartxref\n\(offset)\n%%EOF\n"
        return (Data((body + tail).utf8), offset)
    }

    @Test func testUnusedQuartzObjectsBecomeLinkedFreeEntriesWithoutMovingContent() {
        let (original, offset) = table([
            "0000000000 65535 f \n", "0000000009 00000 n \n",
            "0000000000 00000 n \n", "0000000000 00007 f \n", "0000000000 00000 n \n"
        ])
        let repaired = PDFCrossReference.repairingQuartzOutput(original)
        #expect(repaired.count == original.count)
        #expect(repaired.prefix(offset) == original.prefix(offset))
        let text = String(decoding: repaired.dropFirst(offset), as: UTF8.self)
        #expect(text.contains("0000000002 65535 f \n0000000009 00000 n \n0000000003 65535 f \n0000000004 00007 f \n0000000000 65535 f \n"))
        #expect(text.hasSuffix("startxref\n\(offset)\n%%EOF\n"))
        #expect(PDFCrossReference.repairingQuartzOutput(repaired) == repaired)
        #expect(String(decoding: original, as: UTF8.self).contains("0000000000 00000 n"))
    }

    @Test func testValidTablesAreByteIdentical() {
        let (data, _) = table(["0000000000 65535 f \n", "0000000009 00000 n \n"])
        #expect(PDFCrossReference.repairingQuartzOutput(data) == data)
    }

    @Test func testCRLFEntriesKeepEveryOffsetStable() {
        let (data, offset) = table(["0000000000 65535 f\r\n", "0000000009 00000 n\r\n",
                                   "0000000000 00000 n\r\n"], lineEnding: "\r\n")
        let result = PDFCrossReference.repairingQuartzOutput(data)
        #expect(result.count == data.count)
        #expect(result.prefix(offset) == data.prefix(offset))
        #expect(String(decoding: result, as: UTF8.self).contains("0000000002 65535 f \n"))
        #expect(!String(decoding: result, as: UTF8.self).contains("0000000000 00000 n"))
    }

    @Test func testUnknownOrIncrementalFormatsAreNeverRewritten() {
        let (bad, _) = table(["0000000000 65535 f \n", "0000000000 00000 n \n"], trailer: "/Prev 20 ")
        let (malformed, _) = table(["0000000000 65535 f \n", "not a valid entry!!\n"])
        let stream = Data("%PDF-1.5\n1 0 obj << /Type /XRef >> stream\nxref\nendstream\nendobj\nstartxref\n9\n%%EOF\n".utf8)
        for data in [Data(), Data("not PDF".utf8), bad, malformed, stream, Data(bad.dropLast(12))] {
            #expect(PDFCrossReference.repairingQuartzOutput(data) == data)
        }
    }

    private func reading(ocr: Bool) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: PageLayout.letter)
        let context = try unwrap(CGContext(consumer: unwrap(CGDataConsumer(data: data)), mediaBox: &box, nil))
        context.beginPDFPage(nil)
        if ocr {
            // A raster page plus an invisible searchable text layer, as used by OCR.
            let raster = try unwrap(CGContext(data: nil, width: 120, height: 160, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            raster.setFillColor(CGColor(gray: 1, alpha: 1)); raster.fill(CGRect(x: 0, y: 0, width: 120, height: 160))
            raster.setFillColor(CGColor(gray: 0, alpha: 1)); raster.fill(CGRect(x: 10, y: 140, width: 70, height: 2))
            context.draw(try unwrap(raster.makeImage()), in: box)
            context.setTextDrawingMode(.invisible)
        }
        context.textPosition = CGPoint(x: 72, y: 700)
        let text = ocr ? "OCR academic reading 123" : "café Ελληνικά Пример 中文"
        let font = CTFontCreateWithName("ArialUnicodeMS" as CFString, 16, nil)
        let line = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font
        ])
        CTLineDraw(CTLineCreateWithAttributedString(line), context)
        context.endPDFPage(); context.closePDF()
        return data as Data
    }

    private func retainForIndependentChecks(_ data: Data, name: String) throws {
        if let folder = ProcessInfo.processInfo.environment["MARGIN_MAKER_TEST_OUTPUT"] {
            let directory = URL(fileURLWithPath: folder)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(name + ".pdf"))
        }
    }

    @Test func testMultilingualTextSurvivesBothOrientationsWithNoZeroOffsetObjects() throws {
        let bytes = try reading(ocr: false)
        let source = try PDFSource(data: bytes)
        for orientation in PageOrientation.allCases {
            let data = try PDFExporter.export(source: source, layouts: [PageLayout()], orientation: orientation)
            try retainForIndependentChecks(data, name: "unicode-\(orientation.rawValue)")
            let document = try unwrap(PDFDocument(data: data))
            for word in ["café", "Ελληνικά", "Пример", "中文"] {
                #expect(document.string?.contains(word) == true)
            }
            let tail = String(decoding: data.suffix(2048), as: UTF8.self)
            #expect(!tail.contains("0000000000 00000 n"))
            #expect(document.page(at: 0)?.bounds(for: .mediaBox).size == orientation.pageSize)
        }
    }

    @Test func testInvisibleOCRTextAndRasterPageSurviveBothOrientations() throws {
        let source = try PDFSource(data: reading(ocr: true))
        for orientation in PageOrientation.allCases {
            let data = try PDFExporter.export(source: source, layouts: [PageLayout()], orientation: orientation)
            try retainForIndependentChecks(data, name: "ocr-\(orientation.rawValue)")
            let document = try unwrap(PDFDocument(data: data))
            #expect(document.string?.contains("OCR academic reading 123") == true)
            #expect(document.findString("academic", withOptions: []).count == 1)
            let cg = try PDFSource.open(data)
            let page = try unwrap(cg.page(at: 1))
            var resources: CGPDFDictionaryRef?
            var images: CGPDFDictionaryRef?
            #expect(CGPDFDictionaryGetDictionary(page.dictionary!, "Resources", &resources))
            #expect(CGPDFDictionaryGetDictionary(try unwrap(resources), "XObject", &images))
            #expect(CGPDFDictionaryGetCount(try unwrap(images)) > 0)
        }
    }
}
