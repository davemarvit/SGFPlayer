// MARK: - Settings Panel View
// Extracted from ContentView to reduce complexity

import SwiftUI
import AppKit

struct SettingsPanelView: View {
    @Binding var isPanelOpen: Bool
    @Binding var activePhysicsModelRaw: Int
    @ObservedObject var physicsIntegration: PhysicsIntegration

    // Physics model parameters - kept for compatibility
    @Binding var m1_repel: Double
    @Binding var m1_spacing: Double
    @Binding var m1_centerPullK: Double
    @Binding var m1_relaxIters: Int
    @Binding var m1_pressureRadiusXR: Double
    @Binding var m1_pressureKFactor: Double
    @Binding var m1_maxStepXR: Double
    @Binding var m1_damping: Double
    @Binding var m1_wallK: Double
    @Binding var m1_anim: Double
    @Binding var m1_stoneStoneK: Double
    @Binding var m1_stoneLidK: Double

    // Auto-play controls moved from main UI
    @Binding var autoNext: Bool
    @Binding var randomNext: Bool
    @Binding var autoStartOnLaunch: Bool
    @Binding var loopGames: Bool
    @Binding var uiMoveDelay: Double

    // Move controls moved from main UI
    @ObservedObject var player: SGFPlayer
    @ObservedObject var app: AppModel
    var onMoveChanged: ((Int) -> Void)?

    // Additional settings
    @Binding var debugLayout: Bool
    @Binding var advancedExpanded: Bool

    // Game cache manager for jitter controls
    var gameCacheManager: GameCacheManager? = nil

    // Search results callback
    var onSearchResultsChanged: (([SGFGameWrapper]) -> Void)? = nil

    // OGS Mode and authentication state
    @AppStorage("ogsMode") private var ogsMode: Bool = false
    @State private var ogsGameID: String = ""
    @State private var ogsUsername: String = ""
    @State private var ogsPassword: String = ""
    @State private var isAuthenticating: Bool = false
    @State private var authError: String? = nil
    @State private var hasLoadedCredentials: Bool = false

    // MARK: - Helper Functions

    /// Extract game ID from either a direct ID number or an OGS URL
    /// Supports URLs like: https://online-go.com/game/12345 or https://online-go.com/game/12345/review
    private func joinGame(from input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try parsing as direct game ID first
        if let gameID = Int(trimmed) {
            NSLog("OGS: 🎮 Parsed direct game ID: \(gameID)")
            app.ogsClient.joinGame(gameID: gameID)
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
                app.ogsClient.joinGame(gameID: gameID)
                return
            }
        }

        NSLog("OGS: ❌ Failed to parse game ID from input: '\(trimmed)'")
    }

    var body: some View {
        ZStack {
            // Background for entire panel
            Rectangle()
                .fill(.thinMaterial.opacity(0.6))

            VStack(spacing: 0) {
                // Header with gear icon
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 1.0)) {
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
                        withAnimation(.easeInOut(duration: 1.0)) {
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
                    FolderSelectionSection(app: app)
                        .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // View Mode selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("View Mode")
                            .font(.headline)

                        Picker("", selection: $app.viewMode) {
                            ForEach(ViewMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Switch between 2D and 3D board views. Game progress is preserved when switching.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // OGS Mode toggle and controls
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode")
                            .font(.headline)

                        Toggle("OGS Mode (Live Games)", isOn: $ogsMode)
                            .onAppear {
                                // Auto-connect if OGS mode is already enabled on startup
                                if ogsMode && !app.ogsClient.isConnected {
                                    app.ogsClient.connect()
                                    NSLog("OGS: 🔌 Auto-connecting on startup (OGS Mode was already ON)")
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: ogsMode) { _, newValue in
                                if newValue {
                                    // Auto-connect when OGS mode is turned on
                                    if !app.ogsClient.isConnected {
                                        app.ogsClient.connect()
                                        NSLog("OGS: 🔌 Auto-connecting when OGS Mode enabled")
                                    }
                                } else {
                                    // Disconnect when OGS mode is turned off
                                    if app.ogsClient.isConnected {
                                        app.ogsClient.disconnect()
                                        NSLog("OGS: 🔌 Disconnecting when OGS Mode disabled")
                                    }
                                }
                            }

                        Text(ogsMode ? "Online Go Server" : "Playing local SGF files")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // OGS Connection controls (shown when OGS mode is on)
                        if ogsMode {
                            VStack(alignment: .leading, spacing: 12) {
                                // Connection status
                                HStack {
                                    Circle()
                                        .fill(app.ogsClient.isConnected ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(app.ogsClient.isConnected ? "Connected" : "Disconnected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                // Authentication - always show when in OGS mode
                                if app.ogsClient.isAuthenticated {
                                    // Show authenticated status
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Logged in as \(app.ogsClient.username ?? "unknown")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Button("Logout") {
                                            // Clear UI fields before deleting credentials
                                            ogsUsername = ""
                                            ogsPassword = ""
                                            hasLoadedCredentials = false
                                            app.ogsClient.deleteCredentials()
                                            // Note: Connection stays active for anonymous spectating
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                } else {
                                    // Show login form
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Login to OGS")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        TextField("Username", text: $ogsUsername)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: .infinity)
                                            .disabled(isAuthenticating)
                                            .onAppear {
                                                if !hasLoadedCredentials, let username = app.ogsClient.username {
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
                                                    if !app.ogsClient.isConnected {
                                                        NSLog("OGS: 🔌 Not connected, connecting first...")
                                                        app.ogsClient.connect()
                                                    }

                                                    isAuthenticating = true
                                                    authError = nil
                                                    app.ogsClient.authenticate(username: ogsUsername, password: ogsPassword) { success, error in
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
                                            if !app.ogsClient.isConnected {
                                                NSLog("OGS: 🔌 Not connected, connecting first...")
                                                app.ogsClient.connect()
                                            }

                                            isAuthenticating = true
                                            authError = nil
                                            app.ogsClient.authenticate(username: ogsUsername, password: ogsPassword) { success, error in
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
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                        .buttonStyle(.plain)
                                        .disabled(isAuthenticating || ogsUsername.isEmpty || ogsPassword.isEmpty)

                                        // Show auth error if any
                                        if let error = authError {
                                            Text("⚠️ \(error)")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }

                                // Find a Game button (shown when authenticated)
                                if app.ogsClient.isConnected {
                                    Button(action: {
                                        // Show PreGameOverlay and close settings panel
                                        app.showPreGameOverlay = true
                                        isPanelOpen = false
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Find a Game")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(app.ogsClient.isAuthenticated ? Color.green.opacity(0.7) : Color.gray.opacity(0.3))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!app.ogsClient.isAuthenticated)
                                }

                                // Game ID input (shown when connected)
                                if app.ogsClient.isConnected {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Watch Game")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            TextField("Game ID or URL", text: $ogsGameID)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(maxWidth: .infinity)
                                                .onSubmit {
                                                    // Trigger join when Return is pressed
                                                    if !ogsGameID.isEmpty {
                                                        NSLog("OGS: 🎮 Join triggered by Return key! Input: '\(ogsGameID)'")
                                                        joinGame(from: ogsGameID)
                                                    }
                                                }

                                            Button("Join") {
                                                NSLog("OGS: 🎮 Join button clicked! Input: '\(ogsGameID)'")
                                                joinGame(from: ogsGameID)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                            .buttonStyle(.plain)
                                            .disabled(ogsGameID.isEmpty)
                                        }
                                    }
                                }

                                // Error display
                                if let error = app.ogsClient.lastError {
                                    Text("Error: \(error)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // Game selection list (only shown when NOT in OGS mode)
                    if !ogsMode {
                        GameSelectionSection(app: app, onSearchResultsChanged: onSearchResultsChanged)
                            .padding(.horizontal, 16)
                    }

                    Divider()
                        .padding(.horizontal, 16)

                    // Physics Model Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Physics Model")
                            Spacer()
                            Picker("Active model", selection: Binding(
                                get: { activePhysicsModelRaw },
                                set: { activePhysicsModelRaw = $0 }
                            )) {
                                // Use new physics system models
                                ForEach(Array(physicsIntegration.availableModels.enumerated()), id: \.offset) { index, model in
                                    Text("Model \(index + 1): \(model.name)").tag(index + 1)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }

                        Text("Current: Physics Model \(physicsIntegration.activePhysicsModel + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // Auto-play Controls
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-play Controls")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            // Put both toggles on the same line with consistent blue color
                            HStack(spacing: 20) {
                                Toggle("Auto-play", isOn: $autoNext)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))

                                Toggle("Random next", isOn: $randomNext)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                            }
                            .padding(.horizontal, 16)

                            // Additional playback settings
                            HStack(spacing: 20) {
                                Toggle("Auto-start on launch", isOn: $autoStartOnLaunch)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))

                                Toggle("Loop games", isOn: $loopGames)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            if autoNext {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Move Delay")
                                        Spacer()
                                        Text("\(String(format: "%.1f", uiMoveDelay))s")
                                            .monospacedDigit()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                    // Log scale slider: 0-10s with 1s at midpoint (0.5)
                                    Slider(
                                        value: Binding(
                                            get: {
                                                // Convert delay to log position (0.0 to 1.0)
                                                if uiMoveDelay <= 0.1 { return 0.0 }
                                                let logValue = log10(uiMoveDelay / 0.1) / log10(100.0) // 0.1s to 10s mapped to 0-1
                                                return min(max(logValue, 0.0), 1.0)
                                            },
                                            set: { sliderValue in
                                                // Convert log position back to delay (0.1s to 10s)
                                                let delay = 0.1 * pow(100.0, sliderValue) // 100x range: 0.1s to 10s
                                                uiMoveDelay = min(max(delay, 0.1), 10.0)
                                            }
                                        ),
                                        in: 0.0...1.0
                                    )
                                    .controlSize(.regular)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    Divider()
                        .padding(.horizontal, 16)

                    // Move Control Slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Move Navigation")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            HStack {
                                Text("Move")
                                Spacer()
                                Text("\(player.currentIndex) / \(max(1, player.moves.count))")
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)

                            Slider(
                                value: Binding(
                                    get: { Double(player.currentIndex) },
                                    set: { newValue in
                                        let newIndex = Int(newValue)
                                        // Stop autoplay when manually seeking
                                        autoNext = false
                                        onMoveChanged?(newIndex)
                                        print("🎮 Settings move slider changed to: \(newIndex), autoplay stopped")
                                    }
                                ),
                                in: 0...Double(max(1, player.moves.count)),
                                step: 1
                            )
                            .controlSize(.regular)
                            .padding(.horizontal, 16)
                        }
                    }

                    Divider()
                        .padding(.horizontal, 16)

                    // Stone Jitter Controls
                    if let gameCacheManager = gameCacheManager {
                        JitterControlsView(gameCacheManager: gameCacheManager)
                    }

                    // COMMENTED OUT: Board Spacing Controls (hard coded values used instead)
                    /*
                    if let gameCacheManager = gameCacheManager {
                        BoardSpacingControlsView(gameCacheManager: gameCacheManager)
                    }
                    */

                    Divider()
                        .padding(.horizontal, 16)

                    // Playback Controls (moved from main UI) - Traditional << < || > >>
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Playback Controls")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            // Scan backward (10 moves back) - <<
                            Button {
                                autoNext = false
                                let newIndex = max(0, player.currentIndex - 10)
                                onMoveChanged?(newIndex)
                            } label: {
                                Text("<<")
                                    .font(.system(.body, design: .monospaced))  // Reduced from title2 to body
                                    .frame(width: 35, height: 28)  // Reduced from 40x30 to 35x28
                            }
                            .disabled(player.currentIndex <= 0)
                            .buttonStyle(.bordered)

                            // Step backward (1 move back) - <
                            Button {
                                autoNext = false
                                let newIndex = max(0, player.currentIndex - 1)
                                onMoveChanged?(newIndex)
                            } label: {
                                Text("<")
                                    .font(.system(.body, design: .monospaced))  // Reduced from title2 to body
                                    .frame(width: 35, height: 28)  // Reduced from 40x30 to 35x28
                            }
                            .disabled(player.currentIndex <= 0)
                            .buttonStyle(.bordered)

                            // Play/Pause - solid triangle / pause bars
                            Button {
                                // Toggle auto-play
                                autoNext.toggle()
                            } label: {
                                Image(systemName: autoNext ? "pause.fill" : "play.fill")
                                    .font(.system(.body))
                                    .frame(width: 35, height: 28)
                            }
                            .buttonStyle(.bordered)

                            // Step forward (1 move forward) - >
                            Button {
                                autoNext = false
                                let maxMoves = max(1, player.moves.count)
                                let newIndex = min(maxMoves - 1, player.currentIndex + 1)
                                onMoveChanged?(newIndex)
                            } label: {
                                Text(">")
                                    .font(.system(.body, design: .monospaced))  // Reduced from title2 to body
                                    .frame(width: 35, height: 28)  // Reduced from 40x30 to 35x28
                            }
                            .disabled(player.currentIndex >= max(1, player.moves.count) - 1)
                            .buttonStyle(.bordered)

                            // Scan forward (10 moves forward) - >>
                            Button {
                                autoNext = false
                                let maxMoves = max(1, player.moves.count)
                                let newIndex = min(maxMoves - 1, player.currentIndex + 10)
                                onMoveChanged?(newIndex)
                            } label: {
                                Text(">>")
                                    .font(.system(.body, design: .monospaced))  // Reduced from title2 to body
                                    .frame(width: 35, height: 28)  // Reduced from 40x30 to 35x28
                            }
                            .disabled(player.currentIndex >= max(1, player.moves.count) - 1)
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Advanced Settings
                    DisclosureGroup("Advanced Settings", isExpanded: $advancedExpanded) {
                        VStack(alignment: .leading, spacing: 12) {

                            // Physics Controls - Simplified for compiler
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Physics Model Controls (Legacy - being replaced)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Current Model: \(physicsIntegration.activePhysicsModel + 1)")
                                    .font(.body.bold())
                            }
                            .padding(.leading, 16)

                            // Debug Layout Toggle
                            Toggle("Debug Layout", isOn: $debugLayout)
                                .padding(.horizontal, 16)

                            // Diagnostics Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("🔍 Diagnostics")
                                        .font(.headline)
                                        .foregroundColor(.blue)

                                    Spacer()

                                    Button("Export") {
                                        exportDiagnostics()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.mini)
                                }

                                Group {
                                    Text("Player State:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("  • Current Move: \(player.currentIndex)")
                                        .font(.caption2)
                                    Text("  • Total Moves: \(player.moves.count)")
                                        .font(.caption2)
                                    Text("  • Board Size: \(player.board.size)")
                                        .font(.caption2)

                                    Text("Physics State:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("  • Active Model: \(physicsIntegration.activePhysicsModel + 1)")
                                        .font(.caption2)
                                    Text("  • Black Stones: \(physicsIntegration.blackStones.count)")
                                        .font(.caption2)
                                    Text("  • White Stones: \(physicsIntegration.whiteStones.count)")
                                        .font(.caption2)

                                    if !physicsIntegration.blackStones.isEmpty {
                                        Text("Black Stone Positions (first 3):")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        ForEach(physicsIntegration.blackStones.prefix(3), id: \.id) { stone in
                                            Text("  • (\(String(format: "%.1f", stone.pos.x)), \(String(format: "%.1f", stone.pos.y)))")
                                                .font(.caption2)
                                                .foregroundColor(stone.pos.x == 0 && stone.pos.y == 0 ? .red : .primary)
                                        }
                                    }
                                }
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 6)
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

    // Helper function to format game info for display
    private func formatGameInfo(_ info: SGFGame.Info) -> String {
        let blackPlayer = info.playerBlack ?? "Unknown"
        let whitePlayer = info.playerWhite ?? "Unknown"
        let date = info.date ?? ""

        if !date.isEmpty {
            return "\(blackPlayer) vs \(whitePlayer) (\(date))"
        } else {
            return "\(blackPlayer) vs \(whitePlayer)"
        }
    }

    private func formatGameDisplayText(_ info: SGFGame.Info) -> String {
        let blackPlayer = info.playerBlack ?? "Unknown"
        let whitePlayer = info.playerWhite ?? "Unknown"
        let date = info.date ?? ""

        if !date.isEmpty {
            return "\(blackPlayer) vs \(whitePlayer) · \(date)"
        } else {
            return "\(blackPlayer) vs \(whitePlayer)"
        }
    }
}

// MARK: - Component Sections

struct FolderSelectionSection: View {
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

                Button("Random game now") {
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

            // Include subfolders toggle
            Toggle("Include subfolders", isOn: .constant(true))
                .foregroundColor(.white)
                .toggleStyle(SwitchToggleStyle(tint: .blue))

            // Folder path display
            if let folderURL = app.folderURL {
                Text("📁 \(folderURL.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}

// Import the extracted game search components
// (GameSelectionSection is now in GameSearchView.swift)

// GameListItem is now in GameSearchView.swift

// GameMetadataView is now in GameSearchView.swift

// Move these methods back to SettingsPanelView where they belong
extension SettingsPanelView {
    private func exportDiagnostics() {
        let timestamp = DateFormatter().string(from: Date())
        let diagnosticData = generateDiagnosticReport()

        let panel = NSSavePanel()
        panel.title = "Export Diagnostics"
        panel.nameFieldStringValue = "SGFPlayer_Diagnostics_\(timestamp.replacingOccurrences(of: " ", with: "_")).txt"
        panel.allowedContentTypes = [.plainText]
        panel.message = "Choose location to save diagnostic report"

        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    try diagnosticData.write(to: url, atomically: true, encoding: .utf8)
                    print("✅ Diagnostics exported to: \(url.path)")
                } catch {
                    print("❌ Failed to export diagnostics: \(error)")
                }
            }
        }
    }

    private func generateDiagnosticReport() -> String {
        let timestamp = Date().description
        var report = "SGFPlayer Diagnostic Report\n"
        report += "Generated: \(timestamp)\n"
        report += "Version: v2.3\n\n"

        report += "=== Player State ===\n"
        report += "Current Move: \(player.currentIndex)\n"
        report += "Total Moves: \(player.moves.count)\n"
        report += "Board Size: \(player.board.size)\n\n"

        report += "=== Physics State ===\n"
        report += "Active Model: \(physicsIntegration.activePhysicsModel + 1)\n"
        report += "Black Stones: \(physicsIntegration.blackStones.count)\n"
        report += "White Stones: \(physicsIntegration.whiteStones.count)\n\n"

        if !physicsIntegration.blackStones.isEmpty {
            report += "=== Black Stone Positions (first 10) ===\n"
            for (index, stone) in physicsIntegration.blackStones.prefix(10).enumerated() {
                let status = (stone.pos.x == 0 && stone.pos.y == 0) ? " ⚠️ AT ORIGIN" : ""
                report += "\(index + 1): (\(String(format: "%.2f", stone.pos.x)), \(String(format: "%.2f", stone.pos.y)))\(status)\n"
            }
            report += "\n"
        }

        if !physicsIntegration.whiteStones.isEmpty {
            report += "=== White Stone Positions (first 10) ===\n"
            for (index, stone) in physicsIntegration.whiteStones.prefix(10).enumerated() {
                let status = (stone.pos.x == 0 && stone.pos.y == 0) ? " ⚠️ AT ORIGIN" : ""
                report += "\(index + 1): (\(String(format: "%.2f", stone.pos.x)), \(String(format: "%.2f", stone.pos.y)))\(status)\n"
            }
            report += "\n"
        }

        report += "=== Game Files ===\n"
        report += "Selected Folder: \(app.folderURL?.path ?? "None")\n"
        report += "Games Found: \(app.games.count)\n"
        if !app.games.isEmpty {
            let gameNames = app.games.map { $0.url.lastPathComponent }
            report += "Games: \(gameNames.prefix(20).joined(separator: ", "))\n"
            if app.games.count > 20 {
                report += "... and \(app.games.count - 20) more\n"
            }
        }

        return report
    }
}

// Separate view for jitter controls with proper SwiftUI observation
struct JitterControlsView: View {
    @ObservedObject var gameCacheManager: GameCacheManager
    @State private var localMultiplier: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stone Jitter")
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Natural Placement")
                    Spacer()
                    Text(String(format: "%.1f", localMultiplier * 5.0))  // Display 0-10 scale with .5 increments
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal, 16)

                Slider(
                    value: Binding(
                        get: { localMultiplier * 5.0 },  // Convert 0-2 to 0-10 for display
                        set: { displayValue in
                            let actualValue = displayValue / 5.0  // Convert 0-10 back to 0-2
                            localMultiplier = actualValue
                            print("🎚️ SLIDER MOVED: display=\(displayValue), actual=\(actualValue), old=\(gameCacheManager.defaultJitterMultiplier)")
                            // Update immediately during dragging for real-time feedback
                            gameCacheManager.defaultJitterMultiplier = CGFloat(actualValue)
                            print("🎚️ SLIDER SET: new value=\(gameCacheManager.defaultJitterMultiplier)")
                        }
                    ),
                    in: 0.0...10.0,
                    step: 0.5  // 0.5 on 0-10 scale = 0.1 on 0-2 scale
                )
                .controlSize(.regular)
                .padding(.horizontal, 16)

                Text("Adjusts how naturally stones are placed off intersections")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }
        }
        .onAppear {
            localMultiplier = Double(gameCacheManager.defaultJitterMultiplier)
        }
        .onChange(of: gameCacheManager.defaultJitterMultiplier) { _, newValue in
            localMultiplier = Double(newValue)
        }
    }
}

// Preview
struct SettingsPanelView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPanelView(
            isPanelOpen: .constant(true),
            activePhysicsModelRaw: .constant(2),
            physicsIntegration: PhysicsIntegration(),
            m1_repel: .constant(1.6),
            m1_spacing: .constant(2.1),
            m1_centerPullK: .constant(0.003),
            m1_relaxIters: .constant(12),
            m1_pressureRadiusXR: .constant(2.6),
            m1_pressureKFactor: .constant(0.25),
            m1_maxStepXR: .constant(0.06),
            m1_damping: .constant(0.82),
            m1_wallK: .constant(0.6),
            m1_anim: .constant(0.6),
            m1_stoneStoneK: .constant(0.15),
            m1_stoneLidK: .constant(0.25),
            autoNext: .constant(true),
            randomNext: .constant(false),
            autoStartOnLaunch: .constant(true),
            loopGames: .constant(true),
            uiMoveDelay: .constant(1.0),
            player: SGFPlayer(),
            app: AppModel(),
            onMoveChanged: { index in
                print("Preview move changed to: \(index)")
            },
            debugLayout: .constant(false),
            advancedExpanded: .constant(false)
        )
        .frame(width: 320, height: 600)
    }
}