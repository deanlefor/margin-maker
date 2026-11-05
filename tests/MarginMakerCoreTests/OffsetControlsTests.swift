import Testing
import PDFKit
@testable import MarginMakerCore
@testable import MarginMaker

@MainActor
@Suite(.serialized)
struct OffsetControlsTests {
    @Test func testNumericInputRejectsInvalidValuesAndSupportsDecimalLocales() {
        for text in ["", " ", "-0.25", "NaN", "inf", "1e999", "0.5 inches", "1,000",
                     "0.001", "0.500", "1.234", "1e-2", "0x1p0"] {
            #expect(AppModel.offsetValue(text, locale: Locale(identifier: "en_US")) == nil)
        }
        for (text, value) in [("0", 0.0), (".25", 0.25), ("0.5", 0.5), (" 0.75 ", 0.75)] {
            #expect(AppModel.offsetValue(text, locale: Locale(identifier: "en_US")) == value)
        }
        #expect(AppModel.offsetValue("0,25", locale: Locale(identifier: "de_DE")) == 0.25)
        #expect(AppModel.offsetValue("0,251", locale: Locale(identifier: "de_DE")) == nil)
    }

    @Test func testBlankDraftKeepsPreviewAndRestoresLastValueOnBlur() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        #expect(model.horizontalOffsetText == "0.00")
        #expect(model.verticalOffsetText == "0.00")
        model.setHorizontalOffsetText("0.5")
        model.setVerticalOffsetText("0.75")
        try await settled(model)
        #expect(model.layout.horizontalOffsetInches == 0.5)
        #expect(model.layout.verticalOffsetInches == 0.75)
        #expect(model.canExport)
        model.setHorizontalOffsetText("")
        #expect(!model.canExport)
        try await settled(model)
        #expect(model.preview != nil)
        #expect(model.layoutWarning == nil)
        let destination = files.directory.appendingPathComponent("blocked.pdf")
        model.export(to: destination)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        model.finishEditingOffset(.horizontal)
        #expect(AppModel.offsetValue(model.horizontalOffsetText) == 0.5)
        #expect(model.canExport)
        model.setHorizontalOffsetText("0.25")
        try await settled(model)
        #expect(model.canExport)
        #expect(model.preview != nil)
        #expect(model.errorMessage == nil)
        #expect(model.layout.scalePercent == 75)
    }

    @Test func testBothFieldsRestoreBlankAndAcceptDecimalEdits() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        for axis in OffsetAxis.allCases {
            let set: (String) -> Void = axis == .horizontal ? model.setHorizontalOffsetText : model.setVerticalOffsetText
            let text: () -> String = { axis == .horizontal ? model.horizontalOffsetText : model.verticalOffsetText }
            set("")
            model.finishEditingOffset(axis)
            #expect(AppModel.offsetValue(text()) == 0)
            for value in ["1", "0.5", "0.75"] {
                set(value)
                model.finishEditingOffset(axis)
                #expect(AppModel.offsetValue(text()) == Double(value))
                #expect(model.layoutWarning == nil)
            }
            set("   ")
            #expect(model.layoutWarning == nil)
            model.finishEditingOffset(axis)
            #expect(AppModel.offsetValue(text()) == 0.75)
            set("9")
            #expect(model.layoutWarning?.contains(axis.label) == true)
            let limit = AppModel.limitText(try unwrap(model.maximumOffset(axis)))
            #expect(model.layoutWarning?.contains(limit) == true)
            #expect(!model.canExport)
            set("")
            model.finishEditingOffset(axis)
            #expect(AppModel.offsetValue(text()) == 0.75)
        }
        try await settled(model)
        #expect(model.canExport)
    }

    @Test func testInvalidTextReportsRangeAndRemainsEditableAfterBlur() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        for axis in OffsetAxis.allCases {
            let set: (String) -> Void = axis == .horizontal ? model.setHorizontalOffsetText : model.setVerticalOffsetText
            for text in ["-1", "abc", "NaN"] {
                set(text)
                model.finishEditingOffset(axis)
                #expect(model.layoutWarning?.contains(axis.label) == true)
                #expect(model.layoutWarning?.contains(model.offsetRangeDescription(axis)) == true)
                #expect(!model.canExport)
            }
            set("0.5")
        }
        try await settled(model)
        #expect(model.canExport)
    }

    @Test func testLimitsUpdateWithScaleAndBlankFallsBackToZeroWhenPriorValueNoLongerFits() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        #expect(model.maximumOffset(.horizontal) == 1.0625)
        #expect(model.maximumOffset(.vertical) == 1.375)
        model.setScale(50)
        #expect(model.maximumOffset(.horizontal) == 2.125)
        #expect(model.maximumOffset(.vertical) == 2.75)
        model.setHorizontalOffsetText("0.5")
        model.setVerticalOffsetText("0.75")
        model.setScale(100)
        #expect(model.maximumOffset(.horizontal) == 0)
        #expect(model.maximumOffset(.vertical) == 0)
        #expect(model.layoutWarning?.contains("0.00–0.00 in") == true)
        model.setHorizontalOffsetText("")
        model.finishEditingOffset(.horizontal)
        model.setVerticalOffsetText("")
        model.finishEditingOffset(.vertical)
        #expect(AppModel.offsetValue(model.horizontalOffsetText) == 0)
        #expect(AppModel.offsetValue(model.verticalOffsetText) == 0)
        #expect(model.layout.horizontalOffsetInches == 0)
        #expect(model.layout.verticalOffsetInches == 0)
        try await settled(model)
        #expect(model.canExport)
    }

    @Test func testRangeUsesScopeSourceSizeCropRotationAndOrientation() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let doc = try unwrap(PDFDocument(data: AppTestFiles.pdf("CROPPED")))
        let page = try unwrap(doc.page(at: 0))
        page.setBounds(CGRect(x: 30, y: 40, width: 200, height: 400), for: .cropBox)
        let other = try unwrap(PDFDocument(data: AppTestFiles.pdf("LETTER")))
        doc.insert(try unwrap(other.page(at: 0)), at: 1)
        try unwrap(doc.dataRepresentation()).write(to: files.first)
        let model = AppModel(previewDebounce: .zero)
        model.open(files.first)
        try await settled(model)
        #expect(model.maximumOffset(.horizontal) == 1.0625) // Smallest allowance across both pages.
        model.setScope(.currentPage)
        #expect(model.maximumOffset(.horizontal) == 2.1875)
        #expect(model.maximumOffset(.vertical) == 1.375)
        model.navigate(1)
        #expect(model.maximumOffset(.horizontal) == 1.0625)
        model.navigate(-1)
        model.setScale(50)
        model.setScope(.allPages)
        #expect(model.maximumOffset(.horizontal) == 2.125)
        #expect(model.settings?.pages[1].scalePercent == 75) // Scope alone preserves overrides.
        model.setHorizontalOffsetText("0")
        #expect(model.settings?.pages.allSatisfy { $0.scalePercent == 50 } == true)
        page.rotation = 90
        try unwrap(doc.dataRepresentation()).write(to: files.second)
        model.open(files.second)
        try await settled(model)
        model.setScope(.currentPage)
        #expect(model.maximumOffset(.horizontal) == 1.0625)
        #expect(model.maximumOffset(.vertical) == 3.90625)
        model.setPageOrientation(.landscape)
        #expect(model.maximumOffset(.horizontal) == 1.375)
        #expect(model.maximumOffset(.vertical) == 2.1875)
        let maximum = try unwrap(model.maximumOffset(.horizontal))
        let displayed = try unwrap(AppModel.offsetValue(AppModel.limitText(maximum)))
        #expect(displayed <= maximum)
        model.setHorizontalOffsetText(AppModel.limitText(maximum))
        model.finishEditingOffset(.horizontal)
        try await settled(model)
        #expect(model.canExport)
    }

    @Test func testDisplayedLimitAvoidsFloatingPointNoiseAndRemainsAccepted() async throws {
        #expect(AppModel.limitText(1.0625.nextDown) == "1.06")
        #expect(AppModel.limitText(1.375) == "1.37")
        #expect(AppModel.limitText(0) == "0.00")
        #expect(AppModel.limitText(0.29) == "0.29")
        #expect(AppModel.limitText(1.06.nextDown) == "1.05")
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        for axis in OffsetAxis.allCases {
            let set: (String) -> Void = axis == .horizontal ? model.setHorizontalOffsetText : model.setVerticalOffsetText
            let maximum = AppModel.limitText(try unwrap(model.maximumOffset(axis)))
            set(maximum)
            #expect(model.layoutWarning == nil)
            set("")
            model.finishEditingOffset(axis)
            let restored = axis == .horizontal ? model.horizontalOffsetText : model.verticalOffsetText
            #expect(AppModel.offsetValue(restored) == AppModel.offsetValue(maximum))
        }
        try await settled(model)
        #expect(model.canExport)
    }

    @Test func testTwoDecimalFormattingOnBlurRestorationAndNavigation() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let doc = try unwrap(PDFDocument(data: AppTestFiles.pdf("FIRST")))
        doc.insert(try unwrap(PDFDocument(data: AppTestFiles.pdf("SECOND"))?.page(at: 0)), at: 1)
        try unwrap(doc.dataRepresentation()).write(to: files.first)
        let model = AppModel(previewDebounce: .zero)
        model.open(files.first)
        try await settled(model)
        for axis in OffsetAxis.allCases {
            let set: (String) -> Void = axis == .horizontal ? model.setHorizontalOffsetText : model.setVerticalOffsetText
            let text: () -> String = { axis == .horizontal ? model.horizontalOffsetText : model.verticalOffsetText }
            for (draft, formatted) in [("0", "0.00"), ("1", "1.00"), (".5", "0.50"), ("0.75", "0.75")] {
                set(draft)
                model.finishEditingOffset(axis)
                #expect(text() == formatted)
            }
            set("")
            model.finishEditingOffset(axis)
            #expect(text() == "0.75")
        }
        model.navigate(1)
        #expect(model.horizontalOffsetText == "0.75")
        #expect(model.verticalOffsetText == "0.75")
        model.setScope(.currentPage)
        model.setScale(50)
        model.navigate(-1)
        model.setScope(.allPages)
        let overrides = model.settings?.pages
        model.finishEditingOffset(.horizontal)
        model.finishEditingOffset(.vertical)
        #expect(model.settings?.pages == overrides) // Formatting is not an All pages adjustment.
        try await settled(model)
    }

    @Test func testExcessPrecisionIsRejectedWithoutRoundingOrApplyingIt() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        for axis in OffsetAxis.allCases {
            let set: (String) -> Void = axis == .horizontal ? model.setHorizontalOffsetText : model.setVerticalOffsetText
            set("0.50")
            set("0.501")
            model.finishEditingOffset(axis)
            #expect(axis.value(in: model.layout) == 0.50)
            #expect(model.layoutWarning?.contains("two decimal places") == true)
            #expect(model.layoutWarning?.contains(model.offsetRangeDescription(axis)) == true)
            #expect(!model.canExport)
            set("")
            model.finishEditingOffset(axis)
        }
        try await settled(model)
        #expect(model.canExport)
    }

    @Test func testEveryAdvertisedCentBoundaryFitsWithoutRoundingGeometry() async throws {
        for limit in [0.0, 0.009, 0.01, 0.29, 1.06.nextDown, 1.0625, 1.375, 3.036931818181818] {
            let rounded = AppModel.maximumInHundredths(limit)
            #expect(rounded <= limit)
            #expect(rounded + 0.01 > limit)
            #expect(AppModel.offsetValue(AppModel.limitText(limit), locale: .current) == rounded)
        }
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        for orientation in PageOrientation.allCases {
            model.setPageOrientation(orientation)
            for scale in [50, 75, 100] {
                model.setScale(Double(scale))
                let horizontalMaximum = AppModel.limitText(try unwrap(model.maximumOffset(.horizontal)))
                let verticalMaximum = AppModel.limitText(try unwrap(model.maximumOffset(.vertical)))
                model.setHorizontalOffsetText(horizontalMaximum)
                model.setVerticalOffsetText(verticalMaximum)
                #expect(model.canExport)
                let placed = try model.layout.placement(for: PageLayout.letter, orientation: orientation)
                var zero = model.layout
                zero.horizontalOffsetInches = 0
                zero.verticalOffsetInches = 0
                #expect(placed.size == (try zero.placement(for: PageLayout.letter, orientation: orientation)).size)
            }
        }
        // UI precision must never restrict the underlying PDF engine's API.
        let precise = PageLayout(horizontalOffsetInches: 1.0625, verticalOffsetInches: 1.375)
        #expect(try precise.placement(for: PageLayout.letter) == CGRect(x: 76.5, y: 99, width: 459, height: 594))
        try await settled(model)
    }

    @Test func testOffscreenInvalidPageBlocksWholeExportAndOrientationRevalidates() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let document = try unwrap(PDFDocument(data: AppTestFiles.pdf("FIRST")))
        let wide = try unwrap(document.page(at: 0))
        wide.setBounds(CGRect(x: 0, y: 0, width: 1000, height: 500), for: .mediaBox)
        let second = try unwrap(PDFDocument(data: AppTestFiles.pdf("SECOND")))
        document.insert(try unwrap(second.page(at: 0)), at: 1)
        try unwrap(document.dataRepresentation()).write(to: files.first)
        let model = AppModel(previewDebounce: .zero)
        model.open(files.first)
        try await settled(model)
        model.setVerticalOffsetText("2")
        try await settled(model)
        #expect(model.preview != nil)
        #expect(model.previewWarning == nil)
        #expect(model.layoutWarning?.hasPrefix("Page 2:") == true)
        #expect(!model.canExport)
        model.navigate(1)
        #expect(model.previewWarning != nil)
        #expect(model.preview == nil)
        #expect(model.layout.scalePercent == 75)
        model.setScale(50)
        try await settled(model)
        #expect(model.canExport)
        model.setVerticalOffsetText("2.25")
        try await settled(model)
        #expect(model.canExport)
        model.setPageOrientation(.landscape)
        try await settled(model)
        #expect(!model.canExport)
        #expect(model.layout.scalePercent == 50)
        model.setVerticalOffsetText("0.5")
        try await settled(model)
        #expect(model.canExport)
    }

    @Test func testOffsetsFollowScopeAndExportWithoutModifyingOriginal() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let document = try unwrap(PDFDocument(data: AppTestFiles.pdf("FIRST")))
        document.insert(try unwrap(PDFDocument(data: AppTestFiles.pdf("SECOND"))?.page(at: 0)), at: 1)
        let original = try unwrap(document.dataRepresentation())
        try original.write(to: files.first)
        let model = AppModel(previewDebounce: .zero)
        model.open(files.first)
        try await settled(model)
        model.setHorizontalOffsetText("0.25")
        model.setVerticalOffsetText("0.5")
        #expect(model.settings?.pages.allSatisfy { $0.horizontalOffsetInches == 0.25 } == true)
        model.setScope(.currentPage)
        model.navigate(1)
        model.setHorizontalOffsetText("0.75")
        model.setAnchor(horizontal: .right, vertical: .top)
        try await settled(model)
        #expect(model.settings?.pages[0].horizontalOffsetInches == 0.25)
        #expect(model.settings?.hasCustomPages == true)
        model.navigate(-1)
        #expect(AppModel.offsetValue(model.horizontalOffsetText) == 0.25)
        model.navigate(1)
        #expect(AppModel.offsetValue(model.horizontalOffsetText) == 0.75)
        try await settled(model)
        let previewText = model.preview?.string
        let destination = files.directory.appendingPathComponent("offset-export.pdf")
        model.export(to: destination)
        try await settled(model)
        #expect(model.errorMessage == nil)
        #expect(model.exportedURL == destination)
        let result = try unwrap(PDFDocument(url: destination))
        #expect(result.pageCount == 2)
        #expect(result.page(at: 0)?.string?.contains("FIRST") == true)
        #expect(result.page(at: 1)?.string == previewText)
        #expect(try Data(contentsOf: files.first) == original)
        model.setScope(.allPages)
        model.setHorizontalOffsetText("0")
        #expect(model.settings?.pages.allSatisfy { $0.horizontalOffsetInches == 0 } == true)
        #expect(model.exportedURL == nil)
        try await settled(model)
    }
}

struct AppVersionTests {
    @Test func testDisplayUsesBundleVersionBuildAndChannel() {
        #expect(AppVersion(info: ["CFBundleShortVersionString": "1.2.3", "CFBundleVersion": "9",
                                 "MarginMakerBuildChannel": "Development"]).label == "v1.2.3 · Development (9)")
        #expect(AppVersion(info: ["CFBundleShortVersionString": "1.2.3", "CFBundleVersion": "10",
                                 "MarginMakerBuildChannel": "Release"]).label == "v1.2.3 (10)")
    }

    @Test func testUnbundledBuildDoesNotInventAReleaseVersion() {
        #expect(AppVersion(info: [:]).label == "Unbundled development build")
        #expect(AppVersion(info: ["CFBundleShortVersionString": ""]).label == "Unbundled development build")
    }

    @Test func testPackagingMetadataIdentifiesSeparateDevelopmentApp() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Packaging/Info.plist"))
        let info = try unwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(info["MarginMakerBuildChannel"] as? String == "Development")
        #expect(info["CFBundleIdentifier"] as? String == "local.marginmaker.development")
        #expect(info["CFBundleName"] as? String == "Margin Maker Dev")
        let version = try unwrap(info["CFBundleShortVersionString"] as? String)
        let build = try unwrap(info["CFBundleVersion"] as? String)
        #expect(AppVersion(info: info).label == "v\(version) · Development (\(build))")
    }
}
