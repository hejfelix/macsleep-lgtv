import Cocoa

let shareDir = (("~/.local/share/macsleep-lgtv") as NSString).expandingTildeInPath
let off      = "\(shareDir)/lgtv-off.sh"
let on       = "\(shareDir)/lgtv-on.sh"

func run(_ path: String, _ arg: String) {
    let t = Process()
    t.launchPath = "/bin/zsh"
    t.arguments = ["-c", "\(path) \(arg) >/dev/null 2>&1 &"]
    do { try t.run() } catch { NSLog("macsleep-lgtv: failed to run \(path): \(error)") }
}

let nc = NSWorkspace.shared.notificationCenter

nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: nil) { _ in
    NSLog("macsleep-lgtv: screensDidSleep")
    run(off, "screensleep")
}
nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: nil) { _ in
    NSLog("macsleep-lgtv: screensDidWake")
    run(on, "screenwake")
}
nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in
    NSLog("macsleep-lgtv: willSleep")
    run(off, "sleep")
}
nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in
    NSLog("macsleep-lgtv: didWake")
    run(on, "wake")
}

NSLog("macsleep-lgtv: watcher started")
RunLoop.main.run()
