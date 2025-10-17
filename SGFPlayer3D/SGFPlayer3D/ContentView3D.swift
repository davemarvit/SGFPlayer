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
    @StateObject private var player = SGFPlayer()
    @StateObject private var sceneManager = SceneManager3D()
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var soundManager = SoundManager.shared
    @StateObject private var ogsClient = OGSClient()
    @StateObject private var timeControl = TimeControlManager()

    // OGS game view model - will be initialized in onAppear
    @State private var ogsGame: OGSGameViewModel?

    // Camera control tracking - load from UserDefaults
    @State private var lastDragPosition: CGPoint = .zero
    @State private var currentRotationX: Float = UserDefaults.standard.float(forKey: "cameraRotationX")
    @State private var currentRotationY: Float = UserDefaults.standard.float(forKey: "cameraRotationY")
    @State private var cameraDistance: CGFloat = UserDefaults.standard.object(forKey: "cameraDistance") as? CGFloat ?? 25.0
    @State private var cameraPanX: CGFloat = UserDefaults.standard.object(forKey: "cameraPanX") as? CGFloat ?? 0.0
    @State private var cameraPanY: CGFloat = UserDefaults.standard.object(forKey: "cameraPanY") as? CGFloat ?? 0.0

    // Playback control
    @State private var isPlaying: Bool = false
    @State private var playbackSpeed: Double = UserDefaults.standard.object(forKey: "playbackSpeed") as? Double ?? 1.0
    @State private var playbackTimer: Timer? = nil
    @State private var gameEndTimer: Timer? = nil

    // UI State
    @State private var isFullscreen: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        let _ = {
            let log = "DEBUG3D: 🚀 ContentView3D body is rendering\n"
            try? log.appendToFile(at: "/tmp/sgfplayer3d_debug.log")
            print(log)
        }()
        return ZStack {
            sceneView
                .contentShape(Rectangle())

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

            overlayUI
        }
        .onChange(of: player.currentIndex) { oldIndex, newIndex in
            // Play stone click sound when moving forward (not backward or seeking)
            if newIndex > oldIndex && newIndex > 0 {
                soundManager.playStoneClick()
            }

            updateStonesWithJitter()

            // Check if game has ended (but not for OGS games - they receive moves continuously)
            if newIndex >= player.moves.count - 1 && ogsGame?.blackName == nil {
                gameEndTimer?.invalidate()
                gameEndTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    advanceToNextGame()
                }
            }
        }
        .onChange(of: app.selection) { _, newSelection in
            if let gameWrapper = newSelection {
                NSLog("DEBUG3D: 📂 Loading game from file: \(gameWrapper.url.lastPathComponent)")
                NSLog("DEBUG3D: 📂 Game has \(gameWrapper.game.setup.count) setup stones: \(gameWrapper.game.setup)")
                NSLog("DEBUG3D: 📂 Game has \(gameWrapper.game.moves.count) moves")

                // IMPORTANT: Stop OGS polling and clear OGS state when switching to a local game
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

                player.load(game: gameWrapper.game)

                // Log board state after loading
                let setupStoneCount = player.board.grid.flatMap { $0 }.compactMap { $0 }.count
                NSLog("DEBUG3D: 📂 After load, board has \(setupStoneCount) stones at index \(player.currentIndex)")

                app.selectGame(gameWrapper)  // Load into cache manager
                updateStonesWithJitter()
            }
        }
        .onChange(of: playbackSpeed) { _, newSpeed in
            UserDefaults.standard.set(newSpeed, forKey: "playbackSpeed")
        }
        .onChange(of: isPlaying) { _, nowPlaying in
            if nowPlaying {
                // Auto-play turned on - start playback immediately
                startPlayback()
            } else {
                // Auto-play turned off - stop playback
                playbackTimer?.invalidate()
                playbackTimer = nil
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

            NSLog("DEBUG3D: 🎮 Received OGSGameLoaded notification with \(game.moves.count) moves")
            player.load(game: game)
            player.seek(to: moveCount)
            updateStonesWithJitter()
        }
        .onAppear {
            // Initialize OGSGameViewModel with shared dependencies
            ogsGame = OGSGameViewModel(ogsClient: ogsClient, player: player, timeControl: timeControl)
            NSLog("DEBUG3D: 🎮 Initialized OGSGameViewModel")

            // Restore camera position on appear
            sceneManager.updateCameraPosition(
                distance: cameraDistance,
                rotationX: currentRotationX,
                rotationY: currentRotationY,
                panX: cameraPanX,
                panY: cameraPanY
            )

            sceneManager.setupInitialScene(player: player)

            // Load the initial game if one is selected
            // Note: We don't call app.selectGame() here because it's called in .onChange(of: app.selection)
            if let gameWrapper = app.selection {
                NSLog("DEBUG3D: 🎮 Loading initial game on appear: \(gameWrapper.url.lastPathComponent)")
                player.load(game: gameWrapper.game)
                updateStonesWithJitter()
            } else {
                NSLog("DEBUG3D: ⚠️ No game selected on appear")
            }
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
            ogsClient: ogsClient,
            isPlaying: $isPlaying,
            playbackSpeed: $playbackSpeed,
            onGameSelected: { game in
                player.load(game: game.game)
                player.seek(to: 0)
                updateStonesWithJitter()
            },
            onJitterChanged: {
                NSLog("DEBUG3D: 🎲 onJitterChanged callback triggered")
                updateStonesWithJitter()
            }
        )
    }

    var overlayUI: some View {
        VStack {
                // Top bar
                HStack {
                    // Settings button (left side)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings.toggle()
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .padding()

                    Text("SGFPlayer 3D")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.leading, -8)

                    Spacer()

                    // Game info - extracted to GameInfoOverlay
                    GameInfoOverlay(
                        ogsGame: ogsGame,
                        timeControl: timeControl,
                        player: player,
                        gameSelection: app.selection
                    )
                    .padding()

                    // Fullscreen button (right side)
                    Button(action: {
                        toggleFullscreen()
                    }) {
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .padding()
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
                    isPlaying: $isPlaying,
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

    private func advanceToNextGame() {
        guard !app.activePlaylist.isEmpty else { return }

        if let currentSelection = app.selection,
           let currentIndex = app.activePlaylist.firstIndex(where: { $0.id == currentSelection.id }) {
            // Move to next game, or loop to beginning
            let nextIndex = (currentIndex + 1) % app.activePlaylist.count
            app.selection = app.activePlaylist[nextIndex]
            player.load(game: app.activePlaylist[nextIndex].game)
            app.selectGame(app.activePlaylist[nextIndex])  // Load into cache manager
            player.seek(to: 0)
            updateStonesWithJitter()

            // Start playing the new game if autoplay was on
            if isPlaying {
                startPlayback()
            }
        } else if let first = app.activePlaylist.first {
            // No selection, start with first game
            app.selection = first
            player.load(game: first.game)
            app.selectGame(first)  // Load into cache manager
            player.seek(to: 0)
            updateStonesWithJitter()

            // Start playing if autoplay was on
            if isPlaying {
                startPlayback()
            }
        }
    }

    private func startPlayback() {
        print("🎬 startPlayback called - currentIndex: \(player.currentIndex), moves: \(player.moves.count), speed: \(playbackSpeed)")

        // If we're at the end, go back to start
        if player.currentIndex >= player.moves.count - 1 {
            print("🎬 At end of game, resetting to start")
            player.seek(to: 0)
            updateStonesWithJitter()
        }

        playbackTimer?.invalidate()
        scheduleNextMove()
    }

    private func scheduleNextMove() {
        // Use a non-repeating timer so we can respect playbackSpeed changes
        playbackTimer = Timer.scheduledTimer(withTimeInterval: playbackSpeed, repeats: false) { [self] _ in
            print("🎬 Timer fired - currentIndex: \(player.currentIndex), moves: \(player.moves.count)")
            if player.currentIndex < player.moves.count - 1 {
                player.seek(to: player.currentIndex + 1)
                updateStonesWithJitter()

                // Schedule next move if still playing
                if isPlaying {
                    scheduleNextMove()
                }
            } else {
                print("🎬 Reached end of game - auto-advance will handle next game")
                // Don't set isPlaying = false here - let auto-advance continue to next game
            }
        }
    }

    private func togglePlayPause() {
        print("🎬 togglePlayPause called - isPlaying will become: \(!isPlaying)")
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            playbackTimer?.invalidate()
        }
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
