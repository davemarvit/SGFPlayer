// MARK: - Energy Minimization Physics Model (Physics 3 Implementation)
// Advanced energy minimization with contact propagation

import Foundation
import CoreGraphics

/// Physics Model 3: Energy Minimization + Contact Propagation
struct EnergyMinimizationModel: PhysicsModel {
    
    let name = "Energy Minimization"
    let description = "Advanced energy minimization with contact propagation and transmission coefficients"
    
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
        let colorSeed = seed &+ (isWhiteBowl ? 0x88888888 : 0x44444444)
        var rng = SimpleRNG(seed: colorSeed)
        
        print("🪨 EnergyMin: Processing \(isWhiteBowl ? "white" : "black") bowl: \(currentStoneCount)→\(targetStoneCount)")
        
        var stones: [StonePosition] = []
        
        // 1. Group drop: place new stones near each other
        let dropAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
        let dropRadiusFactor = pow(rng.nextUnit(), 1.3) // center bias
        let dropRadius = bowlRadius * 0.5 * CGFloat(dropRadiusFactor)
        let dropCenter = CGPoint(
            x: cos(dropAngle) * dropRadius,
            y: sin(dropAngle) * dropRadius
        )
        
        // Add stones with small random offsets from drop point
        for i in 0..<targetStoneCount {
            let offsetAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
            let offsetRadius = 12.0 * CGFloat(rng.nextUnit()) // wider spread than GroupDrop
            let position = CGPoint(
                x: dropCenter.x + cos(offsetAngle) * offsetRadius,
                y: dropCenter.y + sin(offsetAngle) * offsetRadius
            )
            
            stones.append(StonePosition(
                position: position,
                isWhite: isWhiteBowl
            ))
        }
        
        // 2. Advanced energy minimization with contact propagation
        let iterations = advancedEnergyMinimization(
            &stones,
            bowlRadius: bowlRadius,
            stoneRadius: stoneRadius
        )
        
        return BowlPhysicsResult(
            stones: stones,
            convergenceInfo: "EnergyMin: Converged after \(iterations) iterations"
        )
    }
    
    private func advancedEnergyMinimization(
        _ stones: inout [StonePosition],
        bowlRadius: CGFloat,
        stoneRadius: CGFloat
    ) -> Int {
        
        guard stones.count > 1 else { return 0 }
        
        let maxIterations = 30
        let initialTemperature: CGFloat = 2.0
        let coolingRate: CGFloat = 0.9
        let transmissionCoeff: CGFloat = 0.15 // Energy transmission through contacts
        
        var temperature = initialTemperature
        
        for iteration in 0..<maxIterations {
            var totalEnergy: CGFloat = 0
            
            // Calculate contact graph for energy propagation
            let contacts = buildContactGraph(stones, stoneRadius: stoneRadius)
            
            for i in stones.indices {
                // Calculate all forces on stone i
                var force = CGPoint.zero
                
                // 1. Tilted surface force (constant gradient)
                let currentRadius = sqrt(stones[i].position.x * stones[i].position.x + 
                                       stones[i].position.y * stones[i].position.y)
                if currentRadius > 0.1 {
                    let tiltForce: CGFloat = 0.02
                    force.x -= (stones[i].position.x / currentRadius) * tiltForce
                    force.y -= (stones[i].position.y / currentRadius) * tiltForce
                }
                
                // 2. Direct overlap forces
                for j in stones.indices {
                    guard i != j else { continue }
                    
                    let dx = stones[j].position.x - stones[i].position.x
                    let dy = stones[j].position.y - stones[i].position.y
                    let distance = max(0.1, sqrt(dx*dx + dy*dy))
                    
                    if distance < stoneRadius * 2.2 { // interaction range
                        let overlapForce = calculateAdvancedOverlapForce(
                            centerDistance: distance,
                            stoneRadius: stoneRadius
                        )
                        
                        force.x -= (dx / distance) * overlapForce
                        force.y -= (dy / distance) * overlapForce
                    }
                }
                
                // 3. Contact propagation forces (energy transmission through touching stones)
                if let stoneContacts = contacts[i] {
                    for contactIndex in stoneContacts {
                        let dx = stones[contactIndex].position.x - stones[i].position.x
                        let dy = stones[contactIndex].position.y - stones[i].position.y
                        let distance = sqrt(dx*dx + dy*dy)
                        
                        if distance > 0.1 {
                            // Transmitted force through contact
                            let transmittedForce = transmissionCoeff * temperature
                            force.x += (dx / distance) * transmittedForce
                            force.y += (dy / distance) * transmittedForce
                        }
                    }
                }
                
                // 4. Apply movement with simulated annealing
                let movement = CGPoint(
                    x: force.x * temperature * 0.3,
                    y: force.y * temperature * 0.3
                )
                
                stones[i] = StonePosition(
                    id: stones[i].id,
                    position: CGPoint(
                        x: stones[i].position.x + movement.x,
                        y: stones[i].position.y + movement.y
                    ),
                    isWhite: stones[i].isWhite
                )
                
                // Enforce bowl boundaries
                let newRadius = sqrt(stones[i].position.x * stones[i].position.x + 
                                   stones[i].position.y * stones[i].position.y)
                let maxRadius = bowlRadius * 0.75
                if newRadius > maxRadius {
                    stones[i] = StonePosition(
                        id: stones[i].id,
                        position: CGPoint(
                            x: stones[i].position.x * maxRadius / newRadius,
                            y: stones[i].position.y * maxRadius / newRadius
                        ),
                        isWhite: stones[i].isWhite
                    )
                }
                
                totalEnergy += sqrt(movement.x * movement.x + movement.y * movement.y)
            }
            
            temperature *= coolingRate
            
            // Check convergence
            if totalEnergy < 0.05 {
                return iteration + 1
            }
        }
        
        return maxIterations
    }
    
    private func buildContactGraph(_ stones: [StonePosition], stoneRadius: CGFloat) -> [Int: [Int]] {
        var contacts: [Int: [Int]] = [:]
        let contactThreshold = stoneRadius * 2.1 // slightly larger than diameter
        
        for i in stones.indices {
            contacts[i] = []
            for j in stones.indices {
                guard i != j else { continue }
                
                let dx = stones[j].position.x - stones[i].position.x
                let dy = stones[j].position.y - stones[i].position.y
                let distance = sqrt(dx*dx + dy*dy)
                
                if distance < contactThreshold {
                    contacts[i]?.append(j)
                }
            }
        }
        
        return contacts
    }
    
    private func calculateAdvancedOverlapForce(
        centerDistance: CGFloat,
        stoneRadius: CGFloat
    ) -> CGFloat {
        let overlapPercent = max(0, (2 * stoneRadius - centerDistance) / (2 * stoneRadius))
        
        // More sophisticated overlap penalty function
        if overlapPercent < 0.1 {
            return overlapPercent * 0.05 // very light contact
        } else if overlapPercent < 0.3 {
            return pow(overlapPercent, 2) * 0.8 // moderate escalation
        } else if overlapPercent < 0.7 {
            return pow(overlapPercent, 4) * 3.0 // steep energy barrier
        } else {
            return pow(overlapPercent, 3) * 5.0 // very high but finite energy
        }
    }
}

// MARK: - Simple RNG for deterministic physics (same as GroupDrop)
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