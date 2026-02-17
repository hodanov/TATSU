import Foundation

public protocol TimerModelDelegate: AnyObject {
    func timerModel(_ model: TimerModel, didRequestNotification type: TimerModel.NotificationType)
    func timerModelDidUpdateState(_ model: TimerModel)
}

public class TimerModel {

    // MARK: - Types

    public enum Phase {
        case seated
        case standing
    }

    public enum NotificationType {
        case standing
        case walk
    }

    // MARK: - Constants

    public static let standingPresets = [15, 30, 45, 60]
    public static let walkPresets = [30, 60, 90, 120]
    public static let defaultStandingMinutes = 30
    public static let defaultWalkMinutes = 60

    // MARK: - State

    public var elapsedSeconds: Int = 0
    public private(set) var isPaused: Bool = false
    public var standingIntervalSeconds: Int
    public var walkIntervalSeconds: Int

    public weak var delegate: TimerModelDelegate?

    // MARK: - Init

    public init(standingIntervalSeconds: Int = defaultStandingMinutes * 60,
                walkIntervalSeconds: Int = defaultWalkMinutes * 60) {
        self.standingIntervalSeconds = standingIntervalSeconds
        self.walkIntervalSeconds = walkIntervalSeconds
    }

    // MARK: - Computed Properties

    public var currentPhase: Phase {
        elapsedSeconds >= standingIntervalSeconds ? .standing : .seated
    }

    public var displayTime: Int {
        switch currentPhase {
        case .seated:
            return standingIntervalSeconds - elapsedSeconds
        case .standing:
            return walkIntervalSeconds - elapsedSeconds
        }
    }

    public var symbolName: String {
        switch currentPhase {
        case .seated:
            return "figure.seated.side"
        case .standing:
            return "figure.stand"
        }
    }

    public var stateText: String {
        switch currentPhase {
        case .seated:
            return "着席中"
        case .standing:
            return "スタンディング中"
        }
    }

    public var displayTitle: String {
        let prefix = isPaused ? "⏸ " : ""
        return "\(prefix)\(Self.formatTime(displayTime))"
    }

    public var menuStateText: String {
        isPaused ? "\(stateText)（一時停止中）" : stateText
    }

    public var menuTimerText: String {
        switch currentPhase {
        case .seated:
            return "スタンディングまで: \(Self.formatTime(standingIntervalSeconds - elapsedSeconds))"
        case .standing:
            return "散歩まで: \(Self.formatTime(walkIntervalSeconds - elapsedSeconds))"
        }
    }

    public var pauseMenuTitle: String {
        isPaused ? "再開" : "一時停止"
    }

    // MARK: - Pure Functions

    public static func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public static func isValidStandingInterval(_ minutes: Int, walkMinutes: Int) -> Bool {
        minutes < walkMinutes
    }

    public static func isValidWalkInterval(_ minutes: Int, standingMinutes: Int) -> Bool {
        minutes > standingMinutes
    }

    // MARK: - Mutations

    public func tick() {
        guard !isPaused else { return }

        elapsedSeconds += 1

        if elapsedSeconds >= walkIntervalSeconds {
            delegate?.timerModel(self, didRequestNotification: .walk)
            elapsedSeconds = 0
        } else if elapsedSeconds == standingIntervalSeconds {
            delegate?.timerModel(self, didRequestNotification: .standing)
        }

        delegate?.timerModelDidUpdateState(self)
    }

    public func togglePause() {
        isPaused.toggle()
        delegate?.timerModelDidUpdateState(self)
    }

    public func reset() {
        elapsedSeconds = 0
        isPaused = false
        delegate?.timerModelDidUpdateState(self)
    }
}
