// MARK: - Spiral Physics Model (Clean Algorithm)
// Deterministic spiral placement with color separation

import Foundation
import CoreGraphics

/// Simple spiral-based physics model for baseline stone placement
struct SpiralPhysicsModel: PhysicsModel {
    
    let name = "Spiral"
    let description = "Deterministic spiral placement with color offset"
    
    func computeStonePositions(
        currentStoneCount: Int,
        targetStoneCount: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        seed: UInt64,
        isWhiteBowl: Bool
    ) -> BowlPhysicsResult {
        
        var stones: [StonePosition] = []
        
        // Generate positions for target count
        for i in 0..<targetStoneCount {
            let position = generateSpiralPosition(
                index: i,
                totalStones: targetStoneCount,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                isWhiteBowl: isWhiteBowl
            )
            
            stones.append(StonePosition(
                position: position,
                isWhite: isWhiteBowl
            ))
        }
        
        return BowlPhysicsResult(
            stones: stones,
            convergenceInfo: "Spiral: Generated \(stones.count) positions"
        )
    }
    
    private func generateSpiralPosition(
        index: Int,
        totalStones: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        isWhiteBowl: Bool
    ) -> CGPoint {
        
        // Minimum separation between stone centers
        let minSeparation = stoneRadius * 2.2
        let spiralTightness = minSeparation / (2.0 * CGFloat.pi)
        let t = CGFloat(index) * 0.8
        
        // Color offset for separation between white and black stones
        let colorOffset = isWhiteBowl ? CGFloat.pi * 0.4 : 0.0 // 72° offset for white
        
        let radius = min(spiralTightness * t, bowlRadius * 0.35)
        let angle = t * 2.0 * CGFloat.pi + colorOffset
        
        return CGPoint(
            x: radius * cos(angle),
            y: radius * sin(angle)
        )
    }
}