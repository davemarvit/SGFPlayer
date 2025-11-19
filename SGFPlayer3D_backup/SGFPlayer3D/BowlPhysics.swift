// MARK: - File: BowlPhysics.swift
import SwiftUI
import simd

/// Places stones inside a circular lid using
///  - random start (seeded per game + per stone)
///  - center pull (concave lid bias)
///  - pairwise repulsion (avoid overlap)
/// Returns normalized positions in [-1, +1] unit circle (x,y).
struct BowlPhysics {

    struct Point: Equatable { var x: CGFloat; var y: CGFloat }

    static func layout(
        stoneCount: Int,
        seed: UInt64,
        centerPull: CGFloat = 0.045,   // base pull per iteration toward center
        repel: CGFloat = 0.70,         // strength of pairwise push
        iterations: Int = 14
    ) -> [Point] {
        guard stoneCount > 0 else { return [] }

        // Deterministic RNG
        var rng = PCG64(seed: seed)

        // Start from jittered points inside unit circle, biased more toward center
        var p = (0..<stoneCount).map { i -> Point in
            // Unique per stone seed
            let t = rng.nextUnit()
            let r = 0.75 * sqrt(CGFloat(rng.nextUnit()))       // reduced from 0.85, more center bias
            let a = 2 * .pi * CGFloat(t)
            return Point(x: r * cos(a), y: r * sin(a))
        }

        // Advanced relaxation with adaptive physics
        for _ in 0..<iterations {
            // Gentle center pull - only for stones getting too far out
            for i in 0..<p.count {
                let currentR = sqrt(p[i].x*p[i].x + p[i].y*p[i].y)
                
                // Only apply pull if stone is getting far from center
                if currentR > 0.4 {
                    let distanceFactor = (currentR - 0.4) * 1.5  // gradual increase
                    let adaptivePull = centerPull * distanceFactor
                    p[i].x *= (1 - adaptivePull)
                    p[i].y *= (1 - adaptivePull)
                }
            }
            
            // Natural repulsion - only when stones are too close
            for i in 0..<p.count {
                for j in (i+1)..<p.count {
                    let dx = p[j].x - p[i].x
                    let dy = p[j].y - p[i].y
                    let d2 = dx*dx + dy*dy + 1e-6
                    let d  = sqrt(d2)
                    
                    // Only repel if stones are overlapping or very close
                    let comfortableDistance: CGFloat = 0.12
                    if d < comfortableDistance {
                        let overlap = comfortableDistance - d
                        let push = repel * overlap * 0.5  // gentle push
                        let ux = dx / max(d, 0.001), uy = dy / max(d, 0.001)
                        p[i].x -= ux * push * 0.5
                        p[i].y -= uy * push * 0.5
                        p[j].x += ux * push * 0.5
                        p[j].y += uy * push * 0.5
                    }
                }
            }
            
            // Soft wall with stronger edge repulsion
            for i in 0..<p.count {
                let r = sqrt(p[i].x*p[i].x + p[i].y*p[i].y)
                let maxR: CGFloat = 0.85  // tighter boundary
                
                if r > maxR {
                    // Strong pushback from edge
                    let overshoot = r - maxR
                    let pushbackStrength = min(0.3, overshoot * 2.0)  // strong correction
                    let normalizedX = p[i].x / r
                    let normalizedY = p[i].y / r
                    
                    p[i].x = normalizedX * (maxR - pushbackStrength * overshoot)
                    p[i].y = normalizedY * (maxR - pushbackStrength * overshoot)
                } else if r > 0.75 {
                    // Gentle inward nudge for stones approaching edge
                    let edgeFactor = (r - 0.75) / (maxR - 0.75)  // 0 to 1 as approaching edge
                    let inwardPull = centerPull * 2.0 * edgeFactor
                    p[i].x *= (1 - inwardPull)
                    p[i].y *= (1 - inwardPull)
                }
            }
        }

        return p
    }
}

// MARK: - Safe deterministic RNG (Simple LCG)
fileprivate struct PCG64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }
    
    mutating func nextRaw() -> UInt32 {
        // Simple LCG with safe operations - same as SimpleRNG
        state = state &* 1103515245 &+ 12345
        return UInt32((state >> 16) & 0x7FFF_FFFF)
    }
    
    mutating func nextUnit() -> Double { 
        Double(nextRaw()) / Double(0x7FFF_FFFF)
    }
}
