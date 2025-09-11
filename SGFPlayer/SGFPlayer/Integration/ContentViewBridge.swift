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
        stoneViewModel.$blackStonePositions
            .combineLatest(stoneViewModel.$whiteStonePositions)
            .sink { [weak self] blackStones, whiteStones in
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
        // Store bowl info for position conversion
        lastBowlCenters = bowlCenters
        lastBowlRadius = bowlRadius
        
        // Calculate stone radius (approximately 15% of bowl radius)
        let stoneRadius = bowlRadius * 0.15
        
        // Update physics with new stone counts
        stoneViewModel.updateStonePositions(
            currentMove: currentMove,
            blackStoneCount: blackCapturedCount,
            whiteStoneCount: whiteCapturedCount,
            bowlRadius: bowlRadius,
            stoneRadius: stoneRadius,
            gameSeed: gameSeed
        )
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
}

// MARK: - Combine Import
import Combine

// MARK: - Stone Enum Compatibility
// This matches the existing Stone enum in the codebase
enum LegacyStone: Equatable {
    case black, white
}