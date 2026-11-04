import Testing
import CoreGraphics
import CoreText
import PDFKit
@testable import MarginMakerCore

@Suite(.serialized)
struct PDFEngineTests {
    private func fixture(sizes: [CGSize] = [PageLayout.letter],
                         crop: CGRect? = nil, rotation: Int = 0) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: sizes[0])
        let consumer = try unwrap(CGDataConsumer(data: data))
        let context = try unwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        for (index, size) in sizes.enumerated() {
            var pageBox = CGRect(origin: .zero, size: size)
            let boxData = Data(bytes: &pageBox, count: MemoryLayout<CGRect>.size)
            context.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
            context.setFillColor(CGColor(red: 0.1, green: 0.7, blue: 0.6, alpha: 1))
            context.fill(pageBox)
            // The corner marker makes 90/180/270-degree rotation observable.
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 40, y: 50, width: 20, height: 30))
            context.textPosition = CGPoint(x: 72, y: size.height - 100)
            let text = NSAttributedString(string: "PAGE \(index + 1): selectable academic text", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 16, nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
            ])
            CTLineDraw(CTLineCreateWithAttributedString(text), context)
            context.endPDFPage()
        }
        context.closePDF()
        if crop == nil && rotation == 0 { return data as Data }
        let document = try unwrap(PDFDocument(data: data as Data))
        let page = try unwrap(document.page(at: 0))
        if let crop { page.setBounds(crop, for: .cropBox) }
        page.rotation = rotation
        return try unwrap(document.dataRepresentation())
    }

    private func export(_ data: Data, layout: PageLayout = PageLayout(),
                        rotation: DocumentRotation = .original) throws -> Data {
        let source = try PDFSource(data: data)
        return try PDFExporter.export(source: source,
                                      layouts: Array(repeating: layout, count: source.pageCount),
                                      rotation: rotation)
    }

    /// Render solely for verification. The application's export never uses a bitmap.
    private func raster(_ data: Data, pageIndex: Int = 0) throws -> CGContext {
        let provider = try unwrap(CGDataProvider(data: data as CFData))
        let page = try unwrap(CGPDFDocument(provider)?.page(at: pageIndex + 1))
        let context = try unwrap(CGContext(data: nil, width: 612, height: 792,
                                             bitsPerComponent: 8, bytesPerRow: 612 * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                                CGBitmapInfo.byteOrder32Big.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: PageLayout.letter))
        context.drawPDFPage(page)
        return context
    }

    private func coloredBounds(_ context: CGContext, red: Bool = false) throws -> CGRect {
        let bytes = try unwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var minX = 612, minY = 792, maxX = -1, maxY = -1
        for row in 0..<792 {
            for x in 0..<612 {
                let offset = row * context.bytesPerRow + x * 4
                let matches = red
                    ? bytes[offset] > 180 && bytes[offset + 1] < 120 && bytes[offset + 2] < 120
                    : bytes[offset] < 80 && bytes[offset + 1] > 130 && bytes[offset + 2] > 100
                if matches {
                    // Bitmap rows run from the top; PDF coordinates run from the bottom.
                    let y = 791 - row
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX else { throw PDFError.exportFailed }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func assertRect(_ actual: CGRect, _ expected: CGRect, accuracy: Double = 1,
                            file: StaticString = #filePath, line: UInt = #line) {
        expectEqual(actual.minX, expected.minX, accuracy: accuracy, file: file, line: line)
        expectEqual(actual.minY, expected.minY, accuracy: accuracy, file: file, line: line)
        expectEqual(actual.width, expected.width, accuracy: accuracy, file: file, line: line)
        expectEqual(actual.height, expected.height, accuracy: accuracy, file: file, line: line)
    }

    @Test func testAcceptanceMarginsAt75PercentMiddleRight() throws {
        let layout = PageLayout(horizontal: .right)
        let placement = try layout.placement(for: PageLayout.letter)
        assertRect(placement, CGRect(x: 153, y: 99, width: 459, height: 594), accuracy: 0.0001)
        expectEqual(placement.minX / 72, 2.125)
        expectEqual(placement.minY / 72, 1.375)
        expectEqual((792 - placement.maxY) / 72, 1.375)
        assertRect(try coloredBounds(raster(export(fixture(), layout: layout))), placement)
    }

    @Test func testAllNineAnchorsInGeometryAndRenderedOutput() throws {
        let data = try fixture()
        for horizontal in HorizontalAnchor.allCases {
            for vertical in VerticalAnchor.allCases {
                let layout = PageLayout(scalePercent: 50, horizontal: horizontal, vertical: vertical)
                let expected = CGRect(x: Double(horizontal.rawValue) * 153,
                                      y: Double(2 - vertical.rawValue) * 198,
                                      width: 306, height: 396)
                assertRect(try layout.placement(for: PageLayout.letter), expected)
                assertRect(try coloredBounds(raster(export(data, layout: layout))), expected)
            }
        }
    }

    @Test func testMixedDimensionsFitWithoutDistortionAtScaleLimits() throws {
        let sizes = [PageLayout.letter, CGSize(width: 595.28, height: 841.89),
                     CGSize(width: 1000, height: 500), CGSize(width: 100, height: 300)]
        let input = try fixture(sizes: sizes)
        let source = try PDFSource(data: input)
        for scale in [50, 75, 100] {
            let layout = PageLayout(scalePercent: scale)
            let result = try PDFExporter.export(source: source, layouts: Array(repeating: layout, count: 4))
            let document = try unwrap(PDFDocument(data: result))
            expectEqual(document.pageCount, 4)
            for (index, size) in sizes.enumerated() {
                let page = try unwrap(document.page(at: index))
                expectEqual(page.bounds(for: .mediaBox).size, PageLayout.letter)
                let placed = try layout.placement(for: size)
                expectAtLeast(placed.minX, -0.00001)
                expectAtLeast(placed.minY, -0.00001)
                expectAtMost(placed.maxX, 612.00001)
                expectAtMost(placed.maxY, 792.00001)
                expectEqual(placed.width / placed.height, size.width / size.height, accuracy: 0.00001)
            }
        }
    }

    @Test func testSelectableSearchableTextAndPageOrder() throws {
        let input = try fixture(sizes: [PageLayout.letter, CGSize(width: 595, height: 842)])
        let document = try unwrap(PDFDocument(data: export(input)))
        expectEqual(document.pageCount, 2)
        for index in 0..<2 {
            let page = try unwrap(document.page(at: index))
            expectTrue(page.string?.contains("PAGE \(index + 1): selectable academic text") == true)
            expectEqual(page.rotation, 0)
        }
        let selections = document.findString("academic", withOptions: [])
        expectEqual(selections.count, 2)
        expectFalse(try unwrap(selections.first).bounds(for: document.page(at: 0)!).isEmpty)
    }

    @Test func testAllRotationsPreserveTextSizeAndCornerMarker() throws {
        for angle in [0, 90, 180, 270] {
            let input = try fixture(rotation: angle)
            let source = try PDFSource(data: input)
            let expectedSize = angle % 180 == 0 ? PageLayout.letter : CGSize(width: 792, height: 612)
            expectEqual(source.visiblePageSizes[0], expectedSize)
            let result = try export(input)
            if let folder = ProcessInfo.processInfo.environment["MARGIN_MAKER_TEST_OUTPUT"] {
                let directory = URL(fileURLWithPath: folder)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try input.write(to: directory.appendingPathComponent("source-\(angle).pdf"))
                try result.write(to: directory.appendingPathComponent("export-\(angle).pdf"))
            }
            let document = try unwrap(PDFDocument(data: result))
            expectTrue(document.string?.contains("selectable academic text") == true)
            let placement = try PageLayout().placement(for: expectedSize)
            let image = try raster(result)
            assertRect(try coloredBounds(image), placement)
            // Independent expected rotation of the red lower-left source marker.
            let marker: CGRect
            switch angle {
            case 90: marker = CGRect(x: 50, y: 612 - 60, width: 30, height: 20)
            case 180: marker = CGRect(x: 612 - 60, y: 792 - 80, width: 20, height: 30)
            case 270: marker = CGRect(x: 792 - 80, y: 40, width: 30, height: 20)
            default: marker = CGRect(x: 40, y: 50, width: 20, height: 30)
            }
            let factor = placement.width / expectedSize.width
            let expected = CGRect(x: placement.minX + marker.minX * factor,
                                  y: placement.minY + marker.minY * factor,
                                  width: marker.width * factor, height: marker.height * factor)
            assertRect(try coloredBounds(image, red: true), expected, accuracy: 1.5)
        }
    }

    @Test func testOffsetCropBoxesClipContentForEveryRotation() throws {
        let crop = CGRect(x: 100, y: 110, width: 400, height: 580)
        for angle in [0, 90, 180, 270] {
            let source = try PDFSource(data: fixture(crop: crop, rotation: angle))
            let layout = PageLayout(scalePercent: 75, horizontal: .center, vertical: .top)
            let result = try PDFExporter.export(source: source, layouts: [layout])
            let expectedSize = angle % 180 == 0 ? crop.size : CGSize(width: crop.height, height: crop.width)
            expectEqual(source.visiblePageSizes[0], expectedSize)
            let image = try raster(result)
            assertRect(try coloredBounds(image), try layout.placement(for: expectedSize))
            // The red source marker is outside this crop box and must be clipped away.
            expectThrows(try coloredBounds(image, red: true))
        }
    }

    @Test func testDocumentRotationComposesWithSourceRotationAndPreservesText() throws {
        for sourceAngle in [0, 90, 180, 270] {
            let input = try fixture(rotation: sourceAngle)
            for rotation in DocumentRotation.allCases {
                let result = try export(input, rotation: rotation)
                let document = try unwrap(PDFDocument(data: result))
                let page = try unwrap(document.page(at: 0))
                expectEqual(page.bounds(for: .mediaBox).size, PageLayout.letter)
                expectEqual(page.rotation, 0)
                expectEqual(document.findString("academic", withOptions: []).count, 1)
                let totalAngle = (sourceAngle + rotation.rawValue) % 360
                let size = totalAngle % 180 == 0 ? PageLayout.letter : CGSize(width: 792, height: 612)
                let placement = try PageLayout().placement(for: size)
                let image = try raster(result)
                assertRect(try coloredBounds(image), placement)
                // Known source marker rotated clockwise, calculated independently
                // from Core Graphics and the application's orientation helpers.
                let marker: CGRect
                switch totalAngle {
                case 90: marker = CGRect(x: 50, y: 552, width: 30, height: 20)
                case 180: marker = CGRect(x: 552, y: 712, width: 20, height: 30)
                case 270: marker = CGRect(x: 712, y: 40, width: 30, height: 20)
                default: marker = CGRect(x: 40, y: 50, width: 20, height: 30)
                }
                let factor = placement.width / size.width
                let expected = CGRect(x: placement.minX + marker.minX * factor,
                                      y: placement.minY + marker.minY * factor,
                                      width: marker.width * factor, height: marker.height * factor)
                assertRect(try coloredBounds(image, red: true), expected, accuracy: 1.5)
            }
        }
    }

    @Test func testDocumentRotationClipsOffsetCropsWithEverySourceRotation() throws {
        let crop = CGRect(x: 100, y: 110, width: 400, height: 580)
        for sourceAngle in [0, 90, 180, 270] {
            let input = try fixture(crop: crop, rotation: sourceAngle)
            let layout = PageLayout(scalePercent: 100, horizontal: .right, vertical: .bottom)
            for rotation in DocumentRotation.allCases {
                let result = try export(input, layout: layout, rotation: rotation)
                if let folder = ProcessInfo.processInfo.environment["MARGIN_MAKER_TEST_OUTPUT"] {
                    let directory = URL(fileURLWithPath: folder)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try input.write(to: directory.appendingPathComponent("crop-source-\(sourceAngle).pdf"))
                    try result.write(to: directory.appendingPathComponent("crop-\(sourceAngle)-\(rotation.rawValue).pdf"))
                }
                let totalAngle = (sourceAngle + rotation.rawValue) % 360
                let size = totalAngle % 180 == 0 ? crop.size : CGSize(width: 580, height: 400)
                let image = try raster(result)
                assertRect(try coloredBounds(image), try layout.placement(for: size))
                expectThrows(try coloredBounds(image, red: true))
            }
        }
    }

    @Test func testRotatedMixedPageExportMatchesSinglePagePreview() throws {
        let input = try fixture(sizes: [PageLayout.letter, CGSize(width: 595.28, height: 841.89),
                                        CGSize(width: 1000, height: 500)])
        let source = try PDFSource(data: input)
        let layouts = [PageLayout(scalePercent: 50, horizontal: .left, vertical: .top),
                       PageLayout(scalePercent: 100, horizontal: .right, vertical: .bottom),
                       PageLayout()]
        for rotation in DocumentRotation.allCases {
            let result = try PDFExporter.export(source: source, layouts: layouts, rotation: rotation)
            let document = try unwrap(PDFDocument(data: result))
            expectEqual(document.pageCount, 3)
            for index in 0..<3 {
                let page = try unwrap(document.page(at: index))
                expectEqual(page.bounds(for: .mediaBox).size, PageLayout.letter)
                expectTrue(page.string?.contains("PAGE \(index + 1): selectable academic text") == true)
                let preview = try PDFExporter.export(source: source, layouts: layouts,
                                                     rotation: rotation, pageIndices: [index])
                let fullImage = try raster(result, pageIndex: index)
                let previewImage = try raster(preview)
                expectEqual(Data(bytes: try unwrap(fullImage.data), count: fullImage.bytesPerRow * fullImage.height),
                            Data(bytes: try unwrap(previewImage.data), count: previewImage.bytesPerRow * previewImage.height))
            }
            if let folder = ProcessInfo.processInfo.environment["MARGIN_MAKER_TEST_OUTPUT"] {
                let directory = URL(fileURLWithPath: folder)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try result.write(to: directory.appendingPathComponent("document-rotation-\(rotation.rawValue).pdf"))
            }
        }
        expectEqual(source.data, input)
    }

    @Test func testSmallSourcePagesScaleUpToLetterFitAtEveryRotation() throws {
        let input = try fixture(sizes: [CGSize(width: 100, height: 300)])
        for rotation in DocumentRotation.allCases {
            let visibleSize = rotation.rawValue % 180 == 0
                ? CGSize(width: 100, height: 300) : CGSize(width: 300, height: 100)
            for scale in [50, 75, 100] {
                let layout = PageLayout(scalePercent: scale)
                let result = try export(input, layout: layout, rotation: rotation)
                assertRect(try coloredBounds(raster(result)), try layout.placement(for: visibleSize))
            }
        }
    }

    @Test func testDocumentRotationCyclesIndependentlyOfPageScopeAndLayouts() throws {
        var settings = try DocumentLayout(pageCount: 3)
        expectEqual(settings.rotation, .original)
        settings.scope = .currentPage
        settings.selectPage(1)
        settings.apply(PageLayout(scalePercent: 63, horizontal: .left, vertical: .bottom))
        let pages = settings.pages
        for expected in [DocumentRotation.clockwise90, .clockwise180, .clockwise270, .original] {
            settings.rotateClockwise()
            expectEqual(settings.rotation, expected)
            expectEqual(settings.pages, pages)
            expectEqual(settings.pageIndex, 1)
            expectEqual(settings.scope, .currentPage)
        }
        settings.rotateClockwise()
        settings.scope = .allPages
        settings.apply(PageLayout())
        expectEqual(settings.rotation, .clockwise90)
        expectFalse(settings.hasCustomPages)
        expectEqual(try DocumentLayout(pageCount: 3).rotation, .original)
    }

    @Test func testSinglePagePreviewMatchesThatExportPage() throws {
        let source = try PDFSource(data: fixture(sizes: [PageLayout.letter, PageLayout.letter]))
        let layouts = [PageLayout(), PageLayout(scalePercent: 60, horizontal: .left, vertical: .bottom)]
        let single = try PDFExporter.export(source: source, layouts: layouts, pageIndices: [1])
        let document = try unwrap(PDFDocument(data: single))
        expectEqual(document.pageCount, 1)
        expectTrue(document.string?.contains("PAGE 2") == true)
        assertRect(try coloredBounds(raster(single)), try layouts[1].placement(for: PageLayout.letter))
    }

    @Test func testRejectsInvalidEmptyAndZeroPagePDFs() throws {
        expectThrows(try PDFSource(data: Data())) { expectEqual($0 as? PDFError, .emptyFile) }
        expectThrows(try PDFSource(data: Data("not a PDF".utf8))) {
            expectEqual($0 as? PDFError, .invalidPDF)
        }
        // A valid page tree with zero pages (PDFKit won't serialize an empty document).
        var empty = "%PDF-1.4\n"
        let first = empty.utf8.count
        empty += "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
        let second = empty.utf8.count
        empty += "2 0 obj\n<< /Type /Pages /Kids [] /Count 0 >>\nendobj\n"
        let xref = empty.utf8.count
        empty += "xref\n0 3\n0000000000 65535 f \n"
        empty += String(format: "%010d 00000 n \n%010d 00000 n \n", first, second)
        empty += "trailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        expectThrows(try PDFSource(data: Data(empty.utf8))) {
            let error = $0 as? PDFError
            expectTrue(error == .noPages || error == .invalidPDF)
        }
    }

    @Test func testRejectsPasswordLockedPDFWithActionableMessage() throws {
        let document = try unwrap(PDFDocument(data: fixture()))
        let locked = try unwrap(document.dataRepresentation(options: [
            PDFDocumentWriteOption.userPasswordOption: "secret",
            PDFDocumentWriteOption.ownerPasswordOption: "owner-secret"
        ]))
        expectThrows(try PDFSource(data: locked)) {
            expectEqual($0 as? PDFError, .locked)
            expectTrue($0.localizedDescription.contains("unlocked copy"))
        }
    }

    @Test func testRejectsInvalidSettingsAndIndices() throws {
        let source = try PDFSource(data: fixture())
        for scale in [0, 49, 101] {
            expectThrows(try PDFExporter.export(source: source, layouts: [PageLayout(scalePercent: scale)]))
        }
        expectThrows(try PDFExporter.export(source: source, layouts: []))
        for indices in [[], [-1], [1]] {
            expectThrows(try PDFExporter.export(source: source, layouts: [PageLayout()], pageIndices: indices))
        }
    }

    @Test func testOriginalFileUnchangedAndAllAliasesProtected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("reading.pdf")
        let symlink = directory.appendingPathComponent("symlink.pdf")
        let hardlink = directory.appendingPathComponent("hardlink.pdf")
        let output = directory.appendingPathComponent("reading-margins.pdf")
        let input = try fixture()
        try input.write(to: original)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: original)
        try FileManager.default.linkItem(at: original, to: hardlink)
        let result = try export(input)
        for alias in [original, symlink, hardlink, directory.appendingPathComponent("READING.pdf")] {
            // Case aliases only exist on a case-insensitive volume.
            if FileManager.default.fileExists(atPath: alias.path) {
                expectThrows(try PDFExporter.write(result, to: alias, protecting: original)) {
                    expectEqual($0 as? PDFError, .originalFile)
                }
            }
        }
        try PDFExporter.write(result, to: output, protecting: original)
        expectEqual(try Data(contentsOf: original), input)
        expectEqual(try Data(contentsOf: output), result)
    }

    @Test func testExportedPageSupportsNewHighlightAnnotations() throws {
        let document = try unwrap(PDFDocument(data: export(fixture())))
        let page = try unwrap(document.page(at: 0))
        let selection = try unwrap(document.findString("academic", withOptions: []).first)
        let annotation = PDFAnnotation(bounds: selection.bounds(for: page), forType: .highlight, withProperties: nil)
        page.addAnnotation(annotation)
        let reopened = try unwrap(PDFDocument(data: unwrap(document.dataRepresentation())))
        expectEqual(reopened.page(at: 0)?.annotations.count, 1)
        expectTrue(reopened.string?.contains("academic") == true)
    }

    @Test func testDocumentSettingsDefaultAllPagesAndIndividualOverrides() throws {
        var settings = try DocumentLayout(pageCount: 3)
        expectEqual(settings.scope, .allPages)
        expectEqual(settings.current, PageLayout())
        expectEqual(settings.current.horizontal, .center)
        expectEqual(settings.current.vertical, .middle)
        expectEqual(settings.current.scalePercent, 75)
        assertRect(try settings.current.placement(for: PageLayout.letter),
                   CGRect(x: 76.5, y: 99, width: 459, height: 594), accuracy: 0.0001)
        let first = PageLayout(scalePercent: 80, horizontal: .left, vertical: .top)
        settings.apply(first)
        expectEqual(settings.pages, Array(repeating: first, count: 3))
        settings.scope = .currentPage
        settings.selectPage(1)
        let second = PageLayout(scalePercent: 55, horizontal: .center, vertical: .bottom)
        settings.apply(second)
        expectEqual(settings.pages, [first, second, first])
        expectTrue(settings.hasCustomPages)
        settings.selectPage(0)
        expectEqual(settings.current, first)
        settings.selectPage(99)
        expectEqual(settings.pageIndex, 0)
        settings.scope = .allPages
        // Merely choosing a scope does not silently discard overrides.
        expectTrue(settings.hasCustomPages)
        settings.apply(PageLayout())
        expectFalse(settings.hasCustomPages)
        expectEqual(settings.pages, Array(repeating: PageLayout(), count: 3))
        expectThrows(try DocumentLayout(pageCount: 0))
    }
}
