import Foundation
import SwiftUI

/// Manages game clock countdown and time control
/// Handles live countdown during player turns and synchronizes with OGS updates
class TimeControlManager: ObservableObject {
    // Current clock times (updated live during countdown)
    @Published var blackTimeRemaining: TimeInterval?
    @Published var whiteTimeRemaining: TimeInterval?
    @Published var blackPeriodsRemaining: Int?
    @Published var whitePeriodsRemaining: Int?

    // Time control settings (from OGS)
    private var blackPeriodTime: TimeInterval?
    private var whitePeriodTime: TimeInterval?

    // Current player whose clock is running
    @Published var currentPlayerColor: Stone = .black

    // Countdown timer
    private var countdownTimer: Timer?
    private var lastUpdateTime: Date?

    // Whether clock is actively counting down
    @Published var isClockRunning = false

    init() {
        NSLog("TimeControl: 🕐 TimeControlManager initialized")
    }

    deinit {
        stopClock()
    }

    // MARK: - Public API

    /// Update clock from OGS clock event
    /// - Parameters:
    ///   - blackTime: Black player's time remaining
    ///   - whiteTime: White player's time remaining
    ///   - blackPeriods: Black player's byo-yomi periods
    ///   - whitePeriods: White player's byo-yomi periods
    ///   - blackPeriod: Length of black's byo-yomi period
    ///   - whitePeriod: Length of white's byo-yomi period
    func updateFromOGS(
        blackTime: TimeInterval?,
        whiteTime: TimeInterval?,
        blackPeriods: Int?,
        whitePeriods: Int?,
        blackPeriod: TimeInterval?,
        whitePeriod: TimeInterval?
    ) {
        NSLog("TimeControl: 📡 Received OGS clock update - Black: \(blackTime ?? -1)s, White: \(whiteTime ?? -1)s")

        // Update times from server
        self.blackTimeRemaining = blackTime
        self.whiteTimeRemaining = whiteTime
        self.blackPeriodsRemaining = blackPeriods
        self.whitePeriodsRemaining = whitePeriods
        self.blackPeriodTime = blackPeriod
        self.whitePeriodTime = whitePeriod

        // Reset last update time for countdown
        self.lastUpdateTime = Date()

        NSLog("TimeControl: ✅ Clock synced with OGS")
    }

    /// Start the countdown clock for the current player
    func startClock() {
        guard !isClockRunning else {
            NSLog("TimeControl: ⚠️ Clock already running")
            return
        }

        NSLog("TimeControl: ▶️ Starting clock for \(currentPlayerColor == .black ? "Black" : "White")")
        isClockRunning = true
        lastUpdateTime = Date()

        // Update every 0.1 seconds for smooth countdown
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }

    /// Stop the countdown clock
    func stopClock() {
        guard isClockRunning else { return }

        NSLog("TimeControl: ⏸️ Stopping clock")
        isClockRunning = false
        countdownTimer?.invalidate()
        countdownTimer = nil
        lastUpdateTime = nil
    }

    /// Switch to the other player's clock
    /// - Parameter newPlayer: The color of the player whose turn it now is
    func switchToPlayer(_ newPlayer: Stone) {
        NSLog("TimeControl: 🔄 Switching clock to \(newPlayer == .black ? "Black" : "White")")

        // Stop current countdown
        let wasRunning = isClockRunning
        stopClock()

        // Switch player
        currentPlayerColor = newPlayer

        // Restart if it was running
        if wasRunning {
            startClock()
        }
    }

    /// Reset all clocks
    func reset() {
        NSLog("TimeControl: 🔄 Resetting all clocks")
        stopClock()
        blackTimeRemaining = nil
        whiteTimeRemaining = nil
        blackPeriodsRemaining = nil
        whitePeriodsRemaining = nil
        blackPeriodTime = nil
        whitePeriodTime = nil
        currentPlayerColor = .black
    }

    // MARK: - Private Methods

    private func updateCountdown() {
        guard let lastUpdate = lastUpdateTime else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdate)
        lastUpdateTime = now

        // Decrement the current player's time
        if currentPlayerColor == .black {
            if let currentTime = blackTimeRemaining {
                let newTime = max(0, currentTime - elapsed)
                blackTimeRemaining = newTime

                // Check if main time expired and need to move to byo-yomi
                if newTime <= 0 && (blackPeriodsRemaining ?? 0) > 0 {
                    handleByoyomiTransition(isBlack: true)
                }
            }
        } else {
            if let currentTime = whiteTimeRemaining {
                let newTime = max(0, currentTime - elapsed)
                whiteTimeRemaining = newTime

                // Check if main time expired and need to move to byo-yomi
                if newTime <= 0 && (whitePeriodsRemaining ?? 0) > 0 {
                    handleByoyomiTransition(isBlack: false)
                }
            }
        }
    }

    /// Handle transition from main time to byo-yomi period
    private func handleByoyomiTransition(isBlack: Bool) {
        if isBlack {
            guard let periods = blackPeriodsRemaining, periods > 0,
                  let periodTime = blackPeriodTime else { return }

            NSLog("TimeControl: ⏰ Black entering byo-yomi: \(periods) periods of \(periodTime)s")
            blackPeriodsRemaining = periods - 1
            blackTimeRemaining = periodTime
        } else {
            guard let periods = whitePeriodsRemaining, periods > 0,
                  let periodTime = whitePeriodTime else { return }

            NSLog("TimeControl: ⏰ White entering byo-yomi: \(periods) periods of \(periodTime)s")
            whitePeriodsRemaining = periods - 1
            whiteTimeRemaining = periodTime
        }
    }
}
