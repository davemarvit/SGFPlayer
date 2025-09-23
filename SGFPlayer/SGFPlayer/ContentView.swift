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
    @StateObject private var player = SGFPlayer()
    @StateObject private var bowls = PlayerCapturesAdapter()

    // NEW MODULAR PHYSICS ARCHITECTURE
    @StateObject private var physicsIntegration = PhysicsIntegration()

    // NEW: ViewModels for cleaner architecture (Session 2)
    @StateObject private var uiStateVM = UIStateViewModel()

    // NEW: Services for modular business logic
    @StateObject private var gameAnalysisService = GameAnalysisService()
    @StateObject private var layoutService = LayoutService()
    @StateObject private var settingsPanelService = SettingsPanelService()
    
    // UI State (transitioning to uiStateVM)
    // isPanelOpen and showPhysicsDemo now managed by settingsPanelService
    @State private var fadeTimer: Timer? = nil
    
    // Initialization tracking to prevent repeated app initialization
    @State private var isInitialized: Bool = false
    // Note: boardStoneDiameter is now managed by UIStateViewModel for responsive sizing
    // Settings now managed by settingsPanelService
    
    // Shadow parameters, physics parameters, and UI move delay now managed by settingsPanelService
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
    // activePhysicsModelRaw now managed by settingsPanelService.activePhysicsModel
    
    var body: some View {
        ZStack {
            // Main content with single-level layout management
            GeometryReader { geometry in
                let layout = layoutService.calculateResponsiveLayout(
                    in: geometry,
                    topSpaceCellUnits: app.gameCacheManager.topSpaceCellUnits,
                    bottomSpaceCellUnits: app.gameCacheManager.bottomSpaceCellUnits
                )

                ZStack {
                    // Tatami background filling entire window
                    Image("tatami")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()

                    // Simple Board View with explicit positioning
                    let (currentBlackCaptured, currentWhiteCaptured) = getCurrentCaptures()
                    SimpleBoardView(
                        player: player,
                        physicsIntegration: physicsIntegration,  // Only for bowls, not board stones
                        boardStoneDiameter: uiStateVM.boardStoneDiameter,
                        gameCacheManager: app.gameCacheManager,
                        boardFrame: layout.boardFrame,
                        ulBowlCenter: layout.ulBowlCenter,
                        lrBowlCenter: layout.lrBowlCenter,
                        bowlRadius: layout.bowlRadius
                    )
                    .onAppear {
                        // Update physics with correct bowl positions from responsive layout
                        updatePhysicsWithLayout(layout, currentBlackCaptured, currentWhiteCaptured)
                        // Update UI state for responsive stone sizing
                        uiStateVM.handleWindowResize(geometry.size)
                    }
                    .onChange(of: layout.bowlRadius) { oldRadius, newRadius in
                        // Update physics when layout changes
                        print("🔍 onChange(bowlRadius): \(oldRadius) → \(newRadius)")
                        updatePhysicsWithLayout(layout, currentBlackCaptured, currentWhiteCaptured)
                    }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        // Update UI state when window size changes
                        print("🔍 onChange(geometry): \(oldSize) → \(newSize)")
                        uiStateVM.handleWindowResize(newSize)

                        // Use async dispatch to avoid feedback loops
                        let sizeChange = abs(newSize.width - oldSize.width) + abs(newSize.height - oldSize.height)
                        if sizeChange > 5.0 {  // Higher threshold to avoid minor changes
                            print("🔍 Significant geometry change detected: \(sizeChange)")
                            // Defer physics update to break potential feedback loop
                            DispatchQueue.main.async {
                                let newLayout = layoutService.calculateResponsiveLayout(
                                    in: geometry,
                                    topSpaceCellUnits: app.gameCacheManager.topSpaceCellUnits,
                                    bottomSpaceCellUnits: app.gameCacheManager.bottomSpaceCellUnits
                                )
                                print("🔍 Deferred layout recalc: bowlRadius=\(newLayout.bowlRadius)")
                                updatePhysicsWithLayout(newLayout, currentBlackCaptured, currentWhiteCaptured)
                            }
                        }
                    }

                }
            }
            
            // Top overlay with settings on left, fullscreen on right
            VStack {
                HStack {
                    // Settings button (upper left)
                    Button {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            settingsPanelService.togglePanel()
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(GlassTopButton())
                    .padding(.leading, 20)
                    .opacity(uiStateVM.buttonsVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: uiStateVM.buttonsVisible ? 0.2 : 0.5), value: uiStateVM.buttonsVisible)

                    Spacer()

                    // Fullscreen button (upper right)
                    Button {
                        uiStateVM.toggleFullscreen()
                    } label: {
                        Image(systemName: uiStateVM.isWindowFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .imageScale(.medium)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(GlassTopButton())
                    .padding(.trailing, 20)
                    .opacity(uiStateVM.buttonsVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: uiStateVM.buttonsVisible ? 0.2 : 0.5), value: uiStateVM.buttonsVisible)
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
            if settingsPanelService.isPanelOpen {
                ZStack {
                    // Backdrop - visible overlay to catch clicks outside panel
                    Color.black.opacity(0.001) // Minimal but clickable background
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                settingsPanelService.closePanel()
                            }
                        }

                    HStack(spacing: 0) {
                        // Add some negative space on the left
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 10)

                        // Settings panel with translucent background
                        SettingsPanelView(
                            settingsService: settingsPanelService,
                            physicsIntegration: physicsIntegration,
                            player: player,
                            app: app,
                            onMoveChanged: { newIndex in
                                player.seek(to: newIndex)
                                updatePhysicsForMove(newIndex)
                            },
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
            if settingsPanelService.showPhysicsDemo {
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
                                settingsPanelService.showPhysicsDemo = false
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                        Spacer()
                    }
                }
                .zIndex(20)
            }

            // GameInfoBar - positioned using responsive layout
            GeometryReader { geometry in
                let layout = layoutService.calculateResponsiveLayout(
                    in: geometry,
                    topSpaceCellUnits: app.gameCacheManager.topSpaceCellUnits,
                    bottomSpaceCellUnits: app.gameCacheManager.bottomSpaceCellUnits
                )
                let (currentBlackCaptured, currentWhiteCaptured) = getCurrentCaptures()
                GameInfoBar(
                    gameCacheManager: app.gameCacheManager,
                    blackCapturedCount: currentBlackCaptured,
                    whiteCapturedCount: currentWhiteCaptured,
                    player: player,
                    autoNext: $settingsPanelService.autoNext
                )
                .position(
                    x: geometry.size.width / 2,
                    y: layout.boardFrame.maxY + (geometry.size.height - layout.boardFrame.maxY) / 2 + (geometry.size.height - layout.boardFrame.maxY) * 0.15
                )
            }
            .allowsHitTesting(true)
            .zIndex(15) // Above settings panel (10) to ensure button clicks work
        }
        .onAppear {
            if !isInitialized {
                isInitialized = true
                initializeApp()
            } else {
                print("🔧 DEBUG: Skipping initializeApp() - already initialized")
            }
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
                gameAnalysisService.clearCache()
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
        .onChange(of: settingsPanelService.autoNext) { _, isAutoPlay in
            if isAutoPlay {
                player.play()
                print("🎮 Auto-play started")
            } else {
                player.pause()
                print("🎮 Auto-play paused")
            }
        }
        .onChange(of: settingsPanelService.uiMoveDelay) { _, newDelay in
            player.setPlayInterval(newDelay)
            print("🎮 Play interval updated to \(newDelay)s")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if settingsPanelService.randomOnStart, app.selection == nil { pickRandomGame() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameDidFinish)) { _ in
            if settingsPanelService.randomNext {
                // Wait 5 seconds, then pick the next random game and restart if auto-play is on
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    pickRandomGame()
                    // If auto-play is enabled, automatically start the new game
                    if settingsPanelService.autoNext {
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
            // Arrow keys stop autoplay
            settingsPanelService.autoNext = false
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
            settingsPanelService.autoNext = false
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
            settingsPanelService.autoNext.toggle()
            print("🎮 Keyboard: Toggled auto-play to \(settingsPanelService.autoNext)")
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
        print("🚀 INIT: initializeApp() called")
        // Sync physics model from settings service to integration system
        if physicsIntegration.activePhysicsModel != (settingsPanelService.activePhysicsModel - 1) {
            physicsIntegration.activePhysicsModel = max(0, min(5, settingsPanelService.activePhysicsModel - 1))
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
        
        // Load game if available, otherwise load test game
        if let game = app.selection?.game {
            player.load(game: game)
            print("📋 Loaded existing game selection with \(game.moves.count) moves")
        } else if player.moves.isEmpty {
            print("🔧 DEBUG: Loading test game since no game is selected")
            createSampleGame()
            print("📋 Test game loaded with \(player.moves.count) moves")
        } else {
            print("🔧 DEBUG: Skipping game load - game already loaded with \(player.moves.count) moves")
        }
        print("🎯 CURRENT MOVE INDEX: \(player.currentIndex)")
        print("🎯 TOTAL MOVES: \(player.moves.count)")
        print("🎯 BOARD STONES: \(player.board.grid.flatMap { $0 }.compactMap { $0 }.count)")
        
        // Start autoplay if enabled
        if settingsPanelService.autoNext {
            print("🎮 Auto-play enabled")
        }
        
        print("🚀 NEW MODULAR PHYSICS: ContentView initialized with resolved stone clustering")
        print("   - Black stones in UL bowl: \(physicsIntegration.blackStones.count)")  
        print("   - White stones in LR bowl: \(physicsIntegration.whiteStones.count)")
    }
    
    private func updatePhysicsForMove(_ moveIndex: Int) {
        // Calculate captures based on current move
        let (blackCapturedCount, whiteCapturedCount) = getCurrentCaptures(for: moveIndex)
        
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
    
    
    // MARK: - Capture Calculation (using GameAnalysisService)

    private func getCurrentCaptures() -> (black: Int, white: Int) {
        return getCurrentCaptures(for: player.currentIndex)
    }

    private func getCurrentCaptures(for moveIndex: Int) -> (black: Int, white: Int) {
        guard let game = app.selection?.game else {
            return (0, 0)
        }
        return gameAnalysisService.calculateCapturesAtMove(moveIndex, for: game)
    }
    
    private func clearCacheAndRefresh() {
        tallyAtMove = [0:(0,0)]
        gridAtMove.removeAll()
        layoutAtMove.removeAll()
        gameAnalysisService.clearCache()
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

    // Update physics with responsive layout positions
    private func updatePhysicsWithLayout(_ layout: ResponsiveLayout, _ blackCaptured: Int, _ whiteCaptured: Int) {
        // CRITICAL FIX: Update actualBowlRadius to match the real calculated radius
        actualBowlRadius = layout.bowlRadius
        actualUlCenter = layout.ulBowlCenter
        actualLrCenter = layout.lrBowlCenter

        let gameSeed = UInt64(12345) // Simplified for now

        physicsIntegration.updateStonePositions(
            currentMove: player.currentIndex,
            blackStoneCount: blackCaptured,
            whiteStoneCount: whiteCaptured,
            bowlRadius: layout.bowlRadius,
            gameSeed: gameSeed,
            ulCenter: layout.ulBowlCenter,
            lrCenter: layout.lrBowlCenter
        )

        print("🔄 RESPONSIVE PHYSICS UPDATE: Move \(player.currentIndex), Black: \(blackCaptured), White: \(whiteCaptured)")
        print("🎯 Layout Bowl positions: UL(\(layout.ulBowlCenter.x), \(layout.ulBowlCenter.y)) LR(\(layout.lrBowlCenter.x), \(layout.lrBowlCenter.y)) radius:\(layout.bowlRadius)")
        print("🎲 Stone counts: Black physics=\(physicsIntegration.blackStones.count), White physics=\(physicsIntegration.whiteStones.count)")
        print("🔍 RADIUS FIX: Updated actualBowlRadius from 100.0 to \(layout.bowlRadius)")
    }

    // Legacy function - now delegated to ViewModel
    private func toggleFullscreen() {
        uiStateVM.toggleFullscreen()
    }

    // Button fade timer management - transitioning to ViewModel
    private func resetButtonFadeTimer() {
        fadeTimer?.invalidate()
        uiStateVM.showButtons()

        fadeTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                uiStateVM.hideButtons()
            }
        }
    }
    
    private func createSampleGame() {
        // Create some sample moves to test the interface
        print("🎮 Creating sample game for testing...")

        // Use embedded SGF content to avoid sandboxing issues
        let sgfContent = """
(;GM[1]FF[4]CA[UTF-8]AP[Claude Code Test]ST[2]RU[Japanese]SZ[19]KM[6.50]PW[White Player]PB[Black Player]WR[1d]BR[1d]DT[2024-09-17]RE[B+0.50]
;B[pd];W[dd];B[pq];W[dp];B[fq];W[cn];B[jp];W[qf];B[nc];W[rd];B[qc];W[qi];B[qk];W[oi];B[ok];W[mi];B[mk];W[ki];B[ik];W[ii];B[gk];W[gi];B[ek];W[dh];B[dk];W[ck];B[cl];W[bk];B[bl];W[ak];B[al];W[bj];B[cj];W[aj];B[ci];W[bi];B[ch];W[bg];B[cg];W[bf];B[cf];W[be];B[ce];W[bd];B[cd];W[cc];B[bc];W[ac];B[bb];W[ab];B[cb];W[db];B[ca];W[dc];B[da];W[ea];B[ba];W[eb];B[fb];W[fc];B[gb];W[gc];B[hb];W[hc];B[ib];W[ic];B[jb];W[jc];B[kb];W[kc];B[lb];W[lc];B[mb];W[mc];B[nb];W[oc];B[ob];W[pc];B[qb];W[pb];B[pa];W[oa];B[qa];W[na];B[ma];W[od];B[ne];W[oe];B[nf];W[of];B[ng];W[og];B[nh];W[oh];B[ni];W[nj];B[mj];W[oj];B[pk];W[pj];B[qj];W[pi];B[ri];W[rh];B[si];W[sh];B[rj];W[qh];B[ql];W[rm];B[rl];W[sm];B[sl];W[pm];B[pl];W[om];B[ol];W[nm];B[nl];W[mm];B[ml];W[lm];B[ll];W[km];B[kl];W[jm];B[jl];W[im];B[il];W[hm];B[hl];W[gm];B[gl];W[fm];B[fl];W[em];B[el];W[dm];B[dl];W[cm];B[bm];W[bn];B[an];W[ao];B[am];W[bp];B[cq];W[cp];B[dq];W[ep];B[eq];W[fp];B[gp];W[go];B[hp];W[ho];B[io];W[in];B[jo];W[jn];B[ko];W[ln];B[lo];W[mo];B[mp];W[no];B[np];W[op];B[oq];W[pp];B[qp];W[po];B[qo];W[pn];B[qn];W[qm];B[rn];W[sn];B[so];W[ro];B[sp];W[rp];B[rq];W[sq];B[sr];W[sp];B[tp];W[sq];B[tr];W[rr];B[qr];W[rs];B[qs];W[ss];B[ts];W[sr];B[tq];W[pr];B[ps];W[or];B[os];W[nr];B[ns];W[mr];B[ms];W[lr];B[ls];W[kr];B[ks];W[jr];B[js];W[ir];B[is];W[hr];B[hs];W[gr];B[gs];W[fr];B[fs];W[er];B[es];W[dr];B[ds];W[cr];B[cs];W[br];B[bs];W[ar];B[as];W[aq];B[bq];W[ap];B[br];W[as];B[ar])
"""

        print("🔍 Using embedded SGF content to avoid sandboxing issues")
        do {
            print("📋 SGF Content preview: \(String(sgfContent.prefix(200)))...")

            // Parse and load the SGF game
            let tree = try SGFParser.parse(text: sgfContent)
            let game = SGFGame.from(tree: tree)
            player.load(game: game)

            // Advance to move 20 to show some stones on the board
            player.seek(to: 20)

            print("📋 SGF game loaded with \(game.moves.count) moves, advanced to move 20")
            print("🎯 Board should now show stones at move \(player.currentIndex)")
            print("🎯 Current board grid has \(player.board.grid.flatMap { $0 }.compactMap { $0 }.count) stones")

        } catch {
            print("❌ Failed to parse embedded SGF: \(error)")
            print("❌ Error details: \(String(describing: error))")
        }
        
        // Create a simple demo setup
        print("📋 Demo game created - ready for testing")
    }

}

// MARK: - Responsive Layout Management

// MARK: - Layout calculations now handled by LayoutService

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