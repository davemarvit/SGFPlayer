// MARK: - ContentView Integration Bridge
// Clean bridge between new modular architecture and existing UI

import Foundation
import SwiftUI

/// Bridge that connects the new modular architecture with existing ContentView
class ContentViewBridge: ObservableObject {
    
    // New architecture components
    @Published private var stoneViewModel = StonePositionViewModel()
    
    // Bridge state for ContentView
    @Published var blackStoneUIPositions: [UIStone] = []
    @Published var whiteStoneUIPositions: [UIStone] = []
    @Published var physicsStatus: String = ""
    @Published var isPhysicsActive: Bool = true
    
    // Physics model selection
    var availablePhysicsModels: [(index: Int, name: String, description: String)] {
        return stoneViewModel.availablePhysicsModels
    }
    
    var activePhysicsModelIndex: Int {
        get { stoneViewModel.activePhysicsModelIndex }
        set { 
            stoneViewModel.activePhysicsModelIndex = newValue
            physicsStatus = "Switched to: \(stoneViewModel.activeModelName)"
        }
    }
    
    init() {
        // Monitor stone position changes and convert to UI positions
        // CRITICAL FIX: Use debounce to prevent stale data from being processed
        stoneViewModel.$blackStonePositions
            .combineLatest(stoneViewModel.$whiteStonePositions)
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { [weak self] blackStones, whiteStones in
                print("🔄 ContentViewBridge: Processing stones - Black: \(blackStones.count), White: \(whiteStones.count)")
                self?.updateUIPositions()
            }
            .store(in: &cancellables)
        
        // Monitor physics status
        stoneViewModel.$physicsInfo
            .sink { [weak self] info in
                self?.physicsStatus = info
            }
            .store(in: &cancellables)
        
        stoneViewModel.$isComputingPhysics
            .sink { [weak self] isComputing in
                self?.isPhysicsActive = !isComputing
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var lastBowlCenters: (upperLeft: CGPoint?, lowerRight: CGPoint?) = (nil, nil)
    private var lastBowlRadius: CGFloat = 100.0
    
    /// Initialize the bridge with game state
    func initializeWithGame(boardGrid: [[LegacyStone?]]) {
        // Convert existing Stone enum to GameStone
        let gameGrid: [[GameStone?]] = boardGrid.map { row in
            row.map { stone in
                switch stone {
                case .black: return .black
                case .white: return .white
                case nil: return nil
                }
            }
        }
        
        stoneViewModel.initializeWithBaseState(boardGrid: gameGrid)
        physicsStatus = "Initialized with \(stoneViewModel.activeModelName)"
    }
    
    /// Update stone positions for current game state
    func updateForGameState(
        currentMove: Int,
        blackCapturedCount: Int, // stones captured by white (in UL bowl)
        whiteCapturedCount: Int, // stones captured by black (in LR bowl)
        bowlRadius: CGFloat,
        gameSeed: UInt64,
        bowlCenters: (upperLeft: CGPoint, lowerRight: CGPoint)
    ) {
        print("🔍 ContentViewBridge: ===== UPDATE START =====")
        print("🔍 ContentViewBridge: bowlRadius=\(bowlRadius), centers=\(bowlCenters)")
        print("🔍 ContentViewBridge: Captured counts: black=\(blackCapturedCount), white=\(whiteCapturedCount)")

        // Store bowl info for position conversion
        lastBowlCenters = bowlCenters
        lastBowlRadius = bowlRadius

        // Calculate stone radius using same method as board stones for consistent scaling
        // bowlRadius = max(boardWidth, boardHeight) / 3 / 2, so max(boardWidth, boardHeight) = bowlRadius * 6
        let maxBoardDimension = bowlRadius * 6
        let cellWidth = maxBoardDimension / 19 // assuming 19x19 board
        let realCellWidth: CGFloat = 22.0 // mm (from SimpleBoardView)
        let realBlackStoneDiameter: CGFloat = 22.2 // mm (from SimpleBoardView)
        let boardStoneSize = (realBlackStoneDiameter / realCellWidth) * cellWidth
        let stoneRadius = boardStoneSize / 2

        print("🔍 ContentViewBridge: Calculated stoneRadius=\(stoneRadius) from bowlRadius=\(bowlRadius)")
        print("🔍 ContentViewBridge: Stone count before physics: Black=\(stoneViewModel.blackStonePositions.count), White=\(stoneViewModel.whiteStonePositions.count)")

        // Update physics with new stone counts
        stoneViewModel.updateStonePositions(
            currentMove: currentMove,
            blackStoneCount: blackCapturedCount,
            whiteStoneCount: whiteCapturedCount,
            bowlRadius: bowlRadius,
            stoneRadius: stoneRadius,
            gameSeed: gameSeed
        )

        print("🔍 ContentViewBridge: Stone count after physics: Black=\(stoneViewModel.blackStonePositions.count), White=\(stoneViewModel.whiteStonePositions.count)")
        print("🔍 ContentViewBridge: ===== UPDATE END =====")
    }
    
    /// Convert physics positions to UI positions
    private func updateUIPositions() {
        guard let upperLeftCenter = lastBowlCenters.upperLeft,
              let lowerRightCenter = lastBowlCenters.lowerRight else {
            return
        }
        
        // Convert black stones (in upper-left bowl)
        blackStoneUIPositions = stoneViewModel.getUIStones(
            forBowl: .upperLeft,
            bowlCenter: upperLeftCenter,
            bowlRadius: lastBowlRadius
        )
        
        // Convert white stones (in lower-right bowl)
        whiteStoneUIPositions = stoneViewModel.getUIStones(
            forBowl: .lowerRight,
            bowlCenter: lowerRightCenter,
            bowlRadius: lastBowlRadius
        )
    }
    
    /// Get diagnostic information
    func getDiagnosticInfo() -> String {
        return stoneViewModel.getDiagnosticInfo()
    }
    
    /// Force physics recalculation (for debugging)
    func recalculatePhysics() {
        // This could be used to force a recalculation
        physicsStatus = "Recalculating..."
    }

    /// Reset bridge state for new game
    func reset() {
        // Clear UI positions immediately
        blackStoneUIPositions.removeAll()
        whiteStoneUIPositions.removeAll()

        // Reset underlying ViewModel
        stoneViewModel.reset()

        // Clear bowl state
        lastBowlCenters = (nil, nil)
        lastBowlRadius = 100.0

        physicsStatus = "Bridge Reset"
    }
}

// MARK: - Combine Import
import Combine

// MARK: - Stone Enum Compatibility
// This matches the existing Stone enum in the codebase
enum LegacyStone: Equatable {
    case black, white
}