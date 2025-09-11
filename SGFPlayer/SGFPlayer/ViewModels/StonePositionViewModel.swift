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
        // Check cache first
        if let cachedLayout = cacheManager.getCachedLayout(forMove: currentMove) {
            print("🔄 ViewModel: Cache hit for move \(currentMove)")
            blackStonePositions = cachedLayout.blackStones
            whiteStonePositions = cachedLayout.whiteStones
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
                currentStoneCount: self.blackStonePositions.count,
                targetStoneCount: blackStoneCount,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                seed: gameSeed,
                isWhiteBowl: false
            )
            
            // Compute white stones (captured by black, in lower-right bowl)  
            let whiteResult = self.physicsEngine.computeStonePositions(
                currentStoneCount: self.whiteStonePositions.count,
                targetStoneCount: whiteStoneCount,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                seed: gameSeed,
                isWhiteBowl: true
            )
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.blackStonePositions = blackResult.stones
                self.whiteStonePositions = whiteResult.stones
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
            // Convert from physics coordinates (bowl-relative) to UI coordinates (screen-relative)
            let uiPosition = CGPoint(
                x: bowlCenter.x + stonePos.position.x,
                y: bowlCenter.y + stonePos.position.y
            )
            
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
                position: uiPosition,
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