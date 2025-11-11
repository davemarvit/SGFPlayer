import SwiftUI

/// Pre-game overlay that appears before a game starts
/// Shows game setup options and automatch/challenge UI
struct PreGameOverlay: View {
    @ObservedObject var ogsClient: OGSClient
    @State private var gameSettings: GameSettings = GameSettings.load()
    @Binding var isVisible: Bool  // Control visibility externally

    // UI state
    @State private var challengeUsername = ""

    // Filter state (persisted)
    @AppStorage("filterLive") private var filterLive = true  // Real-time games (Blitz + Live)
    @AppStorage("filterCorrespondence") private var filterCorrespondence = true  // Turn-based (days/weeks per move)
    @AppStorage("filter9x9") private var filter9x9 = true
    @AppStorage("filter13x13") private var filter13x13 = true
    @AppStorage("filter19x19") private var filter19x19 = true

    // Overlay size (persisted)
    @AppStorage("preGameOverlayWidth") private var overlayWidth: Double = 700
    @AppStorage("preGameOverlayHeight") private var overlayHeight: Double = 700

    // Last refresh timestamp for debugging
    @State private var lastRefresh: Date = Date()

    // Resize drag state
    @State private var isDragging = false

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
                    Text("Find a Game [v3.86]")
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
            .frame(width: overlayWidth, height: overlayHeight)
            .background(Color(white: 0.15))  // Dark gray background instead of thinMaterial
            .cornerRadius(12)
            .shadow(radius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)  // Subtle border, not bright blue
            )
            .overlay(alignment: .bottomTrailing) {
                // Resize handle in bottom-right corner
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(isDragging ? 0.9 : 0.5))
                    .padding(8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                // Update size based on drag, with min/max bounds
                                let newWidth = max(500, min(1200, overlayWidth + value.translation.width))
                                let newHeight = max(400, min(900, overlayHeight + value.translation.height))
                                overlayWidth = newWidth
                                overlayHeight = newHeight
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .help("Drag to resize")
            }
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
                    Text("\(filteredGames.count) games (raw: \(ogsClient.availableGames.count))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    if let username = ogsClient.username {
                        if let rank = ogsClient.userRank {
                            Text("Logged in as: \(username) (\(rankString(rank)))")
                                .font(.caption2)
                                .foregroundColor(.cyan.opacity(0.9))
                        } else {
                            Text("Logged in as: \(username)")
                                .font(.caption2)
                                .foregroundColor(.cyan.opacity(0.9))
                        }
                    } else {
                        Text("Not logged in")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.9))
                    }

                    Text("Updated: \(lastRefresh, formatter: Self.timeFormatter)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))

                    Text("Filters: RT=\(filterLive) C=\(filterCorrespondence) 9=\(filter9x9) 13=\(filter13x13) 19=\(filter19x19)")
                        .font(.caption2)
                        .foregroundColor(.yellow.opacity(0.8))
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
                            GameChallengeCard(
                                challenge: challenge,
                                isOwnChallenge: challenge.challenger.id == ogsClient.playerID,
                                onAccept: {
                                    acceptChallenge(challenge)
                                },
                                onCancel: {
                                    cancelChallenge(challenge)
                                }
                            )
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

            // Check expired/abandoned flags
            let blackLost = challenge.game.blackLost
            let whiteLost = challenge.game.whiteLost
            let annulled = challenge.game.annulled

            // A challenge is NOT available if it's expired or abandoned
            let notExpired = !blackLost && !whiteLost && !annulled

            // Debug first game
            if challenge.id == all.first?.id {
                NSLog("PreGameOverlay: First game - black:\(challenge.game.black?.description ?? "nil") white:\(challenge.game.white?.description ?? "nil") started:\(challenge.game.started ?? "nil") blackLost:\(blackLost) whiteLost:\(whiteLost) annulled:\(annulled) notExpired:\(notExpired)")
            }

            // Skip games that are already accepted/started OR expired/abandoned
            guard notAccepted && notExpired else {
                return false
            }

            // Speed filter - "Real-time" includes Blitz, Live, Rapid, Fischer, Byoyomi, Canadian, Simple
            // Only "Correspondence" is turn-based
            let timeControlDisplay = challenge.timeControlDisplay.lowercased()
            let isCorr = timeControlDisplay == "correspondence"
            let isRealTime = !isCorr  // Everything except correspondence is real-time

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
                    Text("Create Public Game")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Divider between public and direct challenge
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 4)

            Text("Challenge a Specific Player")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            Text("Send a direct challenge to a player by username")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 8) {
                TextField("Player username", text: $challengeUsername)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .disabled(ogsClient.isSendingChallenge)

                Button(action: challengePlayer) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Challenge")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(challengeUsername.isEmpty ? Color.gray.opacity(0.5) : Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(challengeUsername.isEmpty || ogsClient.isSendingChallenge)
            }

            if ogsClient.isSendingChallenge {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Sending challenge...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if let error = ogsClient.lastError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.9))
            }
        }
    }

    // MARK: - Game Settings Section

    private var gameSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Game Settings")
                .font(.headline)
                .foregroundColor(.white)

            // Two-column layout matching OGS
            HStack(alignment: .top, spacing: 24) {
                // Left Column
                VStack(alignment: .leading, spacing: 12) {
                    // Game Name
                    settingRow(label: "Game Name") {
                        TextField("Game Name", text: $gameSettings.gameName)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .onChange(of: gameSettings.gameName) { _ in gameSettings.save() }
                    }

                    // Invite-only
                    settingRow(label: "Invite-only") {
                        Toggle("", isOn: $gameSettings.inviteOnly)
                            .labelsHidden()
                            .onChange(of: gameSettings.inviteOnly) { _ in gameSettings.save() }
                    }

                    // Rules
                    settingRow(label: "Rules") {
                        Picker("", selection: $gameSettings.rules) {
                            ForEach(GameRules.allCases) { rule in
                                Text(rule.rawValue).tag(rule)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: gameSettings.rules) { _ in gameSettings.save() }
                    }

                    // Time Control System
                    settingRow(label: "Time Control") {
                        Picker("", selection: $gameSettings.timeControlSystem) {
                            ForEach(TimeControlSystem.allCases) { system in
                                Text(system.rawValue).tag(system)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: gameSettings.timeControlSystem) { _ in gameSettings.save() }
                    }

                    // Main Time (always shown)
                    settingRow(label: "Main Time") {
                        HStack(spacing: 4) {
                            TextField("", value: $gameSettings.mainTimeMinutes, format: .number)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .padding(6)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                .frame(width: 60)
                                .onChange(of: gameSettings.mainTimeMinutes) { _ in gameSettings.save() }
                            Stepper("", value: $gameSettings.mainTimeMinutes, in: 1...999, step: 1)
                                .labelsHidden()
                                .onChange(of: gameSettings.mainTimeMinutes) { _ in gameSettings.save() }
                            Text("min")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    // Fischer-specific fields
                    if gameSettings.timeControlSystem == .fischer {
                        settingRow(label: "Time Increment") {
                            HStack(spacing: 4) {
                                TextField("", value: $gameSettings.fischerIncrementSeconds, format: .number)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .padding(6)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .frame(width: 60)
                                    .onChange(of: gameSettings.fischerIncrementSeconds) { _ in gameSettings.save() }
                                Stepper("", value: $gameSettings.fischerIncrementSeconds, in: 1...999, step: 1)
                                    .labelsHidden()
                                    .onChange(of: gameSettings.fischerIncrementSeconds) { _ in gameSettings.save() }
                                Text("sec")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        settingRow(label: "Max Time") {
                            HStack(spacing: 4) {
                                TextField("", value: $gameSettings.fischerMaxTimeMinutes, format: .number)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .padding(6)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .frame(width: 60)
                                    .onChange(of: gameSettings.fischerMaxTimeMinutes) { _ in gameSettings.save() }
                                Stepper("", value: $gameSettings.fischerMaxTimeMinutes, in: 1...999, step: 1)
                                    .labelsHidden()
                                    .onChange(of: gameSettings.fischerMaxTimeMinutes) { _ in gameSettings.save() }
                                Text("min")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }

                    // Byo-Yomi/Canadian/Simple-specific fields
                    if gameSettings.timeControlSystem == .byoyomi ||
                       gameSettings.timeControlSystem == .canadian ||
                       gameSettings.timeControlSystem == .simple {
                        settingRow(label: "Time per Period") {
                            HStack(spacing: 4) {
                                TextField("", value: $gameSettings.periodTimeSeconds, format: .number)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .padding(6)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .frame(width: 60)
                                    .onChange(of: gameSettings.periodTimeSeconds) { _ in gameSettings.save() }
                                Stepper("", value: $gameSettings.periodTimeSeconds, in: 1...999, step: 1)
                                    .labelsHidden()
                                    .onChange(of: gameSettings.periodTimeSeconds) { _ in gameSettings.save() }
                                Text("sec")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        settingRow(label: "Periods") {
                            HStack(spacing: 4) {
                                TextField("", value: $gameSettings.periods, format: .number)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .padding(6)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .frame(width: 60)
                                    .onChange(of: gameSettings.periods) { _ in gameSettings.save() }
                                Stepper("", value: $gameSettings.periods, in: 1...99, step: 1)
                                    .labelsHidden()
                                    .onChange(of: gameSettings.periods) { _ in gameSettings.save() }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Right Column
                VStack(alignment: .leading, spacing: 12) {
                    // Ranked
                    settingRow(label: "Ranked") {
                        Toggle("", isOn: $gameSettings.ranked)
                            .labelsHidden()
                            .onChange(of: gameSettings.ranked) { _ in gameSettings.save() }
                    }

                    // Board Size
                    settingRow(label: "Board Size") {
                        Picker("", selection: $gameSettings.boardSize) {
                            Text("9×9").tag(9)
                            Text("13×13").tag(13)
                            Text("19×19").tag(19)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: gameSettings.boardSize) { _ in gameSettings.save() }
                    }

                    // Handicap
                    settingRow(label: "Handicap") {
                        Picker("", selection: $gameSettings.handicap) {
                            ForEach(HandicapOption.allCases) { handicap in
                                Text(handicap.rawValue).tag(handicap)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: gameSettings.handicap) { _ in gameSettings.save() }
                    }

                    // Komi
                    settingRow(label: "Komi") {
                        Picker("", selection: $gameSettings.komi) {
                            ForEach(KomiOption.allCases) { komi in
                                Text(komi.rawValue).tag(komi)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: gameSettings.komi) { _ in gameSettings.save() }
                    }

                    // Custom Komi Value (shown when Custom is selected)
                    if gameSettings.komi == .custom {
                        settingRow(label: "Komi Value") {
                            HStack(spacing: 4) {
                                TextField("6.5", value: $gameSettings.customKomi, format: .number)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .padding(6)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .frame(width: 60)
                                    .onChange(of: gameSettings.customKomi) { _ in gameSettings.save() }
                                Stepper("", value: $gameSettings.customKomi, in: 0.5...99.5, step: 1.0)
                                    .labelsHidden()
                                    .onChange(of: gameSettings.customKomi) { _ in gameSettings.save() }
                            }
                        }
                    }

                    // Your Color
                    settingRow(label: "Your Color") {
                        Picker("", selection: $gameSettings.colorPreference) {
                            ForEach(ColorPreference.allCases) { color in
                                Text(color.rawValue).tag(color)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: gameSettings.colorPreference) { _ in gameSettings.save() }
                    }

                    // Disable Analysis
                    settingRow(label: "Disable Analysis") {
                        HStack {
                            Toggle("", isOn: $gameSettings.disableAnalysis)
                                .labelsHidden()
                                .onChange(of: gameSettings.disableAnalysis) { _ in gameSettings.save() }
                            Text("*")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                        }
                    }

                    // Restrict Rank
                    settingRow(label: "Restrict Rank") {
                        Toggle("", isOn: $gameSettings.restrictRank)
                            .labelsHidden()
                            .onChange(of: gameSettings.restrictRank) { _ in gameSettings.save() }
                    }

                    // Rank Restrictions (shown when Restrict Rank is on)
                    if gameSettings.restrictRank {
                        VStack(alignment: .leading, spacing: 8) {
                            settingRow(label: "  Ranks Above") {
                                Picker("", selection: Binding(
                                    get: { rankRestrictionToInt(gameSettings.ranksAbove) },
                                    set: { gameSettings.ranksAbove = intToRankRestriction($0); gameSettings.save() }
                                )) {
                                    Text("Any").tag(-1)
                                    ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], id: \.self) { value in
                                        Text("±\(value) rank\(value == 1 ? "" : "s")").tag(value)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 100)
                            }

                            settingRow(label: "  Ranks Below") {
                                Picker("", selection: Binding(
                                    get: { rankRestrictionToInt(gameSettings.ranksBelow) },
                                    set: { gameSettings.ranksBelow = intToRankRestriction($0); gameSettings.save() }
                                )) {
                                    Text("Any").tag(-1)
                                    ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], id: \.self) { value in
                                        Text("±\(value) rank\(value == 1 ? "" : "s")").tag(value)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 100)
                            }

                            // Show actual rank range if user rank is known
                            if let userRank = ogsClient.userRank {
                                Text(rankRangeDescription(userRank: userRank))
                                    .font(.caption2)
                                    .foregroundColor(.cyan.opacity(0.8))
                                    .padding(.leading, 16)
                                    .padding(.top, 4)
                            }
                        }
                    }

                    Text("* Also disables conditional moves")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // Helper to create consistent setting rows
    private func settingRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 120, alignment: .trailing)
            content()
        }
    }

    // MARK: - Helper Functions

    private func rankString(_ rank: Double) -> String {
        // OGS rank: 0-29 = kyu (30k-1k), 30-38 = dan (1d-9d)
        if rank < 30 {
            let kyu = 30 - Int(rank)
            return "\(kyu)k"
        } else {
            let dan = Int(rank) - 29
            return "\(dan)d"
        }
    }

    // Show the actual rank range based on user's rank and restrictions
    private func rankRangeDescription(userRank: Double) -> String {
        // Calculate min and max ranks
        var minRank = 0
        var maxRank = 36 // 9d professional

        switch gameSettings.ranksBelow {
        case .any:
            minRank = 0
        case .limit(let delta):
            minRank = max(0, Int(userRank) - delta)
        }

        switch gameSettings.ranksAbove {
        case .any:
            maxRank = 36
        case .limit(let delta):
            maxRank = min(36, Int(userRank) + delta)
        }

        // Format the range
        let minRankStr = rankString(Double(minRank))
        let maxRankStr = rankString(Double(maxRank))
        let userRankStr = rankString(userRank)

        if minRank == 0 && maxRank == 36 {
            return "→ Accepting all ranks"
        } else {
            return "→ Range: \(minRankStr) to \(maxRankStr) (you: \(userRankStr))"
        }
    }

    // Convert RankRestriction to Int for Picker
    private func rankRestrictionToInt(_ restriction: RankRestriction) -> Int {
        switch restriction {
        case .any:
            return -1
        case .limit(let value):
            return value
        }
    }

    // Convert Int from Picker to RankRestriction
    private func intToRankRestriction(_ value: Int) -> RankRestriction {
        if value == -1 {
            return .any
        } else {
            return .limit(value)
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

    private func cancelChallenge(_ challenge: OGSChallenge) {
        NSLog("PreGameOverlay: Canceling challenge \(challenge.id)")

        ogsClient.cancelChallenge(challengeID: challenge.id) { success, error in
            if success {
                NSLog("PreGameOverlay: ✅ Challenge canceled successfully")
                // Refresh the list to remove the canceled challenge
                DispatchQueue.main.async {
                    self.refreshAvailableGames()
                }
            } else {
                NSLog("PreGameOverlay: ❌ Failed to cancel challenge: \(error ?? "unknown error")")
            }
        }
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

    private func challengePlayer() {
        let username = challengeUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            NSLog("PreGameOverlay: ⚠️ Challenge username is empty")
            return
        }

        NSLog("PreGameOverlay: Challenging player '\(username)' with settings: \(gameSettings)")

        // Save settings
        gameSettings.save()

        // Send challenge to specific player
        ogsClient.sendChallenge(to: username, settings: gameSettings)

        // Clear the username field on success (will be handled by OGSClient state)
        // The UI will show loading state via ogsClient.isSendingChallenge
    }
}

// MARK: - Game Challenge Card

struct GameChallengeCard: View {
    let challenge: OGSChallenge
    let isOwnChallenge: Bool  // Is this the user's own challenge?
    let onAccept: () -> Void
    let onCancel: (() -> Void)?  // Optional cancel callback

    var body: some View {
        HStack(spacing: 12) {
            // Left: Accept or Cancel button
            if isOwnChallenge {
                // Show Cancel button for user's own challenges
                Button(action: { onCancel?() }) {
                    VStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                        Text("Cancel")
                            .font(.caption2)
                    }
                    .frame(width: 60)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                // Show Accept button for other players' challenges
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
            }

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
