import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers
import MarginMakerCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var source: PDFSource?
    @Published private(set) var sourceURL: URL?
    @Published private(set) var settings: DocumentLayout?
    @Published private(set) var preview: PDFDocument?
    @Published private(set) var isBusy = false
    @Published private(set) var previewIsBusy = false
    @Published private(set) var activity = ""
    @Published var errorMessage: String?
    @Published private(set) var exportedURL: URL?
    @Published private(set) var pendingOpenURL: URL?
    @Published private(set) var filePanelIsPresented = false
    private var previewTask: Task<Void, Never>?
    private var previewWorker: Task<Data, Error>?
    private var previewRevision = 0
    private var pendingPreview: PreviewRequest?
    private var openRevision = 0

    private struct PreviewRequest: Sendable {
        let revision: Int
        let source: PDFSource
        let settings: DocumentLayout
    }

    typealias PreviewConversion = @Sendable (PDFSource, [PageLayout], PageOrientation, Int) throws -> Data
    private let loadSource: @Sendable (URL) throws -> PDFSource
    private let convertPreview: PreviewConversion
    private let writeExport: @Sendable (Data, URL, SourceFileProtection) throws -> Void
    private let previewDebounce: Duration

    // Injectable work boundaries let regression tests hold a real worker in flight
    // without relying on machine speed or exposing any extra interface controls.
    init(loadSource: @escaping @Sendable (URL) throws -> PDFSource = { try PDFSource(contentsOf: $0) },
         convertPreview: @escaping PreviewConversion = { source, layouts, orientation, index in
             try PDFExporter.export(source: source, layouts: layouts, orientation: orientation, pageIndices: [index])
         },
         writeExport: @escaping @Sendable (Data, URL, SourceFileProtection) throws -> Void = {
             try PDFExporter.write($0, to: $1, protecting: $2)
         },
         previewDebounce: Duration = .milliseconds(65)) {
        self.loadSource = loadSource
        self.convertPreview = convertPreview
        self.writeExport = writeExport
        self.previewDebounce = previewDebounce
    }

    var canChoosePDF: Bool { !filePanelIsPresented }
    var canExport: Bool { source != nil && !isBusy && !filePanelIsPresented }
    var canGoBack: Bool { (settings?.pageIndex ?? 0) > 0 && !isBusy }
    var canGoForward: Bool {
        guard let settings else { return false }
        return settings.pageIndex + 1 < settings.pages.count && !isBusy
    }
    var layout: PageLayout { settings?.current ?? PageLayout() }
    var scope: EditScope { settings?.scope ?? .allPages }
    var pageOrientation: PageOrientation { settings?.orientation ?? .portrait }

    func choosePDF() {
        guard canChoosePDF else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a reading. Your original PDF stays untouched."
        filePanelIsPresented = true
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                self.filePanelIsPresented = false
                if response == .OK, let url = panel.url { self.open(url) }
                else { self.startPendingOpenIfSafe() }
            }
        }
    }

    func open(_ url: URL) {
        completeOpenRequest(url, revision: beginOpenRequest())
    }

    /// Reserve order at the user action, before an asynchronous drop provider resolves.
    func beginOpenRequest() -> Int {
        openRevision += 1
        pendingOpenURL = nil
        errorMessage = nil
        return openRevision
    }

    func completeOpenRequest(_ url: URL, revision: Int) {
        guard revision == openRevision else { return }
        guard url.isFileURL else {
            failOpenRequest("Choose a local PDF file from your Mac.", revision: revision)
            return
        }
        pendingOpenURL = url
        startPendingOpenIfSafe()
    }

    func failOpenRequest(_ message: String, revision: Int) {
        guard revision == openRevision else { return }
        pendingOpenURL = nil
        errorMessage = message
    }

    private func startPendingOpenIfSafe() {
        guard !isBusy, !filePanelIsPresented, let url = pendingOpenURL else { return }
        let revision = openRevision
        pendingOpenURL = nil
        isBusy = true
        activity = "Opening \(url.lastPathComponent)…"
        let load = loadSource
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
                finishOperation()
            }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try load(url)
                }.value
                // A newer user action supersedes this import, even if its URL is
                // still being decoded. A failed new import keeps the old document.
                guard revision == openRevision else { return }
                let newSettings = try DocumentLayout(pageCount: loaded.pageCount)
                source = loaded
                sourceURL = url
                settings = newSettings
                exportedURL = nil
                preview = nil
                refreshPreview()
            } catch {
                failOpenRequest("Couldn’t open “\(url.lastPathComponent)”. \(error.localizedDescription)",
                                revision: revision)
            }
        }
    }

    private func finishOperation() {
        isBusy = false
        activity = ""
        startPendingOpenIfSafe()
    }

    func setScope(_ scope: EditScope) { settings?.scope = scope }

    func setPageOrientation(_ orientation: PageOrientation) {
        guard source != nil, !isBusy, orientation != pageOrientation else { return }
        settings?.setOrientation(orientation)
        exportedURL = nil
        refreshPreview()
    }

    func setScale(_ scale: Double) {
        var updated = layout
        updated.scalePercent = Int(scale.rounded())
        apply(updated)
    }

    func setAnchor(horizontal: HorizontalAnchor, vertical: VerticalAnchor) {
        var updated = layout
        updated.horizontal = horizontal
        updated.vertical = vertical
        apply(updated)
    }

    private func apply(_ layout: PageLayout) {
        guard !isBusy else { return }
        settings?.apply(layout)
        exportedURL = nil
        refreshPreview()
    }

    func navigate(_ delta: Int) {
        guard let settings, !isBusy else { return }
        self.settings?.selectPage(settings.pageIndex + delta)
        refreshPreview()
    }

    private func refreshPreview() {
        previewRevision += 1
        guard let source, let settings else { return }
        pendingPreview = PreviewRequest(revision: previewRevision, source: source, settings: settings)
        previewIsBusy = true
        previewWorker?.cancel()
        guard previewTask == nil else { return }
        previewTask = Task { await processPreviews() }
    }

    private func processPreviews() async {
        defer { previewTask = nil }
        while let candidate = pendingPreview {
            do {
                try await Task.sleep(for: previewDebounce)
                guard let request = pendingPreview, request.revision == candidate.revision else { continue }
                pendingPreview = nil
                let convert = convertPreview
                let worker = Task.detached(priority: .userInitiated) {
                    try convert(request.source, request.settings.pages, request.settings.orientation,
                                request.settings.pageIndex)
                }
                previewWorker = worker
                // Do not release the single worker slot until drawing actually
                // finishes. Cancellation alone does not stop Core Graphics drawing.
                let data = try await worker.value
                previewWorker = nil
                guard request.revision == previewRevision else { continue }
                guard let document = PDFDocument(data: data) else { throw PDFError.exportFailed }
                preview = document
                previewIsBusy = false
            } catch is CancellationError {
                previewWorker = nil
                // The next iteration owns the latest pending request.
            } catch {
                previewWorker = nil
                guard candidate.revision == previewRevision else { continue }
                previewIsBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func chooseExport() {
        guard canExport, let sourceURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-margins.pdf"
        panel.message = "Save a new PDF with US Letter pages and selectable source text."
        filePanelIsPresented = true
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                self.filePanelIsPresented = false
                if response == .OK, let destination = panel.url { self.export(to: destination) }
                else { self.startPendingOpenIfSafe() }
            }
        }
    }

    func export(to destination: URL) {
        guard canExport, let source, let protection = source.fileProtection, let settings else { return }
        isBusy = true
        activity = "Exporting \(source.pageCount) \(source.pageCount == 1 ? "page" : "pages")…"
        let write = writeExport
        Task {
            let access = destination.startAccessingSecurityScopedResource()
            defer {
                if access { destination.stopAccessingSecurityScopedResource() }
                finishOperation()
            }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PDFExporter.validateDestination(destination, protecting: protection)
                    let data = try PDFExporter.export(source: source, layouts: settings.pages,
                                                      orientation: settings.orientation)
                    try write(data, destination, protection)
                }.value
                exportedURL = destination
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
