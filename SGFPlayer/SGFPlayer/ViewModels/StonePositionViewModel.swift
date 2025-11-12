// MARK: - Stone Position View Model
// Clean separation between physics computation and UI display

import Foundation
import Combine
import SwiftUI

/// View model that manages stone positioning with clean architecture
class StonePositionViewModel: ObservableObject {
    
    // Dependencies
    private let physicsEngine = PhysicsEngine()
    private let cacheManager = CacheManager()
    
    // Published state for UI
    @Published var blackStonePositions: [StonePosition] = []
    @Published var whiteStonePositions: [StonePosition] = []
    @Published var isComputingPhysics: Bool = false
    @Published var physicsInfo: String = ""
    
    // Internal state tracking for physics continuity
    private var currentBlackStoneCount: Int = 0
    private var currentWhiteStoneCount: Int = 0
    
    // Configuration
    @Published var activePhysicsModelIndex: Int = 1 {
        didSet {
            physicsModelChanged()
        }
    }
    
    var availablePhysicsModels: [(index: Int, name: String, description: String)] {
        return physicsEngine.availableModels
    }
    
    var activeModelName: String {
        return physicsEngine.activeModel.name
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Keep physics engine in sync
        $activePhysicsModelIndex
            .sink { [weak self] index in
                self?.physicsEngine.activeModelIndex = index
            }
            .store(in: &cancellables)
    }
    
    private func physicsModelChanged() {
        let modelName = physicsEngine.activeModel.name
        cacheManager.validatePhysicsModel(modelName)
        physicsInfo = "Switched to: \(modelName)"
        print("🔄 ViewModel: Physics model changed to \(modelName)")
    }
    
    /// Initialize with base game state
    func initializeWithBaseState(boardGrid: [[GameStone?]]) {
        cacheManager.initializeWithBaseState(grid: boardGrid)
        blackStonePositions = []
        whiteStonePositions = []
        currentBlackStoneCount = 0
        currentWhiteStoneCount = 0
        physicsInfo = "Initialized with \(physicsEngine.activeModel.name)"
    }
    
    /// Update stone positions for the current game state
    func updateStonePositions(
        currentMove: Int,
        blackStoneCount: Int,
        whiteStoneCount: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        gameSeed: UInt64
    ) {
        // Special handling for move 0 or when both counts are 0 - force clear
        if currentMove == 0 || (blackStoneCount == 0 && whiteStoneCount == 0) {
            print("🔄 ViewModel: Force clearing stones for move \(currentMove), counts: B=\(blackStoneCount), W=\(whiteStoneCount)")
            blackStonePositions.removeAll()
            whiteStonePositions.removeAll()
            currentBlackStoneCount = 0
            currentWhiteStoneCount = 0
            physicsInfo = "Cleared for move \(currentMove)"
            return
        }

        // Check cache first
        if let cachedLayout = cacheManager.getCachedLayout(forMove: currentMove) {
            print("🔄 ViewModel: Cache hit for move \(currentMove)")
            blackStonePositions = cachedLayout.blackStones
            whiteStonePositions = cachedLayout.whiteStones
            currentBlackStoneCount = cachedLayout.blackStones.count
            currentWhiteStoneCount = cachedLayout.whiteStones.count
            physicsInfo = "Cache hit: \(cachedLayout.physicsModel)"
            return
        }
        
        print("🔄 ViewModel: Cache miss for move \(currentMove), computing physics")
        isComputingPhysics = true
        
        // Compute physics for both bowls
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Compute black stones (captured by white, in upper-left bowl)
            let blackResult = self.physicsEngine.computeStonePositions(
                currentStoneCount: self.currentBlackStoneCount,
                targetStoneCount: blackStoneCount,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                seed: gameSeed,
                isWhiteBowl: false
            )
            
            print("🔍 ViewModel: Black stones - current: \(self.currentBlackStoneCount), target: \(blackStoneCount), result: \(blackResult.stones.count)")
            
            // Compute white stones (captured by black, in lower-right bowl)  
            let whiteResult = self.physicsEngine.computeStonePositions(
                currentStoneCount: self.currentWhiteStoneCount,
                targetStoneCount: whiteStoneCount,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                seed: gameSeed,
                isWhiteBowl: true
            )
            
            print("🔍 ViewModel: White stones - current: \(self.currentWhiteStoneCount), target: \(whiteStoneCount), result: \(whiteResult.stones.count)")
            
            // Update UI on main thread with incremental updates to prevent blinking
            DispatchQueue.main.async {
                self.updateStonesIncremental(current: &self.blackStonePositions, pending: blackResult.stones)
                self.updateStonesIncremental(current: &self.whiteStonePositions, pending: whiteResult.stones)
                self.currentBlackStoneCount = blackResult.stones.count
                self.currentWhiteStoneCount = whiteResult.stones.count
                self.isComputingPhysics = false
                
                let info = [blackResult.convergenceInfo, whiteResult.convergenceInfo]
                    .compactMap { $0 }
                    .joined(separator: "; ")
                self.physicsInfo = info
                
                // Cache the results
                let layout = CachedLayout(
                    blackStones: blackResult.stones,
                    whiteStones: whiteResult.stones,
                    physicsModel: self.physicsEngine.activeModel.name
                )
                self.cacheManager.setCachedLayout(layout, forMove: currentMove)
                
                print("🔄 ViewModel: Updated positions for move \(currentMove)")
            }
        }
    }
    
    /// Convert physics positions to UI positions for display
    func getUIStones(
        forBowl bowlType: BowlType,
        bowlCenter: CGPoint,
        bowlRadius: CGFloat
    ) -> [UIStone] {
        
        let positions = bowlType == .upperLeft ? blackStonePositions : whiteStonePositions
        
        return positions.enumerated().map { index, stonePos in
            // Keep position relative to bowl center - GameBoardView will add bowl center
            let relativePosition = stonePos.position
            
            // Choose appropriate image
            let imageName: String
            if stonePos.isWhite {
                let variant = (index % 5) + 1 // Use different clam variants
                imageName = String(format: "clam_%02d", variant)
            } else {
                imageName = "stone_black"
            }
            
            return UIStone(
                id: stonePos.id,
                position: relativePosition,  // Keep relative to bowl center
                imageName: imageName
            )
        }
    }
    
    /// Get diagnostic information for debugging
    func getDiagnosticInfo() -> String {
        let stats = cacheManager.getCacheStats()
        let modelInfo = "\(physicsEngine.activeModel.name) (\(physicsEngine.activeModelIndex))"
        return "Model: \(modelInfo), Cache: \(stats), Info: \(physicsInfo)"
    }

    /// Update stones by completely replacing the array to prevent phantom stones
    ///
    /// Previous "incremental" approach tried to prevent blinking by reusing stone objects,
    /// but this caused phantom stones when navigating between moves because stale stone
    /// IDs and properties persisted. Complete replacement ensures each move has correct stones.
    private func updateStonesIncremental(current: inout [StonePosition], pending: [StonePosition]) {
        // CRITICAL FIX: Complete array replacement instead of incremental updates
        // This prevents phantom stones from stale data when navigating between moves
        current = pending

        print("🔄 ViewModel: Replaced stone array - count: \(pending.count)")
    }

    /// Reset ViewModel state for new game
    func reset() {
        // Clear all stone positions
        blackStonePositions.removeAll()
        whiteStonePositions.removeAll()

        // Reset state tracking
        currentBlackStoneCount = 0
        currentWhiteStoneCount = 0
        isComputingPhysics = false

        physicsInfo = "ViewModel Reset"
        print("🔄 StonePositionViewModel: Reset")
    }
}

// MARK: - Supporting Types

enum BowlType {
    case upperLeft  // Black stones captured by white
    case lowerRight // White stones captured by black
}

struct UIStone: Identifiable {
    let id: UUID
    let position: CGPoint
    let imageName: String
}