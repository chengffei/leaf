import SwiftUI

@main
struct LeafApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(viewing: BookDocument.self) { file in
            BookWindow(book: file.document)
                .frame(minWidth: 420, minHeight: 360)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .defaultSize(width: 760, height: 920)
        .commands { ReaderCommands() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // 关掉最后一本书 = 退出，不留空壳进程
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
