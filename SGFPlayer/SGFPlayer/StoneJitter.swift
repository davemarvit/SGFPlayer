// MARK: - StoneJitter.swift
// Drop this into your project and add to the SGFPlayer target.

import CoreGraphics
import Foundation

/// Human-ish jitter generator + local relaxation (in *radius* units).
/// Stable across scrubbing thanks to seeded RNG (x,y,moveIndex).
final class StoneJitter {

    // Preset (radius-relative)
    struct Preset {
        var sigma:  CGFloat = 0.12   // std-dev of random offset (~12% of radius)
        var clamp:  CGFloat = 0.25   // hard clamp per-axis (radius units)
        var minDistance: CGFloat = 0.8  // minimum distance between stone centers (in grid units) - require very close contact
        var pushStrength: CGFloat = 0.3  // how strong collision displacement is - keep small for realistic movement
    }

    // Public knob (0 = perfect, 1 = preset look, >1 = wilder)
    var eccentricity: CGFloat = 1.0 { didSet { recomputeEffective() } }

    // Live values (derived from preset + eccentricity)
    private var sigma:  CGFloat = 0.12
    private var clamp:  CGFloat = 0.25
    private var minDistance: CGFloat = 1.8
    private var pushStrength: CGFloat = 0.3

    private var preset = Preset()

    // 2D per-intersection offsets (in radius units)
    // initialJitter[y][x] = CGPoint(ox, oy) - the base random jitter, stable per position
    // finalOffsets[y][x] = CGPoint(ox, oy) - after relaxation, calculated fresh each time
    private var initialJitter: [[CGPoint?]] = []
    private var finalOffsets: [[CGPoint?]] = []
    private var size: Int = 0

    // Cache key lets us invalidate when the SGF move changes
    private var lastPreparedMove: Int = .min

    init(size: Int = 0, eccentricity: CGFloat = 1.0) {
        self.size = size
        self.eccentricity = eccentricity
        recomputeEffective()
        resizeIfNeeded(size)
    }

    // Call whenever board size changes (19, 13, 9…)
    func resizeIfNeeded(_ newSize: Int) {
        guard newSize != size || initialJitter.isEmpty else { return }
        size = newSize
        initialJitter = Array(repeating: Array(repeating: nil, count: size), count: size)
        finalOffsets = Array(repeating: Array(repeating: nil, count: size), count: size)
        lastPreparedMove = .min
    }

    // Prepare before drawing the current position.
    // Pass in a boolean occupancy grid for currently placed stones.
    func prepare(forMove moveIndex: Int, boardSize: Int, occupied: [[Bool]]) {
        resizeIfNeeded(boardSize)
        if moveIndex != lastPreparedMove {
            // Clear initial jitter for positions that are no longer occupied
            // This preserves stable base jitter for existing stones
            for y in 0..<size {
                for x in 0..<size {
                    if !occupied[y][x] {
                        initialJitter[y][x] = nil
                        finalOffsets[y][x] = nil
                    }
                }
            }

            // FIXED: Only clear final offsets for stones that could be affected by relaxation
            // Instead of clearing all offsets, only clear offsets for stones within
            // relaxation range of newly placed or removed stones
            clearAffectedRegions(occupied: occupied)

            lastPreparedMove = moveIndex
        }
    }

    // Clear final offsets only for regions that could be affected by stone placement/removal
    private func clearAffectedRegions(occupied: [[Bool]]) {
        // For now, only clear final offsets for positions that have stones
        // This prevents isolated stones from moving when unrelated stones are played
        for y in 0..<size {
            for x in 0..<size {
                if occupied[y][x] {
                    // Only clear if this stone might be affected by neighboring changes
                    if hasNearbyChanges(x: x, y: y, occupied: occupied) {
                        finalOffsets[y][x] = nil
                    }
                }
            }
        }
    }

    // Check if a stone position might be affected by nearby changes
    private func hasNearbyChanges(x: Int, y: Int, occupied: [[Bool]]) -> Bool {
        // Check only immediate adjacent positions for direct stone collisions
        let range = 1 // Check only adjacent cells for direct interactions
        let xmin = max(0, x - range)
        let xmax = min(size - 1, x + range)
        let ymin = max(0, y - range)
        let ymax = min(size - 1, y + range)

        for ny in ymin...ymax {
            for nx in xmin...xmax {
                if nx != x || ny != y {
                    // If there's a stone nearby, this position might need recalculation
                    if occupied[ny][nx] {
                        return true
                    }
                }
            }
        }
        return false
    }

    // Returns the jitter offset (in *radius* units) for a stone being shown at (x,y).
    // - Parameters:
    //   - x,y: board coordinates
    //   - moveIndex: current move index (stable seeding while scrubbing)
    //   - r: stone radius in pixels (used only for relaxation math)
    //   - occupied: current occupancy grid (true if a stone is present)
    func offset(forX x: Int,
                y: Int,
                moveIndex: Int,
                radius r: CGFloat,
                occupied: [[Bool]]) -> CGPoint {

        // Early exit if no jitter
        if eccentricity <= 0.001 {
            return .zero
        }

        // If we already have a final offset calculated, return it
        if let finalOffset = finalOffsets[safe: y]?[safe: x] ?? nil {
            return finalOffset
        }
        if (initialJitter[safe: y]?[safe: x] ?? nil) == nil {
            // Draw a fresh jitter offset (gaussian in radius units, clamped)
            var s = seedFor(x: x, y: y, move: moveIndex)
            let g = gaussian2D(&s)

            // Apply random sign assignment based on position to ensure natural distribution
            let signSeedX = seedFor(x: x * 3, y: y, move: moveIndex)
            let signSeedY = seedFor(x: x, y: y * 3, move: moveIndex)
            let signX: CGFloat = (signSeedX % 2 == 0) ? 1.0 : -1.0
            let signY: CGFloat = (signSeedY % 2 == 0) ? 1.0 : -1.0

            let ox = clampValue(abs(g.gx) * sigma * signX, maxAbs: clamp)
            let oy = clampValue(abs(g.gy) * sigma * signY, maxAbs: clamp)

            initialJitter[y][x] = CGPoint(x: ox, y: oy)
        }

        // Start with initial jitter
        guard let initialOffset = initialJitter[y][x] else {
            // This shouldn't happen since we just created it above, but safety first
            return .zero
        }
        finalOffsets[y][x] = initialOffset

        // Skip collision detection if jitter is minimal (performance optimization)
        if eccentricity > 0.1 {
            // Resolve collisions with neighboring stones
            resolveCollisions(cx: x, cy: y, r: r, occupied: occupied)
        }

        // Return final relaxed position, clamped
        guard let finalOffset = finalOffsets[y][x] else {
            return .zero // Safety fallback
        }
        let clampedOffset = CGPoint(
            x: clampValue(finalOffset.x, maxAbs: clamp),
            y: clampValue(finalOffset.y, maxAbs: clamp)
        )
        finalOffsets[y][x] = clampedOffset

        return clampedOffset
    }

    // Force clear all cached jitter (for when eccentricity changes)
    func clearCache() {
        for y in 0..<size {
            for x in 0..<size {
                initialJitter[y][x] = nil
                finalOffsets[y][x] = nil
            }
        }
        lastPreparedMove = .min
    }

    // Clear only final offsets (keeps stable base jitter but forces collision recalculation)
    func clearFinalOffsetsOnly() {
        for y in 0..<size {
            for x in 0..<size {
                finalOffsets[y][x] = nil
            }
        }
        // Don't reset lastPreparedMove - we only want to recalculate collisions
    }

    // MARK: - Internals

    private func recomputeEffective() {
        sigma = preset.sigma * eccentricity
        clamp = preset.clamp * eccentricity
        minDistance = preset.minDistance
        pushStrength = preset.pushStrength
    }

    private func resolveCollisions(cx: Int, cy: Int, r: CGFloat, occupied: [[Bool]], depth: Int = 0) {
        guard size > 0 else { return }
        guard depth < 2 else { return } // Limit cascade to prevent excessive stone movement
        guard cx >= 0, cy >= 0, cx < size, cy < size else { return }
        guard cy < finalOffsets.count, cx < finalOffsets[cy].count else { return }

        // Get position of the newly placed stone (at cx, cy)
        guard let centerStoneOffset = finalOffsets[cy][cx] else { return }
        let centerPos = CGPoint(
            x: CGFloat(cx) + centerStoneOffset.x,
            y: CGFloat(cy) + centerStoneOffset.y
        )

        // Check only orthogonal neighbors for realistic collision detection
        let adjacentPositions = [
            (cx-1, cy), (cx+1, cy),  // horizontal neighbors
            (cx, cy-1), (cx, cy+1)   // vertical neighbors
            // Note: diagonal neighbors removed - too far apart for natural stone contact
        ]

        for (nx, ny) in adjacentPositions {
            guard nx >= 0, ny >= 0, nx < size, ny < size else { continue }
            guard ny < occupied.count, nx < occupied[ny].count else { continue }
            guard occupied[ny][nx] else { continue }
            guard nx != cx || ny != cy else { continue }
            guard ny < finalOffsets.count, nx < finalOffsets[ny].count else { continue }

            // Get neighboring stone position
            let neighborOffset = finalOffsets[ny][nx] ?? .zero
            let neighborPos = CGPoint(
                x: CGFloat(nx) + neighborOffset.x,
                y: CGFloat(ny) + neighborOffset.y
            )

            // Calculate distance between stone centers accounting for rectangular cells
            let dx = neighborPos.x - centerPos.x
            let dy = neighborPos.y - centerPos.y

            // Normalize for cell aspect ratio: horizontal = 22mm, vertical = 23.7mm
            let cellAspectRatio = 23.7 / 22.0 // vertical/horizontal spacing ratio
            let normalizedDy = dy / cellAspectRatio // convert vertical distance to horizontal units
            let distance = hypot(dx, normalizedDy)

            // Check if stones are too close (collision)
            if distance < minDistance && distance > 0.001 {
                // Calculate push direction accounting for cell aspect ratio
                let normalizedDistance = hypot(dx, normalizedDy)
                let pushDir = CGPoint(
                    x: dx / normalizedDistance,
                    y: normalizedDy / normalizedDistance * cellAspectRatio // convert back to actual cell units
                )

                // Calculate how much to push apart
                let overlap = minDistance - distance
                let pushAmount = overlap * pushStrength

                // Push the neighboring stone away along the contact line
                var newNeighborOffset = neighborOffset
                newNeighborOffset.x += pushDir.x * pushAmount
                newNeighborOffset.y += pushDir.y * pushAmount

                // Clamp the neighbor's offset
                newNeighborOffset.x = clampValue(newNeighborOffset.x, maxAbs: clamp)
                newNeighborOffset.y = clampValue(newNeighborOffset.y, maxAbs: clamp)

                // Safely update the neighbor's offset
                if ny < finalOffsets.count && nx < finalOffsets[ny].count {
                    finalOffsets[ny][nx] = newNeighborOffset
                }

                // Chain reaction: check if this pushed stone now collides with others
                resolveCollisions(cx: nx, cy: ny, r: r, occupied: occupied, depth: depth + 1)
            }
        }
    }

    @inline(__always) private func clampValue(_ v: CGFloat, maxAbs: CGFloat) -> CGFloat {
        min(max(v, -maxAbs), maxAbs)
    }

    // MARK: RNG (deterministic)

    private func seedFor(x: Int, y: Int, move: Int) -> UInt32 {
        // Take absolute values to prevent negative value crashes
        let safeX = abs(x + 11)
        let safeY = abs(y + 17)
        let safeMove = abs(move + 23)

        var s = UInt32(safeX) &* 73856093
        s ^= UInt32(safeY) &* 19349663
        s ^= UInt32(safeMove) &* 83492791
        s = s == 0 ? 0x9e3779b9 : s
        return s
    }

    private func xorshift32(_ s: inout UInt32) -> Double {
        s ^= s << 13
        s ^= s >> 17
        s ^= s << 5
        return Double(s) / 4294967296.0
    }

    /// Box–Muller → 2-D gaussian (mean 0, std 1)
    private func gaussian2D(_ state: inout UInt32) -> (gx: CGFloat, gy: CGFloat) {
        let u1 = max(xorshift32(&state), 1e-9)
        let u2 = xorshift32(&state)
        let mag = sqrt(-2.0 * log(u1))
        let a = 2.0 * Double.pi * u2
        return (CGFloat(mag * cos(a)), CGFloat(mag * sin(a)))
    }
}

// Safe index helper
private extension Array {
    subscript(safe index: Int) -> Element? { (0..<count).contains(index) ? self[index] : nil }
}
