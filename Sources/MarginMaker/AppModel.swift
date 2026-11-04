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
    private var previewTask: Task<Void, Never>?
    private var previewRevision = 0

    var canExport: Bool { source != nil && !isBusy }
    var canGoBack: Bool { (settings?.pageIndex ?? 0) > 0 && !isBusy }
    var canGoForward: Bool {
        guard let settings else { return false }
        return settings.pageIndex + 1 < settings.pages.count && !isBusy
    }
    var layout: PageLayout { settings?.current ?? PageLayout() }
    var scope: EditScope { settings?.scope ?? .allPages }
    var documentRotation: DocumentRotation { settings?.rotation ?? .original }

    func choosePDF() {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a reading. Your original PDF stays untouched."
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.open(url) }
        }
    }

    func open(_ url: URL) {
        guard !isBusy else { return }
        isBusy = true
        activity = "Opening PDF…"
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
                isBusy = false
            }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try PDFSource(data: Data(contentsOf: url))
                }.value
                source = loaded
                sourceURL = url
                settings = try DocumentLayout(pageCount: loaded.pageCount)
                exportedURL = nil
                preview = nil
                refreshPreview()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setScope(_ scope: EditScope) { settings?.scope = scope }

    func rotateDocument() {
        guard source != nil, !isBusy else { return }
        settings?.rotateClockwise()
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
        previewTask?.cancel()
        previewRevision += 1
        let revision = previewRevision
        guard let source, let settings else { return }
        previewIsBusy = true
        previewTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(65))
                let worker = Task.detached(priority: .userInitiated) {
                    try PDFExporter.export(source: source, layouts: settings.pages,
                                           rotation: settings.rotation,
                                           pageIndices: [settings.pageIndex])
                }
                let data = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                guard revision == previewRevision else { return }
                guard let document = PDFDocument(data: data) else { throw PDFError.exportFailed }
                preview = document
                previewIsBusy = false
            } catch is CancellationError {
                // A newer slider movement or page selection owns the preview now.
            } catch {
                guard revision == previewRevision else { return }
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
        panel.begin { [weak self] response in
            guard response == .OK, let destination = panel.url else { return }
            Task { @MainActor in self?.export(to: destination) }
        }
    }

    private func export(to destination: URL) {
        guard canExport, let source, let sourceURL, let settings else { return }
        isBusy = true
        activity = "Exporting \(source.pageCount) \(source.pageCount == 1 ? "page" : "pages")…"
        Task {
            let access = destination.startAccessingSecurityScopedResource()
            defer {
                if access { destination.stopAccessingSecurityScopedResource() }
                isBusy = false
            }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PDFExporter.validateDestination(destination, sourceURL: sourceURL)
                    let data = try PDFExporter.export(source: source, layouts: settings.pages,
                                                      rotation: settings.rotation)
                    try PDFExporter.write(data, to: destination, protecting: sourceURL)
                }.value
                exportedURL = destination
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
