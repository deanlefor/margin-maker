import Testing
import SwiftUI
import AppKit
@testable import MarginMaker

@MainActor
@Suite(.serialized)
struct OffsetTextFieldTests {
    private class DeferredEditorField: OffsetNSTextField {
        var simulatedEditor: NSText?
        override func currentEditor() -> NSText? { simulatedEditor }
    }

    @Test func testInitialSelectionWaitsForFieldEditorCreation() async throws {
        let field = DeferredEditorField()
        field.stringValue = "0.75"
        let editor = NSTextView()
        editor.string = field.stringValue
        field.selectOnInitialFocus() // AppKit has not attached its editor yet.
        field.simulatedEditor = editor
        try await eventually("newly attached editor selects all") {
            editor.selectedRange() == NSRange(location: 0, length: 4)
        }
    }

    @Test func testDeferredSelectionDoesNotOverrideLaterCursorOrTextEdits() async throws {
        for changedText in [false, true] {
            let field = DeferredEditorField()
            field.stringValue = "0.75"
            let editor = NSTextView()
            editor.string = field.stringValue
            field.selectOnInitialFocus()
            field.simulatedEditor = editor
            if changedText {
                field.stringValue = "0.5"
                editor.string = "0.5"
            } else {
                field.cancelPendingFocusSelection() // Another click/keyboard command.
            }
            editor.setSelectedRange(NSRange(location: 1, length: 0))
            try await Task.sleep(for: .milliseconds(10))
            #expect(editor.selectedRange() == NSRange(location: 1, length: 0))
        }
    }

    @Test func testFocusClickIsRecognizedWhenAppKitAttachesEditorBeforeMouseDown() throws {
        let field = DeferredEditorField()
        field.stringValue = "0"
        let click = try unwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
                                                modifierFlags: [], timestamp: 12, windowNumber: 0,
                                                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let later = try unwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
                                                modifierFlags: [], timestamp: 13, windowNumber: 0,
                                                context: nil, eventNumber: 2, clickCount: 1, pressure: 1))
        field.selectOnInitialFocus(event: click)
        field.simulatedEditor = NSTextView()
        #expect(field.isInitialFocusClick(click))
        #expect(!field.isInitialFocusClick(later))
        // Keyboard focus must not turn the next ordinary mouse click into select-all.
        field.selectOnInitialFocus(event: nil)
        #expect(!field.isInitialFocusClick(later))
        field.cancelPendingFocusSelection()
    }

    @Test func testNativeDelegateAcceptsEditsAndRestoresBlankOnEndEditing() async throws {
        let files = try AppTestFiles()
        defer { files.remove() }
        let model = AppModel(previewDebounce: .zero)
        model.open(files.old)
        try await settled(model)
        for axis in OffsetAxis.allCases {
            let binding = Binding<String>(
                get: { axis == .horizontal ? model.horizontalOffsetText : model.verticalOffsetText },
                set: { axis == .horizontal ? model.setHorizontalOffsetText($0) : model.setVerticalOffsetText($0) })
            let wrapper = OffsetTextField(text: binding, label: axis.label, accessibilityHelp: "",
                                          onEndEditing: { model.finishEditingOffset(axis) })
            let coordinator = wrapper.makeCoordinator()
            let field = OffsetNSTextField()
            for value in ["1", "0.5", "0.75"] {
                field.stringValue = value
                coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
                coordinator.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
                #expect(AppModel.offsetValue(binding.wrappedValue) == Double(value))
                #expect(field.stringValue == String(format: "%.2f", Double(value)!))
            }
            field.stringValue = ""
            coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
            #expect(binding.wrappedValue.isEmpty)
            #expect(model.layoutWarning == nil)
            coordinator.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
            #expect(AppModel.offsetValue(field.stringValue) == 0.75)
            #expect(field.stringValue == binding.wrappedValue)
        }
        try await settled(model)
        #expect(model.canExport)
    }
}
