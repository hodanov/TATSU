import Cocoa
import UniformTypeIdentifiers
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, TimerModelDelegate {

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var model: TimerModel!

    private static let standingKey = "standingIntervalMinutes"
    private static let walkKey = "walkIntervalMinutes"
    private static let characterImageKey = "characterImageName"

    private var pauseMenuItem: NSMenuItem!
    private var stateMenuItem: NSMenuItem!
    private var timerMenuItem: NSMenuItem!
    private var standingSubmenu: NSMenu!
    private var walkSubmenu: NSMenu!

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaults()

        let standingMinutes = UserDefaults.standard.integer(forKey: Self.standingKey)
        let walkMinutes = UserDefaults.standard.integer(forKey: Self.walkKey)
        model = TimerModel(standingIntervalSeconds: standingMinutes * 60,
                           walkIntervalSeconds: walkMinutes * 60)
        model.delegate = self

        requestNotificationPermission()
        setupStatusItem()
        startTimer()

        if let savedPath = UserDefaults.standard.string(forKey: Self.characterImageKey) {
            FloatingCharacterPanel.shared.updateImage(path: savedPath)
        }
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Self.standingKey: TimerModel.defaultStandingMinutes,
            Self.walkKey: TimerModel.defaultWalkMinutes
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
            button.image = NSImage(systemSymbolName: model.symbolName, accessibilityDescription: "TATSU")
            button.imagePosition = .imageLeading
            button.title = model.displayTitle
        }

        let menu = NSMenu()

        stateMenuItem = NSMenuItem(title: model.menuStateText, action: nil, keyEquivalent: "")
        stateMenuItem.isEnabled = false
        menu.addItem(stateMenuItem)

        timerMenuItem = NSMenuItem(title: model.menuTimerText, action: nil, keyEquivalent: "")
        timerMenuItem.isEnabled = false
        menu.addItem(timerMenuItem)

        menu.addItem(NSMenuItem.separator())

        pauseMenuItem = NSMenuItem(title: model.pauseMenuTitle, action: #selector(togglePause), keyEquivalent: "p")
        menu.addItem(pauseMenuItem)

        menu.addItem(NSMenuItem(title: "リセット", action: #selector(resetTimer), keyEquivalent: "r"))

        menu.addItem(NSMenuItem.separator())

        let standingItem = NSMenuItem(title: "スタンディング間隔", action: nil, keyEquivalent: "")
        standingSubmenu = buildIntervalSubmenu(
            presets: TimerModel.standingPresets,
            currentMinutes: UserDefaults.standard.integer(forKey: Self.standingKey),
            action: #selector(changeStandingInterval(_:))
        )
        standingItem.submenu = standingSubmenu
        menu.addItem(standingItem)

        let walkItem = NSMenuItem(title: "散歩間隔", action: nil, keyEquivalent: "")
        walkSubmenu = buildIntervalSubmenu(
            presets: TimerModel.walkPresets,
            currentMinutes: UserDefaults.standard.integer(forKey: Self.walkKey),
            action: #selector(changeWalkInterval(_:))
        )
        walkItem.submenu = walkSubmenu
        menu.addItem(walkItem)

        menu.addItem(NSMenuItem(
            title: "通知画像を選択...",
            action: #selector(selectCharacterImage),
            keyEquivalent: ""
        ))

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

        guard TimerModel.isValidStandingInterval(newMinutes, walkMinutes: walkMinutes) else {
            return
        }

        UserDefaults.standard.set(newMinutes, forKey: Self.standingKey)
        model.standingIntervalSeconds = newMinutes * 60
        updateSubmenuCheck(standingSubmenu, selectedMinutes: newMinutes)
        model.reset()
    }

    @objc private func changeWalkInterval(_ sender: NSMenuItem) {
        let newMinutes = sender.tag
        let standingMinutes = UserDefaults.standard.integer(forKey: Self.standingKey)

        guard TimerModel.isValidWalkInterval(newMinutes, standingMinutes: standingMinutes) else {
            return
        }

        UserDefaults.standard.set(newMinutes, forKey: Self.walkKey)
        model.walkIntervalSeconds = newMinutes * 60
        updateSubmenuCheck(walkSubmenu, selectedMinutes: newMinutes)
        model.reset()
    }

    @objc private func selectCharacterImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            UserDefaults.standard.set(url.path, forKey: Self.characterImageKey)
            FloatingCharacterPanel.shared.updateImage(path: url.path)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.model.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    // MARK: - TimerModelDelegate

    func timerModel(_ model: TimerModel, didRequestNotification type: TimerModel.NotificationType) {
        switch type {
        case .standing:
            sendNotification(title: "スタンディングに切り替えよう！🧍", body: "30分経ったよ。立ち上がろう。")
        case .walk:
            sendNotification(title: "散歩しよう！🚶", body: "1時間経ったよ。少し歩いてリフレッシュしよう。")
        }
        FloatingCharacterPanel.shared.show(for: type)
    }

    func timerModelDidUpdateState(_ model: TimerModel) {
        updateDisplay()
    }

    // MARK: - Display Update

    private func updateDisplay() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: model.symbolName, accessibilityDescription: "TATSU")
            button.title = model.displayTitle
        }

        stateMenuItem.title = model.menuStateText
        timerMenuItem.title = model.menuTimerText
        pauseMenuItem.title = model.pauseMenuTitle
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
        model.togglePause()
    }

    @objc private func resetTimer() {
        model.reset()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
