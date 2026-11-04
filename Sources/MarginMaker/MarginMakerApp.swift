import SwiftUI
import AppKit

@main
struct MarginMakerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 840, minHeight: 660)
                .onOpenURL { model.open($0) }
        }
        .defaultSize(width: 980, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF…") { model.choosePDF() }
                    .keyboardShortcut("o")
                    .disabled(model.isBusy)
                Button("Export PDF…") { model.chooseExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!model.canExport)
            }
            CommandMenu("Page") {
                Button("Previous Page") { model.navigate(-1) }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!model.canGoBack)
                Button("Next Page") { model.navigate(1) }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!model.canGoForward)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
