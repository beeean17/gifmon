import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ResourceMonitor()
    private let gifController = GIFController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor.onUpdate = { cpu, ram in
            print(String(format: "[GifCat] CPU: %5.1f%%  RAM: %5.1f%%", cpu * 100, ram * 100))
        }
        monitor.start()

        // Step 3-1: GIFController는 GIF 로드 후 start(). usage=0.5 고정으로 동작 확인
        // gifController.onFrame 은 Step 4(OverlayWindow)에서 연결
        gifController.updateSpeed(usage: 0.5)
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        gifController.stop()
    }
}
