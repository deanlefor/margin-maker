// Development-only probe, compiled with Sources/MarginMakerCore/*.swift.
import Foundation
import CoreGraphics
import PDFKit

@main struct PDFCompatibilityProbe {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        for name in ["actualtext", "unicode", "ocr"] {
            let bytes = try Data(contentsOf: directory.appendingPathComponent(name + ".pdf"))
            let source = try PDFSource(data: bytes)
            for orientation in PageOrientation.allCases {
                let result = try PDFExporter.export(source: source,
                    layouts: Array(repeating: PageLayout(), count: source.pageCount), orientation: orientation)
                try result.write(to: directory.appendingPathComponent("\(name)-\(orientation.rawValue).pdf"))
            }
            // Isolate framework behavior from all Margin Maker layout and repair code.
            let page = CGPDFDocument(CGDataProvider(data: bytes as CFData)!)!.page(at: 1)!
            let output = NSMutableData()
            var box = page.getBoxRect(.mediaBox)
            let context = CGContext(consumer: CGDataConsumer(data: output)!, mediaBox: &box, nil)!
            context.beginPDFPage(nil); context.drawPDFPage(page)
            context.endPDFPage(); context.closePDF()
            try (output as Data).write(to: directory.appendingPathComponent("\(name)-bare-quartz.pdf"))
        }
        let source = try Data(contentsOf: directory.appendingPathComponent("actualtext.pdf"))
        let document = PDFDocument(data: source)!
        try document.dataRepresentation()!.write(to: directory.appendingPathComponent("actualtext-pdfkit-resave.pdf"))
    }
}
