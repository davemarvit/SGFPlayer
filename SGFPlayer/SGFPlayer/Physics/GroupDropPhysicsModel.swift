// MARK: - Group Drop Physics Model (Physics 2 Implementation)
// Group dropping with tilted surface physics and energy minimization

import Foundation
import CoreGraphics

/// Physics Model 2: Group Drop + Tilted Surface Physics
struct GroupDropPhysicsModel: PhysicsModel {
    
    let name = "Group Drop"
    let description = "Group dropping with tilted surface physics and biconvex overlap penalties"
    
    func computeStonePositions(
        currentStoneCount: Int,
        targetStoneCount: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        seed: UInt64,
        isWhiteBowl: Bool
    ) -> BowlPhysicsResult {
        
        guard targetStoneCount > 0 else {
            return BowlPhysicsResult(stones: [])
        }
        
        // Use color-specific seed for different positioning
        let colorSeed = seed &+ (isWhiteBowl ? 0x77777777 : 0x33333333)
        var rng = SimpleRNG(seed: colorSeed)
        
        print("🪨 GroupDrop: Processing \(isWhiteBowl ? "white" : "black") bowl: \(currentStoneCount)→\(targetStoneCount)")
        
        var stones: [StonePosition] = []
        
        // Keep existing stones if reducing count
        if currentStoneCount > targetStoneCount {
            // TODO: Implement stone removal logic if needed
            // For now, just generate fresh positions
        }
        
        // Add new stones if increasing count
        if targetStoneCount > currentStoneCount {
            let newStoneCount = targetStoneCount - currentStoneCount
            print("🪨 GroupDrop: Dropping \(newStoneCount) stones as a group (existing: \(currentStoneCount))")
            
            stones.append(contentsOf: dropStoneGroup(
                newStoneCount: newStoneCount,
                existingStoneCount: currentStoneCount,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                rng: &rng,
                isWhiteBowl: isWhiteBowl
            ))
        } else {
            // Generate all stones fresh
            stones.append(contentsOf: dropStoneGroup(
                newStoneCount: targetStoneCount,
                existingStoneCount: 0,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                rng: &rng,
                isWhiteBowl: isWhiteBowl
            ))
        }
        
        // Energy minimization to reduce overlaps
        let iterations = minimizeEnergy(&stones, bowlRadius: bowlRadius, stoneRadius: stoneRadius)
        
        return BowlPhysicsResult(
            stones: stones,
            convergenceInfo: "GroupDrop: Converged after \(iterations) iterations"
        )
    }
    
    private func dropStoneGroup(
        newStoneCount: Int,
        existingStoneCount: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        rng: inout SimpleRNG,
        isWhiteBowl: Bool
    ) -> [StonePosition] {
        
        var stones: [StonePosition] = []
        
        // 1. Choose drop location (random spot within bowl)
        let dropAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
        let dropRadiusFactor = pow(rng.nextUnit(), 1.2) // slight center bias
        let dropRadius = bowlRadius * 0.6 * CGFloat(dropRadiusFactor) // avoid extreme edges
        let dropCenter = CGPoint(
            x: cos(dropAngle) * dropRadius,
            y: sin(dropAngle) * dropRadius
        )
        
        // 2. Drop stones near the drop point with small variations
        for _ in 0..<newStoneCount {
            let offsetAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
            let offsetRadius = 8.0 * CGFloat(rng.nextUnit()) // small spread in points
            let position = CGPoint(
                x: dropCenter.x + cos(offsetAngle) * offsetRadius,
                y: dropCenter.y + sin(offsetAngle) * offsetRadius
            )
            
            stones.append(StonePosition(
                position: position,
                isWhite: isWhiteBowl
            ))
        }
        
        return stones
    }
    
    private func minimizeEnergy(
        _ stones: inout [StonePosition],
        bowlRadius: CGFloat,
        stoneRadius: CGFloat
    ) -> Int {
        
        guard stones.count > 1 else { return 0 }
        
        let maxIterations = 20
        let initialTemperature: CGFloat = 1.0
        let coolingRate: CGFloat = 0.85
        let tiltConstant: CGFloat = 0.01 // tilted surface constant
        
        var temperature = initialTemperature
        
        for iteration in 0..<maxIterations {
            var totalMovement: CGFloat = 0
            
            for i in stones.indices {
                // Calculate forces on stone i
                var force = CGPoint.zero
                
                // 1. Tilted surface force (constant pull toward center)
                let currentRadius = sqrt(stones[i].position.x * stones[i].position.x + 
                                       stones[i].position.y * stones[i].position.y)
                if currentRadius > 0.1 {
                    let centerForce = tiltConstant
                    force.x -= (stones[i].position.x / currentRadius) * centerForce
                    force.y -= (stones[i].position.y / currentRadius) * centerForce
                }
                
                // 2. Biconvex overlap forces from other stones
                for j in stones.indices {
                    guard i != j else { continue }
                    
                    let dx = stones[j].position.x - stones[i].position.x
                    let dy = stones[j].position.y - stones[i].position.y
                    let distance = max(0.1, sqrt(dx*dx + dy*dy))
                    
                    if distance < stoneRadius * 2.0 { // stones are overlapping
                        let overlapForce = calculateBiconvexOverlapForce(
                            centerDistance: distance,
                            stoneRadius: stoneRadius
                        )
                        
                        // Push stones apart
                        force.x -= (dx / distance) * overlapForce
                        force.y -= (dy / distance) * overlapForce
                    }
                }
                
                // 3. Apply movement with temperature-based noise
                let movement = CGPoint(
                    x: force.x * temperature * 0.5,
                    y: force.y * temperature * 0.5
                )
                
                stones[i] = StonePosition(
                    id: stones[i].id,
                    position: CGPoint(
                        x: stones[i].position.x + movement.x,
                        y: stones[i].position.y + movement.y
                    ),
                    isWhite: stones[i].isWhite
                )
                
                // Keep within bowl bounds
                let currentDist = sqrt(stones[i].position.x * stones[i].position.x + 
                                     stones[i].position.y * stones[i].position.y)
                let maxRadius = bowlRadius * 0.8
                if currentDist > maxRadius {
                    stones[i] = StonePosition(
                        id: stones[i].id,
                        position: CGPoint(
                            x: stones[i].position.x * maxRadius / currentDist,
                            y: stones[i].position.y * maxRadius / currentDist
                        ),
                        isWhite: stones[i].isWhite
                    )
                }
                
                totalMovement += sqrt(movement.x * movement.x + movement.y * movement.y)
            }
            
            temperature *= coolingRate
            
            // Check convergence
            if totalMovement < 0.1 {
                return iteration + 1
            }
        }
        
        return maxIterations
    }
    
    private func calculateBiconvexOverlapForce(
        centerDistance: CGFloat,
        stoneRadius: CGFloat
    ) -> CGFloat {
        let overlapPercent = max(0, (2 * stoneRadius - centerDistance) / (2 * stoneRadius))
        
        if overlapPercent < 0.2 {
            return overlapPercent * 0.1 // minimal penalty for light contact
        } else if overlapPercent < 0.8 {
            return pow(overlapPercent, 3) * 2.0 // escalating penalty
        } else {
            return pow(overlapPercent, 2) * 3.0 // very high but finite penalty
        }
    }
}

// MARK: - Simple RNG for deterministic physics
private struct SimpleRNG {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }
    
    mutating func nextRaw() -> UInt64 {
        state = state &* 1103515245 &+ 12345
        return state
    }
    
    mutating func nextUnit() -> Double {
        return Double(nextRaw() >> 16) / Double(UInt64.max >> 16)
    }
}