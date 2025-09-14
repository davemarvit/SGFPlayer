// MARK: - Compatibility Layer
// Maintains compatibility with existing ContentView while using new architecture

import Foundation
import SwiftUI

/// Convert between new modular architecture and existing ContentView expectations
struct CompatibilityLayer {
    
    /// Convert new UIStone to existing CapturedStone format
    static func convertToLegacyFormat(
        uiStones: [UIStone],
        bowlRadius: CGFloat
    ) -> [LegacyCapturedStone] {
        
        return uiStones.map { uiStone in
            // uiStone.position is already relative to bowl center from the physics engine
            // GameBoardView expects stone.pos to be offset from bowl center
            let relativePos = uiStone.position
            
            // Create normalized position (relative to bowl center, -1.0 to 1.0)
            let normalizedPos = CGPoint(
                x: relativePos.x / bowlRadius,
                y: relativePos.y / bowlRadius
            )
            
            return LegacyCapturedStone(
                isWhite: uiStone.imageName.contains("clam"),
                imageName: uiStone.imageName,
                pos: relativePos,  // Use relative position for bowl offset
                normalizedPos: normalizedPos
            )
        }
    }
    
    /// Create a clean physics replacement that integrates with ContentView
    static func createPhysicsReplacement() -> PhysicsReplacement {
        return PhysicsReplacement()
    }
}

/// Clean replacement for the tangled physics code in ContentView
class PhysicsReplacement: ObservableObject {
    
    private let bridge = ContentViewBridge()
    
    // Published properties that ContentView can observe
    @Published var capUL: [LegacyCapturedStone] = [] // Black stones captured by white (upper-left bowl)
    @Published var capLR: [LegacyCapturedStone] = [] // White stones captured by black (lower-right bowl)
    @Published var physicsInfo: String = ""
    
    // Physics model selection compatible with ContentView
    var activePhysicsModelRaw: Int {
        get { bridge.activePhysicsModelIndex }
        set { bridge.activePhysicsModelIndex = newValue }
    }
    
    init() {
        // Monitor bridge changes and update legacy format
        bridge.$blackStoneUIPositions
            .sink { [weak self] uiStones in
                guard let self = self else { return }
                self.capUL = CompatibilityLayer.convertToLegacyFormat(
                    uiStones: uiStones,
                    bowlRadius: self.currentBowlRadius
                )
                print("🔄 PhysicsReplacement: Updated black stones: \(uiStones.count), radius: \(self.currentBowlRadius)")
            }
            .store(in: &cancellables)
        
        bridge.$whiteStoneUIPositions
            .sink { [weak self] uiStones in
                guard let self = self else { return }
                self.capLR = CompatibilityLayer.convertToLegacyFormat(
                    uiStones: uiStones,
                    bowlRadius: self.currentBowlRadius
                )
                print("🔄 PhysicsReplacement: Updated white stones: \(uiStones.count), radius: \(self.currentBowlRadius)")
            }
            .store(in: &cancellables)
        
        bridge.$physicsStatus
            .sink { [weak self] status in
                self?.physicsInfo = status
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var currentBowlRadius: CGFloat = 100.0
    
    /// Initialize with game (called by ContentView)
    func initializeWithGame(player: SGFPlayer) {
        // Convert Stone to LegacyStone
        let legacyGrid: [[LegacyStone?]] = player.board.grid.map { row in
            row.map { stone in
                switch stone {
                case .black: return .black
                case .white: return .white
                case nil: return nil
                }
            }
        }
        bridge.initializeWithGame(boardGrid: legacyGrid)
        print("🔄 PhysicsReplacement: Initialized with new architecture")
    }
    
    /// Update stone positions (called by ContentView during move changes)
    func updateStonePositions(
        currentMove: Int,
        blackCapturedCount: Int,
        whiteCapturedCount: Int,
        bowlRadius: CGFloat,
        gameSeed: UInt64,
        bowlCenters: (upperLeft: CGPoint, lowerRight: CGPoint)
    ) {
        currentBowlRadius = bowlRadius
        
        bridge.updateForGameState(
            currentMove: currentMove,
            blackCapturedCount: blackCapturedCount,
            whiteCapturedCount: whiteCapturedCount,
            bowlRadius: bowlRadius,
            gameSeed: gameSeed,
            bowlCenters: bowlCenters
        )
        
        print("🔄 PhysicsReplacement: Updated positions for move \(currentMove)")
    }
    
    /// Get available physics models (for ContentView settings)
    var availableModels: [(index: Int, name: String, description: String)] {
        return bridge.availablePhysicsModels
    }
    
    /// Compatibility method for existing ContentView reset logic
    func reset() {
        capUL.removeAll()
        capLR.removeAll()
        physicsInfo = "Reset"
        print("🔄 PhysicsReplacement: Reset")
    }
    
    /// Get diagnostic info for debugging
    func getDiagnosticInfo() -> String {
        return bridge.getDiagnosticInfo()
    }
}

// MARK: - Legacy CapturedStone structure (maintaining compatibility)
struct LegacyCapturedStone: Identifiable {
    let id = UUID()
    let isWhite: Bool
    let imageName: String     // "stone_black" or "clam_0X"
    var pos: CGPoint          // absolute position in current view coordinates
    var normalizedPos: CGPoint // scale-independent position (-1.0 to 1.0 relative to bowl)
    
    init(isWhite: Bool, imageName: String, pos: CGPoint, normalizedPos: CGPoint = .zero) {
        self.isWhite = isWhite
        self.imageName = imageName
        self.pos = pos
        self.normalizedPos = normalizedPos
    }
}

// MARK: - Combine Import
import Combine