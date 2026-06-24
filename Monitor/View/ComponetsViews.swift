import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cpuItem: NSStatusItem!
    private var ramItem: NSStatusItem!
    private var networkItem: NSStatusItem!
    private var timer: Timer?
    private let cpu = CpuMonitor()
    private let memory = MemoryMonitor()
    private let network = NetworkMonitor()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        cpuItem = makeStatusItem(symbol: "cpu", title: "...")
        ramItem = makeStatusItem(symbol: "memorychip", title: "...")
        networkItem = makeStatusItem(symbol: "network", title: "...")

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
        if let usage = try? cpu.usage() {
            cpuItem.button?.title = " \(String(format: "%.1f", usage))%"
        }

        //        // RAM
        if let snap = try? memory.snapshot() {
            // result: (used) / (total)gb
            ramItem.button?.title = "\(snap.formatted(in: .gigabytes))"
        }

        // NETWORK
        if let rate = try? network.rate() {
            networkItem.button?.title =
                "↓ \(rate.downloadFormatted(in: .megabytes)) ↑ \(rate.uploadFormatted(in: .megabytes))"
        }
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
        item.menu = menu

        return item
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
