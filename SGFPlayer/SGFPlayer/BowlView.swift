// MARK: - File: BowlView.swift
import SwiftUI

struct BowlView: View {
    struct LidStone: Identifiable, Equatable {
        let id: UUID
        let imageName: String
        /// Position **relative to the lid center**, in points/pixels
        var offset: CGPoint
    }
    
    // Images & layout
    let lidImageName: String
    let center: CGPoint
    let lidSize: CGFloat        // pixels
    let stones: [LidStone]
    
    // Shadows (already scaled by caller)
    let lidShadowOpacity: CGFloat
    let lidShadowRadius: CGFloat
    let lidShadowDX: CGFloat
    let lidShadowDY: CGFloat
    
    let stoneShadowOpacity: CGFloat
    let stoneShadowRadius: CGFloat
    let stoneShadowDX: CGFloat
    let stoneShadowDY: CGFloat
    
    // Stone diameter on the **board** right now (so bowl stones match the board stones)
    let stoneDiameter: CGFloat  // pixels
    
    // --- Bowl physics (normalized) ---
    let repulsion: CGFloat
    let targetSpacingXRadius: CGFloat
    let centerPullPerLid: CGFloat
    let relaxIterations: Int

    // NEW: extra tunables
    let pressureRadiusXR: CGFloat   // default 2.6 (× stone radius)
    let pressureKFactor:  CGFloat   // default 0.25 (× repulsion)
    let maxStepXR:        CGFloat   // default 0.06 (× stone radius per iter)
    let damping:          CGFloat   // default 0.90
    let wallK:            CGFloat   // default 0.50
    let animDuration:     Double    // default 0.14
    
    // Local copy so we can animate relaxed positions
    @State private var layout: [UUID: CGPoint] = [:]
    
    var body: some View {
        ZStack {
            Image(lidImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: lidSize, height: lidSize)
                .shadow(color: .black.opacity(lidShadowOpacity),
                        radius: lidShadowRadius,
                        x: lidShadowDX, y: lidShadowDY)
                .position(center)
            
            ForEach(stones) { s in
                let p = layout[s.id] ?? s.offset
                Image(s.imageName)
                    .resizable()
                    .aspectRatio(1.0, contentMode: .fit)  // Force 1:1 aspect ratio
                    .frame(width: stoneDiameter, height: stoneDiameter)
                    .clipped()  // Ensure consistent bounds
                    .shadow(color: .black.opacity(stoneShadowOpacity),
                            radius: stoneShadowRadius,
                            x: stoneShadowDX, y: stoneShadowDY)
                    .position(x: center.x + p.x, y: center.y + p.y)
            }
        }
        // Recompute & animate relaxed layout whenever any relevant input changes
        .onAppear { animateRelax() }
        .onChange(of: stones) { _, _ in animateRelax() }
        .onChange(of: lidSize) { _, _ in animateRelax() }
        .onChange(of: stoneDiameter) { _, _ in animateRelax() }
        .onChange(of: repulsion) { _, _ in animateRelax() }
        .onChange(of: targetSpacingXRadius) { _, _ in animateRelax() }
        .onChange(of: centerPullPerLid) { _, _ in animateRelax() }
        .onChange(of: relaxIterations) { _, _ in animateRelax() }
    }
    
    // Drive the relaxation + animate into @State `layout` (adaptive, uses animDuration)
    private func animateRelax() {
        let newLayout = relaxedLayout()

        // If the movement is tiny, animate faster; if anything moved a bit, use a hair longer.
        var anyBigMove = false
        for s in stones {
            if let old = layout[s.id], let new = newLayout[s.id] {
                let dx = new.x - old.x, dy = new.y - old.y
                if (dx*dx + dy*dy) > 4.0 { // > ~2 px net
                    anyBigMove = true
                    break
                }
            } else {
                anyBigMove = true // initial layout or a newly–added stone
                break
            }
        }

        // Base timing comes from the slider; keep sensible floors so it never snaps.
        // Increased durations for more natural, slower stone movements
        let long  = max(0.4, animDuration * 3.0)      // for bigger moves - much slower
        let short = max(0.2, animDuration * 2.0)      // for tiny moves - slower

        withAnimation(.easeOut(duration: anyBigMove ? long : short)) {
            layout = newLayout
        }
    }
    
    // Compute a size-aware relaxed layout from current inputs
    private func relaxedLayout() -> [UUID: CGPoint] {
        // If relaxIterations is very low (like 5-10), assume we're using external physics (Physics 4/5)
        // and just use the provided positions directly
        if relaxIterations <= 10 {
            print("🎯 BowlView: Using external physics positions (relaxIterations=\(relaxIterations), stoneCount=\(stones.count))")
            let result = stones.reduce(into: [UUID: CGPoint]()) { $0[$1.id] = $1.offset }
            print("🎯 BowlView: External stone positions: \(result.values.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
            return result
        }
        
        // Otherwise use BowlView's internal physics
        let lidRadius = lidSize * 0.46                // conservative inner radius
        let rStone    = stoneDiameter * 0.5           // board-matched radius
        let desiredD  = max(0.0, targetSpacingXRadius) * rStone
        let pullDist  = centerPullPerLid * lidRadius  // pixels per iteration
        
        return relax(stones: stones,
                     desiredCenterDistance: desiredD,
                     repulsion: repulsion,
                     pullPerIter: pullDist,
                     keepWithin: lidRadius * 0.7,  // Keep stones in inner 70% of bowl
                     iterations: relaxIterations)
    }
    
    // MARK: - Size-aware relaxation (all forces normalized)
    // MARK: - Size-aware relaxation with pressure + damping
    private func relax(
        stones: [LidStone],
        desiredCenterDistance: CGFloat,
        repulsion: CGFloat,
        pullPerIter: CGFloat,
        keepWithin: CGFloat,
        iterations: Int
    ) -> [UUID: CGPoint] {
        
        guard !stones.isEmpty else { return [:] }
        
        // Current positions we’ll be updating
        var p = stones.reduce(into: [UUID: CGPoint]()) { $0[$1.id] = $1.offset }
        
        // --- Tunables (all size-relative) ---------------------------------------
        // Pressure pushes neighbors apart even when they’re not overlapping.
        // It acts within a short radius around each stone (a “cone” footprint).
        let rStoneGuess = max(1.0, desiredCenterDistance * 0.5) // stone radius ≈ desired/2
        let pressureRadius: CGFloat = 2.6 * rStoneGuess         // area a stone “loads”
        let pressureK: CGFloat = 0.25 * repulsion               // strength of the weight term
        
        // Motion control
        let maxStep: CGFloat = 0.10 * rStoneGuess               // clamp per iteration
        let damping: CGFloat = 0.82                              // viscous damping (lower = less slide)
        
        // Edge softness (don’t slam against the ring)
        let wallK: CGFloat = 0.35
        
        // Scratch “velocities” for this relaxation pass (purely local)
        var v = stones.reduce(into: [UUID: CGPoint]()) { $0[$1.id] = .zero }
        
        // Handle the trivial single-stone case early.
        if stones.count == 1 {
            let id = stones[0].id
            var pos = p[id]!
            let len = max(0.0001, hypot(pos.x, pos.y))
            let pull = min(pullPerIter, len)
            pos.x -= (pos.x / len) * pull
            pos.y -= (pos.y / len) * pull
            
            // soft clamp within bowl
            let r = max(0.0001, hypot(pos.x, pos.y))
            let maxR = max(0.0, keepWithin)
            if r > maxR {
                let s = maxR / r
                pos.x *= s; pos.y *= s
            }
            p[id] = pos
            return p
        }
        
        // --- Iterative relaxation ----------------------------------------------
        let iters = max(1, iterations)
        for _ in 0..<iters {
            
            // Accumulate forces
            var force = stones.reduce(into: [UUID: CGPoint]()) { $0[$1.id] = .zero }
            
            // Pairwise terms: overlap repulsion + pressure cone
            for i in 0..<(stones.count - 1) {
                for j in (i+1)..<stones.count {
                    let idA = stones[i].id, idB = stones[j].id
                    let ax = p[idA]!.x, ay = p[idA]!.y
                    let bx = p[idB]!.x, by = p[idB]!.y

                    var dx = bx - ax, dy = by - ay
                    var d  = sqrt(dx*dx + dy*dy)
                    if d < 0.0001 { d = 0.0001; dx = desiredCenterDistance; dy = 0 }
                    let ux = dx / d, uy = dy / d

                    // 1) Overlap-only push (keeps discs from interpenetrating)
                    if d < desiredCenterDistance {
                        let overlap = (desiredCenterDistance - d) * 0.5 * max(0, repulsion)
                        force[idA]!.x -= ux * overlap
                        force[idA]!.y -= uy * overlap
                        force[idB]!.x += ux * overlap
                        force[idB]!.y += uy * overlap
                    }

                    // 2) Weight/pressure “cone” (short range, encourages spreading)
                    if d < pressureRadius {
                        // Taper with distance; zero at the cone edge
                        let t = 1 - (d / pressureRadius)
                        let push = pressureK * t * t    // smooth falloff, bounded
                        // Push both ways (like two neighboring “loads” seeking area)
                        force[idA]!.x -= ux * push
                        force[idA]!.y -= uy * push
                        force[idB]!.x += ux * push
                        force[idB]!.y += uy * push
                    }
                }
            }

            // NEW: simple downward bias from stones above (encourages outward spread)
            // y grows downward in SwiftUI. Each “above” stone adds a tiny +y force,
            // tapered by vertical separation. Set `downBiasK = 0` to disable entirely.
            let downBiasK = max(0, desiredCenterDistance) * 0.02 // px per iter per above-stone
            if downBiasK > 0, stones.count > 1 {
                for i in 0..<stones.count {
                    let idI = stones[i].id
                    let yi = p[idI]!.y
                    var acc: CGFloat = 0
                    for j in 0..<stones.count where j != i {
                        let yj = p[stones[j].id]!.y
                        if yj < yi { // stone j is above i
                            let dy = yi - yj
                            // gentle falloff so far-above stones contribute less
                            acc += 1 / (1 + dy / max(1, desiredCenterDistance))
                        }
                    }
                    force[idI]!.y += acc * downBiasK
                }
            }
            
            // Center pull + soft wall clamp
            for s in stones {
                let id = s.id
                var pos = p[id]!
                var fx = force[id]!.x
                var fy = force[id]!.y
                
                // Concave pull (acts like friction/settling toward middle of the well)
                let len = max(0.0001, hypot(pos.x, pos.y))
                let pull = min(pullPerIter, len)
                fx += (-pos.x / len) * pull
                fy += (-pos.y / len) * pull
                
                // Soft wall (if outside keepWithin, nudge inward smoothly)
                let r = max(0.0001, hypot(pos.x, pos.y))
                let maxR = max(0.0, keepWithin)
                if r > maxR {
                    let inward = wallK * (r - maxR)
                    fx += (-pos.x / r) * inward
                    fy += (-pos.y / r) * inward
                }
                
                // Integrate with damping + step cap
                var vx = (v[id]!.x + fx) * damping
                var vy = (v[id]!.y + fy) * damping
                let vm = max(0.0001, sqrt(vx*vx + vy*vy))
                if vm > maxStep {
                    vx *= (maxStep / vm)
                    vy *= (maxStep / vm)
                }
                v[id] = CGPoint(x: vx, y: vy)
                pos.x += vx; pos.y += vy
                p[id] = pos
            }
        }
        
        return p
    }
}
