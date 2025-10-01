// MARK: - SimpleBoardView (Screensaver)
import Foundation
import CoreGraphics
import Cocoa

struct SimpleBoardRenderer {
    let boardSize: Int
    let stoneDiameter: CGFloat

    func renderBoard(
        board: BoardSnapshot,
        in context: CGContext,
        boardRect: CGRect,
        lastMove: MoveRef? = nil
    ) {
        let cellSize = min(boardRect.width, boardRect.height) / CGFloat(boardSize)
        let boardPixelSize = cellSize * CGFloat(boardSize - 1)

        // Center the board in the rect
        let boardOriginX = boardRect.midX - boardPixelSize / 2
        let boardOriginY = boardRect.midY - boardPixelSize / 2

        context.saveGState()

        // Draw board background
        context.setFillColor(CGColor(red: 0.85, green: 0.65, blue: 0.4, alpha: 1.0)) // Wood color
        context.fill(boardRect)

        // Draw grid lines
        context.setStrokeColor(CGColor.black)
        context.setLineWidth(1.0)

        // Vertical lines
        for x in 0..<boardSize {
            let lineX = boardOriginX + CGFloat(x) * cellSize
            context.move(to: CGPoint(x: lineX, y: boardOriginY))
            context.addLine(to: CGPoint(x: lineX, y: boardOriginY + boardPixelSize))
            context.strokePath()
        }

        // Horizontal lines
        for y in 0..<boardSize {
            let lineY = boardOriginY + CGFloat(y) * cellSize
            context.move(to: CGPoint(x: boardOriginX, y: lineY))
            context.addLine(to: CGPoint(x: boardOriginX + boardPixelSize, y: lineY))
            context.strokePath()
        }

        // Draw star points for 19x19 board
        if boardSize == 19 {
            let starPoints = [(3, 3), (3, 9), (3, 15), (9, 3), (9, 9), (9, 15), (15, 3), (15, 9), (15, 15)]
            context.setFillColor(CGColor.black)

            for (x, y) in starPoints {
                let pointX = boardOriginX + CGFloat(x) * cellSize
                let pointY = boardOriginY + CGFloat(y) * cellSize
                let pointRect = CGRect(
                    x: pointX - 3,
                    y: pointY - 3,
                    width: 6,
                    height: 6
                )
                context.fillEllipse(in: pointRect)
            }
        }

        // Draw stones
        for y in 0..<board.grid.count {
            for x in 0..<board.grid[y].count {
                if let stone = board.grid[y][x] {
                    let stoneX = boardOriginX + CGFloat(x) * cellSize - stoneDiameter / 2
                    let stoneY = boardOriginY + CGFloat(y) * cellSize - stoneDiameter / 2
                    let stoneRect = CGRect(
                        x: stoneX,
                        y: stoneY,
                        width: stoneDiameter,
                        height: stoneDiameter
                    )

                    // Draw stone
                    switch stone {
                    case .black:
                        context.setFillColor(CGColor.black)
                    case .white:
                        context.setFillColor(CGColor.white)
                    }
                    context.fillEllipse(in: stoneRect)

                    // Draw stone border
                    context.setStrokeColor(CGColor.black)
                    context.setLineWidth(1.0)
                    context.strokeEllipse(in: stoneRect)

                    // Highlight last move
                    if let lastMove = lastMove,
                       lastMove.x == x && lastMove.y == y {
                        context.setStrokeColor(CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
                        context.setLineWidth(3.0)
                        context.strokeEllipse(in: stoneRect)
                    }
                }
            }
        }

        context.restoreGState()
    }
}