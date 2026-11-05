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
    @Published private(set) var horizontalOffsetText = "0.00"
    @Published private(set) var verticalOffsetText = "0.00"
    private var lastValidOffsets: [OffsetAxis: Double] = [.horizontal: 0, .vertical: 0]
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
    var canExport: Bool {
        source != nil && !isBusy && !filePanelIsPresented && layoutWarning == nil &&
        OffsetAxis.allCases.allSatisfy { !isBlankOffset($0) }
    }
    var canGoBack: Bool { (settings?.pageIndex ?? 0) > 0 && !isBusy }
    var canGoForward: Bool {
        guard let settings else { return false }
        return settings.pageIndex + 1 < settings.pages.count && !isBusy
    }
    var layout: PageLayout { settings?.current ?? PageLayout() }
    var scope: EditScope { settings?.scope ?? .allPages }
    var pageOrientation: PageOrientation { settings?.orientation ?? .portrait }

    private var offsetInputWarning: String? {
        for axis in OffsetAxis.allCases where !isBlankOffset(axis) {
            if Self.offsetValue(offsetText(axis)) == nil {
                return "\(axis.label) offset: enter a number in \(offsetRangeDescription(axis)) using at most two decimal places (0.01 in increments)."
            }
        }
        return nil
    }

    private func offsetText(_ axis: OffsetAxis) -> String {
        axis == .horizontal ? horizontalOffsetText : verticalOffsetText
    }

    private func isBlankOffset(_ axis: OffsetAxis) -> Bool {
        offsetText(axis).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Ask the unchanged placement calculation for the scaled size at zero
    /// offsets. This keeps displayed limits in agreement with the PDF engine.
    private func offsetLimits(for size: CGSize, layout: PageLayout, orientation: PageOrientation) throws -> CGSize {
        var zero = layout
        zero.horizontalOffsetInches = 0
        zero.verticalOffsetInches = 0
        let placed = try zero.placement(for: size, orientation: orientation)
        let canvas = orientation.pageSize
        return CGSize(width: max(0, (canvas.width - placed.width) / 144),
                      height: max(0, (canvas.height - placed.height) / 144))
    }

    /// An All pages edit applies the current page's scale to every source page.
    /// Existing overrides remain intact until an adjustment, as before.
    func maximumOffset(_ axis: OffsetAxis) -> Double? {
        guard let source, let settings else { return nil }
        let indices = scope == .allPages ? Array(settings.pages.indices) : [settings.pageIndex]
        return indices.compactMap { index -> Double? in
            guard let limits = try? offsetLimits(for: source.visiblePageSizes[index], layout: layout,
                                                 orientation: settings.orientation) else { return nil }
            return axis == .horizontal ? limits.width : limits.height
        }.min()
    }

    static func maximumInHundredths(_ limit: Double) -> Double {
        guard limit.isFinite, limit >= 0 else { return 0 }
        var cents = (limit * 100).rounded(.down)
        // Correct binary multiplication/division at exact cent boundaries,
        // without ever advertising a value above the full-precision limit.
        if (cents + 1) / 100 <= limit { cents += 1 }
        if cents / 100 > limit { cents -= 1 }
        return max(0, cents) / 100
    }

    func maximumInputOffset(_ axis: OffsetAxis) -> Double? {
        maximumOffset(axis).map(Self.maximumInHundredths)
    }

    static func limitText(_ limit: Double) -> String {
        offsetText(maximumInHundredths(limit))
    }

    func offsetRangeDescription(_ axis: OffsetAxis) -> String {
        maximumOffset(axis).map { "0.00–\(Self.limitText($0)) in" } ?? "nonnegative inches (0.01 in increments)"
    }

    /// Check every page, including overrides away from the current preview.
    var layoutWarning: String? {
        if let offsetInputWarning { return offsetInputWarning }
        guard let source, let settings else { return nil }
        for index in settings.pages.indices {
            if let warning = placementWarning(at: index, source: source, settings: settings) {
                return "Page \(index + 1): \(warning)"
            }
        }
        return nil
    }

    var previewWarning: String? {
        if let offsetInputWarning { return offsetInputWarning }
        guard let source, let settings else { return nil }
        return placementWarning(at: settings.pageIndex, source: source, settings: settings)
    }

    private func placementWarning(at index: Int, source: PDFSource, settings: DocumentLayout) -> String? {
        do {
            let page = settings.pages[index]
            let limits = try offsetLimits(for: source.visiblePageSizes[index], layout: page,
                                          orientation: settings.orientation)
            let problems = OffsetAxis.allCases.compactMap { axis -> String? in
                let maximum = axis == .horizontal ? limits.width : limits.height
                guard axis.value(in: page) > Self.maximumInHundredths(maximum) else { return nil }
                return "\(axis.label) offset allows 0.00–\(Self.limitText(maximum)) in"
            }
            if !problems.isEmpty {
                return problems.joined(separator: "; ") + " at \(page.scalePercent)% with \(settings.orientation.rawValue.lowercased()) output. Reduce the offset or choose a smaller scale. Scaling has not changed."
            }
            _ = try page.placement(for: source.visiblePageSizes[index], orientation: settings.orientation)
            return nil
        } catch { return error.localizedDescription }
    }

    static func offsetValue(_ text: String, locale: Locale = .current) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        guard normalized.range(of: #"^(?:[0-9]+(?:\.[0-9]{0,2})?|\.[0-9]{1,2})$"#,
                               options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite, value >= 0 else { return nil }
        return value
    }

    func setHorizontalOffsetText(_ text: String) {
        guard source != nil, !isBusy else { return }
        horizontalOffsetText = text
        applyOffsetInputs()
    }

    func setVerticalOffsetText(_ text: String) {
        guard source != nil, !isBusy else { return }
        verticalOffsetText = text
        applyOffsetInputs()
    }

    private func applyOffsetInputs() {
        exportedURL = nil
        for axis in OffsetAxis.allCases {
            if let value = Self.offsetValue(offsetText(axis)), let maximum = maximumInputOffset(axis), value <= maximum {
                lastValidOffsets[axis] = value
            }
        }
        // Blank is an unfinished edit, not an invalid number. Preview the last
        // accepted value until blur restores its text; export waits for completion.
        let horizontal = isBlankOffset(.horizontal) ? restoredOffset(.horizontal) : Self.offsetValue(horizontalOffsetText)
        let vertical = isBlankOffset(.vertical) ? restoredOffset(.vertical) : Self.offsetValue(verticalOffsetText)
        guard let horizontal, let vertical else {
            refreshPreview()
            return
        }
        var updated = layout
        updated.horizontalOffsetInches = horizontal
        updated.verticalOffsetInches = vertical
        apply(updated)
    }

    private func restoredOffset(_ axis: OffsetAxis) -> Double {
        let previous = lastValidOffsets[axis] ?? 0
        return previous <= (maximumInputOffset(axis) ?? 0) ? previous : 0
    }

    func finishEditingOffset(_ axis: OffsetAxis) {
        let wasBlank = isBlankOffset(axis)
        let value = wasBlank ? restoredOffset(axis) : Self.offsetValue(offsetText(axis))
        if let value {
            let text = Self.offsetText(value)
            if axis == .horizontal { horizontalOffsetText = text }
            else { verticalOffsetText = text }
            // Valid edits already updated the layout while typing. Formatting
            // alone must not apply All pages and erase existing overrides.
            if wasBlank { applyOffsetInputs() }
        }
    }

    private static func offsetText(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(2)))
    }

    private func syncOffsetInputs() {
        horizontalOffsetText = Self.offsetText(layout.horizontalOffsetInches)
        verticalOffsetText = Self.offsetText(layout.verticalOffsetInches)
        for axis in OffsetAxis.allCases {
            let value = axis.value(in: layout)
            lastValidOffsets[axis] = value.isFinite && value >= 0 &&
                value <= (maximumInputOffset(axis) ?? 0) ? value : 0
        }
    }

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
                syncOffsetInputs()
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
        syncOffsetInputs()
        refreshPreview()
    }

    private func refreshPreview() {
        previewRevision += 1
        guard let source, let settings else { return }
        if previewWarning != nil {
            pendingPreview = nil
            previewWorker?.cancel()
            preview = nil
            previewIsBusy = false
            return
        }
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
