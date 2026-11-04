import Testing
import CoreGraphics
import PDFKit
import Darwin
@testable import MarginMakerCore

@Suite(.serialized)
struct SourceFileProtectionTests {
    private let manager = FileManager.default

    private func withReading(_ body: (URL, URL, Data, PDFSource) throws -> Void) throws {
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputDirectory = directory.appendingPathComponent("input")
        try manager.createDirectory(at: inputDirectory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        let bytes = NSMutableData()
        var box = CGRect(origin: .zero, size: PageLayout.letter)
        let context = try unwrap(CGContext(consumer: unwrap(CGDataConsumer(data: bytes)), mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.fill(CGRect(x: 20, y: 30, width: 40, height: 50))
        context.endPDFPage()
        context.closePDF()
        let original = inputDirectory.appendingPathComponent("reading.pdf")
        try (bytes as Data).write(to: original)
        let source = try PDFSource(contentsOf: original)
        try body(directory, original, bytes as Data, source)
    }

    private func output(_ source: PDFSource) throws -> Data {
        try PDFExporter.export(source: source, layouts: [PageLayout()])
    }

    private func reject(_ destination: URL, source: PDFSource) throws {
        let protection = try unwrap(source.fileProtection)
        expectThrows(try PDFExporter.write(output(source), to: destination, protecting: protection)) {
            expectEqual($0 as? PDFError, .originalFile)
        }
    }

    private func assertNoStagingFiles(_ directory: URL) throws {
        let files = try manager.contentsOfDirectory(atPath: directory.path)
        expectFalse(files.contains { $0.hasPrefix(".margin-maker-") })
    }

    @Test(arguments: ["renamed.pdf", "elsewhere/moved.pdf"])
    func testRenamedOrMovedSourceCannotBeReplaced(relativePath: String) throws {
        try withReading { directory, original, bytes, source in
            let moved = directory.appendingPathComponent(relativePath)
            try manager.createDirectory(at: moved.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.moveItem(at: original, to: moved)
            try reject(moved, source: source)
            expectEqual(try Data(contentsOf: moved), bytes)
            expectEqual(source.data, bytes)
            try assertNoStagingFiles(moved.deletingLastPathComponent())
        }
    }

    @Test func testSourceDirectoryRenameAndAliasesRemainProtected() throws {
        try withReading { directory, original, bytes, source in
            let movedDirectory = directory.appendingPathComponent("renamed-input")
            try manager.moveItem(at: original.deletingLastPathComponent(), to: movedDirectory)
            let moved = movedDirectory.appendingPathComponent("reading.pdf")
            let symlink = directory.appendingPathComponent("symbolic.pdf")
            let hardlink = directory.appendingPathComponent("hard.pdf")
            let folderLink = directory.appendingPathComponent("folder-link")
            try manager.createSymbolicLink(at: symlink, withDestinationURL: moved)
            try manager.linkItem(at: moved, to: hardlink)
            try manager.createSymbolicLink(at: folderLink, withDestinationURL: movedDirectory)
            for alias in [moved, symlink, hardlink, folderLink.appendingPathComponent("reading.pdf"),
                          movedDirectory.appendingPathComponent("../renamed-input/reading.pdf")] {
                try reject(alias, source: source)
            }
            let caseAlias = movedDirectory.appendingPathComponent("READING.PDF")
            if manager.fileExists(atPath: caseAlias.path) { try reject(caseAlias, source: source) }
            expectEqual(try Data(contentsOf: moved), bytes)
            expectEqual(try Data(contentsOf: hardlink), bytes)
        }
    }

    @Test func testRetargetedImportSymlinkDoesNotChangeProtectedIdentity() throws {
        try withReading { directory, original, bytes, _ in
            let link = directory.appendingPathComponent("import-link.pdf")
            try manager.createSymbolicLink(at: link, withDestinationURL: original)
            let imported = try PDFSource(contentsOf: link)
            let moved = directory.appendingPathComponent("moved.pdf")
            try manager.moveItem(at: original, to: moved)
            let other = directory.appendingPathComponent("other.pdf")
            try bytes.write(to: other)
            try manager.removeItem(at: link)
            try manager.createSymbolicLink(at: link, withDestinationURL: other)
            try reject(moved, source: imported)
            expectEqual(imported.data, bytes)
            expectEqual(try Data(contentsOf: moved), bytes)
            expectEqual(try Data(contentsOf: other), bytes)
        }
    }

    @Test func testHardLinkImportSurvivesUnlinkAndPathReuse() throws {
        try withReading { directory, original, bytes, _ in
            let link = directory.appendingPathComponent("import-hardlink.pdf")
            try manager.linkItem(at: original, to: link)
            let imported = try PDFSource(contentsOf: link)
            try manager.removeItem(at: link)
            try Data("unrelated replacement".utf8).write(to: link)
            try reject(original, source: imported)
            expectEqual(try Data(contentsOf: original), bytes)
        }
    }

    @Test func testFinderAliasImportAndDestinationRemainProtectedAfterMove() throws {
        try withReading { directory, original, bytes, _ in
            let alias = directory.appendingPathComponent("Finder alias.pdf")
            let bookmark = try original.bookmarkData(options: .suitableForBookmarkFile,
                                                     includingResourceValuesForKeys: nil, relativeTo: nil)
            try URL.writeBookmarkData(bookmark, to: alias)
            expectTrue(try alias.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true)
            let imported = try PDFSource(contentsOf: alias)
            let moved = directory.appendingPathComponent("moved.pdf")
            try manager.moveItem(at: original, to: moved)
            try reject(moved, source: imported)
            try reject(alias, source: imported)
            let newAlias = directory.appendingPathComponent("new alias.pdf")
            let newBookmark = try moved.bookmarkData(options: .suitableForBookmarkFile,
                                                      includingResourceValuesForKeys: nil, relativeTo: nil)
            try URL.writeBookmarkData(newBookmark, to: newAlias)
            try reject(newAlias, source: imported)
            expectEqual(imported.data, bytes)
            expectEqual(try Data(contentsOf: moved), bytes)
        }
    }

    @Test func testDistinctCopyAndNewDestinationCanBeWrittenAfterSourceMove() throws {
        try withReading { directory, original, bytes, source in
            let moved = directory.appendingPathComponent("moved.pdf")
            try manager.moveItem(at: original, to: moved)
            let duplicate = directory.appendingPathComponent("duplicate.pdf")
            try bytes.write(to: duplicate)
            let newFile = directory.appendingPathComponent("new.pdf")
            let protection = try unwrap(source.fileProtection)
            let result = try output(source)
            for destination in [duplicate, newFile] {
                try PDFExporter.write(result, to: destination, protecting: protection)
                expectEqual(try Data(contentsOf: destination), result)
                expectEqual(try unwrap(PDFDocument(url: destination)).pageCount, 1)
            }
            expectEqual(try Data(contentsOf: moved), bytes)
            try assertNoStagingFiles(directory)
        }
    }

    @Test(arguments: ["rename", "symlink", "hardlink"])
    func testDestinationChangedAfterStagingIsRechecked(change: String) throws {
        try withReading { directory, original, bytes, source in
            let destination = directory.appendingPathComponent("output.pdf")
            let protection = try unwrap(source.fileProtection)
            try PDFExporter.validateDestination(destination, protecting: protection)
            do {
                let staged = try StagedPDFWrite(data: output(source), destination: destination)
                switch change {
                case "rename": try manager.moveItem(at: original, to: destination)
                case "symlink": try manager.createSymbolicLink(at: destination, withDestinationURL: original)
                default: try manager.linkItem(at: original, to: destination)
                }
                expectThrows(try staged.commit(protecting: protection)) {
                    expectEqual($0 as? PDFError, .originalFile)
                }
                expectEqual(try Data(contentsOf: destination), bytes)
            }
            try assertNoStagingFiles(directory)
        }
    }

    @Test func testReplacementUsesPinnedDirectoryAfterParentRename() throws {
        try withReading { directory, original, bytes, source in
            let parent = directory.appendingPathComponent("exports")
            try manager.createDirectory(at: parent, withIntermediateDirectories: true)
            let destination = parent.appendingPathComponent("output.pdf")
            let result = try output(source)
            let staged = try StagedPDFWrite(data: result, destination: destination)
            let movedParent = directory.appendingPathComponent("moved-exports")
            try manager.moveItem(at: parent, to: movedParent)
            try manager.createDirectory(at: parent, withIntermediateDirectories: true)
            try manager.linkItem(at: original, to: destination)
            try staged.commit(protecting: unwrap(source.fileProtection))
            expectEqual(try Data(contentsOf: movedParent.appendingPathComponent("output.pdf")), result)
            expectEqual(try Data(contentsOf: destination), bytes)
            expectEqual(try Data(contentsOf: original), bytes)
            try assertNoStagingFiles(movedParent)
        }
    }

    @Test func testFailedCommitPreservesFilesAndRemovesStagingFile() throws {
        try withReading { directory, original, bytes, source in
            let destination = directory.appendingPathComponent("output.pdf")
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            let marker = destination.appendingPathComponent("keep.txt")
            let markerBytes = Data("existing content".utf8)
            try markerBytes.write(to: marker)
            expectThrows(try PDFExporter.write(output(source), to: destination,
                                               protecting: unwrap(source.fileProtection)))
            expectEqual(try Data(contentsOf: marker), markerBytes)
            expectEqual(try Data(contentsOf: original), bytes)
            try assertNoStagingFiles(directory)
        }
    }

    @Test(.enabled(if: geteuid() != 0))
    func testFailedStagingPreservesExistingDestination() throws {
        try withReading { directory, original, bytes, source in
            let parent = directory.appendingPathComponent("read-only")
            try manager.createDirectory(at: parent, withIntermediateDirectories: true)
            let destination = parent.appendingPathComponent("existing.pdf")
            let previous = Data("prior destination".utf8)
            try previous.write(to: destination)
            try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: parent.path)
            defer { try? manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path) }
            expectThrows(try PDFExporter.write(output(source), to: destination,
                                               protecting: unwrap(source.fileProtection)))
            expectEqual(try Data(contentsOf: destination), previous)
            expectEqual(try Data(contentsOf: original), bytes)
            try assertNoStagingFiles(parent)
        }
    }
}
