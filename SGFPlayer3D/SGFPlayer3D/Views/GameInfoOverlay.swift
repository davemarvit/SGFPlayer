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

    // Background opacity - configurable for 2D vs 3D
    // 2D: 0.6 (matches settings panel), 3D: 0.3 (70% transparent)
    var backgroundOpacity: Double = 0.6

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Black player info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("⚫")
                        .font(.caption)
                    if let blackName = ogsGame?.blackName {
                        // OGS mode
                        Text("\(blackName)")
                            .foregroundColor(.white)
                            .font(.subheadline)
                        if let blackRank = ogsGame?.blackRank {
                            Text("[\(blackRank)]")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption2)
                        }
                    } else if let selection = gameSelection {
                        // Local game mode
                        Text("\(selection.game.info.playerBlack ?? "?")")
                            .foregroundColor(.white)
                            .font(.subheadline)
                        if let blackRank = selection.game.info.blackRank {
                            Text("[\(blackRank)]")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption2)
                        }
                    }
                }

                // Black time (OGS only)
                if ogsGame?.blackName != nil, let timeRemaining = timeControl.blackTimeRemaining {
                    HStack(spacing: 4) {
                        Text(formatTime(timeRemaining))
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption2)
                        if let periods = timeControl.blackPeriodsRemaining, periods > 0 {
                            if periods == 1 {
                                Text("SD")
                                    .foregroundColor(.red)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            } else {
                                let periodTimeStr = timeControl.blackPeriodTime.map { formatTime($0) } ?? "---"
                                Text("(\(periods)×\(periodTimeStr))")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding(.leading, 14)
                }

                // Black captures
                HStack(spacing: 4) {
                    Text("Cap: \(player.blackCaptured)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption2)
                }
                .padding(.leading, 14)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // White player info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("⚪")
                        .font(.caption)
                    if let whiteName = ogsGame?.whiteName {
                        // OGS mode
                        Text("\(whiteName)")
                            .foregroundColor(.white)
                            .font(.subheadline)
                        if let whiteRank = ogsGame?.whiteRank {
                            Text("[\(whiteRank)]")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption2)
                        }
                    } else if let selection = gameSelection {
                        // Local game mode
                        Text("\(selection.game.info.playerWhite ?? "?")")
                            .foregroundColor(.white)
                            .font(.subheadline)
                        if let whiteRank = selection.game.info.whiteRank {
                            Text("[\(whiteRank)]")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption2)
                        }
                    }
                }

                // White time (OGS only)
                if ogsGame?.blackName != nil, let timeRemaining = timeControl.whiteTimeRemaining {
                    HStack(spacing: 4) {
                        Text(formatTime(timeRemaining))
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption2)
                        if let periods = timeControl.whitePeriodsRemaining, periods > 0 {
                            if periods == 1 {
                                Text("SD")
                                    .foregroundColor(.red)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            } else {
                                let periodTimeStr = timeControl.whitePeriodTime.map { formatTime($0) } ?? "---"
                                Text("(\(periods)×\(periodTimeStr))")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding(.leading, 14)
                }

                // White captures
                HStack(spacing: 4) {
                    Text("Cap: \(player.whiteCaptured)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption2)
                }
                .padding(.leading, 14)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Game info: Komi, ruleset, move counter (compact)
            VStack(alignment: .leading, spacing: 1) {
                if let komi = ogsGame?.komi ?? gameSelection?.game.info.komi {
                    Text("Komi: \(komi)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption2)
                }
                if let ruleset = ogsGame?.ruleset ?? gameSelection?.game.info.ruleset {
                    Text(ruleset)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption2)
                }
                Text("Move \(player.currentIndex)/\(player.moves.count)")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption2)
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // Don't expand horizontally!
        .padding(8)
        .background(.thinMaterial.opacity(backgroundOpacity), in: RoundedRectangle(cornerRadius: 6))
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
