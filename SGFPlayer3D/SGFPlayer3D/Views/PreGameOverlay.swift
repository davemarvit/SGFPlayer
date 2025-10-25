import SwiftUI

/// Pre-game overlay that appears before a game starts
/// Shows game setup options and automatch/challenge UI
struct PreGameOverlay: View {
    @ObservedObject var ogsClient: OGSClient
    @State private var gameSettings: GameSettings = GameSettings.load()
    @Binding var isVisible: Bool  // Control visibility externally

    // UI state - sync with OGSClient.isSearchingForMatch
    @State private var challengeUsername = ""

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
        }
    }

    // MARK: - Available Games Section

    private var availableGamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Games")
                .font(.headline)
                .foregroundColor(.white)

            if ogsClient.availableGames.isEmpty {
                Text("No games available. Create one below!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ogsClient.availableGames) { challenge in
                            GameChallengeCard(challenge: challenge) {
                                acceptChallenge(challenge)
                            }
                        }
                    }
                }
                .frame(height: 140)
            }
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
        VStack(alignment: .leading, spacing: 8) {
            // Player info
            if let challenger = challenge.challenger {
                HStack {
                    Text(challenger.username)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("(\(challenger.displayRank))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Game info
            HStack(spacing: 12) {
                // Board size
                Label(challenge.boardSize, systemImage: "square.grid.3x3")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))

                // Ranked/Unranked
                if challenge.ranked {
                    Label("Ranked", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                } else {
                    Label("Unranked", systemImage: "star")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Time control
            if let timeControl = challenge.timeControl {
                Text(timeControl)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Accept button
            Button(action: onAccept) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Accept")
                }
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 200)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct PreGameOverlay_Previews: PreviewProvider {
    static var previews: some View {
        PreGameOverlay(ogsClient: OGSClient(), isVisible: .constant(true))
            .preferredColorScheme(.dark)
    }
}
