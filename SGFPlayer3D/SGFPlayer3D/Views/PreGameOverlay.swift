import SwiftUI

/// Pre-game overlay that appears before a game starts
/// Shows game setup options and automatch/challenge UI
struct PreGameOverlay: View {
    @ObservedObject var ogsClient: OGSClient
    @State private var gameSettings: GameSettings = GameSettings.load()
    @Binding var isVisible: Bool  // Control visibility externally

    // UI state
    @State private var challengeUsername = ""

    // Filter state
    @State private var filterBlitz = true
    @State private var filterLive = true
    @State private var filterCorrespondence = false
    @State private var filter9x9 = true
    @State private var filter13x13 = true
    @State private var filter19x19 = true

    // Auto-refresh timer
    @State private var refreshTimer: Timer?

    var body: some View {
        ZStack {
            // Dimmed background - but allow clicks to pass through around the edges
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .allowsHitTesting(false)  // Let clicks pass through to buttons underneath

            // Main content card
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Text("Find a Game")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Spacer()

                    // Refresh button
                    Button(action: refreshAvailableGames) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        isVisible = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.white.opacity(0.1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Available Games Section
                        availableGamesSection

                        Divider()
                            .background(Color.white.opacity(0.3))

                        // Create Custom Game Section
                        createGameSection

                        Divider()
                            .background(Color.white.opacity(0.3))

                        // Game Settings Section
                        gameSettingsSection
                    }
                    .padding()
                }
            }
            .frame(maxWidth: 700, maxHeight: 700)
            .background(Color(white: 0.15))  // Dark gray background instead of thinMaterial
            .cornerRadius(12)
            .shadow(radius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)  // Subtle border, not bright blue
            )
        }
        .onAppear {
            // Fetch available games when overlay appears
            refreshAvailableGames()

            // Start auto-refresh timer (every 10 seconds)
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                refreshAvailableGames()
            }
        }
        .onDisappear {
            // Stop timer when overlay closes
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    // MARK: - Available Games Section

    private var availableGamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Games")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(filteredGames.count) games")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            // Filter checkboxes
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    Text("Speed:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Toggle("Blitz", isOn: $filterBlitz)
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    Toggle("Live", isOn: $filterLive)
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    Toggle("Correspondence", isOn: $filterCorrespondence)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }

                HStack(spacing: 16) {
                    Text("Board:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Toggle("9×9", isOn: $filter9x9)
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    Toggle("13×13", isOn: $filter13x13)
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    Toggle("19×19", isOn: $filter19x19)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
            .padding(.vertical, 8)

            if filteredGames.isEmpty {
                Text("No games match your filters. Try adjusting above!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 8) {
                        ForEach(filteredGames) { challenge in
                            GameChallengeCard(challenge: challenge) {
                                acceptChallenge(challenge)
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
    }

    // Filter games based on speed and board size
    private var filteredGames: [OGSChallenge] {
        ogsClient.availableGames.filter { challenge in
            // Speed filter
            let timeControlDisplay = challenge.timeControlDisplay.lowercased()
            let speedMatches = (filterBlitz && timeControlDisplay == "blitz") ||
                               (filterLive && timeControlDisplay == "live") ||
                               (filterCorrespondence && timeControlDisplay == "correspondence")

            // Board size filter
            let boardSize = challenge.game.width
            let sizeMatches = (filter9x9 && boardSize == 9) ||
                              (filter13x13 && boardSize == 13) ||
                              (filter19x19 && boardSize == 19)

            return speedMatches && sizeMatches
        }
    }

    // MARK: - Create Game Section

    private var createGameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Custom Game")
                .font(.headline)
                .foregroundColor(.white)

            Text("Post a public challenge with your settings")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Button(action: createCustomGame) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Game")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Game Settings Section

    private var gameSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game Settings")
                .font(.headline)
                .foregroundColor(.white)

            // Board Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Board Size")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 12) {
                    ForEach([9, 13, 19], id: \.self) { size in
                        Button(action: {
                            gameSettings.boardSize = size
                            gameSettings.save()
                        }) {
                            Text("\(size)×\(size)")
                                .font(.caption)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(gameSettings.boardSize == size ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Rank Range
            VStack(alignment: .leading, spacing: 8) {
                Text("Opponent Rank")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 12) {
                    ForEach(RankRange.allCases) { range in
                        Button(action: {
                            gameSettings.rankRange = range
                            gameSettings.save()
                        }) {
                            Text(range.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(gameSettings.rankRange == range ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Time Control
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Control")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 12) {
                    ForEach(TimeControlPreset.allCases) { preset in
                        Button(action: {
                            gameSettings.timeControl = preset
                            gameSettings.save()
                        }) {
                            Text(preset.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(gameSettings.timeControl == preset ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Color Preference
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 12) {
                    ForEach(ColorPreference.allCases) { color in
                        Button(action: {
                            gameSettings.colorPreference = color
                            gameSettings.save()
                        }) {
                            Text(color.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(gameSettings.colorPreference == color ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func refreshAvailableGames() {
        NSLog("PreGameOverlay: Refreshing available games...")

        ogsClient.fetchAvailableGames { challenges, error in
            if let error = error {
                NSLog("PreGameOverlay: Failed to fetch games: \(error)")
            } else if let challenges = challenges {
                NSLog("PreGameOverlay: Fetched \(challenges.count) available games")
            }
        }
    }

    private func acceptChallenge(_ challenge: OGSChallenge) {
        NSLog("PreGameOverlay: Accepting challenge \(challenge.id)")

        // TODO: Implement challenge acceptance
        // This will require adding an acceptChallenge() method to OGSClient
        // For now, just log it
        NSLog("PreGameOverlay: ⚠️ Challenge acceptance not yet implemented")
    }

    private func createCustomGame() {
        NSLog("PreGameOverlay: Creating custom game with settings: \(gameSettings)")

        // Save settings
        gameSettings.save()

        // Post custom game
        ogsClient.postCustomGame(settings: gameSettings) { success, error in
            if success {
                NSLog("PreGameOverlay: ✅ Custom game posted successfully")
                // Refresh the list to show our new game
                self.refreshAvailableGames()
            } else {
                NSLog("PreGameOverlay: ❌ Failed to post game: \(error ?? "unknown error")")
            }
        }
    }
}

// MARK: - Game Challenge Card

struct GameChallengeCard: View {
    let challenge: OGSChallenge
    let onAccept: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Left: Accept button
            Button(action: onAccept) {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Accept")
                        .font(.caption2)
                }
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Right: Game info
            VStack(alignment: .leading, spacing: 6) {
                // Player info
                HStack(spacing: 6) {
                    Text(challenge.challenger.username)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    Text("(\(challenge.challenger.displayRank))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Game details - first row
                HStack(spacing: 12) {
                    // Board size
                    HStack(spacing: 3) {
                        Image(systemName: "square.grid.3x3")
                            .font(.caption2)
                        Text(challenge.boardSize)
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.9))

                    // Ranked/Unranked
                    HStack(spacing: 3) {
                        if challenge.game.ranked {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text("Ranked")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        } else {
                            Image(systemName: "star")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Unranked")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                // Time control - second row (more prominent)
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text(timeControlDetails)
                        .font(.caption)
                }
                .foregroundColor(.cyan)
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // Extract detailed time control info
    private var timeControlDetails: String {
        guard let params = challenge.game.timeControlParameters,
              let data = params.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return challenge.timeControlDisplay
        }

        let speed = (json["speed"] as? String ?? "").capitalized

        if let system = json["system"] as? String {
            if system == "byoyomi" {
                if let mainTime = json["main_time"] as? Int,
                   let periodTime = json["period_time"] as? Int,
                   let periods = json["periods"] as? Int {
                    return "\(speed): \(mainTime/60)m + \(periods)×\(periodTime)s"
                }
            } else if system == "fischer" {
                if let initialTime = json["initial_time"] as? Int,
                   let increment = json["time_increment"] as? Int {
                    return "\(speed): \(initialTime/60)m + \(increment)s/move"
                }
            }
        }

        return speed
    }
}

// MARK: - Preview

struct PreGameOverlay_Previews: PreviewProvider {
    static var previews: some View {
        PreGameOverlay(ogsClient: OGSClient(), isVisible: .constant(true))
            .preferredColorScheme(.dark)
    }
}
