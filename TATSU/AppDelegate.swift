import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var elapsedSeconds = 0
    private var isPaused = false

    private static let standingPresets = [15, 30, 45, 60]  // 分
    private static let walkPresets = [30, 60, 90, 120]      // 分

    private static let defaultStandingMinutes = 30
    private static let defaultWalkMinutes = 60

    private static let standingKey = "standingIntervalMinutes"
    private static let walkKey = "walkIntervalMinutes"

    private var standingInterval: Int {
        UserDefaults.standard.integer(forKey: Self.standingKey) * 60
    }

    private var walkInterval: Int {
        UserDefaults.standard.integer(forKey: Self.walkKey) * 60
    }

    private var pauseMenuItem: NSMenuItem!
    private var stateMenuItem: NSMenuItem!
    private var timerMenuItem: NSMenuItem!
    private var standingSubmenu: NSMenu!
    private var walkSubmenu: NSMenu!

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaults()
        requestNotificationPermission()
        setupStatusItem()
        startTimer()
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Self.standingKey: Self.defaultStandingMinutes,
            Self.walkKey: Self.defaultWalkMinutes
        ])
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            NSLog("通知の許可: \(granted)")
            if let error = error {
                NSLog("通知の許可リクエストに失敗: \(error.localizedDescription)")
            }
        }
    }

    // フォアグラウンドでも通知を表示する
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: "TATSU")
            button.imagePosition = .imageLeading
            button.title = formatTime(standingInterval)
        }

        let menu = NSMenu()

        stateMenuItem = NSMenuItem(title: "着席中", action: nil, keyEquivalent: "")
        stateMenuItem.isEnabled = false
        menu.addItem(stateMenuItem)

        timerMenuItem = NSMenuItem(title: "次の通知まで: \(formatTime(standingInterval))", action: nil, keyEquivalent: "")
        timerMenuItem.isEnabled = false
        menu.addItem(timerMenuItem)

        menu.addItem(NSMenuItem.separator())

        pauseMenuItem = NSMenuItem(title: "一時停止", action: #selector(togglePause), keyEquivalent: "p")
        menu.addItem(pauseMenuItem)

        menu.addItem(NSMenuItem(title: "リセット", action: #selector(resetTimer), keyEquivalent: "r"))

        menu.addItem(NSMenuItem.separator())

        let standingItem = NSMenuItem(title: "スタンディング間隔", action: nil, keyEquivalent: "")
        standingSubmenu = buildIntervalSubmenu(
            presets: Self.standingPresets,
            currentMinutes: UserDefaults.standard.integer(forKey: Self.standingKey),
            action: #selector(changeStandingInterval(_:))
        )
        standingItem.submenu = standingSubmenu
        menu.addItem(standingItem)

        let walkItem = NSMenuItem(title: "散歩間隔", action: nil, keyEquivalent: "")
        walkSubmenu = buildIntervalSubmenu(
            presets: Self.walkPresets,
            currentMinutes: UserDefaults.standard.integer(forKey: Self.walkKey),
            action: #selector(changeWalkInterval(_:))
        )
        walkItem.submenu = walkSubmenu
        menu.addItem(walkItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func buildIntervalSubmenu(presets: [Int], currentMinutes: Int, action: Selector) -> NSMenu {
        let submenu = NSMenu()
        for minutes in presets {
            let item = NSMenuItem(title: "\(minutes)分", action: action, keyEquivalent: "")
            item.tag = minutes
            if minutes == currentMinutes {
                item.state = .on
            }
            submenu.addItem(item)
        }
        return submenu
    }

    private func updateSubmenuCheck(_ submenu: NSMenu, selectedMinutes: Int) {
        for item in submenu.items {
            item.state = item.tag == selectedMinutes ? .on : .off
        }
    }

    // MARK: - Interval Change

    @objc private func changeStandingInterval(_ sender: NSMenuItem) {
        let newMinutes = sender.tag
        let walkMinutes = UserDefaults.standard.integer(forKey: Self.walkKey)

        if newMinutes >= walkMinutes {
            // スタンディング間隔は散歩間隔より短くないといけない
            return
        }

        UserDefaults.standard.set(newMinutes, forKey: Self.standingKey)
        updateSubmenuCheck(standingSubmenu, selectedMinutes: newMinutes)
        resetTimer()
    }

    @objc private func changeWalkInterval(_ sender: NSMenuItem) {
        let newMinutes = sender.tag
        let standingMinutes = UserDefaults.standard.integer(forKey: Self.standingKey)

        if newMinutes <= standingMinutes {
            // 散歩間隔はスタンディング間隔より長くないといけない
            return
        }

        UserDefaults.standard.set(newMinutes, forKey: Self.walkKey)
        updateSubmenuCheck(walkSubmenu, selectedMinutes: newMinutes)
        resetTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func tick() {
        guard !isPaused else { return }

        elapsedSeconds += 1

        if elapsedSeconds >= walkInterval {
            sendNotification(title: "散歩しよう！🚶", body: "1時間経ったよ。少し歩いてリフレッシュしよう。")
            elapsedSeconds = 0
        } else if elapsedSeconds == standingInterval {
            sendNotification(title: "スタンディングに切り替えよう！🧍", body: "30分経ったよ。立ち上がろう。")
        }

        updateDisplay()
    }

    private func updateDisplay() {
        let nextStanding = standingInterval - elapsedSeconds
        let nextWalk = walkInterval - elapsedSeconds
        let isStandingPhase = elapsedSeconds >= standingInterval

        let displayTime: Int
        let symbolName: String
        let stateText: String

        if isStandingPhase {
            displayTime = nextWalk
            symbolName = "figure.stand"
            stateText = "スタンディング中"
        } else {
            displayTime = nextStanding
            symbolName = "figure.seated.side"
            stateText = "着席中"
        }

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "TATSU")
            let prefix = isPaused ? "⏸ " : ""
            button.title = "\(prefix)\(formatTime(displayTime))"
        }

        stateMenuItem.title = isPaused ? "\(stateText)（一時停止中）" : stateText
        timerMenuItem.title = isStandingPhase
            ? "散歩まで: \(formatTime(nextWalk))"
            : "スタンディングまで: \(formatTime(nextStanding))"
    }

    // MARK: - Notification

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("通知の送信に失敗: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func togglePause() {
        isPaused.toggle()
        pauseMenuItem.title = isPaused ? "再開" : "一時停止"
        updateDisplay()
    }

    @objc private func resetTimer() {
        elapsedSeconds = 0
        isPaused = false
        pauseMenuItem.title = "一時停止"
        updateDisplay()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
