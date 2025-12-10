import SwiftUI

@main
struct ADHDModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        // 不创建任何窗口场景，给一个 Settings 空壳防编译器抱怨
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay = OverlayController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        // （LSUIElement=YES 时不需要再改策略）
        overlay.start()
    }
}
