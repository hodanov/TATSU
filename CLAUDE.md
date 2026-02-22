# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code)
when working with code in this repository.

## Project Overview

TATSU is a macOS menu bar timer app (macOS 13.0+) that
reminds users to stand up and take walks during long desk
work sessions. Built with Swift, AppKit, and
UserNotifications using Swift Package Manager.

## Build & Test Commands

```bash
# Build the app (compiles, generates icons, code-signs)
./build.sh
open build/TATSU.app

# Run tests (uses swift-testing, not XCTest)
swift test

# Run a single test suite
swift test --filter TATSUCoreTests.TimerModelTests

# Markdown lint (run on any created/modified .md files)
markdownlint-cli2 --fix <file.md>
```

## Architecture

Two-layer design separating business logic from UI:

- **`Sources/TATSUCore/TimerModel.swift`** — Pure Swift
  module with all timer logic, state management, and
  validation. No AppKit dependency. Uses
  `TimerModelDelegate` to communicate events to UI.

- **`TATSU/AppDelegate.swift`** — UI layer handling menu
  bar display (SF Symbols), user notifications,
  UserDefaults persistence, and driving the timer via
  1-second `tick()` calls.

- **`TATSU/main.swift`** — App entry point.

The timer has two phases: seated (default 30min) then
standing (default 60min). Each phase ends with a
notification. Intervals are user-configurable with
validation (standing < walk interval).

## Testing

Tests in `Tests/TATSUCoreTests/TimerModelTests.swift`
use **swift-testing** (`@Test`, `@Suite`, `#expect` —
not XCTest). Covers `TimerModel` business logic:
formatTime, tick behavior, phase transitions,
pause/reset, interval validation.

## Dependencies

- `swift-testing` (0.99.0) — test framework only
