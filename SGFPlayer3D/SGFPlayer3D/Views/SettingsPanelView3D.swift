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
    @Binding var playbackSpeed: Double

    var onGameSelected: ((SGFGameWrapper) -> Void)?
    var onJitterChanged: (() -> Void)?
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

                        // OGS Mode toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mode")
                                .font(.headline)
                                .foregroundColor(.white)

                            Toggle("OGS Mode (Live Games)", isOn: $settingsVM.ogsMode)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .foregroundColor(.white)

                            Text(settingsVM.ogsMode ? "Connected to Online Go Server for live games" : "Playing local SGF files")
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
                                            Text("Logged in as \(ogsClient.username ?? "unknown")")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                            Spacer()
                                            Button("Logout") {
                                                ogsClient.deleteCredentials()
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
                                                    NSLog("OGS: 🔑 isConnected: \(ogsClient.isConnected), isAuthenticated: \(ogsClient.isAuthenticated)")
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

                                    // Connect/Disconnect button after authentication section
                                    Button(ogsClient.isConnected ? "Disconnect" : (isConnecting ? "Connecting..." : "Connect")) {
                                        if ogsClient.isConnected {
                                            ogsClient.disconnect()
                                            isConnecting = false
                                        } else {
                                            isConnecting = true
                                            ogsClient.connect()
                                            // Reset connecting state after 3 seconds
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                isConnecting = false
                                            }
                                        }
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(ogsClient.isConnected ? Color.gray.opacity(0.3) : (isConnecting ? Color.gray.opacity(0.3) : Color.blue.opacity(0.3)))
                                    .cornerRadius(4)
                                    .buttonStyle(.plain)
                                    .disabled(isConnecting)
                                    .onChange(of: ogsClient.isConnected) { _, newValue in
                                        if newValue {
                                            isConnecting = false
                                        }
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
                            GameSelectionSection3D(app: app, onGameSelected: onGameSelected)
                                .padding(.horizontal, 16)
                        }

                        Divider()
                            .padding(.horizontal, 16)

                        // Auto-play controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Playback")
                                .font(.headline)
                                .foregroundColor(.white)

                            Toggle("Auto-play", isOn: $autoPlay)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .foregroundColor(.white)

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
