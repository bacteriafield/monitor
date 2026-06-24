import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cpuItem: NSStatusItem!
    private var ramItem: NSStatusItem!
    private var timer: Timer?
    private let monitor = CpuMonitor()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        cpuItem = makeStatusItem(symbol: "cpu", title: "...")
        ramItem = makeStatusItem(symbol: "memory", title: "8.1 GB")
        
        startUpdating()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        timer?.invalidate()
    }
    
    private func startUpdating() {
        update()
        timer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] _ in
            self?.update()
        }
    }
    
    private func update() {
        // CPU
        if let usage = try? monitor.usage() {
            cpuItem.button?.title = " \(String(format: "%.1f", usage))%"
        }

//        // RAM
//        if let (used, total) = ramUsage() {
//            ramItem.button?.title = " \(String(format: "%.1f", used)) / \(String(format: "%.1f", total)) GB"
//        }
    }
    
    private func makeStatusItem(symbol: String, title: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

                if let button = item.button {
                    let image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)
                    image?.isTemplate = true
                    button.image = image
                    button.imagePosition = .imageLeading
                    button.title = " \(title)"
                }
        let menu = NSMenu()
                menu.addItem(NSMenuItem(title: "Monitor", action: nil, keyEquivalent: ""))
                menu.addItem(.separator())
                menu.addItem(
                    NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
                )
                item.menu = menu

                return item
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
