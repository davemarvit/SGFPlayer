// MARK: - File: BowlView.swift
import Foundation
import CoreGraphics
import Cocoa

struct LidStone {
    let id = UUID()
    let isWhite: Bool
    var offset: CGPoint
}

struct BowlRenderer {
    let lidSize: CGFloat
    let stoneDiameter: CGFloat
    let repulsion: CGFloat
    let targetSpacingXRadius: CGFloat
    let centerPullPerLid: CGFloat
    let relaxIterations: Int

    func renderBowl(at center: CGPoint, with stones: [LidStone], in context: CGContext) {
        // Draw lid background (simplified circle)
        context.saveGState()
        context.setFillColor(NSColor.brown.cgColor)
        let lidRect = CGRect(
            x: center.x - lidSize/2,
            y: center.y - lidSize/2,
            width: lidSize,
            height: lidSize
        )
        context.fillEllipse(in: lidRect)

        // Draw stones in the bowl
        let layout = relaxedLayout(stones: stones)

        for stone in stones {
            guard let position = layout[stone.id] else { continue }

            let stoneX = center.x + position.x - stoneDiameter/2
            let stoneY = center.y + position.y - stoneDiameter/2
            let stoneRect = CGRect(x: stoneX, y: stoneY, width: stoneDiameter, height: stoneDiameter)

            // Draw stone
            context.setFillColor(stone.isWhite ? NSColor.white.cgColor : NSColor.black.cgColor)
            context.fillEllipse(in: stoneRect)

            // Draw stone border
            context.setStrokeColor(NSColor.gray.cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: stoneRect)
        }

        context.restoreGState()
    }

    private func relaxedLayout(stones: [LidStone]) -> [UUID: CGPoint] {
        guard !stones.isEmpty else { return [:] }

        // If very few iterations, use original positions
        if relaxIterations <= 10 {
            return stones.reduce(into: [UUID: CGPoint]()) { $0[$1.id] = $1.offset }
        }

        // Simple physics relaxation
        let lidRadius = lidSize * 0.46
        let rStone = stoneDiameter * 0.5
        let desiredD = max(0.0, targetSpacingXRadius) * rStone
        let pullDist = centerPullPerLid * lidRadius

        return relax(
            stones: stones,
            desiredCenterDistance: desiredD,
            repulsion: repulsion,
            pullPerIter: pullDist,
            keepWithin: lidRadius * 0.7,
            iterations: relaxIterations
        )
    }

    private func relax(
        stones: [LidStone],
        desiredCenterDistance: CGFloat,
        repulsion: CGFloat,
        pullPerIter: CGFloat,
        keepWithin: CGFloat,
        iterations: Int
    ) -> [UUID: CGPoint] {

        guard !stones.isEmpty else { return [:] }

        var positions = stones.reduce(into: [UUID: CGPoint]()) { $0[$1.id] = $1.offset }

        // Simple single stone case
        if stones.count == 1 {
            let id = stones[0].id
            var pos = positions[id]!
            let len = max(0.0001, hypot(pos.x, pos.y))
            let pull = min(pullPerIter, len)
            pos.x -= (pos.x / len) * pull
            pos.y -= (pos.y / len) * pull

            let r = max(0.0001, hypot(pos.x, pos.y))
            let maxR = max(0.0, keepWithin)
            if r > maxR {
                let s = maxR / r
                pos.x *= s
                pos.y *= s
            }
            positions[id] = pos
            return positions
        }

        // Iterative relaxation for multiple stones
        for _ in 0..<max(1, iterations) {
            var forces = stones.reduce(into: [UUID: CGPoint]()) { $0[$1.id] = .zero }

            // Calculate pairwise repulsion
            for i in 0..<(stones.count - 1) {
                for j in (i+1)..<stones.count {
                    let idA = stones[i].id
                    let idB = stones[j].id
                    let posA = positions[idA]!
                    let posB = positions[idB]!

                    var dx = posB.x - posA.x
                    var dy = posB.y - posA.y
                    var distance = sqrt(dx*dx + dy*dy)

                    if distance < 0.0001 {
                        distance = 0.0001
                        dx = desiredCenterDistance
                        dy = 0
                    }

                    let ux = dx / distance
                    let uy = dy / distance

                    if distance < desiredCenterDistance {
                        let overlap = (desiredCenterDistance - distance) * 0.5 * repulsion
                        forces[idA]!.x -= ux * overlap
                        forces[idA]!.y -= uy * overlap
                        forces[idB]!.x += ux * overlap
                        forces[idB]!.y += uy * overlap
                    }
                }
            }

            // Apply forces and center pull
            for stone in stones {
                let id = stone.id
                var pos = positions[id]!
                let force = forces[id]!

                // Center pull
                let len = max(0.0001, hypot(pos.x, pos.y))
                let pull = min(pullPerIter, len)
                let centerForceX = (-pos.x / len) * pull
                let centerForceY = (-pos.y / len) * pull

                // Update position
                pos.x += force.x + centerForceX
                pos.y += force.y + centerForceY

                // Keep within bounds
                let r = max(0.0001, hypot(pos.x, pos.y))
                let maxR = max(0.0, keepWithin)
                if r > maxR {
                    let s = maxR / r
                    pos.x *= s
                    pos.y *= s
                }

                positions[id] = pos
            }
        }

        return positions
    }
}