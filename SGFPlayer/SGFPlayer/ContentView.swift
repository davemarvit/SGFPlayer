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

// MARK: - Main ContentView
struct ContentView: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var player = SGFPlayer()
    @StateObject private var bowls = PlayerCapturesAdapter()
    
    // NEW MODULAR PHYSICS ARCHITECTURE
    @StateObject private var physicsIntegration = PhysicsIntegration()
    
    // UI State
    @State private var isPanelOpen: Bool = false
    @State private var showFullscreen: Bool = false
    @State private var showPhysicsDemo: Bool = false
    @State private var buttonsVisible: Bool = true
    @State private var fadeTimer: Timer? = nil
    
    // Settings
    @AppStorage("randomOnStart") private var randomOnStart: Bool = false
    @AppStorage("autoNext") private var autoNext: Bool = false
    @AppStorage("randomNext") private var randomNext: Bool = false
    @State private var boardStoneDiameter: CGFloat = 20.0
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
    
    var body: some View {
        ZStack {
            // Main content
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.black.ignoresSafeArea()

                    // Game Board View
                    let (currentBlackCaptured, currentWhiteCaptured) = calculateCapturesAtMove(player.currentIndex)
                    GameBoardView(
                        player: player,
                        physicsIntegration: physicsIntegration,
                        boardStoneDiameter: boardStoneDiameter,
                        currentBowlRadius: currentBowlRadius,
                        blackCapturedCount: currentBlackCaptured,
                        whiteCapturedCount: currentWhiteCaptured,
                        lidShadowOpacity: lidShadowOpacity,
                        lidShadowRadius: lidShadowRadius,
                        lidShadowDX: lidShadowDX,
                        lidShadowDY: lidShadowDY,
                        stoneShadowOpacity: stoneShadowOpacity,
                        stoneShadowRadius: stoneShadowRadius,
                        stoneShadowDX: stoneShadowDX,
                        stoneShadowDY: stoneShadowDY,
                        gameCacheManager: app.gameCacheManager,
                        autoNext: $autoNext,
                        onBowlPositionsCalculated: { ulCenter, lrCenter, bowlRadius in
                            actualUlCenter = ulCenter
                            actualLrCenter = lrCenter
                            actualBowlRadius = bowlRadius
                        }
                    )
                }
            }
            
            // Top overlay with settings on left, fullscreen on right
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
                    .buttonStyle(GlassTopButton())
                    .padding(.leading, 20)
                    .opacity(buttonsVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: buttonsVisible ? 0.2 : 0.5), value: buttonsVisible)

                    Spacer()

                    // Fullscreen button (upper right)
                    Button {
                        toggleFullscreen()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .imageScale(.medium)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(GlassTopButton())
                    .padding(.trailing, 20)
                    .opacity(buttonsVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: buttonsVisible ? 0.2 : 0.5), value: buttonsVisible)
                }
                .padding(.top, 20)

                Spacer() // Push buttons to top, fill rest of space
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                // Invisible layer to catch mouse movement
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(_):
                            resetButtonFadeTimer()
                        case .ended:
                            break
                        }
                    }
            )
            .onAppear {
                resetButtonFadeTimer()
            }
            
            // Settings panel overlay
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

                        // Settings panel with translucent background
                        SettingsPanelView(
                            isPanelOpen: $isPanelOpen,
                            activePhysicsModelRaw: $activePhysicsModelRaw,
                            physicsIntegration: physicsIntegration,
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
                            uiMoveDelay: $uiMoveDelay,
                            player: player,
                            app: app,
                            onMoveChanged: { newIndex in
                                player.seek(to: newIndex)
                                updatePhysicsForMove(newIndex)
                            },
                            debugLayout: $debugLayout,
                            advancedExpanded: $advancedExpanded,
                            gameCacheManager: app.gameCacheManager
                        )
                        .frame(width: 320)
                        .frame(maxHeight: .infinity)
                        .background(
                            .thinMaterial.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 0)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 25, x: 10, y: 0)

                        Spacer()
                    }
                }
                .transition(.move(edge: .leading))
                .zIndex(10)
            }
            
            // Physics Demo overlay
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
        .onAppear {
            initializeApp()
        }
        .onChange(of: player.currentIndex) { _, newIndex in
            debouncedPhysicsUpdate(newIndex)
        }
        .onChange(of: physicsIntegration.activePhysicsModel) { _, _ in
            clearCacheAndRefresh()
        }
        .onChange(of: app.selection) { _, newSelection in
            if let gameWrapper = newSelection {
                // Clear all cached data BEFORE loading new game to prevent stale capture counts
                tallyAtMove.removeAll()
                physicsIntegration.reset()

                // Now load the new game
                player.load(game: gameWrapper.game)
                // Load game into cache manager for jitter system
                app.gameCacheManager.loadGame(gameWrapper.game, fingerprint: gameWrapper.fingerprint)

                print("🎮 Loaded new game: \(gameWrapper.game.moves.count) moves, board size \(gameWrapper.game.boardSize)")
                print("🎯 Game cache updated with fingerprint: \(gameWrapper.fingerprint)")
                print("🧹 Physics integration and capture cache cleared before new game")
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
            if randomOnStart, app.selection == nil { pickRandomGame() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameDidFinish)) { _ in
            if randomNext {
                // Wait 5 seconds, then pick the next random game and restart if auto-play is on
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    pickRandomGame()
                    // If auto-play is enabled, automatically start the new game
                    if autoNext {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            player.play()
                        }
                    }
                }
            }
        }
        .focusable()
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
            return .handled
        }
    }
    
    // MARK: - Keyboard Controls
    
    private func handleKeyPress(_ keyPress: KeyPress) {
        switch keyPress.key {
        case .leftArrow:
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
            if keyPress.modifiers.contains(.shift) {
                // Shift + Right: Jump forward 10 moves
                let newIndex = min(player.moves.count, player.currentIndex + 10)
                player.seek(to: newIndex)
                updatePhysicsForMove(newIndex)
                print("🎮 Keyboard: Jump forward 10 moves to \(newIndex)")
            } else {
                // Right: Step forward 1 move
                let newIndex = min(player.moves.count, player.currentIndex + 1)
                player.seek(to: newIndex)
                updatePhysicsForMove(newIndex)
                print("🎮 Keyboard: Step forward 1 move to \(newIndex)")
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
    
    // MARK: - Helper Functions
    
    private func initializeApp() {
        // Sync legacy physics model to new system
        if physicsIntegration.activePhysicsModel != (legacyActivePhysicsModel - 1) {
            physicsIntegration.activePhysicsModel = max(0, min(5, legacyActivePhysicsModel - 1))
        }
        
        // DEBUG STONES - Comment out to remove test stones in lids
        // Initialize physics with some test stones to show it's working
        // Use actual bowl positions (will be updated when GameBoardView loads)
        /*
        physicsIntegration.updateStonePositions(
            currentMove: 10,
            blackStoneCount: 12,  // 12 black stones captured by white (more visible)
            whiteStoneCount: 8,   // 8 white stones captured by black (more visible)
            bowlRadius: actualBowlRadius,
            gameSeed: 12345,
            ulCenter: actualUlCenter,
            lrCenter: actualLrCenter
        )

        // Force an update when bowl positions are calculated
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            physicsIntegration.updateStonePositions(
                currentMove: 10,
                blackStoneCount: 12,
                whiteStoneCount: 8,
                bowlRadius: actualBowlRadius,
                gameSeed: 12345,
                ulCenter: actualUlCenter,
                lrCenter: actualLrCenter
            )
            print("🎯 FORCED UPDATE: Bowl positions UL(\(actualUlCenter.x), \(actualUlCenter.y)) LR(\(actualLrCenter.x), \(actualUlCenter.y))")
        }
        */
        
        // Load game if available
        if let game = app.selection?.game {
            player.load(game: game)
        } else {
            // Create some sample moves to demonstrate functionality
            createSampleGame()
            print("📋 Created sample game with \(player.moves.count) moves")
        }
        
        // Start autoplay if enabled
        if autoNext {
            print("🎮 Auto-play enabled")
        }
        
        print("🚀 NEW MODULAR PHYSICS: ContentView initialized with resolved stone clustering")
        print("   - Black stones in UL bowl: \(physicsIntegration.blackStones.count)")  
        print("   - White stones in LR bowl: \(physicsIntegration.whiteStones.count)")
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
        
        physicsIntegration.updateStonePositions(
            currentMove: moveIndex,
            blackStoneCount: blackCapturedCount,
            whiteStoneCount: whiteCapturedCount,
            bowlRadius: actualBowlRadius,
            gameSeed: gameSeed,
            ulCenter: ulCenter,
            lrCenter: lrCenter
        )
        
        print("🔄 PHYSICS UPDATE: Move \(moveIndex), Black: \(blackCapturedCount), White: \(whiteCapturedCount)")
        print("🎯 Bowl positions: UL(\(ulCenter.x), \(ulCenter.y)) LR(\(lrCenter.x), \(lrCenter.y)) radius:\(actualBowlRadius)")
        print("🎲 Stone counts: Black physics=\(physicsIntegration.blackStones.count), White physics=\(physicsIntegration.whiteStones.count)")
    }
    
    private func debouncedPhysicsUpdate(_ moveIndex: Int) {
        // Cancel any pending timer
        physicsUpdateTimer?.invalidate()
        
        // Store the pending update
        pendingPhysicsUpdate = moveIndex
        
        print("🔄 Debouncing physics update for move \(moveIndex)")
        
        // Set a timer for 100ms to batch updates
        physicsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            if let pendingMove = pendingPhysicsUpdate {
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
    
    private func pickRandomGame() {
        guard !app.games.isEmpty else {
            print("🎲 No games available for random selection")
            return
        }

        let randomIndex = Int.random(in: 0..<app.games.count)
        app.selection = app.games[randomIndex]

        print("🎲 Random game selected: \(app.games[randomIndex].url.lastPathComponent)")
    }
    
    private func toggleFullscreen() {
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
    }

    // Button fade timer management
    private func resetButtonFadeTimer() {
        fadeTimer?.invalidate()
        buttonsVisible = true

        fadeTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                buttonsVisible = false
            }
        }
    }
    
    private func createSampleGame() {
        // Create some sample moves to test the interface
        print("🎮 Creating sample game for testing...")
        
        // Load the test SGF file if available
        let testFile = "/Users/Dave/Go/SGFPlayer Code/SGFPlayer/SGFTests/test01.sgf"
        if FileManager.default.fileExists(atPath: testFile) {
            do {
                let sgfContent = try String(contentsOfFile: testFile, encoding: .utf8)
                print("📁 Loading test SGF file: \(testFile)")
                print("📋 SGF Content preview: \(String(sgfContent.prefix(200)))...")
                
                // For now, just note that we have the SGF content
                // Actual parsing would require proper SGF implementation
                print("📋 SGF content loaded - parsing would go here")
                
            } catch {
                print("❌ Failed to load test SGF: \(error)")
            }
        }
        
        // Create a simple demo setup
        print("📋 Demo game created - ready for testing")
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension CGSize {
    var side: CGFloat {
        min(width, height)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppModel())
            .frame(width: 1000, height: 700)
    }
}