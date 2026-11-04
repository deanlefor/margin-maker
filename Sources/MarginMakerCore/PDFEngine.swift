import Foundation
import CoreGraphics

public enum PDFError: LocalizedError, Equatable {
    case emptyFile, invalidPDF, locked, noPages, invalidPage, invalidScale
    case layoutCount, invalidPageIndex, exportFailed, originalFile

    public var errorDescription: String? {
        switch self {
        case .emptyFile: "This file is empty. Choose a PDF containing at least one page."
        case .invalidPDF: "This file could not be read as a PDF. Try opening it in Preview and exporting a new PDF."
        case .locked: "This PDF is password-locked. Open it in Preview or your PDF editor and export an unlocked copy first."
        case .noPages: "This PDF has no pages. Choose a PDF containing at least one page."
        case .invalidPage: "A page has invalid dimensions or rotation. Export a fresh copy from your PDF editor and try again."
        case .invalidScale: "Choose a scale between 50% and 100%."
        case .layoutCount: "The page settings do not match this PDF. Reopen the PDF and try again."
        case .invalidPageIndex: "That page is outside this PDF."
        case .exportFailed: "The PDF could not be created. Choose another destination and try again."
        case .originalFile: "Choose a different filename. Margin Maker never replaces the original PDF."
        }
    }
}

/// Immutable file bytes, so preview and export use the same snapshot of the source.
/// Core Graphics documents are created inside each worker, never shared across threads.
public struct PDFSource: Sendable {
    public let data: Data
    public let visiblePageSizes: [CGSize]
    public var pageCount: Int { visiblePageSizes.count }

    public init(data: Data) throws {
        let document = try Self.open(data)
        guard document.numberOfPages > 0 else { throw PDFError.noPages }
        var sizes: [CGSize] = []
        for index in 1...document.numberOfPages {
            guard let page = document.page(at: index) else { throw PDFError.invalidPage }
            let box = page.getBoxRect(.cropBox).intersection(page.getBoxRect(.mediaBox))
            let rotation = ((page.rotationAngle % 360) + 360) % 360
            guard !box.isNull, !box.isInfinite, box.width.isFinite, box.height.isFinite,
                  box.width > 0, box.height > 0, rotation % 90 == 0 else {
                throw PDFError.invalidPage
            }
            sizes.append(rotation == 90 || rotation == 270
                         ? CGSize(width: box.height, height: box.width) : box.size)
        }
        self.data = data
        visiblePageSizes = sizes
    }

    static func open(_ data: Data) throws -> CGPDFDocument {
        guard !data.isEmpty else { throw PDFError.emptyFile }
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else { throw PDFError.invalidPDF }
        if !document.isUnlocked { _ = document.unlockWithPassword("") }
        guard document.isUnlocked else { throw PDFError.locked }
        return document
    }
}

public enum PDFExporter {
    /// Draw original PDF operators into a new PDF context. Never makes a bitmap.
    /// Existing annotations, links, and form widgets are not migrated.
    public static func export(source: PDFSource, layouts: [PageLayout],
                              rotation: DocumentRotation = .original,
                              pageIndices: [Int]? = nil) throws -> Data {
        guard layouts.count == source.pageCount else { throw PDFError.layoutCount }
        let indices = pageIndices ?? Array(0..<source.pageCount)
        guard !indices.isEmpty, indices.allSatisfy({ layouts.indices.contains($0) }) else {
            throw PDFError.invalidPageIndex
        }
        let document = try PDFSource.open(source.data)
        let output = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: PageLayout.letter)
        guard let consumer = CGDataConsumer(data: output),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox,
                                      [kCGPDFContextCreator: "Margin Maker"] as CFDictionary) else {
            throw PDFError.exportFailed
        }
        for index in indices {
            try Task.checkCancellation()
            guard let page = document.page(at: index + 1) else { throw PDFError.invalidPage }
            let visibleSize = rotation.rotatedSize(for: source.visiblePageSizes[index])
            let destination = try layouts[index].placement(for: visibleSize)
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(mediaBox)
            context.saveGState()
            // Clip BEFORE transforming: cropped-out marks must never leak into margins.
            context.clip(to: destination)
            context.translateBy(x: destination.minX, y: destination.minY)
            let scale = destination.width / visibleSize.width
            context.scaleBy(x: scale, y: scale)
            // getDrawingTransform scales down but never up. Normalize the visible
            // page at its original size, then apply our proportional fit explicitly.
            context.concatenate(page.getDrawingTransform(.cropBox,
                                                         rect: CGRect(origin: .zero, size: visibleSize),
                                                         rotate: Int32(rotation.rawValue),
                                                         preserveAspectRatio: true))
            context.drawPDFPage(page)
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
        guard output.length > 0 else { throw PDFError.exportFailed }
        return output as Data
    }

    /// Also rejects symlinks and hard links to the original, including case aliases.
    public static func validateDestination(_ destination: URL, sourceURL: URL) throws {
        let source = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
        let target = destination.standardizedFileURL.resolvingSymlinksInPath()
        guard source != target else { throw PDFError.originalFile }
        let manager = FileManager.default
        if let a = try? manager.attributesOfItem(atPath: source.path),
           let b = try? manager.attributesOfItem(atPath: target.path),
           let sourceInode = a[.systemFileNumber] as? NSNumber,
           let targetInode = b[.systemFileNumber] as? NSNumber,
           sourceInode == targetInode,
           (a[.systemNumber] as? NSNumber) == (b[.systemNumber] as? NSNumber) {
            throw PDFError.originalFile
        }
    }

    public static func write(_ data: Data, to destination: URL, protecting sourceURL: URL) throws {
        try validateDestination(destination, sourceURL: sourceURL)
        try data.write(to: destination, options: .atomic)
    }
}
