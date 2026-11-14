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
        Settings { SettingsView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // 关掉最后一本书 = 退出，不留空壳进程。
    // 不能用 applicationShouldTerminateAfterLastWindowClosed：打开面板也算窗口，
    // 面板一关（取消或选好书、书窗还没出来）就会被当成「最后一个窗口」而退出。
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated {
                guard window?.windowController?.document != nil else { return }
                // 等文档真正从控制器里移除再判断
                DispatchQueue.main.async {
                    if NSDocumentController.shared.documents.isEmpty { NSApp.terminate(nil) }
                }
            }
        }
    }
}
