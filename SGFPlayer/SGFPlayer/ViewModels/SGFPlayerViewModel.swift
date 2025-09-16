// MARK: - SGF Player ViewModel
// Extracted from ContentView.swift to separate game playback logic from UI

import SwiftUI
import Combine
import Foundation

/// ViewModel responsible for SGF game loading, playback control, and move navigation
@MainActor
class SGFPlayerViewModel: ObservableObject {
    // MARK: - Core Game State
    @Published var player = SGFPlayer()
    @Published var bowls = PlayerCapturesAdapter()

    // MARK: - Playback Controls
    @Published var autoNext: Bool = false {
        didSet {
            // Update player interval and autoplay state
            if autoNext {
                player.setPlayInterval(uiMoveDelay)
                if !player.isPlaying {
                    player.play()
                }
            } else {
                player.pause()
            }
            // Sync with AppStorage through ContentView
            autoNextChanged?(autoNext)
        }
    }

    @Published var randomNext: Bool = false {
        didSet {
            randomNextChanged?(randomNext)
        }
    }

    @Published var randomOnStart: Bool = false {
        didSet {
            randomOnStartChanged?(randomOnStart)
        }
    }

    @Published var uiMoveDelay: Double = 0.75 {
        didSet {
            player.setPlayInterval(uiMoveDelay)
            uiMoveDelayChanged?(uiMoveDelay)
        }
    }

    // MARK: - Game State Caching
    @Published var tallyWByB: Int = 0
    @Published var tallyBByW: Int = 0
    @Published var tallyAtMove: [Int:(w:Int,b:Int)] = [0:(0,0)]
    @Published var gridAtMove: [Int : [[Stone?]]] = [:]

    // MARK: - Navigation State - Computed from player
    var currentMoveIndex: Int { player.currentIndex }
    var totalMoves: Int { player.maxIndex }
    var isPlaying: Bool { player.isPlaying }
    var currentBoard: BoardSnapshot { player.board }
    var lastMove: MoveRef? { player.lastMove }

    // MARK: - Timers and Animation
    @Published var physicsUpdateTimer: Timer?
    @Published var pendingPhysicsUpdate: Int?

    // MARK: - AppStorage Synchronization Callbacks
    var autoNextChanged: ((Bool) -> Void)?
    var randomNextChanged: ((Bool) -> Void)?
    var randomOnStartChanged: ((Bool) -> Void)?
    var uiMoveDelayChanged: ((Double) -> Void)?

    // MARK: - Initialization
    init() {
        setupPlayerBindings()
    }

    // MARK: - Public Interface

    /// Load a new SGF game
    func loadGame(_ game: SGFGame) {
        player.load(game: game)
        resetCachedState()
        updateGameState()
    }

    /// Move to next position in game
    func moveNext() {
        guard currentMoveIndex < totalMoves else { return }

        player.stepForward()
        updateGameState()

        // Schedule physics update with debouncing
        schedulePhysicsUpdate()
    }

    /// Move to previous position in game
    func movePrevious() {
        guard currentMoveIndex > 0 else { return }

        player.stepBack()
        updateGameState()

        // Schedule physics update with debouncing
        schedulePhysicsUpdate()
    }

    /// Jump to specific move index
    func seekToMove(_ index: Int) {
        let clampedIndex = max(0, min(index, totalMoves))

        player.seek(to: clampedIndex)
        updateGameState()

        // Stop autoplay when seeking manually
        if autoNext {
            autoNext = false
        }

        // Schedule physics update
        schedulePhysicsUpdate()
    }

    /// Toggle autoplay
    func toggleAutoplay() {
        autoNext.toggle()
    }

    /// Start autoplay
    func startAutoplay() {
        autoNext = true
    }

    /// Stop autoplay
    func stopAutoplay() {
        autoNext = false
    }

    /// Reset to beginning of game
    func resetToBeginning() {
        player.reset()
        updateGameState()
        schedulePhysicsUpdate()
    }

    /// Jump to end of game
    func jumpToEnd() {
        seekToMove(totalMoves)
    }

    // MARK: - Key Handling

    /// Handle arrow key navigation
    func handleKeyPress(_ key: String) {
        switch key {
        case "ArrowRight", " ":
            moveNext()
        case "ArrowLeft":
            movePrevious()
        case "Home":
            resetToBeginning()
        case "End":
            jumpToEnd()
        default:
            break
        }
    }

    // MARK: - Private Implementation

    private func setupPlayerBindings() {
        // Bind player state to our published properties
        player.objectWillChange
            .sink { [weak self] in
                self?.updateGameInfo()
            }
            .store(in: &cancellables)
    }

    private func updateGameInfo() {
        // Game info is now computed properties from player
        updateGameState()
    }

    private func updateGameState() {
        // Update capture tallies
        updateCaptureTallies()

        // Cache grid state for this move
        cacheGridState()
    }

    private func updateCaptureTallies() {
        // Calculate captures by analyzing moves and board state
        let captures = calculateCaptures()
        tallyWByB = captures.whiteByBlack
        tallyBByW = captures.blackByWhite

        // Cache for this move
        tallyAtMove[currentMoveIndex] = (w: tallyWByB, b: tallyBByW)
    }

    private func cacheGridState() {
        // Cache board grid for physics layout calculations
        gridAtMove[currentMoveIndex] = player.board.grid
    }

    private func calculateCaptures() -> (whiteByBlack: Int, blackByWhite: Int) {
        // For now, use bowls adapter for capture counting
        // This maintains compatibility with existing capture logic
        return (whiteByBlack: bowls.whiteStonesCaptured, blackByWhite: bowls.blackStonesCaptured)
    }

    private func resetCachedState() {
        tallyAtMove.removeAll()
        gridAtMove.removeAll()
        tallyWByB = 0
        tallyBByW = 0
        currentMoveIndex = 0
    }

    private func schedulePhysicsUpdate() {
        // Cancel existing timer
        physicsUpdateTimer?.invalidate()

        // Store pending update
        pendingPhysicsUpdate = currentMoveIndex

        // Schedule debounced update
        physicsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.executePhysicsUpdate()
        }
    }

    private func executePhysicsUpdate() {
        guard let moveIndex = pendingPhysicsUpdate else { return }

        // Notify physics system of move change
        NotificationCenter.default.post(
            name: .gameStateChanged,
            object: nil,
            userInfo: ["moveIndex": moveIndex]
        )

        pendingPhysicsUpdate = nil
    }

    // MARK: - Combine Support
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Notifications

extension Notification.Name {
    static let gameStateChanged = Notification.Name("gameStateChanged")
}

// MARK: - Legacy Compatibility

extension SGFPlayerViewModel {
    /// Get cached captures for a specific move (legacy compatibility)
    func getCapturesAtMove(_ moveIndex: Int) -> (whiteByBlack: Int, blackByWhite: Int) {
        if let cached = tallyAtMove[moveIndex] {
            return (whiteByBlack: cached.w, blackByWhite: cached.b)
        }
        return (whiteByBlack: 0, blackByWhite: 0)
    }

    /// Get cached grid for a specific move (legacy compatibility)
    func getGridAtMove(_ moveIndex: Int) -> [[Stone?]]? {
        return gridAtMove[moveIndex]
    }

    /// Sync with AppStorage values (called from ContentView)
    /// Note: We don't set the values directly to avoid triggering didSet callbacks
    func syncFromAppStorage(
        autoNext: Bool,
        randomNext: Bool,
        randomOnStart: Bool,
        uiMoveDelay: Double
    ) {
        // Sync without triggering didSet observers (to avoid infinite loops)
        if self.autoNext != autoNext {
            self._autoNext.wrappedValue = autoNext
        }
        if self.randomNext != randomNext {
            self._randomNext.wrappedValue = randomNext
        }
        if self.randomOnStart != randomOnStart {
            self._randomOnStart.wrappedValue = randomOnStart
        }
        if self.uiMoveDelay != uiMoveDelay {
            self._uiMoveDelay.wrappedValue = uiMoveDelay
            player.setPlayInterval(uiMoveDelay)
        }
    }
}