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
    @State private var filterLive = true  // Real-time games (Blitz + Live)
    @State private var filterCorrespondence = false  // Turn-based (days/weeks per move)
    @State private var filter9x9 = true
    @State private var filter13x13 = true
    @State private var filter19x19 = true

    // Last refresh timestamp for debugging
    @State private var lastRefresh: Date = Date()

    // Time formatter for display
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

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
        .task {
            // Fetch games immediately when overlay appears
            NSLog("PreGameOverlay: 📋 Overlay appeared - fetching initial games")
            print("PreGameOverlay: 📋 Overlay appeared - fetching initial games")
            refreshAvailableGames()

            // Auto-refresh loop
            var count = 0
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    count += 1
                    NSLog("PreGameOverlay: ⏰ Timer #\(count) fired - refreshing games")
                    print("PreGameOverlay: ⏰ Timer #\(count) fired - refreshing games")
                    refreshAvailableGames()
                } catch {
                    // Task cancelled, stop loop
                    NSLog("PreGameOverlay: ❌ Task cancelled")
                    print("PreGameOverlay: ❌ Task cancelled")
                    break
                }
            }
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

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(filteredGames.count) games")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Text("Updated: \(lastRefresh, formatter: Self.timeFormatter)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Filter checkboxes
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    Text("Speed:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Toggle("Real-time", isOn: $filterLive)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .help("Live games played in minutes (includes Blitz and Live)")

                    Toggle("Correspondence", isOn: $filterCorrespondence)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .help("Turn-based games with days/weeks per move")
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
                    // 2-column grid layout
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
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
        let all = ogsClient.availableGames
        NSLog("PreGameOverlay: Filtering \(all.count) total games")

        let filtered = all.filter { challenge in
            // MOST IMPORTANT: Only show games that are truly available
            // Skip if already accepted (black/white/started are populated)
            let notAccepted = challenge.game.black == nil &&
                             challenge.game.white == nil &&
                             challenge.game.started == nil

            // Check expired flags (but may not be reliable)
            let blackLost = challenge.game.blackLost
            let whiteLost = challenge.game.whiteLost
            let annulled = challenge.game.annulled

            // Debug first game
            if challenge.id == all.first?.id {
                NSLog("PreGameOverlay: First game - black:\(challenge.game.black?.description ?? "nil") white:\(challenge.game.white?.description ?? "nil") started:\(challenge.game.started ?? "nil") blackLost:\(blackLost) whiteLost:\(whiteLost) annulled:\(annulled)")
            }

            // Only check if accepted for now - ignore lost/annulled flags
            guard notAccepted else {
                return false  // Skip accepted/started games
            }

            // Speed filter - "Real-time" includes both Blitz and Live
            let timeControlDisplay = challenge.timeControlDisplay.lowercased()
            let isRealTime = timeControlDisplay == "blitz" || timeControlDisplay == "live"
            let isCorr = timeControlDisplay == "correspondence"

            let speedMatches = (filterLive && isRealTime) || (filterCorrespondence && isCorr)

            // Board size filter
            let boardSize = challenge.game.width
            let sizeMatches = (filter9x9 && boardSize == 9) ||
                              (filter13x13 && boardSize == 13) ||
                              (filter19x19 && boardSize == 19)

            return speedMatches && sizeMatches
        }

        NSLog("PreGameOverlay: After filtering: \(filtered.count) games (from \(all.count))")
        return filtered
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
        let currentCount = ogsClient.availableGames.count
        NSLog("PreGameOverlay: 🔄 Refreshing available games (current: \(currentCount))...")

        ogsClient.fetchAvailableGames { challenges, error in
            if let error = error {
                NSLog("PreGameOverlay: ❌ Failed to fetch games: \(error)")
            } else if let challenges = challenges {
                NSLog("PreGameOverlay: ✅ Fetched \(challenges.count) available games")
                // Update last refresh timestamp on main thread
                DispatchQueue.main.async {
                    self.lastRefresh = Date()
                }
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

                // Game settings - third row (rules, handicap, komi)
                HStack(spacing: 8) {
                    // Rules
                    Text(challenge.game.rules.capitalized)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))

                    // Handicap
                    if challenge.game.handicap > 0 {
                        Text("H\(challenge.game.handicap)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text("Even")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))

                    // Komi
                    if let komi = challenge.game.komi {
                        Text("Komi \(komi)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Auto komi")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
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
        let isCorrespondence = speed.lowercased() == "correspondence"

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
                    // Format correspondence games in days/weeks
                    if isCorrespondence {
                        let initialDays = initialTime / 86400
                        let incrementDays = increment / 86400

                        // Format initial time
                        let initialStr: String
                        if initialDays >= 7 {
                            let weeks = initialDays / 7
                            initialStr = "\(weeks)w"
                        } else {
                            initialStr = "\(initialDays)d"
                        }

                        // Format increment
                        let incrementStr: String
                        if incrementDays >= 7 {
                            let weeks = incrementDays / 7
                            incrementStr = "\(weeks)w"
                        } else {
                            incrementStr = "\(incrementDays)d"
                        }

                        return "\(speed): \(initialStr) + \(incrementStr)/move"
                    } else {
                        // Format live/blitz games in minutes
                        return "\(speed): \(initialTime/60)m + \(increment)s/move"
                    }
                }
            } else if system == "simple" {
                // Handle simple time control (used by some correspondence games)
                if let perMove = json["per_move"] as? Int {
                    if isCorrespondence {
                        let days = perMove / 86400
                        if days >= 7 {
                            return "\(speed): \(days/7)w/move"
                        } else {
                            return "\(speed): \(days)d/move"
                        }
                    }
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
