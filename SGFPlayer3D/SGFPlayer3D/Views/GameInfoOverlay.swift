// MARK: - GameInfoOverlay
// Displays game metadata: player info, time controls, captures, komi/rules, move count
//
// Extracted from ContentView3D.swift (Phase 3)
// Original lines: 446-597 (152 lines) + formatTime helper (lines 780-791)

import SwiftUI

struct GameInfoOverlay: View {
    // Observable objects
    var ogsGame: OGSGameViewModel?
    @ObservedObject var timeControl: TimeControlManager
    @ObservedObject var player: SGFPlayer

    // Optional game selection for local game mode
    var gameSelection: SGFGameWrapper?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Player names with ranks
            HStack(spacing: 8) {
                if let blackName = ogsGame?.blackName {
                    // OGS mode
                    Text("\(blackName)")
                        .foregroundColor(.white)
                        .font(.headline)
                    if let blackRank = ogsGame?.blackRank {
                        Text("[\(blackRank)]")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                } else if let selection = gameSelection {
                    // Local game mode
                    Text("\(selection.game.info.playerBlack ?? "?")")
                        .foregroundColor(.white)
                        .font(.headline)
                    if let blackRank = selection.game.info.blackRank {
                        Text("[\(blackRank)]")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                }

                Text("vs")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption)

                if let whiteName = ogsGame?.whiteName {
                    // OGS mode
                    Text("\(whiteName)")
                        .foregroundColor(.white)
                        .font(.headline)
                    if let whiteRank = ogsGame?.whiteRank {
                        Text("[\(whiteRank)]")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                } else if let selection = gameSelection {
                    // Local game mode
                    Text("\(selection.game.info.playerWhite ?? "?")")
                        .foregroundColor(.white)
                        .font(.headline)
                    if let whiteRank = selection.game.info.whiteRank {
                        Text("[\(whiteRank)]")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                }
            }

            // Time remaining (OGS only)
            if ogsGame?.blackName != nil {
                HStack(spacing: 12) {
                    // Black time
                    HStack(spacing: 4) {
                        Text("⚫")
                            .font(.caption)
                        if let timeRemaining = timeControl.blackTimeRemaining {
                            Text(formatTime(timeRemaining))
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                            if let periods = timeControl.blackPeriodsRemaining, periods > 0 {
                                if periods == 1 {
                                    Text("SD")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                } else {
                                    Text("(\(periods)×---)")
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    // White time
                    HStack(spacing: 4) {
                        Text("⚪")
                            .font(.caption)
                        if let timeRemaining = timeControl.whiteTimeRemaining {
                            Text(formatTime(timeRemaining))
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                            if let periods = timeControl.whitePeriodsRemaining, periods > 0 {
                                if periods == 1 {
                                    Text("SD")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                } else {
                                    Text("(\(periods)×---)")
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
            }

            // Captures
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("⚫")
                        .font(.caption)
                    Text("\(player.blackCaptured) captured")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                }
                HStack(spacing: 4) {
                    Text("⚪")
                        .font(.caption)
                    Text("\(player.whiteCaptured) captured")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                }
            }

            // Komi and ruleset
            HStack(spacing: 12) {
                if let komi = ogsGame?.komi ?? gameSelection?.game.info.komi {
                    Text("Komi: \(komi)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                if let ruleset = ogsGame?.ruleset ?? gameSelection?.game.info.ruleset {
                    Text("Rules: \(ruleset)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
            }

            // Move counter
            Text("Move \(player.currentIndex) / \(player.moves.count)")
                .foregroundColor(.white.opacity(0.8))
                .font(.caption)
        }
    }

    // MARK: - Helper Functions

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
