import AppKit
import ServiceManagement
import Darwin
signal(SIGPIPE, SIG_IGN)

struct WindowLimit: Codable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
}
struct Bucket: Codable { let primary: WindowLimit?; let secondary: WindowLimit? }
struct LimitsResult: Codable { let rateLimits: Bucket?; let rateLimitsByLimitId: [String: Bucket]? }
struct Snapshot: Codable {
    let fiveHour: WindowLimit?
    let weekly: WindowLimit?
    let fetchedAt: Date
    static let separator = "  |  "
    static func date(_ timestamp: Double?, full: Bool = false) -> String {
        guard let timestamp else { return "reset unknown" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = .current
        f.dateFormat = full ? "d MMM yyyy HH:mm" : "d MMM HH:mm"
        return f.string(from: Date(timeIntervalSince1970: timestamp))
    }
    static func remaining(_ limit: WindowLimit) -> Int {
        Int(max(0, min(100, 100 - limit.usedPercent)).rounded())
    }
    func part(_ limit: WindowLimit?, weekly: Bool, full: Bool = false) -> String {
        let label = weekly ? "Week" : "5h"
        guard let limit else { return "\(label) unavailable" }
        return "\(label) \(Self.remaining(limit))% · \(Self.date(limit.resetsAt, full: full))"
    }
    var title: String {
        part(fiveHour, weekly: false) + Self.separator + part(weekly, weekly: true)
    }
    var styledTitle: NSAttributedString {
        let text = NSMutableAttributedString()
        let normal: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        let subdued: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let emphasis: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        func append(_ value: String, _ attributes: [NSAttributedString.Key: Any]) {
            text.append(NSAttributedString(string: value, attributes: attributes))
        }
        for (index, limit) in [fiveHour, weekly].enumerated() {
            if index > 0 { append(Self.separator, subdued) }
            append(index == 0 ? "5h " : "Week ", normal)
            guard let limit else { append("unavailable", subdued); continue }
            let left = Self.remaining(limit)
            if left <= 20 {
                var warning = normal
                warning[.foregroundColor] = left <= 10 ? NSColor.systemRed : NSColor.systemOrange
                append("● ", warning)
            }
            append("\(left)%", emphasis)
            append(" · \(Self.date(limit.resetsAt))", subdued)
        }
        return text
    }
}

enum UsageFailure: LocalizedError {
    case missingHelper, timeout, disconnected, service, invalid
    var errorDescription: String? {
        switch self {
        case .missingHelper: return "Codex helper not found. Install or open Codex, then refresh."
        case .timeout: return "Usage request timed out. Check your connection and refresh."
        case .disconnected: return "Codex helper stopped before returning usage. Open Codex and refresh."
        case .service: return "Usage service unavailable or sign-in required. Open Codex and refresh."
        case .invalid: return "Codex returned no readable usage limits."
        }
    }
}
final class UsageReader {
    static func helper() -> String? {
        let candidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            NSHomeDirectory() + "/Applications/Codex.app/Contents/Resources/codex",
            NSHomeDirectory() + "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            NSHomeDirectory() + "/.local/bin/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static func read() throws -> Snapshot {
        guard let path = helper() else { throw UsageFailure.missingHelper }
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        process.standardInput = input; process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: timeout)
        let deadline = Date().addingTimeInterval(20)
        defer {
            timeout.cancel()
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            try? output.fileHandleForReading.close()
        }
        func send(_ value: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: value)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "codex_usage_menu", "title": "Codex Usage", "version": "1.0.0"]]])
        var buffer = Data()
        while Date() < deadline {
            let chunk = output.fileHandleForReading.availableData
            guard !chunk.isEmpty else {
                throw Date() >= deadline ? UsageFailure.timeout : UsageFailure.disconnected
            }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                let line = buffer.prefix(upTo: newline)
                buffer.removeSubrange(...newline)
                guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any], let id = message["id"] as? Int else { continue }
                if message["error"] != nil { throw UsageFailure.service }
                if id == 1 {
                    try send(["method": "initialized", "params": [:]])
                    try send(["id": 2, "method": "account/rateLimits/read"])
                } else if id == 2 {
                    guard let result = message["result"] else { throw UsageFailure.invalid }
                    let decoded = try JSONDecoder().decode(LimitsResult.self, from: JSONSerialization.data(withJSONObject: result))
                    guard let bucket = decoded.rateLimitsByLimitId?["codex"] ?? decoded.rateLimits, bucket.primary != nil || bucket.secondary != nil else { throw UsageFailure.invalid }
                    let windows = [bucket.primary, bucket.secondary].compactMap { $0 }
                    let five = windows.first { $0.windowDurationMins == 300 }
                    let week = windows.first { $0.windowDurationMins == 10080 }
                    // Match actual window lengths rather than mislabeling a changed plan's limits.
                    guard five != nil || week != nil else { throw UsageFailure.invalid }
                    return Snapshot(fiveHour: five, weekly: week, fetchedAt: Date())
                }
            }
        }
        throw UsageFailure.timeout
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var snapshot: Snapshot?
    var failure: String?
    var refreshing = false
    var timer: Timer?
    var wakeObserver: NSObjectProtocol?
    let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        statusItem.button?.setAccessibilityLabel("Codex remaining percentages and next reset times")
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        if let data = defaults.data(forKey: "lastSnapshot") { snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) }
        failure = snapshot == nil ? nil : "Showing saved reading while refreshing."
        render()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.refresh() }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
    }
    func render() {
        let stale = failure != nil || snapshot.map { Date().timeIntervalSince($0.fetchedAt) > 300 } == true
        let title = NSMutableAttributedString(attributedString: snapshot?.styledTitle ?? NSAttributedString(
            string: "5h —% · —  |  Week —% · —",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]))
        if stale { title.append(NSAttributedString(string: " · stale", attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor])) }
        statusItem.button?.attributedTitle = title
        statusItem.button?.toolTip = "Codex • Remaining allowance • Reset times in \(TimeZone.current.identifier)\n" + (failure ?? (refreshing ? "Refreshing…" : "Click for details and controls"))
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        render(); menu.removeAllItems()
        func info(_ title: String) { let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""); item.isEnabled = false; menu.addItem(item) }
        info("Codex Usage — remaining allowance")
        if let snapshot {
            info(snapshot.part(snapshot.fiveHour, weekly: false, full: true))
            info(snapshot.part(snapshot.weekly, weekly: true, full: true))
            let f = DateFormatter(); f.timeStyle = .medium; f.dateStyle = .short
            info("Last updated: \(f.string(from: snapshot.fetchedAt))")
        }
        info("Reset time zone: \(TimeZone.current.identifier)")
        if let failure { info(failure) }
        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: refreshing ? "Refreshing…" : "Refresh now", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self; refreshItem.isEnabled = !refreshing; menu.addItem(refreshItem)
        let open = NSMenuItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: ""); open.target = self; menu.addItem(open)
        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self; login.state = SMAppService.mainApp.status == .enabled ? .on : .off; menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Codex Usage", action: #selector(quitApp), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }
    func refresh() {
        guard !refreshing else { return }; refreshing = true; render()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { try UsageReader.read() }
            DispatchQueue.main.async {
                guard let self else { return }; self.refreshing = false
                switch result {
                case .success(let value):
                    self.snapshot = value; self.failure = nil
                    if let data = try? JSONEncoder().encode(value) { self.defaults.set(data, forKey: "lastSnapshot") }
                case .failure(let error): self.failure = error.localizedDescription
                }
                self.render()
            }
        }
    }
    @objc func refreshAction() { refresh() }
    @objc func openCodex() {
        let paths = ["/Applications/Codex.app", "/Applications/ChatGPT.app"]
        if let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
    }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert(); alert.messageText = "Could not change launch at login"; alert.informativeText = error.localizedDescription; alert.runModal()
        }
    }
    @objc func quitApp() { NSApp.terminate(nil) }
}

if CommandLine.arguments.contains("--check") {
    do { print(try UsageReader.read().title) } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
