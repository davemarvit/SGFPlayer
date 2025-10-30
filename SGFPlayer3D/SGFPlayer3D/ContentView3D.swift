// MARK: - ContentView3D - 3D Go Board Viewer
// This is a new 3D version of SGFPlayer that uses SceneKit for 3D board rendering

import SwiftUI
import SceneKit

// Helper for logging to file
extension String {
    func appendToFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            handle.write(self.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try self.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct ContentView3D: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var sceneManager = SceneManager3D()
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var soundManager = SoundManager.shared

    // Convenience properties to access centralized components from AppModel
    private var player: SGFPlayer { app.player }
    private var ogsClient: OGSClient { app.ogsClient }
    private var timeControl: TimeControlManager { app.timeControl }
    private var ogsGame: OGSGameViewModel? { app.ogsGame }

    // Camera control tracking - load from UserDefaults
    @State private var lastDragPosition: CGPoint = .zero
    @State private var currentRotationX: Float = UserDefaults.standard.float(forKey: "cameraRotationX")
    @State private var currentRotationY: Float = UserDefaults.standard.float(forKey: "cameraRotationY")
    @State private var cameraDistance: CGFloat = UserDefaults.standard.object(forKey: "cameraDistance") as? CGFloat ?? 25.0
    @State private var cameraPanX: CGFloat = UserDefaults.standard.object(forKey: "cameraPanX") as? CGFloat ?? 0.0
    @State private var cameraPanY: CGFloat = UserDefaults.standard.object(forKey: "cameraPanY") as? CGFloat ?? 0.0

    // Playback control
    @AppStorage("autoNext") private var autoNext: Bool = false
    @AppStorage("randomNext") private var randomNext: Bool = false
    @AppStorage("autoStartOnLaunch") private var autoStartOnLaunch: Bool = true
    @AppStorage("randomOnStart") private var randomOnStart: Bool = false
    @AppStorage("loopGames") private var loopGames: Bool = true
    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 0.75

    // Track previous currentIndex to only play sound on NEW moves (not every poll)
    @State private var previousMoveIndex: Int = -1
    // Track last loaded OGS move count to avoid re-seeking on every poll
    @State private var lastLoadedOGSMoveCount: Int = -1

    // Search state
    @State private var filteredGames: [SGFGameWrapper] = []
    @State private var isSearchActive: Bool = false
    @AppStorage("lastSearchQuery") private var lastSearchQuery: String = ""
    @AppStorage("isSearchActivePersisted") private var isSearchActivePersisted: Bool = false

    // UI State
    @State private var isFullscreen: Bool = false
    @State private var showSettings: Bool = false
    @State private var showControls: Bool = true
    @State private var hideControlsTimer: Timer? = nil

    // Computed property for active games list (filtered or all)
    private var activeGamesList: [SGFGameWrapper] {
        return isSearchActive && !filteredGames.isEmpty ? filteredGames : app.games
    }

    var body: some View {
        let _ = {
            let log = "DEBUG3D: 🚀 ContentView3D body is rendering\n"
            try? log.appendToFile(at: "/tmp/sgfplayer3d_debug.log")
            print(log)
        }()
        return ZStack {
            sceneView
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    // Show controls on any mouse movement
                    switch phase {
                    case .active(_):
                        showControlsWithTimer()
                    case .ended:
                        break
                    }
                }

            if showSettings {
                // Background overlay that closes settings when tapped
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings = false
                        }
                    }

                settingsPanel
            }

            // Pre-game overlay for finding/creating games
            if app.showPreGameOverlay {
                PreGameOverlay(ogsClient: ogsClient, isVisible: $app.showPreGameOverlay)
            }

            overlayUI
        }
        .onReceive(player.$currentIndex) { newIndex in
            // Update 3D board immediately
            updateStonesWithJitter()

            // Play stone click sound ONLY when moving forward to a NEW move
            // Don't play on polling updates (newIndex == previousMoveIndex)
            if newIndex > previousMoveIndex && newIndex > 0 {
                soundManager.playStoneClick()
            }
            previousMoveIndex = newIndex
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameDidFinish)) { _ in
            handleGameFinished()
        }
        .onChange(of: app.selection) { _, newSelection in
            if let gameWrapper = newSelection {
                NSLog("DEBUG3D: 📂 Loading game from file: \(gameWrapper.url.lastPathComponent)")
                NSLog("DEBUG3D: 📂 Game has \(gameWrapper.game.setup.count) setup stones: \(gameWrapper.game.setup)")
                NSLog("DEBUG3D: 📂 Game has \(gameWrapper.game.moves.count) moves")

                // IMPORTANT: Only allow local game selection when NOT connected to OGS
                if ogsClient.isConnected {
                    NSLog("DEBUG3D: 🛑 Cannot select local game - OGS is connected")
                    return
                }

                // Stop OGS polling and clear OGS state when switching to a local game
                // Otherwise OGS polling will continue updating the board with OGS game moves
                if ogsGame?.blackName != nil {
                    NSLog("DEBUG3D: 🛑 Switching from OGS game to local game - stopping OGS polling")
                    ogsGame?.stopPolling()
                    ogsGame?.blackName = nil
                    ogsGame?.whiteName = nil
                    ogsGame?.blackRank = nil
                    ogsGame?.whiteRank = nil
                    ogsGame?.komi = nil
                    ogsGame?.ruleset = nil
                    ogsClient.currentGameID = nil
                    timeControl.reset()
                }

                // Note: player.load() is now handled by app.selectGame() in AppModel
                // This ensures game state is centralized and shared between 2D and 3D views

                // Log board state after loading
                let setupStoneCount = player.board.grid.flatMap { $0 }.compactMap { $0 }.count
                NSLog("DEBUG3D: 📂 After load, board has \(setupStoneCount) stones at index \(player.currentIndex)")

                updateStonesWithJitter()

                // Auto-start playback if autoplay is enabled
                if autoNext {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        player.play()
                        NSLog("DEBUG3D: 🔄 Auto-started playback for new game selection")
                    }
                }
            }
        }
        .onChange(of: playbackSpeed) { _, newSpeed in
            player.setPlayInterval(newSpeed)
        }
        .onChange(of: autoNext) { _, isAutoPlay in
            if isAutoPlay {
                player.play()
            } else {
                player.pause()
            }
        }
        .onChange(of: app.gameCacheManager.defaultJitterMultiplier) { _, newJitter in
            NSLog("DEBUG3D: 🎲 Jitter changed to: \(newJitter)")
            updateStonesWithJitter()
        }
        .onChange(of: currentRotationX) { _, newValue in
            saveCameraState()
        }
        .onChange(of: currentRotationY) { _, newValue in
            saveCameraState()
        }
        .onChange(of: cameraDistance) { _, newValue in
            saveCameraState()
        }
        .onChange(of: cameraPanX) { _, newValue in
            saveCameraState()
        }
        .onChange(of: cameraPanY) { _, newValue in
            saveCameraState()
        }
        .onChange(of: ogsClient.blackTimeRemaining) { oldTime, newTime in
            NSLog("DEBUG3D: ⏱️ Black time changed: \(oldTime ?? -1) -> \(newTime ?? -1)")
            // Sync OGS clock updates to TimeControlManager
            timeControl.updateFromOGS(
                blackTime: ogsClient.blackTimeRemaining,
                whiteTime: ogsClient.whiteTimeRemaining,
                blackPeriods: ogsClient.blackPeriodsRemaining,
                whitePeriods: ogsClient.whitePeriodsRemaining,
                blackPeriod: ogsClient.blackPeriodTime,
                whitePeriod: ogsClient.whitePeriodTime
            )

            // Start clock if we're in an OGS game
            if ogsGame?.blackName != nil && !timeControl.isClockRunning {
                timeControl.startClock()
            }
        }
        .onChange(of: ogsClient.whiteTimeRemaining) { oldTime, newTime in
            NSLog("DEBUG3D: ⏱️ White time changed: \(oldTime ?? -1) -> \(newTime ?? -1)")
            // Sync OGS clock updates to TimeControlManager
            timeControl.updateFromOGS(
                blackTime: ogsClient.blackTimeRemaining,
                whiteTime: ogsClient.whiteTimeRemaining,
                blackPeriods: ogsClient.blackPeriodsRemaining,
                whitePeriods: ogsClient.whitePeriodsRemaining,
                blackPeriod: ogsClient.blackPeriodTime,
                whitePeriod: ogsClient.whitePeriodTime
            )

            // Start clock if we're in an OGS game
            if ogsGame?.blackName != nil && !timeControl.isClockRunning {
                timeControl.startClock()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Don't auto-select random games when connected to OGS
            if randomOnStart, app.selection == nil, !ogsClient.isConnected {
                app.pickRandomGame(from: activeGamesList)
                NSLog("DEBUG3D: 🎲 Random game selected on app activation")
            }

            // Resume auto-play if in local mode and a game is loaded
            if !ogsClient.isConnected, app.selection != nil, autoNext, !player.isPlaying {
                NSLog("DEBUG3D: ▶️ Resuming auto-play on app activation")
                player.play()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSConnected"))) { _ in
            NSLog("DEBUG3D: 🔌 OGS connected - clearing local game selection and clearing board")
            app.selection = nil
            player.clear()  // Completely clear board including handicap stones
            player.pause()  // Stop any playback
            ogsClient.currentGameID = nil  // Clear any active OGS game
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSGameDataReceived"))) { notification in
            // Only process if we have an active OGS game ID (allows initial game load)
            guard ogsClient.currentGameID != nil else {
                NSLog("DEBUG3D: 🛑 Ignoring OGSGameDataReceived - no active game ID")
                return
            }
            ogsGame?.handleGameData(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSMoveReceived"))) { notification in
            // Only process if we have an active OGS game ID
            guard ogsClient.currentGameID != nil else {
                NSLog("DEBUG3D: 🛑 Ignoring OGSMoveReceived - no active game ID")
                return
            }
            ogsGame?.handleMove(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSRateLimited"))) { _ in
            // Only process if we have an active OGS game ID
            guard ogsClient.currentGameID != nil else {
                NSLog("DEBUG3D: 🛑 Ignoring OGSRateLimited - no active game ID")
                return
            }
            ogsGame?.handleThrottling()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSPlayerInfo"))) { notification in
            // Only process if we have an active OGS game ID (allows initial player info load)
            guard ogsClient.currentGameID != nil else {
                NSLog("DEBUG3D: 🛑 Ignoring OGSPlayerInfo - no active game ID")
                return
            }
            ogsGame?.handlePlayerInfo(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSGameLoaded"))) { notification in
            // Only process if we have an active OGS game ID
            guard ogsClient.currentGameID != nil else {
                NSLog("DEBUG3D: 🛑 Ignoring OGSGameLoaded - no active game ID")
                return
            }

            // Handle game loading from OGSGameViewModel
            guard let userInfo = notification.userInfo,
                  let game = userInfo["game"] as? SGFGame,
                  let moveCount = userInfo["moveCount"] as? Int else {
                NSLog("DEBUG3D: ❌ Invalid OGSGameLoaded notification")
                return
            }

            // IMPORTANT: Only reload/seek if the move count has actually changed
            // Otherwise polling will trigger seek() every second, causing spurious click sounds
            if moveCount != lastLoadedOGSMoveCount {
                NSLog("DEBUG3D: 🎮 Received OGSGameLoaded notification with \(game.moves.count) moves (changed from \(lastLoadedOGSMoveCount))")
                player.load(game: game)
                player.seek(to: moveCount)
                updateStonesWithJitter()
                lastLoadedOGSMoveCount = moveCount
            } else {
                NSLog("DEBUG3D: 🔄 OGSGameLoaded poll - move count unchanged (\(moveCount))")
            }
        }
        .onAppear {
            // OGSGameViewModel is now initialized in AppModel.init()
            // This ensures it's shared between 2D and 3D views

            // Auto-connect to OGS if OGS mode is enabled
            if settingsVM.ogsMode && !ogsClient.isConnected {
                ogsClient.connect()
                NSLog("DEBUG3D: 🔌 Auto-connecting to OGS on startup (OGS Mode was ON)")
            }

            // Restore camera position on appear
            sceneManager.updateCameraPosition(
                distance: cameraDistance,
                rotationX: currentRotationX,
                rotationY: currentRotationY,
                panX: cameraPanX,
                panY: cameraPanY
            )

            sceneManager.setupInitialScene(player: player)

            // Update stones for initial game if one is selected
            // Note: Game is already loaded in AppModel.player during AppModel.init()
            if let gameWrapper = app.selection {
                NSLog("DEBUG3D: 🎮 Initial game already loaded: \(gameWrapper.url.lastPathComponent)")
                updateStonesWithJitter()
            } else {
                NSLog("DEBUG3D: ⚠️ No game selected on appear")
            }

            // Start the auto-hide timer for controls
            showControlsWithTimer()

            // Set initial playback speed
            player.setPlayInterval(playbackSpeed)

            // Restore search state if persisted
            if isSearchActivePersisted && !lastSearchQuery.isEmpty {
                NSLog("DEBUG3D: 🔍 Restoring search state: '\(lastSearchQuery)'")
                performSearch(query: lastSearchQuery)
            }

            handleAppLaunch()
        }
    }

    var sceneView: some View {
        ZStack {
            SceneView(
                scene: sceneManager.scene,
                pointOfView: sceneManager.cameraNode,
                options: []  // Use our custom lighting only
            )

            // Overlay to capture all camera control events
            CameraControlHandler(
                rotationX: $currentRotationX,
                rotationY: $currentRotationY,
                distance: $cameraDistance,
                panX: $cameraPanX,
                panY: $cameraPanY,
                sceneManager: sceneManager
            )
        }
        .ignoresSafeArea()
    }

    var settingsPanel: some View {
        SettingsPanelContainer(
            showSettings: $showSettings,
            player: player,
            settingsVM: settingsVM,
            soundManager: soundManager,
            ogsClient: app.ogsClient,
            isPlaying: $autoNext,
            randomNext: $randomNext,
            autoStartOnLaunch: $autoStartOnLaunch,
            loopGames: $loopGames,
            playbackSpeed: $playbackSpeed,
            onGameSelected: { game in
                player.load(game: game.game)
                player.seek(to: 0)
                updateStonesWithJitter()
            },
            onJitterChanged: {
                NSLog("DEBUG3D: 🎲 onJitterChanged callback triggered")
                updateStonesWithJitter()
            },
            onSearchResultsChanged: { searchResults in
                filteredGames = searchResults
                isSearchActive = !searchResults.isEmpty

                // Persist search state
                isSearchActivePersisted = isSearchActive
                if isSearchActive && searchResults.count < app.games.count {
                    // Extract search query by finding the common pattern in search results
                    if let firstGame = searchResults.first {
                        let info = firstGame.game.info
                        let blackPlayer = info.playerBlack ?? ""
                        let whitePlayer = info.playerWhite ?? ""
                        // For now, just save the first player name as a simple heuristic
                        lastSearchQuery = blackPlayer.isEmpty ? whitePlayer : blackPlayer
                    }
                } else if !isSearchActive {
                    lastSearchQuery = ""
                }

                NSLog("DEBUG3D: 🔍 Updated filtered games to \(searchResults.count) games, search active: \(isSearchActive)")

                // Always switch to first game in search results
                if !searchResults.isEmpty {
                    NSLog("DEBUG3D: 🔍 Switching to first game in search results")
                    app.selection = searchResults.first
                    player.reset()

                    // Start playback if it was already enabled
                    if autoNext {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            player.play()
                            NSLog("DEBUG3D: 🔍 Started autoplay after search switch")
                        }
                    }
                }
            }
        )
    }

    var overlayUI: some View {
        VStack(spacing: 0) {
                // Top bar
                HStack(alignment: .top) {
                    // Settings button (left side)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings.toggle()
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    .opacity(showControls ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.2), value: showControls)

                    Spacer()

                    // Game info with fullscreen button overlay
                    ZStack(alignment: .topTrailing) {
                        GameInfoOverlay(
                            ogsGame: app.ogsGame,
                            timeControl: app.timeControl,
                            player: player,
                            gameSelection: ogsClient.isConnected ? nil : app.selection,  // Hide local game metadata when OGS is connected
                            backgroundOpacity: 0.3  // 3D mode: 70% transparent
                        )

                        // Fullscreen button overlaid on top-right of metadata
                        Button(action: {
                            toggleFullscreen()
                        }) {
                            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .opacity(showControls ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.2), value: showControls)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }

                Spacer()

                // Version number in lower right
                HStack {
                    Spacer()
                    Text("v3.30")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .padding(.trailing, 20)
                        .padding(.bottom, 8)
                }

                // Bottom controls - extracted to PlaybackControls
                PlaybackControls(
                    player: player,
                    isPlaying: $autoNext,
                    onSeek: updateStonesWithJitter,
                    onTogglePlayPause: togglePlayPause
                )
        }
    }

    private func saveCameraState() {
        UserDefaults.standard.set(currentRotationX, forKey: "cameraRotationX")
        UserDefaults.standard.set(currentRotationY, forKey: "cameraRotationY")
        UserDefaults.standard.set(cameraDistance, forKey: "cameraDistance")
        UserDefaults.standard.set(cameraPanX, forKey: "cameraPanX")
        UserDefaults.standard.set(cameraPanY, forKey: "cameraPanY")
    }

    private func toggleFullscreen() {
        guard let window = NSApplication.shared.windows.first else {
            return
        }
        window.toggleFullScreen(nil)
    }

    private func showControlsWithTimer() {
        // Show controls immediately
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls = true
        }

        // Cancel existing timer
        hideControlsTimer?.invalidate()

        // Set new timer to hide after 1.5 seconds
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = false
            }
        }
    }

    private func handleGameFinished() {
        // Game has finished - advance to next game if in loop mode
        // Don't auto-advance when connected to OGS
        if randomNext, !ogsClient.isConnected {
            // Wait 5 seconds, then pick the next random game and restart if auto-play is on
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                app.pickRandomGame(from: activeGamesList)
                // If auto-play is enabled, automatically start the new game
                if autoNext {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        player.play()
                    }
                }
            }
        } else if loopGames && !ogsClient.isConnected {
            // Wait 5 seconds, then advance to next game in sequence (or loop back to first)
            // Only for local games, not OGS games (they receive moves continuously)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                app.advanceToNextGame(from: activeGamesList)
                // If auto-play is enabled, automatically start the new game
                if autoNext {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        player.play()
                    }
                }
            }
        }
    }

    private func performSearch(query: String) {
        let searchLower = query.lowercased()
        let searchResults = app.games.filter { gameWrapper in
            let info = gameWrapper.game.info
            let blackPlayer = info.playerBlack?.lowercased() ?? ""
            let whitePlayer = info.playerWhite?.lowercased() ?? ""
            return blackPlayer.contains(searchLower) || whitePlayer.contains(searchLower)
        }

        filteredGames = searchResults
        isSearchActive = !searchResults.isEmpty
        NSLog("DEBUG3D: 🔍 Search restored: \(searchResults.count) games found for '\(query)'")
    }

    private func handleAppLaunch() {
        // Auto-start playing on launch if enabled, we have a game selected, and NOT in OGS mode
        if autoStartOnLaunch && app.selection != nil && !settingsVM.ogsMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                autoNext = true
                player.play()
                NSLog("DEBUG3D: 🚀 Auto-started playback on launch")
            }
        } else if settingsVM.ogsMode {
            NSLog("DEBUG3D: ⏸️ Skipping auto-play - in OGS mode")
        }
    }

    private func togglePlayPause() {
        autoNext.toggle()
        // The .onChange(of: autoNext) handler will call player.play() or player.pause()
    }

    private func updateStonesWithJitter() {
        // Generate jitter offsets on-the-fly based on board positions
        let jitterMultiplier = app.gameCacheManager.defaultJitterMultiplier

        // Generate stable jitter for each stone position
        var jitterOffsets: [BoardPosition: CGPoint] = [:]
        let board = player.board

        for row in 0..<board.size {
            for col in 0..<board.size {
                if board.grid[row][col] != nil {
                    let position = BoardPosition(x: col, y: row)

                    // Generate deterministic jitter based on position
                    let seed = UInt32(col * 73856093 + row * 19349663)
                    var rng = seed
                    let jitterX = CGFloat(Double(rng % 1000) / 1000.0 - 0.5) * 0.22 // -0.11 to +0.11
                    rng = rng &* 1103515245 &+ 12345
                    let jitterY = CGFloat(Double(rng % 1000) / 1000.0 - 0.5) * 0.22

                    jitterOffsets[position] = CGPoint(x: jitterX, y: jitterY)
                }
            }
        }

        sceneManager.updateStones(from: player, jitterMultiplier: jitterMultiplier, jitterOffsets: jitterOffsets)
    }
}

// MARK: - Preview
struct ContentView3D_Previews: PreviewProvider {
    static var previews: some View {
        ContentView3D()
            .environmentObject(AppModel())
    }
}
