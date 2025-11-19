// MARK: - Settings Panel View for SGFPlayer3D
// Simplified version focused on game selection and 3D-specific settings

import SwiftUI

struct SettingsPanelView3D: View {
    @Binding var isPanelOpen: Bool
    @ObservedObject var app: AppModel
    @ObservedObject var player: SGFPlayer
    @ObservedObject var settingsVM: SettingsViewModel
    @ObservedObject var soundManager: SoundManager
    @ObservedObject var ogsClient: OGSClient

    // Playback controls
    @Binding var autoPlay: Bool
    @Binding var randomNext: Bool
    @Binding var autoStartOnLaunch: Bool
    @Binding var loopGames: Bool
    @Binding var playbackSpeed: Double

    var onGameSelected: ((SGFGameWrapper) -> Void)?
    var onJitterChanged: (() -> Void)?
    var onSearchResultsChanged: (([SGFGameWrapper]) -> Void)?
    var onBackgroundChanged: ((BackgroundType) -> Void)?
    var onResetCamera: (() -> Void)?

    @State private var localJitterMultiplier: CGFloat = 1.0
    @State private var ogsGameID: String = ""
    @State private var ogsUsername: String = ""
    @State private var ogsPassword: String = ""
    @State private var isAuthenticating: Bool = false
    @State private var isConnecting: Bool = false
    @State private var authError: String? = nil
    @State private var hasLoadedCredentials = false

    // MARK: - Helper Functions

    /// Extract game ID from either a direct ID number or an OGS URL
    /// Supports URLs like: https://online-go.com/game/12345 or https://online-go.com/game/12345/review
    private func joinGame(from input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try parsing as direct game ID first
        if let gameID = Int(trimmed) {
            NSLog("OGS: 🎮 Parsed direct game ID: \(gameID)")
            ogsClient.joinGame(gameID: gameID)
            return
        }

        // Try extracting from URL
        if let url = URL(string: trimmed),
           let host = url.host,
           host.contains("online-go.com") {
            // Extract game ID from path like "/game/12345" or "/game/12345/review"
            let pathComponents = url.pathComponents
            if let gameIndex = pathComponents.firstIndex(of: "game"),
               gameIndex + 1 < pathComponents.count,
               let gameID = Int(pathComponents[gameIndex + 1]) {
                NSLog("OGS: 🎮 Extracted game ID \(gameID) from URL: \(trimmed)")
                ogsClient.joinGame(gameID: gameID)
                return
            }
        }

        NSLog("OGS: ❌ Failed to parse game ID from input: '\(trimmed)'")
    }

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

    var body: some View {
        ZStack {
            // Background for entire panel
            Rectangle()
                .fill(.thinMaterial)

            VStack(spacing: 0) {
                // Header with gear icon
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPanelOpen = false
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                    .padding(.top, 20)

                    Text("Settings")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPanelOpen = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                }
                .padding(.trailing, 50)
                .padding(.bottom, 16)

                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Folder selection
                        FolderSelectionSection3D(app: app)
                            .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // View Mode selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("View Mode")
                                .font(.headline)
                                .foregroundColor(.white)

                            Picker("", selection: $app.viewMode) {
                                ForEach(ViewMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("Switch between 2D and 3D board views. Game progress is preserved when switching.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Last Move Effects (combinable)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Move Effects")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Select one or more effects to combine")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(LastMoveEffect.allCases) { effect in
                                    Toggle(isOn: Binding(
                                        get: { LastMoveIndicatorSettings.isEffectEnabled(effect) },
                                        set: { enabled in
                                            LastMoveIndicatorSettings.setEffect(effect, enabled: enabled)
                                            // Force scene refresh by updating stones
                                            // Preserve playback state
                                            let wasPlaying = player.isPlaying
                                            player.seek(to: player.currentIndex)
                                            if wasPlaying {
                                                player.play()
                                            }
                                        }
                                    )) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(effect.rawValue)
                                                .foregroundColor(.white)
                                            Text(effect.description)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Play Mode selection (Local / OGS)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Play Mode")
                                .font(.headline)
                                .foregroundColor(.white)

                            Picker("", selection: $settingsVM.ogsMode) {
                                Text("Local").tag(false)
                                Text("OGS").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .onAppear {
                                // Auto-connect if OGS mode is already enabled on startup
                                if settingsVM.ogsMode && !ogsClient.isConnected {
                                    ogsClient.connect()
                                    NSLog("OGS: 🔌 Auto-connecting on startup (OGS Mode was already ON)")
                                }
                            }
                            .onChange(of: settingsVM.ogsMode) { _, newValue in
                                if newValue {
                                    // Auto-connect when OGS mode is turned on
                                    if !ogsClient.isConnected {
                                        ogsClient.connect()
                                        NSLog("OGS: 🔌 Auto-connecting when OGS Mode enabled")
                                    }
                                } else {
                                    // Disconnect when OGS mode is turned off
                                    if ogsClient.isConnected {
                                        ogsClient.disconnect()
                                        NSLog("OGS: 🔌 Disconnecting when OGS Mode disabled")
                                    }

                                    // Auto-start playing local games if enabled
                                    if autoStartOnLaunch {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            // If no game is selected, pick one first
                                            if app.selection == nil && !app.games.isEmpty {
                                                let randomOnStart = UserDefaults.standard.bool(forKey: "randomOnStart")
                                                if randomOnStart {
                                                    app.pickRandomGame(from: app.games)
                                                    NSLog("OGS: 🎲 Picked random game after switching to local mode")
                                                } else {
                                                    app.selectGame(app.games[0])
                                                    NSLog("OGS: 🎮 Picked first game after switching to local mode")
                                                }
                                            }

                                            // Start playing
                                            if app.selection != nil {
                                                autoPlay = true
                                                player.play()
                                                NSLog("OGS: ▶️ Auto-started playback after switching to local mode")
                                            }
                                        }
                                    }
                                }
                            }

                            Text(settingsVM.ogsMode ? "Play live games on Online Go Server" : "Play local SGF game files")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            // OGS Connection controls (shown when OGS mode is on)
                            if settingsVM.ogsMode {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Connection status
                                    HStack {
                                        Circle()
                                            .fill(ogsClient.isConnected ? Color.green : Color.red)
                                            .frame(width: 8, height: 8)
                                        Text(ogsClient.isConnected ? "Connected" : "Disconnected")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }

                                    // Authentication - always show when in OGS mode
                                    if ogsClient.isAuthenticated {
                                        // Show authenticated status
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Logged in as \(ogsClient.username ?? "unknown")\(ogsClient.userRank != nil ? " (\(rankString(ogsClient.userRank!)))" : " (rank unknown)")")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                            Spacer()
                                            Button("Logout") {
                                                // Clear UI fields before deleting credentials
                                                ogsUsername = ""
                                                ogsPassword = ""
                                                hasLoadedCredentials = false
                                                ogsClient.deleteCredentials()
                                                // Note: Connection stays active for anonymous spectating
                                            }
                                            .foregroundColor(.white)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.red.opacity(0.6))
                                            .cornerRadius(4)
                                            .buttonStyle(.plain)
                                        }
                                    } else {
                                        // Show login form
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Login (optional for spectating)")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.6))

                                                TextField("Username", text: $ogsUsername)
                                                    .textFieldStyle(.roundedBorder)
                                                    .frame(maxWidth: .infinity)
                                                    .disabled(isAuthenticating)
                                                    .onAppear {
                                                        if !hasLoadedCredentials, let username = ogsClient.username {
                                                            ogsUsername = username
                                                            hasLoadedCredentials = true
                                                            NSLog("OGS: 📋 Prepopulated username: \(username)")
                                                        }
                                                    }

                                                SecureField("Password", text: $ogsPassword)
                                                    .textFieldStyle(.roundedBorder)
                                                    .frame(maxWidth: .infinity)
                                                    .disabled(isAuthenticating)
                                                    .onSubmit {
                                                        // Trigger login when Return is pressed
                                                        if !ogsUsername.isEmpty && !ogsPassword.isEmpty && !isAuthenticating {
                                                            NSLog("OGS: 🔑 Login triggered by Return key")

                                                            // Ensure we're connected before authenticating
                                                            if !ogsClient.isConnected {
                                                                NSLog("OGS: 🔌 Not connected, connecting first...")
                                                                ogsClient.connect()
                                                            }

                                                            isAuthenticating = true
                                                            authError = nil
                                                            ogsClient.authenticate(username: ogsUsername, password: ogsPassword) { success, error in
                                                                DispatchQueue.main.async {
                                                                    isAuthenticating = false
                                                                    if !success {
                                                                        authError = error ?? "Login failed"
                                                                        NSLog("OGS: ❌ Login failed: \(error ?? "unknown")")
                                                                    } else {
                                                                        NSLog("OGS: ✅ Login successful!")
                                                                        ogsPassword = ""
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }

                                                Button(isAuthenticating ? "Logging in..." : "Login") {
                                                    NSLog("OGS: 🔑 Login button clicked! Username: '\(ogsUsername)', Password length: \(ogsPassword.count)")

                                                    // Ensure we're connected before authenticating
                                                    if !ogsClient.isConnected {
                                                        NSLog("OGS: 🔌 Not connected, connecting first...")
                                                        ogsClient.connect()
                                                    }

                                                    isAuthenticating = true
                                                    authError = nil
                                                    ogsClient.authenticate(username: ogsUsername, password: ogsPassword) { success, error in
                                                        DispatchQueue.main.async {
                                                            isAuthenticating = false
                                                            if !success {
                                                                authError = error ?? "Login failed"
                                                                NSLog("OGS: ❌ Login failed: \(error ?? "unknown")")
                                                            } else {
                                                                NSLog("OGS: ✅ Login successful!")
                                                                // Clear password for security
                                                                ogsPassword = ""
                                                            }
                                                        }
                                                    }
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(isAuthenticating ? Color.gray.opacity(0.6) : Color.green.opacity(0.8))
                                                .cornerRadius(6)
                                                .buttonStyle(.plain)
                                                .disabled(isAuthenticating || ogsUsername.isEmpty || ogsPassword.isEmpty)

                                                // Show auth error if any
                                                if let error = authError {
                                                    Text("Login error: \(error)")
                                                        .font(.caption)
                                                        .foregroundColor(.red.opacity(0.9))
                                                        .lineLimit(2)
                                                }
                                        }
                                    }

                                    // Find a Game button (shown when authenticated)
                                    if ogsClient.isConnected {
                                        Button(action: {
                                            app.showPreGameOverlay = true
                                            isPanelOpen = false
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Find a Game")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(ogsClient.isAuthenticated ? Color.green.opacity(0.7) : Color.gray.opacity(0.3))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!ogsClient.isAuthenticated)
                                    }

                                    // Game ID input (shown when connected)
                                    if ogsClient.isConnected {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Watch Game")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))

                                            HStack {
                                                TextField("Game ID or URL", text: $ogsGameID)
                                                    .textFieldStyle(.roundedBorder)
                                                    .frame(maxWidth: .infinity)
                                                    .onSubmit {
                                                        // Trigger join when Enter is pressed
                                                        if !ogsGameID.isEmpty {
                                                            NSLog("OGS: 🎮 Join triggered by Enter key! Input: '\(ogsGameID)'")
                                                            joinGame(from: ogsGameID)
                                                        }
                                                    }

                                                Button("Join") {
                                                    NSLog("OGS: 🎮 Join button clicked! Input: '\(ogsGameID)'")
                                                    joinGame(from: ogsGameID)
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(.orange.opacity(0.8))
                                                .cornerRadius(6)
                                                .buttonStyle(.plain)
                                                .disabled(ogsGameID.isEmpty)
                                            }
                                        }
                                    }

                                    // Error display
                                    if let error = ogsClient.lastError {
                                        Text("Error: \(error)")
                                            .font(.caption)
                                            .foregroundColor(.red.opacity(0.8))
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Background selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Background")
                                .font(.headline)
                                .foregroundColor(.white)

                            Picker("", selection: Binding(
                                get: { settingsVM.backgroundType },
                                set: { newValue in
                                    settingsVM.backgroundType = newValue
                                    onBackgroundChanged?(newValue)
                                }
                            )) {
                                Text("Star Field").tag(BackgroundType.stars)
                                Text("HDRI (if available)").tag(BackgroundType.hdri)
                                Text("Solid Color").tag(BackgroundType.solid)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Game selection list (only shown when NOT in OGS mode)
                        if !settingsVM.ogsMode {
                            GameSelectionSection(app: app, onSearchResultsChanged: onSearchResultsChanged)
                                .padding(.horizontal, 16)
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        // Auto-play controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Playback")
                                .font(.headline)
                                .foregroundColor(.white)

                            // Put both toggles on the same line with consistent blue color
                            HStack(spacing: 20) {
                                Toggle("Auto-play", isOn: $autoPlay)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    .foregroundColor(.white)

                                Toggle("Random next", isOn: $randomNext)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    .foregroundColor(.white)
                            }

                            // Additional playback settings
                            HStack(spacing: 20) {
                                Toggle("Auto-start on launch", isOn: $autoStartOnLaunch)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    .foregroundColor(.white)

                                Toggle("Loop games", isOn: $loopGames)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 8)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Move Delay")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.1fs", playbackSpeed))")
                                        .monospacedDigit()
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .font(.caption)

                                // Log scale slider: 0.1-10s with ~1s at midpoint
                                Slider(
                                    value: Binding(
                                        get: {
                                            // Convert playbackSpeed to log position (0.0 to 1.0)
                                            if playbackSpeed <= 0.1 { return 0.0 }
                                            let logValue = log10(playbackSpeed / 0.1) / log10(100.0) // 0.1s to 10s mapped to 0-1
                                            return min(max(logValue, 0.0), 1.0)
                                        },
                                        set: { sliderValue in
                                            // Convert log position back to delay (0.1s to 10s)
                                            let delay = 0.1 * pow(100.0, sliderValue) // 100x range: 0.1s to 10s
                                            playbackSpeed = min(max(delay, 0.1), 10.0)
                                        }
                                    ),
                                    in: 0.0...1.0
                                )
                                .controlSize(.regular)
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Volume controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sound")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Volume")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(soundManager.volume * 100))%")
                                        .monospacedDigit()
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .font(.caption)

                                Slider(
                                    value: Binding(
                                        get: { soundManager.volume },
                                        set: { newValue in
                                            soundManager.setVolume(newValue)
                                        }
                                    ),
                                    in: 0.0...1.0,
                                    step: 0.05
                                )
                                .controlSize(.regular)
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Jitter controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stone Jitter")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Amount")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.1f", localJitterMultiplier))")
                                        .monospacedDigit()
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .font(.caption)

                                Slider(
                                    value: $localJitterMultiplier,
                                    in: 0.0...2.0,
                                    step: 0.1
                                )
                                .controlSize(.regular)
                                .onChange(of: localJitterMultiplier) { oldValue, newValue in
                                    NSLog("DEBUG3D: 🎲 Jitter slider changed from \(oldValue) to \(newValue)")
                                    app.gameCacheManager.defaultJitterMultiplier = newValue
                                    onJitterChanged?()
                                }
                            }
                            .onAppear {
                                localJitterMultiplier = app.gameCacheManager.defaultJitterMultiplier
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Move navigation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Move Navigation")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Move")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(player.currentIndex) / \(max(1, player.moves.count))")
                                        .monospacedDigit()
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .font(.caption)

                                Slider(
                                    value: Binding(
                                        get: { Double(player.currentIndex) },
                                        set: { newValue in
                                            let newIndex = Int(newValue)
                                            player.seek(to: newIndex)
                                        }
                                    ),
                                    in: 0...Double(max(1, player.moves.count)),
                                    step: 1
                                )
                                .controlSize(.regular)
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Camera controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Camera (3D View)")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Use mouse drag to rotate camera around board")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            Button("Reset Board Orientation") {
                                onResetCamera?()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.blue.opacity(0.8))
                            .cornerRadius(8)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.automatic)
            }
        }
        .frame(width: 320)
    }
}

struct FolderSelectionSection3D: View {
    @ObservedObject var app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Folder selection buttons
            HStack(spacing: 12) {
                Button("Open folder...") {
                    app.promptForFolder()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.8))
                .cornerRadius(8)
                .buttonStyle(.plain)

                Button("Random game") {
                    if !app.games.isEmpty {
                        app.selection = app.games.randomElement()
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.8))
                .cornerRadius(8)
                .buttonStyle(.plain)
            }

            // Folder path display
            if let folderURL = app.folderURL {
                Text("📁 \(folderURL.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Text("\(app.games.count) games")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct GameSelectionSection3D: View {
    @ObservedObject var app: AppModel
    var onGameSelected: ((SGFGameWrapper) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Games")
                .font(.headline)
                .foregroundColor(.white)

            // Game list (scrollable, showing ~7 games)
            if !app.games.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(app.games.enumerated()), id: \.element.id) { index, gameWrapper in
                            GameListItem3D(
                                gameWrapper: gameWrapper,
                                isSelected: app.selection?.id == gameWrapper.id,
                                onTap: {
                                    app.selection = gameWrapper
                                    onGameSelected?(gameWrapper)
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 200)  // ~7 games at 28px each
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.3))
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                Text("No games available")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.3))
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            }

            // Show selected game metadata
            if let selection = app.selection {
                VStack(alignment: .leading, spacing: 6) {
                    let info = selection.game.info
                    let moveCount = selection.game.moves.count

                    HStack {
                        Text("Moves: \(moveCount)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        if let date = info.date {
                            Text("Date: \(date)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    if let result = info.result {
                        Text("Result: \(result)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

struct GameListItem3D: View {
    let gameWrapper: SGFGameWrapper
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let blackPlayer = gameWrapper.game.info.playerBlack ?? "?"
        let whitePlayer = gameWrapper.game.info.playerWhite ?? "?"
        let playerInfo = "\(blackPlayer) vs \(whitePlayer)"

        HStack {
            Text(playerInfo)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? Color.cyan.opacity(0.9) : .white.opacity(0.9))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.cyan.opacity(0.15) : Color.clear)
        )
        .onTapGesture {
            onTap()
        }
    }
}
