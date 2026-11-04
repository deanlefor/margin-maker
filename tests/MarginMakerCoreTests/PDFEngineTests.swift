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
                        orientation: PageOrientation = .portrait) throws -> Data {
        let source = try PDFSource(data: data)
        return try PDFExporter.export(source: source,
                                      layouts: Array(repeating: layout, count: source.pageCount),
                                      orientation: orientation)
    }

    /// Render solely for verification. The application's export never uses a bitmap.
    private func raster(_ data: Data, pageIndex: Int = 0) throws -> CGContext {
        let provider = try unwrap(CGDataProvider(data: data as CFData))
        let page = try unwrap(CGPDFDocument(provider)?.page(at: pageIndex + 1))
        let size = page.getBoxRect(.mediaBox).size
        let width = Int(size.width), height = Int(size.height)
        let context = try unwrap(CGContext(data: nil, width: width, height: height,
                                             bitsPerComponent: 8, bytesPerRow: width * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                                CGBitmapInfo.byteOrder32Big.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.drawPDFPage(page)
        return context
    }

    private func coloredBounds(_ context: CGContext, red: Bool = false) throws -> CGRect {
        let bytes = try unwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var minX = context.width, minY = context.height, maxX = -1, maxY = -1
        for row in 0..<context.height {
            for x in 0..<context.width {
                let offset = row * context.bytesPerRow + x * 4
                let matches = red
                    ? bytes[offset] > 180 && bytes[offset + 1] < 120 && bytes[offset + 2] < 120
                    : bytes[offset] < 80 && bytes[offset + 1] > 130 && bytes[offset + 2] > 100
                if matches {
                    // Bitmap rows run from the top; PDF coordinates run from the bottom.
                    let y = context.height - 1 - row
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

    // Thresholding an antialiased edge can exclude a partially covered pixel.
    // Check each edge within one pixel, rather than accumulating that rounding
    // twice in the width/height. Vector geometry is checked separately.
    private func assertRenderedEdges(_ actual: CGRect, _ expected: CGRect,
                                     file: StaticString = #filePath, line: UInt = #line) {
        expectEqual(actual.minX, expected.minX, accuracy: 1, file: file, line: line)
        expectEqual(actual.minY, expected.minY, accuracy: 1, file: file, line: line)
        expectEqual(actual.maxX, expected.maxX, accuracy: 1, file: file, line: line)
        expectEqual(actual.maxY, expected.maxY, accuracy: 1, file: file, line: line)
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
        for orientation in PageOrientation.allCases {
            let canvas = orientation.pageSize
            let data = try fixture(sizes: [canvas])
            for scale in [50, 75, 100] {
                for horizontal in HorizontalAnchor.allCases {
                    for vertical in VerticalAnchor.allCases {
                        let layout = PageLayout(scalePercent: scale, horizontal: horizontal, vertical: vertical)
                        let width = canvas.width * Double(scale) / 100
                        let height = canvas.height * Double(scale) / 100
                        let expected = CGRect(x: (canvas.width - width) * Double(horizontal.rawValue) / 2,
                                              y: (canvas.height - height) * Double(2 - vertical.rawValue) / 2,
                                              width: width, height: height)
                        assertRect(try layout.placement(for: canvas, orientation: orientation), expected)
                        let result = try export(data, layout: layout, orientation: orientation)
                        assertRect(try coloredBounds(raster(result)), expected)
                    }
                }
            }
        }
    }

    @Test func testMixedDimensionsFitWithoutDistortionAtScaleLimits() throws {
        let sizes = [PageLayout.letter, CGSize(width: 595.28, height: 841.89),
                     CGSize(width: 1000, height: 500), CGSize(width: 100, height: 300)]
        let input = try fixture(sizes: sizes)
        let source = try PDFSource(data: input)
        for orientation in PageOrientation.allCases {
            for scale in [50, 75, 100] {
                let layout = PageLayout(scalePercent: scale)
                let result = try PDFExporter.export(source: source, layouts: Array(repeating: layout, count: 4),
                                                    orientation: orientation)
                let document = try unwrap(PDFDocument(data: result))
                expectEqual(document.pageCount, 4)
                for (index, size) in sizes.enumerated() {
                    let page = try unwrap(document.page(at: index))
                    expectEqual(page.bounds(for: .mediaBox).size, orientation.pageSize)
                    let placed = try layout.placement(for: size, orientation: orientation)
                    expectAtLeast(placed.minX, -0.00001)
                    expectAtLeast(placed.minY, -0.00001)
                    expectAtMost(placed.maxX, orientation.pageSize.width + 0.00001)
                    expectAtMost(placed.maxY, orientation.pageSize.height + 0.00001)
                    expectEqual(placed.width / placed.height, size.width / size.height, accuracy: 0.00001)
                    assertRenderedEdges(try coloredBounds(raster(result, pageIndex: index)), placed)
                }
            }
        }
    }

    @Test func testSelectableSearchableTextAndPageOrder() throws {
        let input = try fixture(sizes: [PageLayout.letter, CGSize(width: 595, height: 842)])
        for orientation in PageOrientation.allCases {
            let document = try unwrap(PDFDocument(data: export(input, orientation: orientation)))
            expectEqual(document.pageCount, 2)
            for index in 0..<2 {
                let page = try unwrap(document.page(at: index))
                expectTrue(page.string?.contains("PAGE \(index + 1): selectable academic text") == true)
                expectEqual(page.rotation, 0)
                expectEqual(page.bounds(for: .mediaBox).size, orientation.pageSize)
            }
            let selections = document.findString("academic", withOptions: [])
            expectEqual(selections.count, 2)
            expectFalse(try unwrap(selections.first).bounds(for: document.page(at: 0)!).isEmpty)
        }
    }

    @Test func testSourceRotationsStayUprightInBothCanvasOrientations() throws {
        for angle in [0, 90, 180, 270] {
            let input = try fixture(rotation: angle)
            let source = try PDFSource(data: input)
            let visibleSize = angle % 180 == 0 ? PageLayout.letter : CGSize(width: 792, height: 612)
            expectEqual(source.visiblePageSizes[0], visibleSize)
            for orientation in PageOrientation.allCases {
                let result = try export(input, orientation: orientation)
                if let folder = ProcessInfo.processInfo.environment["MARGIN_MAKER_TEST_OUTPUT"] {
                    let directory = URL(fileURLWithPath: folder)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try input.write(to: directory.appendingPathComponent("source-\(angle).pdf"))
                    try result.write(to: directory.appendingPathComponent("export-\(orientation.rawValue)-\(angle).pdf"))
                }
                let document = try unwrap(PDFDocument(data: result))
                let page = try unwrap(document.page(at: 0))
                expectEqual(page.bounds(for: .mediaBox).size, orientation.pageSize)
                expectEqual(page.rotation, 0)
                expectEqual(document.findString("academic", withOptions: []).count, 1)
                let placement = try PageLayout().placement(for: visibleSize, orientation: orientation)
                let image = try raster(result)
                assertRect(try coloredBounds(image), placement)
                // Only the imported /Rotate moves this marker. Canvas orientation
                // must never add a quarter turn to the reading.
                let marker: CGRect
                switch angle {
                case 90: marker = CGRect(x: 50, y: 552, width: 30, height: 20)
                case 180: marker = CGRect(x: 552, y: 712, width: 20, height: 30)
                case 270: marker = CGRect(x: 712, y: 40, width: 30, height: 20)
                default: marker = CGRect(x: 40, y: 50, width: 20, height: 30)
                }
                let factor = placement.width / visibleSize.width
                let expected = CGRect(x: placement.minX + marker.minX * factor,
                                      y: placement.minY + marker.minY * factor,
                                      width: marker.width * factor, height: marker.height * factor)
                assertRect(try coloredBounds(image, red: true), expected, accuracy: 1.5)
            }
        }
    }

    @Test func testOffsetCropBoxesClipContentInBothCanvasOrientations() throws {
        let crop = CGRect(x: 100, y: 110, width: 400, height: 580)
        for angle in [0, 90, 180, 270] {
            let source = try PDFSource(data: fixture(crop: crop, rotation: angle))
            let layout = PageLayout(scalePercent: 75, horizontal: .center, vertical: .top)
            let visibleSize = angle % 180 == 0 ? crop.size : CGSize(width: crop.height, height: crop.width)
            expectEqual(source.visiblePageSizes[0], visibleSize)
            for orientation in PageOrientation.allCases {
                let result = try PDFExporter.export(source: source, layouts: [layout], orientation: orientation)
                let image = try raster(result)
                assertRect(try coloredBounds(image), try layout.placement(for: visibleSize, orientation: orientation))
                // The source marker lies outside the crop and must stay invisible.
                expectThrows(try coloredBounds(image, red: true))
            }
        }
    }

    @Test func testLandscapeCanvasKeepsPortraitReadingUprightAt75Percent() throws {
        let layout = PageLayout(horizontal: .right)
        let result = try export(fixture(), layout: layout, orientation: .landscape)
        let image = try raster(result)
        // Portrait Letter fits the 612 pt canvas height, then scales to 75%.
        // A rotated reading would instead occupy a wide, short rectangle.
        let factor = 612.0 / 792.0 * 0.75
        let expected = CGRect(x: 792 - 612 * factor, y: 76.5, width: 612 * factor, height: 459)
        assertRect(try layout.placement(for: PageLayout.letter, orientation: .landscape), expected, accuracy: 0.0001)
        assertRect(try coloredBounds(image), expected)
        let marker = CGRect(x: expected.minX + 40 * factor, y: expected.minY + 50 * factor,
                            width: 20 * factor, height: 30 * factor)
        assertRect(try coloredBounds(image, red: true), marker, accuracy: 1.5)
    }

    @Test func testCroppedSourceOrientationAndEnlargementAt100Percent() throws {
        let crop = CGRect(x: 30, y: 40, width: 200, height: 300)
        let layout = PageLayout(scalePercent: 100, horizontal: .right, vertical: .bottom)
        for angle in [0, 90, 180, 270] {
            let input = try fixture(crop: crop, rotation: angle)
            let size = angle % 180 == 0 ? crop.size : CGSize(width: 300, height: 200)
            let marker: CGRect
            switch angle {
            case 90: marker = CGRect(x: 10, y: 170, width: 30, height: 20)
            case 180: marker = CGRect(x: 170, y: 260, width: 20, height: 30)
            case 270: marker = CGRect(x: 260, y: 10, width: 30, height: 20)
            default: marker = CGRect(x: 10, y: 10, width: 20, height: 30)
            }
            for orientation in PageOrientation.allCases {
                let result = try export(input, layout: layout, orientation: orientation)
                let placement = try layout.placement(for: size, orientation: orientation)
                let image = try raster(result)
                assertRect(try coloredBounds(image), placement)
                let factor = placement.width / size.width
                let expected = CGRect(x: placement.minX + marker.minX * factor,
                                      y: placement.minY + marker.minY * factor,
                                      width: marker.width * factor, height: marker.height * factor)
                assertRect(try coloredBounds(image, red: true), expected, accuracy: 1.5)
            }
        }
    }

    @Test func testMixedPageExportMatchesSinglePagePreviewsInBothOrientations() throws {
        let document = try unwrap(PDFDocument(data: fixture(sizes: [PageLayout.letter,
            CGSize(width: 595.28, height: 841.89), CGSize(width: 1000, height: 500),
            CGSize(width: 320, height: 480)])))
        for (index, angle) in [0, 90, 180, 270].enumerated() {
            try unwrap(document.page(at: index)).rotation = angle
        }
        try unwrap(document.page(at: 1)).setBounds(CGRect(x: 48, y: 30, width: 522, height: 760), for: .cropBox)
        let input = try unwrap(document.dataRepresentation())
        let source = try PDFSource(data: input)
        let layouts = [PageLayout(scalePercent: 50, horizontal: .left, vertical: .top),
                       PageLayout(scalePercent: 100, horizontal: .right, vertical: .bottom),
                       PageLayout(), PageLayout(scalePercent: 63, horizontal: .left, vertical: .bottom)]
        for orientation in PageOrientation.allCases {
            let result = try PDFExporter.export(source: source, layouts: layouts, orientation: orientation)
            let exported = try unwrap(PDFDocument(data: result))
            expectEqual(exported.pageCount, 4)
            for index in 0..<4 {
                let page = try unwrap(exported.page(at: index))
                expectEqual(page.bounds(for: .mediaBox).size, orientation.pageSize)
                expectEqual(page.rotation, 0)
                expectTrue(page.string?.contains("PAGE \(index + 1)") == true)
                let preview = try PDFExporter.export(source: source, layouts: layouts,
                                                     orientation: orientation, pageIndices: [index])
                let fullImage = try raster(result, pageIndex: index)
                let previewImage = try raster(preview)
                expectEqual(Data(bytes: try unwrap(fullImage.data), count: fullImage.bytesPerRow * fullImage.height),
                            Data(bytes: try unwrap(previewImage.data), count: previewImage.bytesPerRow * previewImage.height))
                let size = source.visiblePageSizes[index]
                assertRenderedEdges(try coloredBounds(fullImage), try layouts[index].placement(for: size, orientation: orientation))
            }
            if let folder = ProcessInfo.processInfo.environment["MARGIN_MAKER_TEST_OUTPUT"] {
                let directory = URL(fileURLWithPath: folder)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try input.write(to: directory.appendingPathComponent("mixed-source.pdf"))
                try result.write(to: directory.appendingPathComponent("mixed-\(orientation.rawValue).pdf"))
            }
        }
        expectEqual(source.data, input)
    }

    @Test func testSmallSourcePagesScaleUpInBothCanvasOrientations() throws {
        for angle in [0, 90, 180, 270] {
            let input = try fixture(sizes: [CGSize(width: 100, height: 300)], rotation: angle)
            let visibleSize = angle % 180 == 0 ? CGSize(width: 100, height: 300) : CGSize(width: 300, height: 100)
            for orientation in PageOrientation.allCases {
                for scale in [50, 75, 100] {
                    let layout = PageLayout(scalePercent: scale)
                    let result = try export(input, layout: layout, orientation: orientation)
                    assertRect(try coloredBounds(raster(result)), try layout.placement(for: visibleSize, orientation: orientation))
                }
            }
        }
    }

    @Test func testPageOrientationPreservesScopePageIndexAndIndividualLayouts() throws {
        var settings = try DocumentLayout(pageCount: 3)
        expectEqual(settings.orientation, .portrait)
        settings.scope = .currentPage
        settings.selectPage(1)
        settings.apply(PageLayout(scalePercent: 63, horizontal: .left, vertical: .bottom))
        let pages = settings.pages
        for orientation in [PageOrientation.landscape, .portrait, .landscape] {
            settings.setOrientation(orientation)
            expectEqual(settings.orientation, orientation)
            expectEqual(settings.pages, pages)
            expectEqual(settings.pageIndex, 1)
            expectEqual(settings.scope, .currentPage)
        }
        settings.scope = .allPages
        settings.apply(PageLayout())
        expectEqual(settings.orientation, .landscape)
        expectFalse(settings.hasCustomPages)
        expectEqual(try DocumentLayout(pageCount: 3).orientation, .portrait)
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
        let source = try PDFSource(contentsOf: original)
        let protection = try unwrap(source.fileProtection)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: original)
        try FileManager.default.linkItem(at: original, to: hardlink)
        let result = try export(input)
        for alias in [original, symlink, hardlink, directory.appendingPathComponent("READING.pdf")] {
            // Case aliases only exist on a case-insensitive volume.
            if FileManager.default.fileExists(atPath: alias.path) {
                expectThrows(try PDFExporter.write(result, to: alias, protecting: protection)) {
                    expectEqual($0 as? PDFError, .originalFile)
                }
            }
        }
        try PDFExporter.write(result, to: output, protecting: protection)
        expectEqual(try Data(contentsOf: original), input)
        expectEqual(try Data(contentsOf: output), result)
    }

    @Test func testExportedPageSupportsNewHighlightAnnotations() throws {
        let input = try fixture()
        for orientation in PageOrientation.allCases {
            let document = try unwrap(PDFDocument(data: export(input, orientation: orientation)))
            let page = try unwrap(document.page(at: 0))
            let selection = try unwrap(document.findString("academic", withOptions: []).first)
            let annotation = PDFAnnotation(bounds: selection.bounds(for: page), forType: .highlight, withProperties: nil)
            page.addAnnotation(annotation)
            let reopened = try unwrap(PDFDocument(data: unwrap(document.dataRepresentation())))
            expectEqual(reopened.page(at: 0)?.annotations.count, 1)
            expectEqual(reopened.page(at: 0)?.bounds(for: .mediaBox).size, orientation.pageSize)
            expectTrue(reopened.string?.contains("academic") == true)
        }
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
