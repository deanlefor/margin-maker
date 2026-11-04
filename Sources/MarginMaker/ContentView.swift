import SwiftUI
import PDFKit
import MarginMakerCore

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            controls
            Divider()
            workspace
        }
        .tint(.teal)
        .navigationTitle("Margin Maker")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { model.choosePDF() } label: { Label("Open PDF…", systemImage: "folder") }
                    .disabled(model.isBusy)
                    .help("Open a PDF (⌘O)")
            }
            ToolbarItem(placement: .principal) {
                if let url = model.sourceURL {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 280)
                        .padding(.horizontal, 12)
                        .clipped()
                        .help(url.path)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { model.chooseExport() } label: { Label("Export PDF…", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canExport)
                    .help("Export a new PDF (⇧⌘E)")
            }
        }
        .alert("Margin Maker", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 7) {
                Label("Room to think.", systemImage: "rectangle.inset.filled.trailinghalf")
                    .font(.system(size: 19, weight: .semibold))
                Text("Make space for your notes.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Apply changes to").font(.headline)
                Picker(selection: Binding(get: { model.scope }, set: { model.setScope($0) })) {
                    ForEach(EditScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Apply changes to")
                Text(model.scope == .allPages
                     ? "Your next adjustment applies to every page."
                     : "Adjust this page. Other pages keep their settings.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Position").font(.headline)
                VStack(spacing: 7) {
                    ForEach(VerticalAnchor.allCases, id: \.self) { vertical in
                        HStack(spacing: 7) {
                            ForEach(HorizontalAnchor.allCases, id: \.self) { horizontal in
                                anchorButton(horizontal, vertical)
                            }
                        }
                    }
                }
                Text("Leave a margin where you need it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Scale").font(.headline)
                    Spacer()
                    Text("\(model.layout.scalePercent)%")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                }
                Slider(value: Binding(get: { Double(model.layout.scalePercent) }, set: { model.setScale($0) }),
                       in: 50...100, step: 1)
                    .accessibilityLabel("Scale")
                    .accessibilityValue("\(model.layout.scalePercent) percent")
                HStack {
                    Text("50%")
                    Spacer()
                    Text("100% · Fit to Letter")
                }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 8) {
                Label("On your Mac. Only.", systemImage: "lock.shield")
                    .font(.caption.weight(.medium))
                Text("No uploads. No accounts.\nYour original stays untouched.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 256)
        .background(.regularMaterial)
        .disabled(model.source == nil || model.isBusy)
    }

    private func anchorButton(_ horizontal: HorizontalAnchor, _ vertical: VerticalAnchor) -> some View {
        let selected = model.layout.horizontal == horizontal && model.layout.vertical == vertical
        return Button {
            model.setAnchor(horizontal: horizontal, vertical: vertical)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(selected ? Color.teal.opacity(0.65) : Color.secondary.opacity(0.35), lineWidth: 1)
                    .frame(width: 23, height: 29)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(selected ? Color.teal : Color.secondary)
                    .frame(width: 10, height: 13)
                    .offset(x: CGFloat(horizontal.rawValue - 1) * 5,
                            y: CGFloat(vertical.rawValue - 1) * 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 49)
            .background(selected ? Color.teal.opacity(0.13) : Color.primary.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selected ? Color.teal : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(vertical.label) \(horizontal.label.lowercased())")
        .accessibilityLabel("\(vertical.label) \(horizontal.label.lowercased())")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            HStack {
                Label("US Letter", systemImage: "doc")
                Text("8.5 × 11 in").foregroundStyle(.tertiary)
                Spacer()
                if model.settings?.hasCustomPages == true {
                    Text("Individual page settings").foregroundStyle(.secondary)
                }
                Button {
                    model.rotateDocument()
                } label: {
                    Label("Rotate document", systemImage: "rotate.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.primary)
                .disabled(model.source == nil || model.isBusy)
                .help("Rotate every source page 90° clockwise. Four clicks restore the original orientation. Current rotation: \(model.documentRotation.rawValue)°.")
                .accessibilityLabel("Rotate document clockwise")
                .accessibilityValue("\(model.documentRotation.rawValue) degrees clockwise")
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 24).padding(.vertical, 15)

            ZStack {
                if model.source != nil {
                    PDFPreview(document: model.preview)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .opacity(model.previewIsBusy ? 0.55 : 1)
                } else {
                    emptyState
                }
                if model.isBusy || model.previewIsBusy {
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        if model.isBusy { Text(model.activity).font(.caption) }
                    }
                    .padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .frame(width: 130, height: 168)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<10) { index in
                        Capsule().fill(Color.gray.opacity(index == 0 ? 0.4 : 0.2))
                            .frame(width: index == 0 ? 40 : (index % 3 == 0 ? 51 : 66), height: 3)
                    }
                }
                .frame(width: 87, height: 126)
                .background(Color.teal.opacity(0.07))
                .padding(.trailing, 7)
            }
            Text("A little more room for ideas.").font(.title2.weight(.semibold))
            Text("Open a PDF, choose its position, and make room for notes.")
                .font(.body).foregroundStyle(.secondary)
            Button("Open PDF…") { model.choosePDF() }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(model.isBusy)
            Text("Works offline · Selectable text stays selectable")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(30)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if let settings = model.settings {
                Button { model.navigate(-1) } label: { Image(systemName: "chevron.left") }
                    .disabled(!model.canGoBack).help("Previous page (⌘[)")
                    .accessibilityLabel("Previous page")
                Text("Page \(settings.pageIndex + 1) of \(settings.pages.count)")
                    .font(.callout).monospacedDigit()
                Button { model.navigate(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(!model.canGoForward).help("Next page (⌘])")
                    .accessibilityLabel("Next page")
                Spacer()
                if let url = model.exportedURL {
                    Menu {
                        Button("Open Exported PDF") { NSWorkspace.shared.open(url) }
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    } label: { Label("PDF exported", systemImage: "checkmark.circle.fill") }
                        .menuStyle(.borderlessButton).fixedSize()
                        .help(url.path)
                } else {
                    Text("Preview matches export").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("A fresh page for every page of your reading.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 24).frame(height: 54)
    }
}

private struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePage
        view.displayBox = .mediaBox
        view.autoScales = true
        view.backgroundColor = .clear
        view.pageShadowsEnabled = true
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
            view.autoScales = true
        }
    }
}
