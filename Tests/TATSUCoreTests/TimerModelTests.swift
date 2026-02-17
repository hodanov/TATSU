import Testing
@testable import TATSUCore

// MARK: - Mock Delegate

final class MockTimerModelDelegate: TimerModelDelegate {
    var receivedNotifications: [TimerModel.NotificationType] = []
    var stateUpdateCount = 0

    func timerModel(_ model: TimerModel, didRequestNotification type: TimerModel.NotificationType) {
        receivedNotifications.append(type)
    }

    func timerModelDidUpdateState(_ model: TimerModel) {
        stateUpdateCount += 1
    }
}

// MARK: - Helper

private func makeModel(standing: Int = 10, walk: Int = 20) -> (TimerModel, MockTimerModelDelegate) {
    let model = TimerModel(standingIntervalSeconds: standing, walkIntervalSeconds: walk)
    let delegate = MockTimerModelDelegate()
    model.delegate = delegate
    return (model, delegate)
}

// MARK: - A. formatTime

@Suite("formatTime")
struct FormatTimeTests {
    @Test func zero() {
        #expect(TimerModel.formatTime(0) == "00:00")
    }

    @Test func underOneMinute() {
        #expect(TimerModel.formatTime(45) == "00:45")
    }

    @Test func exactMinutes() {
        #expect(TimerModel.formatTime(300) == "05:00")
    }

    @Test func mixedMinutesSeconds() {
        #expect(TimerModel.formatTime(1830) == "30:30")
    }

    @Test func largeValue() {
        #expect(TimerModel.formatTime(3600) == "60:00")
    }
}

// MARK: - B. Initial State

@Suite("Initial State")
struct InitialStateTests {
    @Test func elapsed() {
        let (model, _) = makeModel()
        #expect(model.elapsedSeconds == 0)
    }

    @Test func notPaused() {
        let (model, _) = makeModel()
        #expect(model.isPaused == false)
    }

    @Test func seatedPhase() {
        let (model, _) = makeModel()
        #expect(model.currentPhase == .seated)
    }
}

// MARK: - C. tick

@Suite("tick")
struct TickTests {
    @Test func incrementsElapsed() {
        let (model, _) = makeModel()
        model.tick()
        #expect(model.elapsedSeconds == 1)
    }

    @Test func whenPausedDoesNotIncrement() {
        let (model, _) = makeModel()
        model.togglePause()
        model.tick()
        #expect(model.elapsedSeconds == 0)
    }

    @Test func atStandingIntervalSendsStandingNotification() {
        let (model, delegate) = makeModel()
        model.elapsedSeconds = 9 // next tick reaches 10 == standingInterval
        model.tick()
        #expect(delegate.receivedNotifications == [.standing])
    }

    @Test func atWalkIntervalSendsWalkNotification() {
        let (model, delegate) = makeModel()
        model.elapsedSeconds = 19 // next tick reaches 20 == walkInterval
        model.tick()
        #expect(delegate.receivedNotifications == [.walk])
    }

    @Test func atWalkIntervalResetsToZero() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 19
        model.tick()
        #expect(model.elapsedSeconds == 0)
    }

    @Test func betweenIntervalsNoNotification() {
        let (model, delegate) = makeModel()
        model.elapsedSeconds = 5
        model.tick()
        #expect(delegate.receivedNotifications.isEmpty)
    }
}

// MARK: - D. Phase & Display Computation

@Suite("Phase and Display")
struct PhaseAndDisplayTests {
    @Test func beforeStandingIsSeated() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 5
        #expect(model.currentPhase == .seated)
    }

    @Test func atStandingIsStanding() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 10
        #expect(model.currentPhase == .standing)
    }

    @Test func displayTimeSeatedShowsCountdownToStanding() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 3
        #expect(model.displayTime == 7) // 10 - 3
    }

    @Test func displayTimeStandingShowsCountdownToWalk() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 15
        #expect(model.displayTime == 5) // 20 - 15
    }

    @Test func symbolNameSeated() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 0
        #expect(model.symbolName == "figure.seated.side")
    }

    @Test func symbolNameStanding() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 10
        #expect(model.symbolName == "figure.stand")
    }
}

// MARK: - E. Display Text

@Suite("Display Text")
struct DisplayTextTests {
    @Test func displayTitleNotPaused() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 0
        // displayTime = 10s => "00:10"
        #expect(model.displayTitle == "00:10")
    }

    @Test func displayTitlePaused() {
        let (model, _) = makeModel()
        model.togglePause()
        model.elapsedSeconds = 0
        #expect(model.displayTitle == "⏸ 00:10")
    }

    @Test func menuStateTextSeatedPaused() {
        let (model, _) = makeModel()
        model.togglePause()
        #expect(model.menuStateText == "着席中（一時停止中）")
    }

    @Test func menuTimerTextStanding() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 15
        #expect(model.menuTimerText == "散歩まで: 00:05")
    }
}

// MARK: - F. togglePause / reset

@Suite("togglePause and reset")
struct PauseResetTests {
    @Test func togglePauseFlipsState() {
        let (model, _) = makeModel()
        #expect(model.isPaused == false)
        model.togglePause()
        #expect(model.isPaused == true)
        model.togglePause()
        #expect(model.isPaused == false)
    }

    @Test func togglePauseNotifiesDelegate() {
        let (model, delegate) = makeModel()
        model.togglePause()
        #expect(delegate.stateUpdateCount == 1)
    }

    @Test func resetResetsElapsedAndPause() {
        let (model, _) = makeModel()
        model.elapsedSeconds = 100
        model.togglePause()
        model.reset()
        #expect(model.elapsedSeconds == 0)
        #expect(model.isPaused == false)
    }

    @Test func resetFromMidTimer() {
        let (model, _) = makeModel()
        for _ in 0..<5 { model.tick() }
        #expect(model.elapsedSeconds == 5)
        model.reset()
        #expect(model.elapsedSeconds == 0)
        #expect(model.currentPhase == .seated)
    }
}

// MARK: - G. Interval Validation

@Suite("Interval Validation")
struct IntervalValidationTests {
    @Test func validStandingLessThanWalk() {
        #expect(TimerModel.isValidStandingInterval(30, walkMinutes: 60) == true)
    }

    @Test func standingEqualToWalkIsInvalid() {
        #expect(TimerModel.isValidStandingInterval(60, walkMinutes: 60) == false)
    }

    @Test func standingGreaterThanWalkIsInvalid() {
        #expect(TimerModel.isValidStandingInterval(90, walkMinutes: 60) == false)
    }

    @Test func walkLessThanStandingIsInvalid() {
        #expect(TimerModel.isValidWalkInterval(15, standingMinutes: 30) == false)
    }
}
