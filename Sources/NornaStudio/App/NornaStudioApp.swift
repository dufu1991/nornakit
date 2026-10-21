import AppKit
import SwiftUI

@main
struct NornaStudioApp: App {
    @StateObject private var model = StudioModel()
    @NSApplicationDelegateAdaptor(StudioAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Norna Studio") {
            StudioView(model: model)
                .frame(minWidth: 860, minHeight: 640)
        }
        .defaultSize(width: 1320, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开 Mermaid 文件…".studioLocalized, action: model.openSource)
                    .keyboardShortcut("o")
                Button("保存 Mermaid 源码…".studioLocalized, action: model.saveSource)
                    .keyboardShortcut("s")
                Divider()
                Button("导出图表…".studioLocalized, action: model.presentExport)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!model.canExport)
            }
        }
    }
}

final class StudioAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "NornaKit", withExtension: "icns") {
            NSApp.applicationIconImage = NSImage(contentsOf: url)
        }
        #endif
    }
}
