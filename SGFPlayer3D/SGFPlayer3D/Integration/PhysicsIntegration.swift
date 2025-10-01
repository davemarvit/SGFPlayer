// MARK: - Strategic Physics Integration
// Gradual replacement of problematic ContentView physics with clean architecture

import Foundation
import SwiftUI
import Combine

/// Strategic integration point that can gradually replace ContentView physics
class PhysicsIntegration: ObservableObject {
    
    // MARK: - New Architecture
    private let physicsReplacement = CompatibilityLayer.createPhysicsReplacement()
    
    // MARK: - Integration Control
    @Published var useNewPhysics: Bool = true
    @Published var debugMode: Bool = true
    
    // MARK: - Published State (compatible with ContentView)
    @Published var blackStones: [LegacyCapturedStone] = [] {
        didSet {
            Logger.warning("🚀 blackStones @Published CHANGED - OLD: \(oldValue.count), NEW: \(blackStones.count)")
            if DebugConfig.enablePhysicsDebugging {
                Logger.debug("blackStones NEW IDs: \(blackStones.map { $0.id.uuidString.prefix(8) })")
            }
        }
    }
    @Published var whiteStones: [LegacyCapturedStone] = [] {
        didSet {
            Logger.warning("🚀 whiteStones @Published CHANGED - OLD: \(oldValue.count), NEW: \(whiteStones.count)")
            if DebugConfig.enablePhysicsDebugging {
                Logger.debug("whiteStones NEW IDs: \(whiteStones.map { $0.id.uuidString.prefix(8) })")
            }
        }
    }
    @Published var physicsStatus: String = ""
    @Published var isReady: Bool = false
    
    // Batching mechanism to prevent multiple UI updates during physics calculations
    private var isPhysicsInProgress = false
    private var pendingBlackStones: [LegacyCapturedStone] = []
    private var pendingWhiteStones: [LegacyCapturedStone] = []
    private var physicsUpdateTimer: Timer?
    
    // MARK: - Physics Model Selection (compatible with ContentView)
    @Published var activePhysicsModel: Int = 1 {
        didSet {
            if useNewPhysics {
                physicsReplacement.activePhysicsModelRaw = activePhysicsModel
                physicsStatus = "New Physics: Model \(activePhysicsModel)"
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNewPhysicsBindings()
        isReady = true
        Logger.info("PhysicsIntegration: Initialized with new architecture")
    }
    
    private func setupNewPhysicsBindings() {
        // Monitor new physics results with batching to prevent UI oscillation
        physicsReplacement.$capUL
            .sink { [weak self] stones in
                self?.updateBlackStonesBatched(stones)
            }
            .store(in: &cancellables)
        
        physicsReplacement.$capLR
            .sink { [weak self] stones in
                self?.updateWhiteStonesBatched(stones)
            }
            .store(in: &cancellables)
        
        physicsReplacement.$physicsInfo
            .sink { [weak self] info in
                self?.physicsStatus = "New: \(info)"
            }
            .store(in: &cancellables)
    }
    
    private func updateBlackStonesBatched(_ stones: [LegacyCapturedStone]) {
        if DebugConfig.enablePhysicsDebugging {
            Logger.debug("UPDATE_BLACK_STONES_BATCHED - received: \(stones.count), current: \(blackStones.count)")
        }
        pendingBlackStones = stones
        scheduleBatchUpdate()

        if debugMode && DebugConfig.enablePhysicsDebugging {
            Logger.debug("Batched black stones: \(stones.count)")
        }
    }

    private func updateWhiteStonesBatched(_ stones: [LegacyCapturedStone]) {
        if DebugConfig.enablePhysicsDebugging {
            Logger.debug("UPDATE_WHITE_STONES_BATCHED - received: \(stones.count), current: \(whiteStones.count)")
        }
        pendingWhiteStones = stones
        scheduleBatchUpdate()

        if debugMode && DebugConfig.enablePhysicsDebugging {
            Logger.debug("Batched white stones: \(stones.count)")
        }
    }
    
    private func scheduleBatchUpdate() {
        // Cancel any pending update
        physicsUpdateTimer?.invalidate()

        // For physics UI updates, apply immediately to ensure synchronization
        // The batching was designed for preventing UI blinking during rapid updates,
        // but the 50ms delay was causing sync issues with ContentView
        DispatchQueue.main.async {
            self.executeBatchUpdate()
        }
    }
    
    private func executeBatchUpdate() {
        // Apply the final stone positions to UI with smooth updates to prevent blinking
        updateStonesIncremental(current: &blackStones, pending: pendingBlackStones)
        updateStonesIncremental(current: &whiteStones, pending: pendingWhiteStones)

        if debugMode {
            Logger.warning("✅ FINAL PHYSICS UPDATE - Black: \(pendingBlackStones.count), White: \(pendingWhiteStones.count)")
        }

        isPhysicsInProgress = false
    }

    private func updateStonesIncremental(current: inout [LegacyCapturedStone], pending: [LegacyCapturedStone]) {
        // SwiftUI @Published arrays only trigger updates when the array reference changes
        // So we need to replace the entire array, not modify individual elements
        let oldCount = current.count
        current = pending

        if DebugConfig.enablePhysicsDebugging {
            Logger.debug("Array replaced - OLD count: \(oldCount), NEW count: \(pending.count)")
        }

        // REMOVED: Force objectWillChange.send() - this was causing GeometryReader infinite loop
        // @Published property changes automatically trigger view updates
        // print("🚀 PhysicsIntegration: Forced objectWillChange.send()")
    }
    
    // MARK: - Public Interface (compatible with ContentView)
    
    /// Initialize with game state
    func initializeWithGame(_ player: SGFPlayer) {
        if useNewPhysics {
            physicsReplacement.initializeWithGame(player: player)
            physicsStatus = "New Physics: Initialized"
        } else {
            // Fallback to old physics would go here
            physicsStatus = "Old Physics: Not implemented"
        }
    }
    
    // State tracking to prevent unnecessary updates
    private var lastUpdateState: (move: Int, blackCount: Int, whiteCount: Int, bowlRadius: CGFloat)?

    /// Update stone positions for current game state
    func updateStonePositions(
        currentMove: Int,
        blackStoneCount: Int,
        whiteStoneCount: Int,
        bowlRadius: CGFloat,
        gameSeed: UInt64,
        ulCenter: CGPoint,
        lrCenter: CGPoint
    ) {
        // CRITICAL FIX: Check if state actually changed to prevent GeometryReader infinite loop
        let newState = (move: currentMove, blackCount: blackStoneCount, whiteCount: whiteStoneCount, bowlRadius: bowlRadius)

        if let lastState = lastUpdateState,
           lastState.move == newState.move &&
           lastState.blackCount == newState.blackCount &&
           lastState.whiteCount == newState.whiteCount &&
           abs(lastState.bowlRadius - newState.bowlRadius) < 1.0 {

            Logger.warning("⏭️ SKIPPING PHYSICS UPDATE - no meaningful change detected")
            return
        }

        lastUpdateState = newState

        Logger.warning("🚀 UPDATE_STONE_POSITIONS - move: \(currentMove), blackCount: \(blackStoneCount), whiteCount: \(whiteStoneCount), bowlRadius: \(bowlRadius)")
        Logger.warning("Current stone arrays BEFORE update - blackStones: \(blackStones.count), whiteStones: \(whiteStones.count)")

        if useNewPhysics {
            physicsReplacement.updateStonePositions(
                currentMove: currentMove,
                blackCapturedCount: blackStoneCount,
                whiteCapturedCount: whiteStoneCount,
                bowlRadius: bowlRadius,
                gameSeed: gameSeed,
                bowlCenters: (upperLeft: ulCenter, lowerRight: lrCenter)
            )

            print("🚀 PhysicsIntegration: PHYSICS_REPLACEMENT_CALLED - waiting for published updates...")

            if debugMode {
                print("🚀 PhysicsIntegration: Move \(currentMove), Black: \(blackStoneCount), White: \(whiteStoneCount)")
            }
        } else {
            // Fallback to old physics
            physicsStatus = "Old Physics: Would update here"
        }
    }
    
    /// Reset physics state
    func reset() {
        if useNewPhysics {
            physicsReplacement.reset()
        }

        // Cancel any pending batch updates to prevent stale updates from executing
        physicsUpdateTimer?.invalidate()
        physicsUpdateTimer = nil

        // Clear pending stone data to prevent batched updates from restoring stones
        pendingBlackStones.removeAll()
        pendingWhiteStones.removeAll()

        // Clear current stone arrays
        blackStones.removeAll()
        whiteStones.removeAll()

        // Reset physics state flags
        isPhysicsInProgress = false

        // CRITICAL FIX: Clear state tracking to allow fresh updates after reset
        lastUpdateState = nil

        physicsStatus = "Reset"
        print("🚀 PhysicsIntegration: Reset (cleared pending updates + state tracking)")
    }
    
    /// Get available physics models
    var availableModels: [(index: Int, name: String, description: String)] {
        if useNewPhysics {
            return physicsReplacement.availableModels
        } else {
            return [(0, "Legacy", "Old physics system")]
        }
    }
    
    /// Get diagnostic information
    func getDiagnosticInfo() -> String {
        let archStatus = useNewPhysics ? "NEW ARCH" : "OLD ARCH"
        let stoneInfo = "Black: \(blackStones.count), White: \(whiteStones.count)"
        let physicsInfo = useNewPhysics ? physicsReplacement.getDiagnosticInfo() : "Legacy diagnostics"
        
        return "[\(archStatus)] \(stoneInfo) | \(physicsInfo)"
    }
    
    /// Toggle between old and new physics (for testing)
    func togglePhysicsArchitecture() {
        useNewPhysics.toggle()
        let arch = useNewPhysics ? "NEW" : "OLD"
        physicsStatus = "Switched to \(arch) architecture"
        print("🚀 PhysicsIntegration: Switched to \(arch) architecture")
    }
    
    /// Force recalculation (for debugging)
    func forceRecalculation() {
        if useNewPhysics {
            physicsReplacement.reset()
            physicsStatus = "New Physics: Force recalculation"
        }
        print("🚀 PhysicsIntegration: Forced recalculation")
    }
}