
// MARK: - File: BoardViewport.swift
import SwiftUI

struct Textures {
    let board: Image
    let blackStone: Image
    let clamVariants: [Image]

    static let `default` = Textures(
        board: Image("board_kaya"),
        blackStone: Image("stone_black"),
        clamVariants: (1...5).map { Image(String(format: "clam_%02d", $0)) }
    )
}

/// Immutable board snapshot used by the renderer.
struct BoardSnapshot: Equatable {
    let size: Int
    let grid: [[Stone?]] // [y][x]
}

enum Stone: Equatable { case black, white }

struct BoardViewport: View {
    let boardSize: Int
    let state: BoardSnapshot
    let textures: Textures
    let marginPercent: CGFloat   // e.g. 0.041

    // Human jitter parameter (0...5 from UI; used as “amount” in jitter)
    let eccentricity: CGFloat

    // Cell aspect (height / width). 1.04 ≈ subtle Japanese look
    let cellAspect: CGFloat

    // Stone shadow parameters (baseline values; we’ll scale them by tile size)
    let stoneShadowOpacity: CGFloat
    let stoneShadowRadius: CGFloat
    let stoneShadowOffsetX: CGFloat
    let stoneShadowOffsetY: CGFloat

    // Deterministic, per-intersection placement jitter.
    private func jitterOffset(gridX x: Int,
                              gridY y: Int,
                              amount: CGFloat,
                              stepX: CGFloat,
                              stepY: CGFloat) -> CGSize
    {
        guard amount > 0 else { return .zero }

        // Max jitter amplitude ≈ 18% of the stone diameter when amount == 5.
        let tile = min(stepX, stepY)
        let amp  = tile * 0.18 * (amount / 5.0)

        // Smooth, deterministic “noise” using simple sin blends — no RNG state.
        let jx = sin(CGFloat(x) * 12.9898 + CGFloat(y) * 78.233) * amp
        let jy = sin(CGFloat(x) * 26.6517 + CGFloat(y) * 47.313) * amp

        return CGSize(width: jx, height: jy)
    }

    var body: some View {
        ZStack {
            // Photoreal board texture
            textures.board
                .resizable()
                .aspectRatio(1, contentMode: .fit)

            // Grid + hoshi + stones
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size) // square drawing area
                let n = CGFloat(boardSize)

                // Constant border on all four sides, independent of aspect
                let margin: CGFloat = rect.width * marginPercent
                let innerRect = rect.insetBy(dx: margin, dy: margin)

                // Rectangular cells: stepX != stepY.
                let stepX = innerRect.width / max(1, (n - 1))
                let proposedStepY = stepX * max(0.75, cellAspect)   // clamp minimum
                let maxStepY = innerRect.height / max(1, (n - 1))
                let stepY = min(proposedStepY, maxStepY)

                // Center the grid vertically if needed
                let gridHeight = stepY * (n - 1)
                let vPad = (innerRect.height - gridHeight) * 0.5
                let gridRect = CGRect(
                    x: innerRect.minX,
                    y: innerRect.minY + max(0, vPad),
                    width: innerRect.width,
                    height: gridHeight
                )

                // --- Grid lines
                var path = Path()
                // vertical
                for i in 0..<boardSize {
                    let x = gridRect.minX + CGFloat(i) * stepX
                    path.move(to: CGPoint(x: x, y: gridRect.minY))
                    path.addLine(to: CGPoint(x: x, y: gridRect.maxY))
                }
                // horizontal
                for j in 0..<boardSize {
                    let y = gridRect.minY + CGFloat(j) * stepY
                    path.move(to: CGPoint(x: gridRect.minX, y: y))
                    path.addLine(to: CGPoint(x: gridRect.maxX, y: y))
                }
                ctx.stroke(
                    path,
                    with: .color(Color.black.opacity(0.45)),
                    lineWidth: max(1 as CGFloat, stepX * 0.025)
                )

                // --- Hoshi points (19x19)
                if boardSize == 19 {
                    let pts: [(Int, Int)] = [
                        (3,3),(3,9),(3,15),
                        (9,3),(9,9),(9,15),
                        (15,3),(15,9),(15,15)
                    ]
                    let r = min(stepX, stepY) * 0.09
                    for (ix, iy) in pts {
                        let x = gridRect.minX + CGFloat(ix) * stepX
                        let y = gridRect.minY + CGFloat(iy) * stepY
                        let dot = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2*r, height: 2*r))
                        ctx.fill(dot, with: .color(Color.black.opacity(0.7)))
                    }
                }

                // --- Stones with deterministic jitter + simple collision relaxation
                let tile = min(stepX, stepY)              // circular stone diameter that fits in the cell
                let minCenterDist = tile * 0.98           // keep centers just shy of one diameter apart
                let maxDisplacement = tile * 0.22         // clamp drift from intersection
                let relaxIterations = 8

                // Shadow scaling: at tile ≈ 44pt the raw slider values are 1×.
                let stoneShadowScale = tile / 44.0

                // 1) Collect stones with base centers and jittered centers
                struct StonePoint {
                    let ix: Int
                    let iy: Int
                    let baseX: CGFloat
                    let baseY: CGFloat
                    var cx: CGFloat
                    var cy: CGFloat
                    let stone: Stone
                }
                var pts: [StonePoint] = []
                pts.reserveCapacity(state.size * state.size)

                for y in 0..<state.size {
                    for x in 0..<state.size {
                        guard let s = state.grid[y][x] else { continue }
                        let baseX = gridRect.minX + CGFloat(x) * stepX
                        let baseY = gridRect.minY + CGFloat(y) * stepY
                        let j = jitterOffset(gridX: x, gridY: y,
                                             amount: eccentricity,
                                             stepX: stepX, stepY: stepY)
                        pts.append(StonePoint(ix: x, iy: y,
                                              baseX: baseX, baseY: baseY,
                                              cx: baseX + j.width, cy: baseY + j.height,
                                              stone: s))
                    }
                }

                // 2) Relax: push overlapping pairs apart, then clamp toward bases
                if pts.count > 1 {
                    for _ in 0..<relaxIterations {
                        for i in 0..<(pts.count - 1) {
                            for j in (i + 1)..<pts.count {
                                let dx = pts[j].cx - pts[i].cx
                                let dy = pts[j].cy - pts[i].cy
                                let d  = max(0.0001, hypot(dx, dy))
                                if d < minCenterDist {
                                    let overlap = (minCenterDist - d) * 0.5
                                    let ux = dx / d
                                    let uy = dy / d
                                    pts[i].cx -= ux * overlap
                                    pts[i].cy -= uy * overlap
                                    pts[j].cx += ux * overlap
                                    pts[j].cy += uy * overlap
                                }
                            }
                        }
                        for k in 0..<pts.count {
                            let dx = pts[k].cx - pts[k].baseX
                            let dy = pts[k].cy - pts[k].baseY
                            let clampedX = max(-maxDisplacement, min(maxDisplacement, dx))
                            let clampedY = max(-maxDisplacement, min(maxDisplacement, dy))
                            pts[k].cx = pts[k].baseX + clampedX
                            pts[k].cy = pts[k].baseY + clampedY
                        }
                    }
                }

                // 3) Draw with local shadow (board/grid unaffected), scaling the shadow
                for p in pts {
                    let dest = CGRect(x: p.cx - tile/2, y: p.cy - tile/2, width: tile, height: tile)
                    let img: GraphicsContext.ResolvedImage
                    if p.stone == .black {
                        img = ctx.resolve(textures.blackStone)
                    } else {
                        // deterministic pick: hash grid coords → 0..4
                        let idx = abs((p.ix &* 73856093) ^ (p.iy &* 19349663)) % textures.clamVariants.count
                        img = ctx.resolve(textures.clamVariants[idx])
                    }
                    ctx.drawLayer { layer in
                        if stoneShadowOpacity > 0, stoneShadowRadius > 0 {
                            layer.addFilter(.shadow(
                                color: .black.opacity(stoneShadowOpacity),
                                radius: stoneShadowRadius * stoneShadowScale,
                                x: stoneShadowOffsetX * stoneShadowScale,
                                y: stoneShadowOffsetY * stoneShadowScale
                            ))
                        }
                        layer.draw(img, in: dest)
                    }
                }

                // (latest stone marker intentionally removed)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .drawingGroup()
    }
}
