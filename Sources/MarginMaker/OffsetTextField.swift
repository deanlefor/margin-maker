import SwiftUI
import AppKit
import MarginMakerCore

enum OffsetAxis: CaseIterable, Hashable {
    case horizontal, vertical

    var label: String { self == .horizontal ? "Horizontal" : "Vertical" }

    func value(in layout: PageLayout) -> Double {
        self == .horizontal ? layout.horizontalOffsetInches : layout.verticalOffsetInches
    }
}

/// Keep AppKit's cursor/selection editing after the initial focus click.
class OffsetNSTextField: NSTextField {
    private var focusSelectionRevision = 0
    private var initialFocusMouseEvent: NSEvent?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { selectOnInitialFocus() }
        return accepted
    }

    override func selectText(_ sender: Any?) {
        let wasEditing = currentEditor() != nil
        super.selectText(sender)
        if !wasEditing { selectOnInitialFocus() }
    }

    func selectOnInitialFocus(event: NSEvent? = NSApp?.currentEvent) {
        initialFocusMouseEvent = event?.type == .leftMouseDown ? event : nil
        focusSelectionRevision += 1
        let revision = focusSelectionRevision
        let initialText = stringValue
        currentEditor()?.selectAll(nil)
        // The shared field editor may not exist until AppKit completes focus.
        // Select once on the next main-loop turn, with guards against later edits.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.focusSelectionRevision == revision,
                  self.stringValue == initialText else { return }
            self.currentEditor()?.selectAll(nil)
        }
    }

    func cancelPendingFocusSelection() { focusSelectionRevision += 1 }

    func isInitialFocusClick(_ event: NSEvent) -> Bool {
        currentEditor() == nil || (initialFocusMouseEvent?.timestamp == event.timestamp &&
                                  initialFocusMouseEvent?.eventNumber == event.eventNumber)
    }

    override func mouseDown(with event: NSEvent) {
        // NSWindow can give the field its editor BEFORE delivering mouseDown.
        // Recognize that same focus event rather than mistaking it for editing.
        let initialClick = isInitialFocusClick(event)
        if !initialClick { cancelPendingFocusSelection() }
        super.mouseDown(with: event)
        // AppKit positions the insertion point during mouseDown, after becoming
        // first responder. Select only on the click that starts this edit session.
        if initialClick { currentEditor()?.selectAll(nil) }
        initialFocusMouseEvent = nil
    }
}

struct OffsetTextField: NSViewRepresentable {
    @Binding var text: String
    let label: String
    let accessibilityHelp: String
    let onEndEditing: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> OffsetNSTextField {
        let field = OffsetNSTextField()
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.isBezeled = true
        field.alignment = .right
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.usesSingleLineMode = true
        field.placeholderString = "0.00"
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: OffsetNSTextField, context: Context) {
        context.coordinator.parent = self
        // Do not reset the field editor or selection on every model update.
        if field.stringValue != text { field.stringValue = text }
        field.isEnabled = isEnabled
        field.setAccessibilityLabel(label)
        field.setAccessibilityHelp(accessibilityHelp)
        field.toolTip = nil
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: OffsetTextField
        init(_ parent: OffsetTextField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            (field as? OffsetNSTextField)?.cancelPendingFocusSelection()
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            (control as? OffsetNSTextField)?.cancelPendingFocusSelection()
            return false // Preserve AppKit's Tab, arrow-key, and editing commands.
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.onEndEditing()
            // Reflect blank restoration immediately, including Tab navigation.
            if let field = notification.object as? NSTextField, field.stringValue != parent.text {
                field.stringValue = parent.text
            }
        }
    }
}
