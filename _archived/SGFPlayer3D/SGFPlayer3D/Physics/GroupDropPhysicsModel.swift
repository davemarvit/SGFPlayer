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
        
        // Always generate the target number of stones
        // For simplicity, we regenerate all stones to ensure proper clustering
        print("🪨 GroupDrop: Generating \(targetStoneCount) stones (from \(currentStoneCount))")
        
        stones.append(contentsOf: dropStoneGroup(
            newStoneCount: targetStoneCount,
            existingStoneCount: 0,
            bowlRadius: bowlRadius,
            stoneRadius: stoneRadius,
            rng: &rng,
            isWhiteBowl: isWhiteBowl
        ))
        
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
        
        // 1. Choose drop location (random spot within bowl) - more conservative
        let dropAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
        let dropRadiusFactor = pow(rng.nextUnit(), 1.5) // stronger center bias
        let dropRadius = bowlRadius * 0.4 * CGFloat(dropRadiusFactor) // keep closer to center
        let dropCenter = CGPoint(
            x: cos(dropAngle) * dropRadius,
            y: sin(dropAngle) * dropRadius
        )
        
        // 2. Drop stones near the drop point with proper spacing variations
        // Define boundary for initial placement - split the difference between previous constraints
        let maxPlacementDistance = bowlRadius * 0.85 - (stoneRadius * 2.0) // Moderate buffer: original radius + half stone diameter
        
        for _ in 0..<newStoneCount {
            var position: CGPoint
            var attempts = 0
            let maxAttempts = 100
            
            // Retry placement until we find a valid position or exhaust attempts
            repeat {
                // Use progressive radial placement for better distribution
                let offsetAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
                // Moderate spread based on bowl size and stone count
                let baseSpread = bowlRadius * 0.2 // spread relative to bowl size
                let countFactor = sqrt(Double(newStoneCount)) * 0.8 // less spread increase
                let offsetRadius = baseSpread * CGFloat(countFactor) * CGFloat(rng.nextUnit())
                
                position = CGPoint(
                    x: dropCenter.x + cos(offsetAngle) * offsetRadius,
                    y: dropCenter.y + sin(offsetAngle) * offsetRadius
                )
                
                attempts += 1
                
                // Check if this position would place the stone too close to the edge
                let distanceFromCenter = sqrt(position.x * position.x + position.y * position.y)
                
                if distanceFromCenter <= maxPlacementDistance || attempts >= maxAttempts {
                    break // Valid position found, or exhausted attempts
                }
                
            } while true
            
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
        
        let maxIterations = 35  // More iterations for better convergence
        let initialTemperature: CGFloat = 2.0  // Higher initial temperature for more movement
        let coolingRate: CGFloat = 0.88  // Slower cooling for gradual settling
        let tiltConstant: CGFloat = 0.005 // Reduced tilt to allow more spread
        
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
                    
                    // Apply forces when stones are too close (including slight separation)
                    let targetSeparation = stoneRadius * 2.2  // Stones should be slightly apart
                    if distance < targetSeparation {
                        let overlapForce = calculateBiconvexOverlapForce(
                            centerDistance: distance,
                            stoneRadius: stoneRadius
                        )
                        
                        // Push stones apart with stronger force
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
                
                // Keep within bowl bounds - looser constraint for energy minimization movement
                let currentDist = sqrt(stones[i].position.x * stones[i].position.x + 
                                     stones[i].position.y * stones[i].position.y)
                let maxRadius = bowlRadius * 0.9  // Slightly looser than initial placement for energy minimization
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
        // Improved force calculation for better stone separation
        let targetDistance = stoneRadius * 2.2  // Stones should be slightly apart
        let overlapDistance = max(0, targetDistance - centerDistance)
        let overlapPercent = overlapDistance / targetDistance
        
        if overlapPercent < 0.1 {
            return overlapPercent * 0.5 // minimal force for near-contact
        } else if overlapPercent < 0.5 {
            return pow(overlapPercent, 2) * 3.0 // moderate escalating force
        } else if overlapPercent < 0.9 {
            return pow(overlapPercent, 3) * 8.0 // strong force for significant overlap
        } else {
            return pow(overlapPercent, 1.5) * 12.0 // very strong but not infinite force
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