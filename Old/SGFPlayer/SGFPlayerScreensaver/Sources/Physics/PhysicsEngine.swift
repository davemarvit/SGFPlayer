// MARK: - Physics Engine Architecture
// Clean separation between physics computation and UI concerns

import Foundation
import CoreGraphics

/// Represents a stone with a position in bowl-relative coordinates
struct StonePosition {
    let id: UUID
    let position: CGPoint  // Relative to bowl center in radius units
    let isWhite: Bool
    
    init(id: UUID = UUID(), position: CGPoint, isWhite: Bool) {
        self.id = id
        self.position = position
        self.isWhite = isWhite
    }
}

/// Result of physics computation for a bowl
struct BowlPhysicsResult {
    let stones: [StonePosition]
    let convergenceInfo: String?
    
    init(stones: [StonePosition], convergenceInfo: String? = nil) {
        self.stones = stones
        self.convergenceInfo = convergenceInfo
    }
}

/// Clean interface for physics models
protocol PhysicsModel {
    var name: String { get }
    var description: String { get }
    
    /// Compute stone positions for a bowl
    /// - Parameters:
    ///   - currentStoneCount: Current number of stones in bowl
    ///   - targetStoneCount: Desired number of stones in bowl
    ///   - bowlRadius: Bowl radius in points
    ///   - stoneRadius: Stone radius in points
    ///   - seed: Deterministic seed for reproducible results
    ///   - isWhiteBowl: Whether this is the white stone bowl
    /// - Returns: Physics result with stone positions
    func computeStonePositions(
        currentStoneCount: Int,
        targetStoneCount: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        seed: UInt64,
        isWhiteBowl: Bool
    ) -> BowlPhysicsResult
}

/// Central physics engine that manages different physics models
class PhysicsEngine: ObservableObject {
    
    // Available physics models
    private let models: [PhysicsModel] = [
        SpiralPhysicsModel(),
        GroupDropPhysicsModel(),
        EnergyMinimizationModel()
    ]
    
    @Published var activeModelIndex: Int = 1 // Default to GroupDrop (Physics2)
    
    var activeModel: PhysicsModel {
        models[safe: activeModelIndex] ?? models[0]
    }
    
    var availableModels: [(index: Int, name: String, description: String)] {
        models.enumerated().map { (index, model) in
            (index, model.name, model.description)
        }
    }
    
    /// Compute stone positions using the active physics model
    func computeStonePositions(
        currentStoneCount: Int,
        targetStoneCount: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        seed: UInt64,
        isWhiteBowl: Bool
    ) -> BowlPhysicsResult {
        print("🔥 PhysicsEngine: Using \(activeModel.name), \(isWhiteBowl ? "white" : "black") bowl: \(currentStoneCount)→\(targetStoneCount)")
        
        let result = activeModel.computeStonePositions(
            currentStoneCount: currentStoneCount,
            targetStoneCount: targetStoneCount,
            bowlRadius: bowlRadius,
            stoneRadius: stoneRadius,
            seed: seed,
            isWhiteBowl: isWhiteBowl
        )
        
        if let info = result.convergenceInfo {
            print("🔥 PhysicsEngine: \(info)")
        }
        
        return result
    }
}

// MARK: - Safe Array Access
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}