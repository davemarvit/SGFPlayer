// MARK: - ContentView v2.2 - Visual Assets Fixed
// v2.2: Real tatami.jpg, board_kaya.jpg, bowl images, stone images, proper sizing
// v2.1: Controls moved back to settings, textures restored, physics working

import SwiftUI
import AppKit
import Combine

// MARK: - Captured Stone Model (Legacy Compatibility)
struct CapturedStone: Identifiable {
    let id = UUID()
    let isWhite: Bool
    let imageName: String
    var pos: CGPoint
    var normalizedPos: CGPoint

    init(isWhite: Bool, imageName: String, pos: CGPoint = .zero, normalizedPos: CGPoint = .zero) {
        self.isWhite = isWhite
        self.imageName = imageName
        self.pos = pos
        self.normalizedPos = normalizedPos
    }
}

struct LidLayout: Codable {
    let blackStones: [CGPoint]
    let whiteStones: [CGPoint]
}

// MARK: - Main ContentView (Session 2: ViewModels Integration Started)
struct ContentView: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var bowls = PlayerCapturesAdapter()

    // Convenience properties to access centralized components from AppModel
    private var player: SGFPlayer { app.player }
    private var ogsClient: OGSClient { app.ogsClient }
    private var timeControl: TimeControlManager { app.timeControl }
    private var ogsGame: OGSGameViewModel? { app.ogsGame }

    // NEW MODULAR PHYSICS ARCHITECTURE
    @StateObject private var physicsIntegration = PhysicsIntegration()

    // NEW: ViewModels for cleaner architecture (Session 2)
    @StateObject private var uiStateVM = UIStateViewModel()

    // Sound Manager
    @StateObject private var soundManager = SoundManager.shared
    @State private var previousMoveIndex: Int = 0

    // UI State (transitioning to uiStateVM)
    @State private var isPanelOpen: Bool = false
    // showFullscreen, buttonsVisible now managed by uiStateVM
    @State private var showPhysicsDemo: Bool = false
    @State private var fadeTimer: Timer? = nil

    // Settings
    @AppStorage("randomOnStart") private var randomOnStart: Bool = false
    @AppStorage("autoStartOnLaunch") private var autoStartOnLaunch: Bool = true
    @AppStorage("loopGames") private var loopGames: Bool = true

    // Track last loaded OGS move count to avoid re-seeking on every poll
    @State private var lastLoadedOGSMoveCount: Int = -1

    // Filtered games for navigation (when search is active)
    @State private var filteredGames: [SGFGameWrapper] = []
    @State private var isSearchActive: Bool = false

    // Persist search state between launches
    @AppStorage("lastSearchQuery") private var lastSearchQuery: String = ""
    @AppStorage("isSearchActivePersisted") private var isSearchActivePersisted: Bool = false

    // Initialization tracking to prevent repeated app initialization
    @State private var isInitialized: Bool = false
    @AppStorage("autoNext") private var autoNext: Bool = false
    @AppStorage("randomNext") private var randomNext: Bool = false
    // Note: boardStoneDiameter is now managed by UIStateViewModel for responsive sizing
    @AppStorage("activePhysicsModel") private var legacyActivePhysicsModel: Int = 2

    // Shadow parameters
    @AppStorage("lidShadowOpacity") private var lidShadowOpacity: Double = 0.30
    @AppStorage("lidShadowRadius") private var lidShadowRadius: Double = 10
    @AppStorage("lidShadowDX") private var lidShadowDX: Double = 5
    @AppStorage("lidShadowDY") private var lidShadowDY: Double = 8
    @AppStorage("stoneShadowOpacity") private var stoneShadowOpacity: Double = 0.40
    @AppStorage("stoneShadowRadius") private var stoneShadowRadius: Double = 3
    @AppStorage("stoneShadowDX") private var stoneShadowDX: Double = 2
    @AppStorage("stoneShadowDY") private var stoneShadowDY: Double = 8

    // Legacy physics parameters (kept for settings panel compatibility)
    @AppStorage("m1_repel") private var m1_repel: Double = 1.60
    @AppStorage("m1_spacing") private var m1_spacing: Double = 2.12
    @AppStorage("m1_centerPullK") private var m1_centerPullK: Double = 0.0028
    @AppStorage("m1_relaxIters") private var m1_relaxIters: Int = 12
    @AppStorage("m1_pressureRadiusXR") private var m1_pressureRadiusXR: Double = 2.6
    @AppStorage("m1_pressureKFactor") private var m1_pressureKFactor: Double = 0.25
    @AppStorage("m1_maxStepXR") private var m1_maxStepXR: Double = 0.06
    @AppStorage("m1_damping") private var m1_damping: Double = 0.82
    @AppStorage("m1_wallK") private var m1_wallK: Double = 0.60
    @AppStorage("m1_anim") private var m1_anim: Double = 0.6
    @AppStorage("m1_stoneStoneK") private var m1_stoneStoneK: Double = 0.15
    @AppStorage("m1_stoneLidK") private var m1_stoneLidK: Double = 0.25

    // UI state
    @State private var debugLayout = false
    @State private var advancedExpanded: Bool = false
    @AppStorage("uiMoveDelay") private var uiMoveDelay: Double = 0.75
    @State private var currentBowlRadius: CGFloat = 100.0

    // Window title computation
    private var windowTitle: String {
        guard let selection = app.selection else {
            return "SGFPlayer"
        }
        let info = selection.game.info
        let blackPlayer = info.playerBlack ?? "?"
        let whitePlayer = info.playerWhite ?? "?"
        var title = "\(blackPlayer) vs \(whitePlayer)"
        if let date = info.date, !date.isEmpty {
            title += " - \(date)"
        }
        return title
    }

    // Bowl positioning - updated by GameBoardView
    @State private var actualUlCenter: CGPoint = CGPoint(x: 150, y: 150)
    @State private var actualLrCenter: CGPoint = CGPoint(x: 650, y: 450)
    @State private var actualBowlRadius: CGFloat = 100.0

    // Debouncing for physics updates
    @State private var physicsUpdateTimer: Timer?
    @State private var pendingPhysicsUpdate: Int?

    // Capture tallies and caching
    @State private var tallyWByB: Int = 0
    @State private var tallyBByW: Int = 0
    @State private var tallyAtMove: [Int:(w:Int,b:Int)] = [0:(0,0)]
    @State private var gridAtMove: [Int : [[Stone?]]] = [:]
    @State private var layoutAtMove: [Int: LidLayout] = [:]

    // Physics model selection (migrated to new system)
    @State private var activePhysicsModelRaw: Int = 2

    // Computed property for active game list (filtered or all games)
    private var activeGamesList: [SGFGameWrapper] {
        return isSearchActive && !filteredGames.isEmpty ? filteredGames : app.games
    }

    var body: some View {
        NSLog("📺 ContentView.body CALLED - 2D view is rendering!")

        return ZStack {
            mainGameContent
            topButtonsOverlay
            settingsPanelOverlay
            physicsOverlay

            // Pre-game overlay for finding/creating games
            if app.showPreGameOverlay {
                PreGameOverlay(ogsClient: app.ogsClient, isVisible: $app.showPreGameOverlay)
            }

            gameInfoOverlay

            // v3.123: Phantom stones working in both 2D and 3D
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("v3.123")
                        .foregroundColor(.white)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(10)
                        .background(Color.red)
                        .cornerRadius(5)
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            // Show controls on any mouse movement
            switch phase {
            case .active(_):
                resetButtonFadeTimer()
            case .ended:
                break
            }
        }
        .onAppear {
            // Auto-connect to OGS if OGS mode is enabled
            let ogsMode = UserDefaults.standard.bool(forKey: "ogsMode")
            if ogsMode && !ogsClient.isConnected {
                ogsClient.connect()
                NSLog("ContentView: 🔌 Auto-connecting to OGS on startup (OGS Mode was ON)")
            }
        }
        .onReceive(player.$currentIndex) { newIndex in
            // Play stone click sound ONLY when moving forward to a NEW move
            if newIndex > previousMoveIndex && newIndex > 0 {
                soundManager.playStoneClick()
            }
            previousMoveIndex = newIndex

            if !isInitialized {
                initializeApp()
                isInitialized = true
            }
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    resetButtonFadeTimer()
                }
        )
        .onAppear {
            resetButtonFadeTimer()
        }
        .onChange(of: player.currentIndex) { _, newIndex in
            updatePhysicsForMove(newIndex)
        }
        .onChange(of: physicsIntegration.activePhysicsModel) { _, _ in
            clearCacheAndRefresh()
        }
        .onChange(of: app.selection) { _, newSelection in
            if let gameWrapper = newSelection {
                // Clear all cached data BEFORE loading new game to prevent stale capture counts
                tallyAtMove.removeAll()
                physicsIntegration.reset()

                // IMPORTANT: Stop OGS polling and clear OGS state when switching to a local game
                if app.ogsGame?.blackName != nil {
                    NSLog("ContentView: 🛑 Switching from OGS game to local game - stopping OGS polling")
                    app.ogsGame?.stopPolling()
                    app.ogsGame?.blackName = nil
                    app.ogsGame?.whiteName = nil
                    app.ogsGame?.blackRank = nil
                    app.ogsGame?.whiteRank = nil
                    app.ogsGame?.komi = nil
                    app.ogsGame?.ruleset = nil
                    app.ogsClient.currentGameID = nil
                    app.timeControl.reset()
                }

                // Note: Game is now loaded by app.selectGame() in AppModel
                // This ensures game state is centralized and shared between 2D and 3D views

                // Update window title
                updateWindowTitle()

                print("🎮 Loaded new game: \(gameWrapper.game.moves.count) moves, board size \(gameWrapper.game.boardSize)")
                print("🎯 Game cache updated with fingerprint: \(gameWrapper.fingerprint)")
                print("🧹 Physics integration and capture cache cleared before new game")

                // Auto-start playback if autoplay is enabled
                if autoNext {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        player.play()
                        print("🔄 Auto-started playback for new game selection")
                    }
                }
            }
        }
        .onChange(of: autoNext) { _, isAutoPlay in
            if isAutoPlay {
                player.play()
                print("🎮 Auto-play started")
            } else {
                player.pause()
                print("🎮 Auto-play paused")
            }
        }
        .onChange(of: uiMoveDelay) { _, newDelay in
            player.setPlayInterval(newDelay)
            print("🎮 Play interval updated to \(newDelay)s")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Don't auto-select random games when connected to OGS
            if randomOnStart, app.selection == nil, !ogsClient.isConnected {
                app.pickRandomGame(from: activeGamesList)
            }

            // Resume auto-play if in local mode and a game is loaded
            if !ogsClient.isConnected, app.selection != nil, autoNext, !player.isPlaying {
                NSLog("ContentView: ▶️ Resuming auto-play on app activation")
                player.play()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameDidFinish)) { _ in
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
            } else if loopGames {
                // Wait 5 seconds, then advance to next game in sequence (or loop back to first)
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
        .onChange(of: ogsClient.blackTimeRemaining) { oldTime, newTime in
            NSLog("ContentView: ⏱️ Black time changed: \(oldTime ?? -1) -> \(newTime ?? -1)")
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
            NSLog("ContentView: ⏱️ White time changed: \(oldTime ?? -1) -> \(newTime ?? -1)")
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSConnected"))) { _ in
            NSLog("ContentView: 🔌 OGS connected - clearing local game selection and clearing board")
            app.selection = nil
            player.clear()  // Completely clear board including handicap stones
            player.pause()  // Stop any playback
            ogsClient.currentGameID = nil  // Clear any active OGS game
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSGameDataReceived"))) { notification in
            // Only process if we have an active OGS game ID (allows initial game load)
            guard ogsClient.currentGameID != nil else {
                NSLog("ContentView: 🛑 Ignoring OGSGameDataReceived - no active game ID")
                return
            }

            // v3.116: Auto-dismiss the PreGameOverlay when game loads
            if app.showPreGameOverlay {
                NSLog("ContentView: 🎮 Game loaded - auto-dismissing PreGameOverlay")
                app.showPreGameOverlay = false
            }

            ogsGame?.handleGameData(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSMoveReceived"))) { notification in
            // Only process if we have an active OGS game ID
            guard ogsClient.currentGameID != nil else {
                NSLog("ContentView: 🛑 Ignoring OGSMoveReceived - no active game ID")
                return
            }
            ogsGame?.handleMove(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSRateLimited"))) { _ in
            // Only process if we have an active OGS game ID
            guard ogsClient.currentGameID != nil else {
                NSLog("ContentView: 🛑 Ignoring OGSRateLimited - no active game ID")
                return
            }
            ogsGame?.handleThrottling()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSPlayerInfo"))) { notification in
            // Only process if we have an active OGS game ID (allows initial player info load)
            guard ogsClient.currentGameID != nil else {
                NSLog("ContentView: 🛑 Ignoring OGSPlayerInfo - no active game ID")
                return
            }
            ogsGame?.handlePlayerInfo(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSGameLoaded"))) { notification in
            // Only process if we have an active OGS game ID
            guard ogsClient.currentGameID != nil else {
                NSLog("ContentView: 🛑 Ignoring OGSGameLoaded - no active game ID")
                return
            }

            // Handle game loading from OGSGameViewModel
            guard let userInfo = notification.userInfo,
                  let game = userInfo["game"] as? SGFGame,
                  let moveCount = userInfo["moveCount"] as? Int else {
                NSLog("ContentView: ❌ Invalid OGSGameLoaded notification")
                return
            }

            // IMPORTANT: Only reload/seek if the move count has actually changed
            // Otherwise polling will trigger seek() every second, causing spurious updates
            if moveCount != lastLoadedOGSMoveCount {
                NSLog("ContentView: 🎮 Received OGSGameLoaded notification with \(game.moves.count) moves (changed from \(lastLoadedOGSMoveCount))")
                player.load(game: game)
                player.seek(to: moveCount)
                // Force physics and capture updates for the new move
                updatePhysicsForMove(moveCount)
                lastLoadedOGSMoveCount = moveCount
            } else {
                NSLog("ContentView: 🔄 OGSGameLoaded poll - move count unchanged (\(moveCount))")
            }
        }
        .focusable()
        .focusEffectDisabled()  // Disable blue focus ring while keeping keyboard shortcuts
        .onKeyPress { keyPress in
            // Only intercept keys we actually handle (arrow keys, space, escape)
            // Let everything else (letters, numbers, etc.) pass through to TextFields
            switch keyPress.key {
            case .leftArrow, .rightArrow, .space, .escape:
                handleKeyPress(keyPress)
                return .handled
            default:
                return .ignored  // Let other keys pass through to focused controls
            }
        }
    }

    // MARK: - View Components

    private var mainGameContent: some View {
        GeometryReader { geometry in
            let layout = calculateResponsiveLayout(in: geometry)

            ZStack {
                // Tatami background filling entire window
                Image("tatami")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                // Simple Board View with explicit positioning
                SimpleBoardView(
                    player: player,
                    physicsIntegration: physicsIntegration,
                    boardStoneDiameter: uiStateVM.boardStoneDiameter,
                    gameCacheManager: app.gameCacheManager,
                    ogsClient: ogsClient,
                    boardFrame: layout.boardFrame,
                    ulBowlCenter: layout.ulBowlCenter,
                    lrBowlCenter: layout.lrBowlCenter,
                    bowlRadius: layout.bowlRadius
                )
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                // Handle window resizing
                uiStateVM.handleWindowResize(newSize)

                // Use async dispatch to avoid feedback loops
                let sizeChange = abs(newSize.width - oldSize.width) + abs(newSize.height - oldSize.height)
                if sizeChange > 5.0 {  // Higher threshold to avoid minor changes
                    print("🔍 Significant geometry change detected: \(sizeChange)")
                    // Defer physics update to break potential feedback loop
                    DispatchQueue.main.async {
                        let newLayout = calculateResponsiveLayout(in: geometry)
                        let (deferredBlackCaptured, deferredWhiteCaptured) = calculateCapturesAtMove(player.currentIndex)
                        if app.verboseLogging {
                            print("🔍 Deferred layout recalc: bowlRadius=\(newLayout.bowlRadius)")
                        }
                        updatePhysicsWithLayout(newLayout, deferredBlackCaptured, deferredWhiteCaptured)
                    }
                }
            }
        }
    }

    private var topButtonsOverlay: some View {
        VStack {
            HStack {
                // Settings button (upper left)
                Button {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        isPanelOpen.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .imageScale(.large)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)
                .padding(.top, 20)
                .opacity(uiStateVM.buttonsVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: uiStateVM.buttonsVisible ? 0.2 : 0.5), value: uiStateVM.buttonsVisible)

                Spacer()
            }
            Spacer()
        }
    }

    private var settingsPanelOverlay: some View {
        Group {
            if isPanelOpen {
                ZStack {
                    // Backdrop - visible overlay to catch clicks outside panel
                    Color.black.opacity(0.001) // Minimal but clickable background
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                isPanelOpen = false
                            }
                        }

                    HStack(spacing: 0) {
                        // Add some negative space on the left
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 10)
                            .allowsHitTesting(false)  // Let clicks pass through

                        // Settings panel with translucent background
                        SettingsPanelView(
                            isPanelOpen: $isPanelOpen,
                            activePhysicsModelRaw: $activePhysicsModelRaw,
                            physicsIntegration: physicsIntegration,
                            soundManager: soundManager,
                            m1_repel: $m1_repel,
                            m1_spacing: $m1_spacing,
                            m1_centerPullK: $m1_centerPullK,
                            m1_relaxIters: $m1_relaxIters,
                            m1_pressureRadiusXR: $m1_pressureRadiusXR,
                            m1_pressureKFactor: $m1_pressureKFactor,
                            m1_maxStepXR: $m1_maxStepXR,
                            m1_damping: $m1_damping,
                            m1_wallK: $m1_wallK,
                            m1_anim: $m1_anim,
                            m1_stoneStoneK: $m1_stoneStoneK,
                            m1_stoneLidK: $m1_stoneLidK,
                            autoNext: $autoNext,
                            randomNext: $randomNext,
                            autoStartOnLaunch: $autoStartOnLaunch,
                            loopGames: $loopGames,
                            uiMoveDelay: $uiMoveDelay,
                            player: player,
                            app: app,
                            onMoveChanged: { newIndex in
                                player.seek(to: newIndex)
                                updatePhysicsForMove(newIndex)
                            },
                            debugLayout: $debugLayout,
                            advancedExpanded: $advancedExpanded,
                            gameCacheManager: app.gameCacheManager,
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

                                print("🔍 ContentView: Updated filtered games to \(searchResults.count) games, search active: \(isSearchActive)")

                                // Always switch to first game in search results
                                if !searchResults.isEmpty {
                                    print("🔍 Switching to first game in search results")
                                    app.selection = searchResults.first
                                    player.reset()

                                    // Start autoplay if it was already enabled
                                    if autoNext {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            player.play()
                                            print("🔍 Started autoplay after search switch")
                                        }
                                    }
                                }
                            }
                        )
                        .frame(width: 320)
                        .frame(maxHeight: .infinity)
                        .allowsHitTesting(true)  // Ensure panel receives all events

                        Spacer()
                            .allowsHitTesting(false)  // Let clicks pass through to backdrop
                    }
                }
                .transition(.move(edge: .leading))
                .zIndex(10)
            }
        }
    }

    private var physicsOverlay: some View {
        Group {
            if showPhysicsDemo {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea()

                    PhysicsIntegrationDemo()
                        .frame(width: 800, height: 900)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .shadow(radius: 20)

                    VStack {
                        HStack {
                            Spacer()
                            Button("Close Demo") {
                                showPhysicsDemo = false
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                        Spacer()
                    }
                }
                .zIndex(20)
            }
        }
    }

    private var gameInfoOverlay: some View {
        VStack {
            HStack {
                Spacer()

                // Game info with fullscreen button overlay
                ZStack(alignment: .topTrailing) {
                    GameInfoOverlay(
                        ogsGame: app.ogsGame,
                        timeControl: app.timeControl,
                        player: player,
                        gameSelection: ogsClient.isConnected ? nil : app.selection,  // Hide local game metadata when OGS is connected
                        backgroundOpacity: 0.6  // 2D mode: matches settings panel opacity
                    )

                    // Fullscreen button overlaid on top-right of metadata
                    Button {
                        uiStateVM.toggleFullscreen()
                    } label: {
                        Image(systemName: uiStateVM.isWindowFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(uiStateVM.buttonsVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: uiStateVM.buttonsVisible ? 0.2 : 0.5), value: uiStateVM.buttonsVisible)
                }
                .padding(.trailing, 20)
                .padding(.top, 20)
            }

            Spacer()

            // OGS Game Control Buttons (only visible during OGS gameplay)
            if ogsClient.currentGameID != nil, ogsClient.gamePhase == .playing {
                HStack(spacing: 20) {
                    // Undo button
                    Button(action: {
                        if let gameID = ogsClient.currentGameID {
                            ogsClient.requestUndo(gameID: gameID)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Pass button
                    Button(action: {
                        if let gameID = ogsClient.currentGameID {
                            ogsClient.sendPass(gameID: gameID)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.end")
                            Text("Pass")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Resign button
                    Button(action: {
                        if let gameID = ogsClient.currentGameID {
                            // Show confirmation before resigning
                            resignConfirmation(gameID: gameID)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                            Text("Resign")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 10)
                .opacity(uiStateVM.buttonsVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: uiStateVM.buttonsVisible)
            }

            // Playback controls at bottom center (using same component as 3D view)
            PlaybackControls(
                player: player,
                isPlaying: $autoNext,
                onSeek: {
                    // Update physics when seeking in 2D view
                    updatePhysicsForMove(player.currentIndex)
                },
                onTogglePlayPause: {
                    autoNext.toggle()
                }
            )
        }
        .allowsHitTesting(true)
        .zIndex(15) // Above settings panel (10) to ensure button clicks work
    }

    // MARK: - Helper Functions

    private func resignConfirmation(gameID: Int) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Resign Game?"
        alert.informativeText = "Are you sure you want to resign this game? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Resign")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ogsClient.sendResign(gameID: gameID)
        }
        #endif
    }

    private func updateWindowTitle() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.title = windowTitle
                print("🏷️ Updated window title to: \(windowTitle)")
            }
        }
    }

    private func restoreSearchState() {
        // Restore search filter if one was persisted
        if isSearchActivePersisted && !lastSearchQuery.isEmpty {
            print("🔍 Restoring search state: '\(lastSearchQuery)'")
            performSearch(query: lastSearchQuery)
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
        print("🔍 Search restored: \(searchResults.count) games found for '\(query)'")
    }

    private func initializeApp() {
        print("🚀 INIT: initializeApp() called")
        // Sync legacy physics model to new system
        if physicsIntegration.activePhysicsModel != (legacyActivePhysicsModel - 1) {
            physicsIntegration.activePhysicsModel = max(0, min(5, legacyActivePhysicsModel - 1))
        }

        // Initialize PhysicsIntegration with game state
        if let gameWrapper = app.selection {
            physicsIntegration.initializeWithGame(player)
            print("🔧 DEBUG: Game loaded in physics integration with \(gameWrapper.game.moves.count) moves")
        } else {
            print("🔧 DEBUG: Skipping game load - game already loaded with \(player.moves.count) moves")
        }
        print("🎯 CURRENT MOVE INDEX: \(player.currentIndex)")
        print("🎯 TOTAL MOVES: \(player.moves.count)")
        print("🎯 BOARD STONES: \(player.board.grid.flatMap { $0 }.compactMap { $0 }.count)")

        // Restore search state if it was persisted
        restoreSearchState()

        // Start autoplay if enabled
        if autoNext {
            print("🎮 Auto-play enabled")
        }

        // Auto-start playing on launch if enabled, we have a game selected, and NOT in OGS mode
        let ogsMode = UserDefaults.standard.bool(forKey: "ogsMode")
        if autoStartOnLaunch && app.selection != nil && !ogsMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                autoNext = true
                player.play()
                print("🚀 Auto-started playback on launch")
            }
        } else if ogsMode {
            print("⏸️ Skipping auto-play - in OGS mode")
        }

        // Set initial window title
        updateWindowTitle()

        if app.verboseLogging {
            print("🚀 NEW MODULAR PHYSICS: ContentView initialized with resolved stone clustering")
            print("   - Black stones in UL bowl: \(physicsIntegration.blackStones.count)")
            print("   - White stones in LR bowl: \(physicsIntegration.whiteStones.count)")
        }
    }

    private func updatePhysicsForMove(_ moveIndex: Int) {
        // Calculate captures based on current move
        let (blackCapturedCount, whiteCapturedCount) = calculateCapturesAtMove(moveIndex)

        print("🎮 UpdatePhysics for move \(moveIndex): Black captured: \(blackCapturedCount), White captured: \(whiteCapturedCount)")

        // Update physics with new stone counts
        let gameSeed = UInt64(12345) // Simplified for now

        // Use actual bowl positioning from GameBoardView
        let ulCenter = actualUlCenter
        let lrCenter = actualLrCenter
        let bowlRadius = actualBowlRadius

        physicsIntegration.updateStonePositions(
            currentMove: moveIndex,
            blackStoneCount: blackCapturedCount,
            whiteStoneCount: whiteCapturedCount,
            bowlRadius: bowlRadius,
            gameSeed: gameSeed,
            ulCenter: ulCenter,
            lrCenter: lrCenter
        )
    }

    private func updatePhysicsWithLayout(_ layout: ResponsiveLayout, _ blackCaptured: Int, _ whiteCaptured: Int) {
        // Debounce updates to avoid rapid-fire calls during window resizing
        physicsUpdateTimer?.invalidate()
        let moveIndex = player.currentIndex
        pendingPhysicsUpdate = moveIndex

        physicsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            guard let pendingMove = pendingPhysicsUpdate else { return }
            if pendingMove == player.currentIndex { // Still on the same move
                print("🔄 Executing debounced physics update for move \(pendingMove)")
                updatePhysicsForMove(pendingMove)
            }
            pendingPhysicsUpdate = nil
        }
    }

    private func calculateCapturesAtMove(_ moveIndex: Int) -> (black: Int, white: Int) {
        // Check cache first
        if let cached = tallyAtMove[moveIndex] {
            return (cached.b, cached.w)
        }

        // Calculate total captures from start of game to this point
        var totalBlackCaptured = 0
        var totalWhiteCaptured = 0

        guard let game = app.selection?.game else {
            tallyAtMove[moveIndex] = (w: 0, b: 0)
            return (0, 0)
        }

        // Create a temporary player to simulate the game up to moveIndex
        let tempPlayer = SGFPlayer()
        tempPlayer.load(game: game)

        // Play through moves one by one and count captures
        for move in 0..<moveIndex {
            if move >= tempPlayer.moves.count { break }

            let beforeBoard = tempPlayer.board
            tempPlayer.stepForward() // This applies the move and handles captures
            let afterBoard = tempPlayer.board

            // Count stones that disappeared (were captured)
            for row in 0..<beforeBoard.size {
                for col in 0..<beforeBoard.size {
                    if let beforeStone = beforeBoard.grid[row][col],
                       afterBoard.grid[row][col] == nil {
                        // Stone was captured
                        switch beforeStone {
                        case .black:
                            totalBlackCaptured += 1
                        case .white:
                            totalWhiteCaptured += 1
                        }
                    }
                }
            }
        }

        // Cache result
        tallyAtMove[moveIndex] = (w: totalWhiteCaptured, b: totalBlackCaptured)

        return (totalBlackCaptured, totalWhiteCaptured)
    }

    private func clearCacheAndRefresh() {
        tallyAtMove = [0:(0,0)]
        gridAtMove.removeAll()
        layoutAtMove.removeAll()
        bowls.refresh(using: player, gameFingerprint: currentFingerprint())
    }

    private func currentFingerprint() -> String {
        return "\(12345)_\(player.currentIndex)_\(physicsIntegration.activePhysicsModel)"
    }


    private func resetButtonFadeTimer() {
        // Cancel existing timer
        fadeTimer?.invalidate()

        // Show buttons if hidden
        withAnimation(.easeOut(duration: 0.2)) {
            uiStateVM.showButtons()
        }

        // Set timer to hide after 1.5 seconds (matches 3D view)
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                uiStateVM.hideButtons()
            }
        }
    }

    // MARK: - Keyboard Controls

    private func handleKeyPress(_ keyPress: KeyPress) {
        switch keyPress.key {
        case .leftArrow:
            // Arrow keys stop autoplay
            autoNext = false
            if keyPress.modifiers.contains(.shift) {
                // Shift + Left: Jump back 10 moves
                let newIndex = max(0, player.currentIndex - 10)
                player.seek(to: newIndex)
                updatePhysicsForMove(newIndex)
                print("🎮 Keyboard: Jump back 10 moves to \(newIndex)")
            } else {
                // Left: Step back 1 move
                let newIndex = max(0, player.currentIndex - 1)
                player.seek(to: newIndex)
                updatePhysicsForMove(newIndex)
                print("🎮 Keyboard: Step back 1 move to \(newIndex)")
            }
        case .rightArrow:
            // Arrow keys stop autoplay
            autoNext = false
            if keyPress.modifiers.contains(.shift) {
                // Shift + Right: Jump forward 10 moves
                let newIndex = min(player.moves.count, player.currentIndex + 10)
                player.seek(to: newIndex)
                updatePhysicsForMove(newIndex)
                print("🎮 Keyboard: Jump forward 10 moves to \(newIndex)")
            } else {
                // Right: Step forward 1 move
                let newIndex = min(player.moves.count, player.currentIndex + 1)
                print("🎮 Keyboard: Step forward 1 move to \(newIndex) (current: \(player.currentIndex), total: \(player.moves.count))")
                player.seek(to: newIndex)
                updatePhysicsForMove(newIndex)
                print("🎮 Keyboard: Step forward completed, new index: \(player.currentIndex)")
            }
        case .space:
            // Space: Toggle auto-play
            autoNext.toggle()
            print("🎮 Keyboard: Toggled auto-play to \(autoNext)")
        case .escape:
            // Escape: Exit fullscreen mode
            if let window = NSApplication.shared.windows.first, window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
                print("🎮 Keyboard: Exited fullscreen mode")
            }
        default:
            return
        }
    }


}

// MARK: - Responsive Layout Management

struct ResponsiveLayout {
    let boardFrame: CGRect
    let ulBowlCenter: CGPoint
    let lrBowlCenter: CGPoint
    let bowlRadius: CGFloat
    let metadataY: CGFloat
}

extension ContentView {
    func calculateResponsiveLayout(in geometry: GeometryProxy) -> ResponsiveLayout {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height

        // Calculate board dimensions with proper aspect ratio (1.07:1 for Go)
        let boardAspectRatio: CGFloat = 1.07

        // First calculate maximum board size that fits the aspect ratio
        let _ = screenWidth * 0.9  // maxWidthBasedSize not used
        let _ = screenHeight * 0.75 // maxHeightBasedSize not used
        // Calculate spacing requirements using a reference cell size first
        let referenceCellHeight = min(screenWidth, screenHeight) * 0.8 / 19 / boardAspectRatio
        let topSpaceRequired = app.gameCacheManager.topSpaceCellUnits * referenceCellHeight
        let bottomSpaceRequired = app.gameCacheManager.bottomSpaceCellUnits * referenceCellHeight

        // Calculate available space for the board after reserving spacing
        let availableVerticalSpaceForBoard = screenHeight - topSpaceRequired - bottomSpaceRequired
        let availableHorizontalSpaceForBoard = screenWidth

        // Determine board size based on available space (considering both constraints)
        let maxBoardWidthFromHeight = availableVerticalSpaceForBoard * boardAspectRatio
        let _ = availableHorizontalSpaceForBoard / boardAspectRatio // maxBoardHeightFromWidth not used

        let boardWidth: CGFloat
        let boardHeight: CGFloat

        if maxBoardWidthFromHeight <= availableHorizontalSpaceForBoard {
            // Constrained by vertical space (after spacing)
            boardHeight = availableVerticalSpaceForBoard
            boardWidth = boardHeight * boardAspectRatio
        } else {
            // Constrained by horizontal space
            boardWidth = availableHorizontalSpaceForBoard
            boardHeight = boardWidth / boardAspectRatio
        }

        // Calculate final spacing using actual board cell height
        let actualCellHeight = boardHeight / 19
        let topSpace = app.gameCacheManager.topSpaceCellUnits * actualCellHeight
        let _ = app.gameCacheManager.bottomSpaceCellUnits * actualCellHeight // bottomSpace not used

        let boardX = (screenWidth - boardWidth) / 2
        let boardY = topSpace

        let boardFrame = CGRect(x: boardX, y: boardY, width: boardWidth, height: boardHeight)

        // Calculate bowl positions relative to board - bowls should be 1/3 the long side
        // Board is 19x19 cells, and cell HEIGHT > cell WIDTH, so use height for proper scaling
        let bowlDiameterInCells: CGFloat = (19.0 / 3.0) * 1.37  // ~6.33 cells * 1.37 = ~8.67 cells
        let bowlRadius = (bowlDiameterInCells * actualCellHeight) / 2
        if app.verboseLogging {
            print("🥣 BOWL DEBUG: cellHeight=\(actualCellHeight), diameterInCells=\(bowlDiameterInCells), bowlRadius=\(bowlRadius), bowlDiameter=\(bowlRadius*2)")
        }
        let bowlOffset = bowlRadius * 1.1 // Tighter spacing

        let ulBowlCenter = CGPoint(
            x: boardFrame.minX - bowlOffset,
            y: boardFrame.minY + bowlOffset
        )

        let lrBowlCenter = CGPoint(
            x: boardFrame.maxX + bowlOffset,
            y: boardFrame.maxY - bowlOffset + bowlRadius * 1.25
        )

        // Position metadata bar center midway between board bottom and window bottom
        let actualBottomSpace = screenHeight - boardFrame.maxY
        let metadataY = boardFrame.maxY + actualBottomSpace / 2

        // Debug: Print layout values (only if verbose logging enabled)
        if app.verboseLogging {
            print("🎯 METADATA POSITIONING:")
            print("   screenHeight: \(screenHeight)")
            print("   boardFrame.maxY: \(boardFrame.maxY)")
            print("   actualBottomSpace: \(actualBottomSpace)")
            print("   metadataY: \(metadataY)")
            print("   boardBottom to metadataY: \(metadataY - boardFrame.maxY)")
            print("   metadataY to windowBottom: \(screenHeight - metadataY)")
            print("   Expected center Y: \(boardFrame.maxY + actualBottomSpace / 2)")
        }

        return ResponsiveLayout(
            boardFrame: boardFrame,
            ulBowlCenter: ulBowlCenter,
            lrBowlCenter: lrBowlCenter,
            bowlRadius: bowlRadius,
            metadataY: metadataY
        )
    }
}

// MARK: - Button Styles

struct GlassTopButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                .ultraThinMaterial.opacity(configuration.isPressed ? 0.8 : 0.6),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        .linearGradient(
                            colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

