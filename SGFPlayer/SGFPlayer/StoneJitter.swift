// MARK: - StoneJitter.swift
// Drop this into your project and add to the SGFPlayer target.

import CoreGraphics
import Foundation

/// Human-ish jitter generator + local relaxation (in *radius* units).
/// Stable across scrubbing thanks to seeded RNG (x,y,moveIndex).
final class StoneJitter {

    // Preset (radius-relative)
    struct Preset {
        var sigma:  CGFloat = 0.08   // std-dev of random offset (~8% of radius)
        var clamp:  CGFloat = 0.22   // hard clamp per-axis (radius units)
        var contact:CGFloat = 0.98   // min center distance / (2r). 1.0 = kissing
        var relaxIters: Int = 6      // how many smoothing passes when placed
    }

    // Public knob (0 = perfect, 1 = preset look, >1 = wilder)
    var eccentricity: CGFloat = 1.0 { didSet { recomputeEffective() } }

    // Live values (derived from preset + eccentricity)
    private var sigma:  CGFloat = 0.08
    private var clamp:  CGFloat = 0.22
    private var contact:CGFloat = 0.98
    private var relaxIters: Int = 6

    private var preset = Preset()

    // 2D per-intersection offsets (in radius units)
    // offsets[y][x] = CGPoint(ox, oy)
    private var offsets: [[CGPoint?]] = []
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
        guard newSize != size || offsets.isEmpty else { return }
        size = newSize
        offsets = Array(repeating: Array(repeating: nil, count: size), count: size)
        lastPreparedMove = .min
    }

    // Prepare before drawing the current position.
    // Pass in a boolean occupancy grid for currently placed stones.
    func prepare(forMove moveIndex: Int, boardSize: Int, occupied: [[Bool]]) {
        resizeIfNeeded(boardSize)
        if moveIndex != lastPreparedMove {
            // Clear offsets for *future* stones (we keep offsets for stones that exist)
            for y in 0..<size {
                for x in 0..<size {
                    if !occupied[y][x] { offsets[y][x] = nil }
                }
            }
            lastPreparedMove = moveIndex
        }
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
        // If we already have an offset (was placed before), reuse it.
        if let o = offsets[safe: y]?[safe: x] ?? nil { return o }

        // Draw a fresh jitter offset (gaussian in radius units, clamped)
        var s = seedFor(x: x, y: y, move: moveIndex)
        let g = gaussian2D(&s)
        var ox = clampValue(g.gx * sigma, maxAbs: clamp)
        var oy = clampValue(g.gy * sigma, maxAbs: clamp)

        // Save it
        let p = CGPoint(x: ox, y: oy)
        offsets[y][x] = p

        // Light local relaxation to avoid overlaps with neighbors
        relaxAround(cx: x, cy: y, r: r, occupied: occupied)

        // Return possibly-updated value
        let out = offsets[y][x] ?? p
        ox = clampValue(out.x, maxAbs: clamp)
        oy = clampValue(out.y, maxAbs: clamp)
        offsets[y][x] = CGPoint(x: ox, y: oy)
        return offsets[y][x]!
    }

    // MARK: - Internals

    private func recomputeEffective() {
        sigma   = preset.sigma * eccentricity
        // let clamp grow gently so tails aren’t squashed at high ecc.
        let clampScale = 0.75 + 0.25 * min(2.0, eccentricity) // 0..2 → 0.75..1.25
        clamp   = preset.clamp * clampScale
        contact = preset.contact
        relaxIters = preset.relaxIters
    }

    private func relaxAround(cx: Int, cy: Int, r: CGFloat, occupied: [[Bool]]) {
        guard size > 0 else { return }
        let minD = 2.0 * r * contact

        let xmin = max(0, cx - 2), xmax = min(size - 1, cx + 2)
        let ymin = max(0, cy - 2), ymax = min(size - 1, cy + 2)

        guard xmin <= xmax && ymin <= ymax else { return }

        for _ in 0..<relaxIters {
            for y in ymin...ymax {
                for x in xmin...xmax {
                    guard occupied[y][x] else { continue }

                    // Check a small set of neighbors to avoid double work
                    for (nx, ny) in [(x+1,y),(x,y+1),(x+1,y+1),(x-1,y+1)] {
                        guard nx >= xmin, nx <= xmax, ny >= ymin, ny <= ymax else { continue }
                        guard nx >= 0, ny >= 0, nx < size, ny < size else { continue }
                        guard occupied[ny][nx] else { continue }

                        let ax = CGFloat(x) + (offsets[y][x]?.x ?? 0)
                        let ay = CGFloat(y) + (offsets[y][x]?.y ?? 0)
                        let bx = CGFloat(nx) + (offsets[ny][nx]?.x ?? 0)
                        let by = CGFloat(ny) + (offsets[ny][nx]?.y ?? 0)

                        var dx = (bx - ax) * r
                        var dy = (by - ay) * r
                        var dist = hypot(dx, dy)
                        if dist < 1e-6 {
                            dx = CGFloat(nx - x) * 0.001
                            dy = CGFloat(ny - y) * 0.001
                            dist = hypot(dx, dy)
                        }
                        if dist < minD {
                            let need = (minD - dist) * 0.5
                            let ux = dx / dist
                            let uy = dy / dist

                            var A = offsets[y][x] ?? .zero
                            var B = offsets[ny][nx] ?? .zero

                            // convert pixel correction to radius units
                            A.x -= (need * ux) / r
                            A.y -= (need * uy) / r
                            B.x += (need * ux) / r
                            B.y += (need * uy) / r

                            A.x = clampValue(A.x, maxAbs: clamp)
                            A.y = clampValue(A.y, maxAbs: clamp)
                            B.x = clampValue(B.x, maxAbs: clamp)
                            B.y = clampValue(B.y, maxAbs: clamp)

                            offsets[y][x]   = A
                            offsets[ny][nx] = B
                        }
                    }
                }
            }
        }
    }

    @inline(__always) private func clampValue(_ v: CGFloat, maxAbs: CGFloat) -> CGFloat {
        min(max(v, -maxAbs), maxAbs)
    }

    // MARK: RNG (deterministic)

    private func seedFor(x: Int, y: Int, move: Int) -> UInt32 {
        var s = UInt32(bitPattern: Int32((x+11))) &* 73856093
        s ^= UInt32(bitPattern: Int32((y+17))) &* 19349663
        s ^= UInt32(bitPattern: Int32((move+23))) &* 83492791
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
