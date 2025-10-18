import SwiftUI

/// Pre-game overlay that appears before a game starts
/// Shows game setup options and automatch/challenge UI
struct PreGameOverlay: View {
    @ObservedObject var ogsClient: OGSClient
    @State private var gameSettings: GameSettings = GameSettings.load()

    // UI state
    @State private var isSearching = false
    @State private var challengeUsername = ""

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Main content card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Find a Game")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Quick Match Section
                        quickMatchSection

                        Divider()
                            .background(Color.white.opacity(0.3))

                        // Challenge Player Section
                        challengePlayerSection

                        Divider()
                            .background(Color.white.opacity(0.3))

                        // Game Settings Section
                        gameSettingsSection
                    }
                    .padding()
                }
            }
            .frame(maxWidth: 500, maxHeight: 600)
            .background(.thinMaterial)
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }

    // MARK: - Quick Match Section

    private var quickMatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Match")
                .font(.headline)
                .foregroundColor(.white)

            Text("Find an opponent automatically")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Button(action: {
                if isSearching {
                    cancelAutomatch()
                } else {
                    startAutomatch()
                }
            }) {
                HStack {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Searching...")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Start Game")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSearching ? Color.gray.opacity(0.5) : Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Challenge Player Section

    private var challengePlayerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Challenge Player")
                .font(.headline)
                .foregroundColor(.white)

            Text("Send a direct challenge")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack {
                TextField("Username", text: $challengeUsername)
                    .textFieldStyle(.roundedBorder)

                Button(action: sendChallenge) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(challengeUsername.isEmpty ? Color.gray.opacity(0.5) : Color.orange.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(challengeUsername.isEmpty)
            }
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

    private func startAutomatch() {
        isSearching = true
        // TODO: Stage 2 - Implement automatch API call
        NSLog("PreGameOverlay: Starting automatch with settings: \(gameSettings)")
    }

    private func cancelAutomatch() {
        isSearching = false
        // TODO: Stage 2 - Implement cancel automatch
        NSLog("PreGameOverlay: Canceling automatch")
    }

    private func sendChallenge() {
        // TODO: Stage 3 - Implement challenge sending
        NSLog("PreGameOverlay: Sending challenge to \(challengeUsername) with settings: \(gameSettings)")
    }
}

// MARK: - Preview

struct PreGameOverlay_Previews: PreviewProvider {
    static var previews: some View {
        PreGameOverlay(ogsClient: OGSClient())
            .preferredColorScheme(.dark)
    }
}
