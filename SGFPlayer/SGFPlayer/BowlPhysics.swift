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
        centerPull: CGFloat = 0.045,   // pull per iteration toward center
        repel: CGFloat = 0.70,         // strength of pairwise push
        iterations: Int = 14
    ) -> [Point] {
        guard stoneCount > 0 else { return [] }

        // Deterministic RNG
        var rng = PCG64(seed: seed)

        // Start from jittered points inside unit circle
        var p = (0..<stoneCount).map { i -> Point in
            // Unique per stone seed
            let t = rng.nextUnit()
            let r = 0.85 * sqrt(CGFloat(rng.nextUnit()))       // biased inward
            let a = 2 * .pi * CGFloat(t)
            return Point(x: r * cos(a), y: r * sin(a))
        }

        // Simple relaxation
        for _ in 0..<iterations {
            // center pull
            for i in 0..<p.count {
                p[i].x *= (1 - centerPull)
                p[i].y *= (1 - centerPull)
            }
            // pairwise repulsion
            for i in 0..<p.count {
                for j in (i+1)..<p.count {
                    let dx = p[j].x - p[i].x
                    let dy = p[j].y - p[i].y
                    let d2 = dx*dx + dy*dy + 1e-6
                    let d  = sqrt(d2)
                    // inverse distance push
                    let push = repel / max(d, 0.001)
                    let ux = dx / d, uy = dy / d
                    p[i].x -= ux * push * 0.5
                    p[i].y -= uy * push * 0.5
                    p[j].x += ux * push * 0.5
                    p[j].y += uy * push * 0.5
                }
            }
            // clamp to unit circle
            for i in 0..<p.count {
                let r = sqrt(p[i].x*p[i].x + p[i].y*p[i].y)
                if r > 0.98 {
                    p[i].x *= 0.98 / r
                    p[i].y *= 0.98 / r
                }
            }
        }

        return p
    }
}

// MARK: - Tiny deterministic RNG (PCG)
fileprivate struct PCG64 {
    private var state: UInt64
    private var inc: UInt64 = 0x5851f42d4c957f2d

    init(seed: UInt64) {
        state = seed &+ 0x9e3779b97f4a7c15
        _ = nextRaw()
    }
    mutating func nextRaw() -> UInt32 {
        let oldstate = state
        state = oldstate &* 6364136223846793005 &+ (inc | 1)
        var xorshifted = UInt32(((oldstate >> 18) ^ oldstate) >> 27)
        let rot = UInt32(oldstate >> 59)
        return (xorshifted >> rot) | (xorshifted << ((~rot &+ 1) & 31))
    }
    mutating func nextUnit() -> Double { Double(nextRaw()) / Double(UInt32.max) }
}
