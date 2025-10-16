// MARK: - ContentView3D - 3D Go Board Viewer
// This is a new 3D version of SGFPlayer that uses SceneKit for 3D board rendering

import SwiftUI
import SceneKit

// MARK: - CameraControlHandler
// Helper view to capture all camera control events
struct CameraControlHandler: NSViewRepresentable {
    @Binding var rotationX: Float
    @Binding var rotationY: Float
    @Binding var distance: CGFloat
    @Binding var panX: CGFloat
    @Binding var panY: CGFloat
    let sceneManager: SceneManager3D

    func makeNSView(context: Context) -> NSView {
        let view = CameraControlView()
        view.rotationX = rotationX
        view.rotationY = rotationY
        view.distance = distance
        view.panX = panX
        view.panY = panY
        view.sceneManager = sceneManager
        view.onUpdate = { rotX, rotY, dist, pX, pY in
            DispatchQueue.main.async {
                self.rotationX = rotX
                self.rotationY = rotY
                self.distance = dist
                self.panX = pX
                self.panY = pY
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let controlView = nsView as? CameraControlView {
            controlView.rotationX = rotationX
            controlView.rotationY = rotationY
            controlView.distance = distance
            controlView.panX = panX
            controlView.panY = panY
        }
    }

    class CameraControlView: NSView {
        var rotationX: Float = 0
        var rotationY: Float = 0
        var distance: CGFloat = 25
        var panX: CGFloat = 0
        var panY: CGFloat = 0
        var sceneManager: SceneManager3D?
        var onUpdate: ((Float, Float, CGFloat, CGFloat, CGFloat) -> Void)?

        private var lastDragPoint: NSPoint = .zero
        private var magnification: CGFloat = 1.0

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            // Accept mouse events but allow them to pass through when not handled
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func mouseDown(with event: NSEvent) {
            // Accept the event to enable dragging
        }

        override func mouseDragged(with event: NSEvent) {
            let isShiftPressed = event.modifierFlags.contains(.shift)

            if isShiftPressed {
                // Pan mode
                let panSensitivity: CGFloat = 0.02
                panX -= event.deltaX * panSensitivity  // Negate for correct direction
                panY += event.deltaY * panSensitivity

                sceneManager?.updateCameraPosition(
                    distance: distance,
                    rotationX: rotationX,
                    rotationY: rotationY,
                    panX: panX,
                    panY: panY
                )
            } else {
                // Rotate mode
                let sensitivity: CGFloat = 0.005
                rotationY -= Float(event.deltaX * sensitivity)  // Negate for correct direction
                rotationX -= Float(event.deltaY * sensitivity)  // Negate for correct direction

                sceneManager?.pivotNode.eulerAngles.y = CGFloat(rotationY)
                sceneManager?.pivotNode.eulerAngles.x = CGFloat(rotationX)
            }

            onUpdate?(rotationX, rotationY, distance, panX, panY)
        }

        override func scrollWheel(with event: NSEvent) {
            // Zoom with scroll wheel
            let zoomSensitivity: CGFloat = 0.5
            distance -= event.scrollingDeltaY * zoomSensitivity
            distance = max(10, min(100, distance))

            sceneManager?.updateCameraPosition(
                distance: distance,
                rotationX: rotationX,
                rotationY: rotationY,
                panX: panX,
                panY: panY
            )

            onUpdate?(rotationX, rotationY, distance, panX, panY)
        }

        override func magnify(with event: NSEvent) {
            // Pinch to zoom
            distance /= (1.0 + event.magnification)
            distance = max(10, min(100, distance))

            sceneManager?.updateCameraPosition(
                distance: distance,
                rotationX: rotationX,
                rotationY: rotationY,
                panX: panX,
                panY: panY
            )

            onUpdate?(rotationX, rotationY, distance, panX, panY)
        }

        override var acceptsFirstResponder: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // Return self to accept events
            return self
        }
    }
}

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

    // OGS polling
    @State private var ogsPollingTimer: Timer? = nil
    @State private var lastMoveCount: Int = 0
    @State private var ogsBackoffDelay: TimeInterval = 1.0  // Current backoff delay
    @State private var ogsPollingInterval: TimeInterval = 1.0  // Current polling interval
    @State private var ogsIsThrottled: Bool = false

    // OGS game metadata
    @State private var ogsBlackName: String?
    @State private var ogsWhiteName: String?
    @State private var ogsBlackRank: String?
    @State private var ogsWhiteRank: String?
    @State private var ogsKomi: String?
    @State private var ogsRuleset: String?
    @State private var ogsBlackCaptured: Int = 0
    @State private var ogsWhiteCaptured: Int = 0

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

            // Check if game has ended
            if newIndex >= player.moves.count - 1 {
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
            if ogsBlackName != nil && !timeControl.isClockRunning {
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
            if ogsBlackName != nil && !timeControl.isClockRunning {
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
            handleOGSGameData(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSMoveReceived"))) { notification in
            handleOGSMove(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSRateLimited"))) { _ in
            handleThrottling()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSPlayerInfo"))) { notification in
            handleOGSPlayerInfo(notification)
        }
        .onAppear {
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
            if let gameWrapper = app.selection {
                NSLog("DEBUG3D: 🎮 Loading initial game on appear: \(gameWrapper.url.lastPathComponent)")
                player.load(game: gameWrapper.game)
                app.selectGame(gameWrapper)  // Load into cache manager with jitter calculation
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
        HStack {
            SettingsPanelView3D(
                isPanelOpen: $showSettings,
                app: app,
                player: player,
                settingsVM: settingsVM,
                soundManager: soundManager,
                ogsClient: ogsClient,
                autoPlay: $isPlaying,
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
            .transition(.move(edge: .leading))

            Spacer()
        }
        .zIndex(100)
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

                    // Game info - OGS mode or local game
                    VStack(alignment: .trailing, spacing: 4) {
                        // Player names with ranks
                        HStack(spacing: 8) {
                            if let blackName = ogsBlackName {
                                // OGS mode
                                Text("\(blackName)")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                if let blackRank = ogsBlackRank {
                                    Text("[\(blackRank)]")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.caption)
                                }
                            } else if let selection = app.selection {
                                // Local game mode
                                Text("\(selection.game.info.playerBlack ?? "?")")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                if let blackRank = selection.game.info.blackRank {
                                    Text("[\(blackRank)]")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.caption)
                                }
                            }

                            Text("vs")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.caption)

                            if let whiteName = ogsWhiteName {
                                // OGS mode
                                Text("\(whiteName)")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                if let whiteRank = ogsWhiteRank {
                                    Text("[\(whiteRank)]")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.caption)
                                }
                            } else if let selection = app.selection {
                                // Local game mode
                                Text("\(selection.game.info.playerWhite ?? "?")")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                if let whiteRank = selection.game.info.whiteRank {
                                    Text("[\(whiteRank)]")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.caption)
                                }
                            }
                        }

                        // Time remaining (OGS only)
                        if ogsBlackName != nil {
                            HStack(spacing: 12) {
                                // Black time
                                HStack(spacing: 4) {
                                    Text("⚫")
                                        .font(.caption)
                                    if let timeRemaining = timeControl.blackTimeRemaining {
                                        Text(formatTime(timeRemaining))
                                            .foregroundColor(.white.opacity(0.8))
                                            .font(.caption)
                                        if let periods = timeControl.blackPeriodsRemaining, periods > 0 {
                                            if periods == 1 {
                                                Text("SD")
                                                    .foregroundColor(.red)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                            } else {
                                                Text("(\(periods)×---)")
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                // White time
                                HStack(spacing: 4) {
                                    Text("⚪")
                                        .font(.caption)
                                    if let timeRemaining = timeControl.whiteTimeRemaining {
                                        Text(formatTime(timeRemaining))
                                            .foregroundColor(.white.opacity(0.8))
                                            .font(.caption)
                                        if let periods = timeControl.whitePeriodsRemaining, periods > 0 {
                                            if periods == 1 {
                                                Text("SD")
                                                    .foregroundColor(.red)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                            } else {
                                                Text("(\(periods)×---)")
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Captures
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Text("⚫")
                                    .font(.caption)
                                Text("\(player.blackCaptured) captured")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.caption)
                            }
                            HStack(spacing: 4) {
                                Text("⚪")
                                    .font(.caption)
                                Text("\(player.whiteCaptured) captured")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.caption)
                            }
                        }

                        // Komi and ruleset
                        HStack(spacing: 12) {
                            if let komi = ogsKomi ?? app.selection?.game.info.komi {
                                Text("Komi: \(komi)")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.caption)
                            }
                            if let ruleset = ogsRuleset ?? app.selection?.game.info.ruleset {
                                Text("Rules: \(ruleset)")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.caption)
                            }
                        }

                        // Move counter
                        Text("Move \(player.currentIndex) / \(player.moves.count)")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                    }
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
                    Text("v3.25")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .padding(.trailing, 20)
                        .padding(.bottom, 8)
                }

                // Bottom controls - single line playback
                HStack(spacing: 12) {
                    Button(action: {
                        player.seek(to: max(0, player.currentIndex - 1))
                        updateStonesWithJitter()
                    }) {
                        Image(systemName: "backward.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(player.currentIndex <= 0)

                    Button(action: {
                        togglePlayPause()
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])

                    Button(action: {
                        player.seek(to: min(player.moves.count, player.currentIndex + 1))
                        updateStonesWithJitter()
                    }) {
                        Image(systemName: "forward.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(player.currentIndex >= player.moves.count)

                    Slider(value: Binding(
                        get: { Double(player.currentIndex) },
                        set: { newValue in
                            player.seek(to: Int(newValue))
                            updateStonesWithJitter()
                        }
                    ), in: 0...Double(max(1, player.moves.count)), step: 1)
                    .frame(width: 300)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.bottom, 20)
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

    private func handleOGSMove(_ notification: Notification) {
        NSLog("DEBUG3D: 🎯 Received OGSMoveReceived notification")
        guard let userInfo = notification.userInfo,
              let x = userInfo["x"] as? Int,
              let y = userInfo["y"] as? Int,
              let isPass = userInfo["isPass"] as? Bool else {
            NSLog("DEBUG3D: ❌ Invalid move data in notification")
            return
        }

        if isPass {
            NSLog("DEBUG3D: 🎯 Opponent passed - reloading game to get updated move list")
        } else {
            NSLog("DEBUG3D: 🎯 Opponent played at (\(x), \(y)) - reloading game to get updated move list")
        }

        // Re-fetch the game data to get all moves including the new one
        // The OGSClient will post OGSGameDataReceived notification which will reload the game
        if let gameID = ogsClient.currentGameID {
            NSLog("DEBUG3D: 🎯 Re-fetching game \(gameID) to include new move")
            ogsClient.joinGame(gameID: gameID)
        } else {
            NSLog("DEBUG3D: ❌ No current game ID to re-fetch")
        }
    }

    private func handleOGSGameData(_ notification: Notification) {
        NSLog("DEBUG3D: 🎮 Received OGSGameDataReceived notification")
        guard let userInfo = notification.userInfo,
              let moves = userInfo["moves"] as? [[Any]],
              let gameID = userInfo["gameID"] as? Int,
              let gameData = userInfo["gameData"] as? [String: Any] else {
            NSLog("DEBUG3D: ❌ Invalid game data in notification")
            return
        }

        NSLog("DEBUG3D: 🎮 Loading OGS game \(gameID) with \(moves.count) moves")

        // IMPORTANT: Stop any existing polling timer from a previous game
        // Otherwise the old timer will keep fetching the old game's data
        if let currentGameID = ogsClient.currentGameID, currentGameID != gameID {
            NSLog("DEBUG3D: 🔄 Switching from game \(currentGameID) to game \(gameID) - stopping old polling")
            stopOGSPolling()
            // Reset state from previous game
            lastMoveCount = 0
            timeControl.reset()
            NSLog("DEBUG3D: 🔄 Reset time control for new game")
        }

        // Extract komi and ruleset from game data
        if let komi = gameData["komi"] as? Double {
            ogsKomi = String(format: "%.1f", komi)
            NSLog("DEBUG3D: 🎮 Komi: \(ogsKomi ?? "nil")")
        } else if let komiString = gameData["komi"] as? String {
            ogsKomi = komiString
            NSLog("DEBUG3D: 🎮 Komi (string): \(ogsKomi ?? "nil")")
        }

        if let rules = gameData["rules"] as? String {
            ogsRuleset = rules
            NSLog("DEBUG3D: 🎮 Rules: \(ogsRuleset ?? "nil")")
        }

        // Check if this is a new move (move count increased)
        if moves.count > lastMoveCount {
            NSLog("DEBUG3D: 🎯 New moves detected! Previous: \(lastMoveCount), Current: \(moves.count)")
            lastMoveCount = moves.count
        } else if lastMoveCount == 0 {
            // First load
            lastMoveCount = moves.count
        }

        // Create a new SGF game from the OGS moves
        let boardSize = userInfo["boardSize"] as? Int ?? 19
        NSLog("DEBUG3D: 🎮 Board size: \(boardSize)")
        var sgfContent = "(;GM[1]FF[4]SZ[\(boardSize)]"

        // Add player names if available
        if let blackName = userInfo["blackName"] as? String,
           let whiteName = userInfo["whiteName"] as? String {
            sgfContent += "PB[\(blackName)]PW[\(whiteName)]"
        }

        // Add handicap stones
        let handicap = userInfo["handicap"] as? Int ?? 0
        NSLog("DEBUG3D: 🎮 Handicap value from OGS: \(handicap)")

        if handicap > 0 {
            sgfContent += "HA[\(handicap)]"

            // Standard handicap positions for 19x19 board only
            // TODO: Add support for 9x9 and 13x13 boards
            if boardSize != 19 {
                NSLog("DEBUG3D: ⚠️ Handicap on non-19x19 board (\(boardSize)x\(boardSize)) - positions may be incorrect")
            }

            let handicapPositions: [[String]] = [
                [],  // 0 handicap
                [],  // 1 handicap (not used)
                ["pd", "dp"],  // 2 handicap
                ["pd", "dp", "pp"],  // 3 handicap
                ["pd", "dp", "pp", "dd"],  // 4 handicap
                ["pd", "dp", "pp", "dd", "jj"],  // 5 handicap
                ["pd", "dp", "pp", "dd", "pj", "dj"],  // 6 handicap
                ["pd", "dp", "pp", "dd", "pj", "dj", "jj"],  // 7 handicap
                ["pd", "dp", "pp", "dd", "pj", "dj", "jd", "jp"],  // 8 handicap
                ["pd", "dp", "pp", "dd", "pj", "dj", "jd", "jp", "jj"]  // 9 handicap
            ]

            if handicap < handicapPositions.count {
                let positions = handicapPositions[handicap]
                NSLog("DEBUG3D: 🎮 Adding \(positions.count) handicap stones at positions: \(positions)")
                if !positions.isEmpty {
                    sgfContent += "AB"
                    for pos in positions {
                        sgfContent += "[\(pos)]"
                    }
                    NSLog("DEBUG3D: 🎮 Added AB property to SGF")
                }
            } else {
                NSLog("DEBUG3D: ⚠️ Handicap \(handicap) is out of range")
            }
        } else {
            NSLog("DEBUG3D: 🎮 No handicap stones (handicap = 0)")
        }

        // Add moves
        var currentColor: Stone = handicap > 0 ? .white : .black

        for move in moves {
            guard move.count >= 2,
                  let x = move[0] as? Int,
                  let y = move[1] as? Int else { continue }

            // Convert to SGF notation
            let sgfMove = OGSClient.positionToSGF(x: x, y: y)
            let moveTag = currentColor == .black ? "B" : "W"
            sgfContent += ";\(moveTag)[\(sgfMove)]"

            // Alternate colors
            currentColor = currentColor == .black ? .white : .black
        }

        sgfContent += ")"

        NSLog("DEBUG3D: 📝 Generated SGF (first 400 chars): \(sgfContent.prefix(400))...")

        // Log specifically the setup portion (before moves)
        if let setupEnd = sgfContent.range(of: ";B[")?.lowerBound ?? sgfContent.range(of: ";W[")?.lowerBound {
            let setupPortion = String(sgfContent[..<setupEnd])
            NSLog("DEBUG3D: 📝 Setup portion of SGF: \(setupPortion)")
        } else {
            NSLog("DEBUG3D: 📝 Full SGF (no moves yet): \(sgfContent)")
        }

        // Parse and load the SGF
        if let tree = try? SGFParser.parse(text: sgfContent) {
            NSLog("DEBUG3D: ✅ Successfully parsed OGS game, loading...")
            let game = SGFGame.from(tree: tree)
            NSLog("DEBUG3D: 🎮 Game has \(game.setup.count) setup stones: \(game.setup)")
            NSLog("DEBUG3D: 🎮 Game has \(game.moves.count) moves")
            player.load(game: game)

            // Seek to the last move to show current game position
            let lastMoveIndex = moves.count
            NSLog("DEBUG3D: 🎯 Seeking to move \(lastMoveIndex) (current position)")
            player.seek(to: lastMoveIndex)
            updateStonesWithJitter()

            // Determine whose turn it is now
            // Black plays first unless there's a handicap, then white plays first
            // After that, colors alternate
            var currentTurn: Stone = handicap > 0 ? .white : .black
            for _ in 0..<moves.count {
                currentTurn = currentTurn == .black ? .white : .black
            }

            NSLog("DEBUG3D: 🕐 After \(moves.count) moves (handicap: \(handicap)), it's \(currentTurn == .black ? "Black" : "White")'s turn")
            timeControl.switchToPlayer(currentTurn)

            // Always restart polling with the new game ID
            // This ensures we're polling the correct game even if a timer was already running
            stopOGSPolling()
            startOGSPolling(gameID: gameID)
        } else {
            NSLog("DEBUG3D: ❌ Failed to parse SGF from OGS data")
        }
    }

    private func startOGSPolling(gameID: Int, interval: TimeInterval? = nil) {
        let pollingInterval = interval ?? ogsPollingInterval
        NSLog("DEBUG3D: ⏰ Starting OGS polling for game \(gameID) - checking every \(pollingInterval) second(s)")

        // Use the specified interval or default
        ogsPollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [ogsClient] _ in
            NSLog("DEBUG3D: 🔄 Polling OGS for updates to game \(gameID)...")
            ogsClient.joinGame(gameID: gameID)
        }

        // Update the current polling interval
        ogsPollingInterval = pollingInterval
    }

    private func handleThrottling() {
        guard let gameID = ogsClient.currentGameID else {
            NSLog("DEBUG3D: ⚠️ Throttled but no current game ID")
            return
        }

        NSLog("DEBUG3D: ⚠️ Throttled! Stopping polling and backing off for \(ogsBackoffDelay)s")
        ogsIsThrottled = true
        stopOGSPolling()

        // Wait for backoff delay, then resume with longer interval
        DispatchQueue.main.asyncAfter(deadline: .now() + ogsBackoffDelay) { [self] in
            NSLog("DEBUG3D: 🔄 Backoff period over, resuming polling...")

            // Double the backoff for next time (exponential backoff), cap at 60s
            ogsBackoffDelay = min(ogsBackoffDelay * 2, 60.0)

            // Resume polling with increased interval (at least 2.0s during backoff recovery)
            let newInterval = max(2.0, ogsBackoffDelay / 2)
            NSLog("DEBUG3D: 🔄 Resuming with interval \(newInterval)s, next backoff would be \(ogsBackoffDelay)s")

            ogsIsThrottled = false
            startOGSPolling(gameID: gameID, interval: newInterval)

            // After successful polling for a while, reset backoff gradually
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [self] in
                if !ogsIsThrottled && ogsBackoffDelay > 1.0 {
                    // Gradually reduce backoff if we haven't been throttled
                    ogsBackoffDelay = max(1.0, ogsBackoffDelay / 2)
                    NSLog("DEBUG3D: 📉 Reducing backoff delay to \(ogsBackoffDelay)s after successful polling")
                }
            }
        }
    }

    private func stopOGSPolling() {
        ogsPollingTimer?.invalidate()
        ogsPollingTimer = nil
        NSLog("DEBUG3D: ⏰ Stopped OGS polling")
    }

    private func handleOGSPlayerInfo(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            NSLog("DEBUG3D: ❌ No userInfo in OGSPlayerInfo notification")
            return
        }

        NSLog("DEBUG3D: 👥 Received OGSPlayerInfo notification")

        ogsBlackName = userInfo["blackName"] as? String
        ogsWhiteName = userInfo["whiteName"] as? String
        ogsBlackRank = userInfo["blackRank"] as? String
        ogsWhiteRank = userInfo["whiteRank"] as? String

        NSLog("DEBUG3D: 👥 Updated player info: \(ogsBlackName ?? "?") [\(ogsBlackRank ?? "?")] vs \(ogsWhiteName ?? "?") [\(ogsWhiteRank ?? "?")]")
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}


// MARK: - SceneManager3D
// Manages the 3D scene, board, and stones

class SceneManager3D: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let pivotNode = SCNNode()  // Pivot for camera rotation around board center
    private var boardNode: SCNNode?
    private var stoneNodes: [SCNNode] = []
    private var currentPlayer: SGFPlayer?

    // Board configuration
    private let boardSize: Int = 19
    // Traditional Japanese board: cells are taller than they are wide
    // Ratio is approximately 1:1.0773 (width:height)
    private let cellWidth: CGFloat = 1.0
    private let cellHeight: CGFloat = 1.0773
    private let boardThickness: CGFloat = 2.0
    // Traditional Japanese stone sizes: black 22.2mm, white 21.9mm
    // Scale to our units where cellWidth = 1.0
    private let blackStoneRadius: CGFloat = 0.456  // 22.2mm / 22mm * 0.45
    private let whiteStoneRadius: CGFloat = 0.450  // 21.9mm / 22mm * 0.45

    init() {
        setupCamera()
        setupLighting()
        setupBackground()
        createBoard()

        NSLog("DEBUG3D: v0.1.6 SceneManager init complete - NOT loading test game here")
    }

    private func setupBackground() {
        // Create stars as actual 3D geometry objects
        NSLog("DEBUG3D: Creating 3D star field v0.8.6")

        // Dark blue background
        scene.background.contents = NSColor(red: 0.01, green: 0.01, blue: 0.05, alpha: 1.0)

        let starCount = 2000
        let starFieldRadius: CGFloat = 150.0

        for _ in 0..<starCount {
            // Random position on sphere surface
            let theta = CGFloat.random(in: 0...(2 * .pi))
            let phi = CGFloat.random(in: 0...(CGFloat.pi))

            let x = starFieldRadius * sin(phi) * cos(theta)
            let y = starFieldRadius * sin(phi) * sin(theta)
            let z = starFieldRadius * cos(phi)

            // Smaller stars with varied brightness
            let starSize = CGFloat.random(in: 0.15...0.4)
            let brightness = CGFloat.random(in: 0.5...1.0)

            let starMaterial = SCNMaterial()
            starMaterial.diffuse.contents = NSColor(white: brightness, alpha: 1.0)
            starMaterial.lightingModel = .constant  // Unlit
            starMaterial.emission.contents = NSColor(white: brightness, alpha: 1.0)

            let star = SCNSphere(radius: starSize)
            star.materials = [starMaterial]

            let starNode = SCNNode(geometry: star)
            starNode.position = SCNVector3(x, y, z)
            starNode.renderingOrder = -100  // Render behind everything
            scene.rootNode.addChildNode(starNode)
        }

        NSLog("DEBUG3D: Created \(starCount) 3D stars at radius \(starFieldRadius)")
    }



    private func setupCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 1000.0  // Allow seeing stars at distance
        cameraNode.camera = camera

        // Position pivot at board center (y=0 is center of 2.0 thick board)
        pivotNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(pivotNode)

        // Add camera to pivot so it rotates around board center
        pivotNode.addChildNode(cameraNode)

        // Position camera relative to pivot (board center)
        cameraNode.position = SCNVector3(x: 0, y: 15, z: 20)
        cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
    }

    private func setupLighting() {
        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = NSColor(white: 0.4, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // Directional light from upper left (180 degrees from upper right)
        // Was (10, 20, 10) - now (-10, 20, -10) for upper left
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = NSColor(white: 0.8, alpha: 1.0)
        directionalLight.light!.castsShadow = true
        directionalLight.light!.shadowMode = .deferred
        directionalLight.light!.shadowRadius = 3.0  // Soft shadow edges
        directionalLight.light!.shadowSampleCount = 16  // Smooth shadows
        directionalLight.light!.shadowColor = NSColor(white: 0.0, alpha: 0.3)  // Gentle shadow opacity
        directionalLight.position = SCNVector3(x: -10, y: 20, z: -10)
        directionalLight.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(directionalLight)
    }

    func setupInitialScene(player: SGFPlayer) {
        self.currentPlayer = player
        updateStones(from: player)
    }

    func updateStones(from player: SGFPlayer, jitterMultiplier: CGFloat = 1.0, jitterOffsets: [BoardPosition: CGPoint] = [:]) {
        // Remove all existing stones
        stoneNodes.forEach { $0.removeFromParentNode() }
        stoneNodes.removeAll()

        // Create stones based on current board state
        let board = player.board
        let totalWidth = CGFloat(boardSize - 1) * cellWidth
        let totalHeight = CGFloat(boardSize - 1) * cellHeight
        let offsetX = -totalWidth / 2.0
        let offsetZ = -totalHeight / 2.0
        let boardTopY = boardThickness / 2.0

        NSLog("DEBUG3D: 🎯 updateStones called - board size: \(board.size), current index: \(player.currentIndex), jitter: \(jitterMultiplier)")

        // Track stone positions and radii for collision detection
        var stonePositions: [(position: SCNVector3, radius: CGFloat)] = []

        var stoneCount = 0
        for row in 0..<board.size {
            for col in 0..<board.size {
                if let stone = board.grid[row][col] {
                    let stoneRadius = stone == .black ? blackStoneRadius : whiteStoneRadius

                    var x = CGFloat(col) * cellWidth + offsetX
                    var z = CGFloat(row) * cellHeight + offsetZ

                    // Apply jitter if available
                    let position = BoardPosition(x: col, y: row)
                    if let jitterOffset = jitterOffsets[position] {
                        // Jitter is in fraction of stone radius (0-0.22 range)
                        // Scale by stone diameter for more visible effect
                        let stoneDiameter = stoneRadius * 2.0
                        let jitterX = jitterOffset.x * jitterMultiplier * stoneDiameter
                        let jitterZ = jitterOffset.y * jitterMultiplier * stoneDiameter
                        x += jitterX
                        z += jitterZ
                        if jitterMultiplier > 0.1 && stoneCount < 5 {
                            NSLog("DEBUG3D: 🎲 Applying jitter to stone at (\(col),\(row)): offset=(\(jitterOffset.x), \(jitterOffset.y)), scaled=(\(jitterX), \(jitterZ))")
                        }
                    }

                    // Position stone so bottom just touches board
                    // Stone is ellipsoid scaled by thicknessRatio (0.486) in Y
                    let thicknessRatio: CGFloat = 0.486
                    let stoneScaledHalfHeight = stoneRadius * thicknessRatio
                    let y = boardTopY + stoneScaledHalfHeight

                    var finalPosition = SCNVector3(x: x, y: y, z: z)

                    // Check for collisions with existing stones and resolve
                    finalPosition = resolveCollisions(proposedPosition: finalPosition, radius: stoneRadius, existingStones: stonePositions)

                    let stoneNode = createStone(color: stone, at: finalPosition)

                    // Add halo to the last played stone
                    if let lastMove = player.lastMove, lastMove.x == col && lastMove.y == row {
                        addHaloToStone(stoneNode, color: stone, radius: stoneRadius)
                    }

                    scene.rootNode.addChildNode(stoneNode)
                    stoneNodes.append(stoneNode)
                    stonePositions.append((finalPosition, stoneRadius))
                    stoneCount += 1
                }
            }
        }
        NSLog("DEBUG3D: 🎯 Created \(stoneCount) stone nodes")
    }

    private func resolveCollisions(proposedPosition: SCNVector3, radius: CGFloat, existingStones: [(position: SCNVector3, radius: CGFloat)]) -> SCNVector3 {
        var adjustedPosition = proposedPosition

        // Try to resolve collisions by nudging the stone
        for _ in 0..<10 {  // Max 10 iterations
            var hasCollision = false

            for existing in existingStones {
                let dx = adjustedPosition.x - existing.position.x
                let dz = adjustedPosition.z - existing.position.z
                let distance = sqrt(dx * dx + dz * dz)

                // Minimum distance is sum of both radii
                let minDistance = radius + existing.radius

                if distance < minDistance {
                    hasCollision = true

                    // Push the stone away from the collision
                    if distance > 0.001 {
                        let pushDistance = (minDistance - distance) / 2.0
                        let pushX = (dx / distance) * pushDistance
                        let pushZ = (dz / distance) * pushDistance
                        adjustedPosition.x += pushX
                        adjustedPosition.z += pushZ
                    } else {
                        // Stones exactly on top of each other - push in random direction
                        adjustedPosition.x += CGFloat.random(in: -0.1...0.1)
                        adjustedPosition.z += CGFloat.random(in: -0.1...0.1)
                    }
                }
            }

            if !hasCollision {
                break
            }
        }

        return adjustedPosition
    }

    private func createStone(color: Stone, at position: SCNVector3) -> SCNNode {
        // Create bi-convex lens shape (like M&M or lentil)
        // Real Go stones: black 22.2mm, white 21.9mm diameter, 10.7mm thick for size 36
        // Our scale: cellSize = 1.0 unit
        // Thickness ratio: 10.7 / 22 = 0.486

        // Use appropriate radius for stone color
        let stoneRadius = color == .black ? blackStoneRadius : whiteStoneRadius
        let thicknessRatio: CGFloat = 0.486  // 10.7mm / 22mm from real stones

        // Create ellipsoid (sphere scaled to lens shape)
        let sphere = SCNSphere(radius: stoneRadius)
        sphere.segmentCount = 48  // More segments for smoother appearance

        let material = SCNMaterial()

        switch color {
        case .black:
            // Solid black for now - textures have transparency issues
            material.diffuse.contents = NSColor.black
            material.specular.contents = NSColor(white: 0.3, alpha: 1.0)
            material.shininess = 0.8
        case .white:
            // Solid white for now - textures have transparency issues
            material.diffuse.contents = NSColor.white
            material.specular.contents = NSColor(white: 0.9, alpha: 1.0)
            material.shininess = 1.0
        }

        // Configure material properties
        material.isDoubleSided = false
        material.lightingModel = .blinn

        sphere.materials = [material]

        let stoneNode = SCNNode(geometry: sphere)

        // Scale to create bi-convex lens shape
        // The Y scale determines thickness relative to diameter
        stoneNode.scale = SCNVector3(1.0, thicknessRatio, 1.0)

        stoneNode.position = position
        stoneNode.castsShadow = true

        return stoneNode
    }

    private func addHaloToStone(_ stoneNode: SCNNode, color: Stone, radius: CGFloat) {
        NSLog("DEBUG3D: ✨ Adding halo to \(color) stone with radius \(radius)")

        let thicknessRatio: CGFloat = 0.486
        let stoneHalfHeight = radius * thicknessRatio

        // 1. Create permanent glow disc UNDER the stone
        let underGlowRadius = radius * 1.4
        let underGlowHeight: CGFloat = 0.03

        let underDisc = SCNCylinder(radius: underGlowRadius, height: underGlowHeight)
        let underNode = SCNNode(geometry: underDisc)

        let underMaterial = SCNMaterial()
        // Use complementary colors: amber for black stones, bright cyan/blue for white stones
        if color == .white {
            underMaterial.emission.contents = NSColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.25)
            underMaterial.diffuse.contents = NSColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 0.12)
        } else {
            underMaterial.emission.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.25)
            underMaterial.diffuse.contents = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.12)
        }
        underMaterial.isDoubleSided = true
        underMaterial.transparency = 0.88
        underMaterial.lightingModel = .constant
        underMaterial.blendMode = .add
        underMaterial.writesToDepthBuffer = false
        underMaterial.readsFromDepthBuffer = true
        underDisc.materials = [underMaterial]

        underNode.position = SCNVector3(0, -stoneHalfHeight - underGlowHeight/2 + 0.002, 0)
        underNode.opacity = 0.25

        // Add a subtle pulsing animation to the under-glow
        let pulse = SCNAction.sequence([
            SCNAction.fadeOpacity(to: 0.35, duration: 0.8),
            SCNAction.fadeOpacity(to: 0.25, duration: 0.8)
        ])
        let repeatPulse = SCNAction.repeatForever(pulse)
        underNode.runAction(repeatPulse)

        stoneNode.addChildNode(underNode)

        // 2. Create expanding circle rings that move upward (ripple effect)
        let numRings = 3
        for i in 0..<numRings {
            let delay = Double(i) * 0.15

            let ringRadius = radius * 0.8
            let ringThickness: CGFloat = 0.08

            let torus = SCNTorus(ringRadius: ringRadius, pipeRadius: ringThickness)
            torus.ringSegmentCount = 48
            torus.pipeSegmentCount = 12

            let ringNode = SCNNode(geometry: torus)

            let ringMaterial = SCNMaterial()
            // Use darker blue for white stones, bright amber for black stones
            if color == .white {
                ringMaterial.emission.contents = NSColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 0.5)
                ringMaterial.diffuse.contents = NSColor(red: 0.05, green: 0.2, blue: 0.4, alpha: 0.3)
            } else {
                ringMaterial.emission.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.5)
                ringMaterial.diffuse.contents = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.3)
            }
            ringMaterial.isDoubleSided = true
            ringMaterial.transparency = 0.7
            ringMaterial.lightingModel = .constant
            ringMaterial.blendMode = .add
            ringMaterial.writesToDepthBuffer = false
            ringMaterial.readsFromDepthBuffer = true
            torus.materials = [ringMaterial]

            ringNode.position = SCNVector3(0, stoneHalfHeight * 0.5, 0)
            ringNode.opacity = 0
            ringNode.eulerAngles.x = .pi / 2

            // Animation: fade in, expand and rise, fade out
            let fadeIn = SCNAction.fadeOpacity(to: 0.8, duration: 0.15)
            let fadeOut = SCNAction.fadeOut(duration: 0.4)
            let opacitySequence = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                fadeIn,
                SCNAction.wait(duration: 0.1),
                fadeOut
            ])

            let scaleAction = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                SCNAction.scale(to: 2.0, duration: 0.65)
            ])

            let moveUp = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                SCNAction.moveBy(x: 0, y: radius * 1.5, z: 0, duration: 0.65)
            ])

            ringNode.runAction(opacitySequence)
            ringNode.runAction(scaleAction)
            ringNode.runAction(moveUp)

            stoneNode.addChildNode(ringNode)
        }
    }

    private func createBoard() {
        // Create a 3D Go board with traditional Japanese proportions
        // Board has (boardSize - 1) cells, plus 1 cell width border on each side
        // So total = (boardSize - 1) * cellWidth + 2 * cellWidth = (boardSize + 1) * cellWidth
        let boardWidth = CGFloat(boardSize + 1) * cellWidth
        let boardLength = CGFloat(boardSize + 1) * cellHeight

        // Board base
        let boardGeometry = SCNBox(
            width: boardWidth,
            height: boardThickness,
            length: boardLength,
            chamferRadius: 0.0  // Square corners
        )

        // Load kaya texture
        let material = SCNMaterial()
        if let kayaImage = NSImage(named: "board_kaya") {
            material.diffuse.contents = kayaImage
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.diffuse.contentsTransform = SCNMatrix4MakeScale(1.0, 1.0, 1.0)
        } else {
            // Fallback to wood color if image not found
            material.diffuse.contents = NSColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0)
        }
        material.specular.contents = NSColor(white: 0.3, alpha: 1.0)
        material.shininess = 0.1

        // Make board fully opaque - no transparency
        material.transparency = 1.0
        material.isDoubleSided = false  // Only render front face
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true

        boardGeometry.materials = [material]

        let boardNode = SCNNode(geometry: boardGeometry)
        boardNode.position = SCNVector3(x: 0, y: 0, z: 0)
        boardNode.castsShadow = false  // Board doesn't cast shadows
        scene.rootNode.addChildNode(boardNode)
        self.boardNode = boardNode

        // Add opaque blocker plane INSIDE the board to prevent see-through
        // Make it slightly smaller so it's hidden inside
        let blockerPlane = SCNBox(
            width: boardWidth * 0.98,  // Slightly smaller
            height: 0.01,  // Very thin
            length: boardLength * 0.98,  // Slightly smaller
            chamferRadius: 0
        )
        let blockerMaterial = SCNMaterial()
        blockerMaterial.diffuse.contents = NSColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0)  // Wood color
        blockerMaterial.isDoubleSided = false
        blockerMaterial.transparency = 1.0  // Fully opaque
        blockerMaterial.writesToDepthBuffer = true
        blockerPlane.materials = [blockerMaterial]

        let blockerNode = SCNNode(geometry: blockerPlane)
        blockerNode.position = SCNVector3(x: 0, y: -boardThickness / 4.0, z: 0)  // Inside the board, halfway down
        blockerNode.renderingOrder = -1  // Render before everything else
        scene.rootNode.addChildNode(blockerNode)

        // Create grid lines
        createGridLines(boardThickness: boardThickness)
    }

    private func createGridLines(boardThickness: CGFloat) {
        let lineThickness: CGFloat = 0.02
        let lineHeight: CGFloat = 0.002  // Very thin lines
        let lineColor = NSColor.black
        let boardTopY = boardThickness / 2.0 + 0.02  // Position lines well above board surface

        let totalWidth = CGFloat(boardSize - 1) * cellWidth
        let totalHeight = CGFloat(boardSize - 1) * cellHeight
        let offsetX = -totalWidth / 2.0
        let offsetZ = -totalHeight / 2.0

        // Horizontal lines (run along X axis, spaced in Z direction)
        for i in 0..<boardSize {
            let z = CGFloat(i) * cellHeight + offsetZ
            let line = SCNBox(
                width: totalWidth,
                height: lineHeight,
                length: lineThickness,
                chamferRadius: 0
            )
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            material.isDoubleSided = false
            material.writesToDepthBuffer = true
            line.materials = [material]

            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x: 0, y: boardTopY, z: z)
            lineNode.renderingOrder = 1  // Render on top
            scene.rootNode.addChildNode(lineNode)
        }

        // Vertical lines (run along Z axis, spaced in X direction)
        for i in 0..<boardSize {
            let x = CGFloat(i) * cellWidth + offsetX
            let line = SCNBox(
                width: lineThickness,
                height: lineHeight,
                length: totalHeight,
                chamferRadius: 0
            )
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            material.isDoubleSided = false
            material.writesToDepthBuffer = true
            line.materials = [material]

            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x: x, y: boardTopY, z: 0)
            lineNode.renderingOrder = 1  // Render on top
            scene.rootNode.addChildNode(lineNode)
        }

        // Star points (for 19x19 board)
        let starPoints = [(3, 3), (3, 9), (3, 15), (9, 3), (9, 9), (9, 15), (15, 3), (15, 9), (15, 15)]
        for (col, row) in starPoints {
            let xPos = CGFloat(col) * cellWidth + offsetX
            let zPos = CGFloat(row) * cellHeight + offsetZ

            let star = SCNSphere(radius: 0.08)
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            material.isDoubleSided = false
            material.writesToDepthBuffer = true
            star.materials = [material]

            let starNode = SCNNode(geometry: star)
            starNode.position = SCNVector3(x: xPos, y: boardTopY + 0.01, z: zPos)
            starNode.renderingOrder = 1  // Render on top
            scene.rootNode.addChildNode(starNode)
        }
    }

    func updateCamera(angleX: Double, angleY: Double, distance: Double) {
        let x = distance * cos(angleX * .pi / 180) * sin(angleY * .pi / 180)
        let y = distance * sin(angleX * .pi / 180)
        let z = distance * cos(angleX * .pi / 180) * cos(angleY * .pi / 180)

        cameraNode.position = SCNVector3(x: CGFloat(x), y: CGFloat(y), z: CGFloat(z))
        cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
    }

    func updateCameraPosition(distance: CGFloat, rotationX: Float, rotationY: Float, panX: CGFloat, panY: CGFloat) {
        // Update pivot rotation
        pivotNode.eulerAngles.y = CGFloat(rotationY)
        pivotNode.eulerAngles.x = CGFloat(rotationX)

        // Update camera distance and pan
        // Calculate base position at distance
        let baseY: CGFloat = 15
        let baseZ: CGFloat = 20

        // Scale the base position by the distance ratio
        let distanceRatio = distance / 25.0  // 25 was the original distance

        cameraNode.position = SCNVector3(
            x: panX,
            y: baseY * distanceRatio + panY,
            z: baseZ * distanceRatio
        )

        // Look at the pan offset point
        cameraNode.look(at: SCNVector3(x: panX, y: panY, z: 0))
    }
}

// MARK: - Preview
struct ContentView3D_Previews: PreviewProvider {
    static var previews: some View {
        ContentView3D()
            .environmentObject(AppModel())
    }
}
