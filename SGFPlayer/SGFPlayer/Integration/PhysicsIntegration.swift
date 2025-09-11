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
    @Published var blackStones: [LegacyCapturedStone] = []
    @Published var whiteStones: [LegacyCapturedStone] = []
    @Published var physicsStatus: String = ""
    @Published var isReady: Bool = false
    
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
        print("🚀 PhysicsIntegration: Initialized with new architecture")
    }
    
    private func setupNewPhysicsBindings() {
        // Monitor new physics results
        physicsReplacement.$capUL
            .sink { [weak self] stones in
                self?.blackStones = stones
                if self?.debugMode == true {
                    print("🚀 PhysicsIntegration: Updated black stones: \(stones.count)")
                }
            }
            .store(in: &cancellables)
        
        physicsReplacement.$capLR
            .sink { [weak self] stones in
                self?.whiteStones = stones
                if self?.debugMode == true {
                    print("🚀 PhysicsIntegration: Updated white stones: \(stones.count)")
                }
            }
            .store(in: &cancellables)
        
        physicsReplacement.$physicsInfo
            .sink { [weak self] info in
                self?.physicsStatus = "New: \(info)"
            }
            .store(in: &cancellables)
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
        if useNewPhysics {
            physicsReplacement.updateStonePositions(
                currentMove: currentMove,
                blackCapturedCount: blackStoneCount,
                whiteCapturedCount: whiteStoneCount,
                bowlRadius: bowlRadius,
                gameSeed: gameSeed,
                bowlCenters: (upperLeft: ulCenter, lowerRight: lrCenter)
            )
            
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
        blackStones.removeAll()
        whiteStones.removeAll()
        physicsStatus = "Reset"
        print("🚀 PhysicsIntegration: Reset")
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