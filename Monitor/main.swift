import AppKit

class Main {
    func Initialize() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

Main().Initialize() // initialize the app
