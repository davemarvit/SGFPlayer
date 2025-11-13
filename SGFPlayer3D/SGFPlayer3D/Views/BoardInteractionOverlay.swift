// MARK: - Board Interaction Overlay
// Handles mouse interactions for placing moves on the Go board
// Shows phantom stones during mouse hover/drag and sends moves to OGS

import SwiftUI
import AppKit

/// Overlay view that handles board clicks and shows phantom stones
struct BoardInteractionOverlay: View {
    let boardFrame: CGRect
    let gridSize: Int
    @ObservedObject var player: SGFPlayer
    @ObservedObject var ogsClient: OGSClient

    @State private var phantomStonePosition: (x: Int, y: Int)?
    @State private var isMouseDown: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent interaction layer that captures all mouse events
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleMouseMove(at: value.location, isDown: true)
                            }
                            .onEnded { value in
                                handleMouseUp(at: value.location)
                            }
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            if !isMouseDown {
                                handleMouseMove(at: location, isDown: false)
                            }
                        case .ended:
                            if !isMouseDown {
                                phantomStonePosition = nil
                            }
                        }
                    }

                // v3.117: Phantom stone rendering - always show on hover for preview
                if let position = phantomStonePosition {
                    renderPhantomStone(at: position)
                }
            }
        }
        .frame(width: boardFrame.width, height: boardFrame.height)
        .position(x: boardFrame.midX, y: boardFrame.midY)
    }

    private func handleMouseMove(at location: CGPoint, isDown: Bool) {
        isMouseDown = isDown

        // v3.117: Simplified - always show phantom stone on hover for preview/visualization
        // Convert screen coordinates to board position
        if let boardPos = screenToBoardPosition(location) {
            // Check if position is empty
            if player.board.grid[boardPos.y][boardPos.x] == nil {
                phantomStonePosition = boardPos
            } else {
                phantomStonePosition = nil
            }
        } else {
            phantomStonePosition = nil
        }
    }

    private func handleMouseUp(at location: CGPoint) {
        isMouseDown = false

        // Only send move if it's our turn and game is in progress
        guard ogsClient.isMyTurn,
              ogsClient.gamePhase == .playing,
              let position = phantomStonePosition,
              let gameID = ogsClient.currentGameID else {
            phantomStonePosition = nil
            return
        }

        // Convert board position to SGF notation
        let sgfMove = boardPositionToSGF(x: position.x, y: position.y)

        // Send move to OGS
        NSLog("BoardInteraction: 🎯 Sending move: \(sgfMove) at (\(position.x), \(position.y))")
        ogsClient.sendMove(gameID: gameID, move: sgfMove)

        // Clear phantom stone
        phantomStonePosition = nil
    }

    private func screenToBoardPosition(_ screenPoint: CGPoint) -> (x: Int, y: Int)? {
        // Calculate grid dimensions with traditional Go board ratio
        let cellRatio: CGFloat = 15.0 / 14.0
        let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let cellWidth = baseCellWidth
        let cellHeight = baseCellWidth * cellRatio
        let gridWidth = cellWidth * CGFloat(gridSize - 1)
        let gridHeight = cellHeight * CGFloat(gridSize - 1)

        // Center the grid within the board frame
        let offsetX = (boardFrame.width - gridWidth) / 2
        let offsetY = (boardFrame.height - gridHeight) / 2

        // Convert screen point to board frame coordinates
        let localX = screenPoint.x - boardFrame.minX
        let localY = screenPoint.y - boardFrame.minY

        // Convert to grid coordinates
        let gridX = (localX - offsetX) / cellWidth
        let gridY = (localY - offsetY) / cellHeight

        // Round to nearest intersection
        let x = Int(round(gridX))
        let y = Int(round(gridY))

        // Check bounds
        if x >= 0 && x < gridSize && y >= 0 && y < gridSize {
            return (x, y)
        }

        return nil
    }

    private func boardPositionToSGF(x: Int, y: Int) -> String {
        // Convert board coordinates to SGF notation (e.g., (3,3) -> "dd")
        let letters = "abcdefghijklmnopqrs"
        let xChar = letters[letters.index(letters.startIndex, offsetBy: x)]
        let yChar = letters[letters.index(letters.startIndex, offsetBy: y)]
        return "\(xChar)\(yChar)"
    }

    @ViewBuilder
    private func renderPhantomStone(at position: (x: Int, y: Int)) -> some View {
        let cellRatio: CGFloat = 15.0 / 14.0
        let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let cellWidth = baseCellWidth
        let cellHeight = baseCellWidth * cellRatio
        let gridWidth = cellWidth * CGFloat(gridSize - 1)
        let gridHeight = cellHeight * CGFloat(gridSize - 1)

        let offsetX = (boardFrame.width - gridWidth) / 2
        let offsetY = (boardFrame.height - gridHeight) / 2

        let stoneX = boardFrame.minX + offsetX + CGFloat(position.x) * cellWidth
        let stoneY = boardFrame.minY + offsetY + CGFloat(position.y) * cellHeight

        // v3.117: Determine stone color - use OGS player color if available, otherwise alternate
        let stoneColor: Stone
        if let playerColor = ogsClient.playerColor {
            stoneColor = playerColor
        } else {
            // Alternate: black plays on even moves (0, 2, 4...), white on odd (1, 3, 5...)
            stoneColor = (player.currentIndex % 2 == 0) ? .black : .white
        }
        let imageName = stoneColor == .black ? "stone_black" : "clam_01"

        // Stone size (slightly smaller than actual stones)
        let realBlackStoneDiameter: CGFloat = 22.2
        let realWhiteStoneDiameter: CGFloat = 21.9
        let realCellWidth: CGFloat = 22.0
        let stoneSize = stoneColor == .black
            ? (realBlackStoneDiameter / realCellWidth) * cellWidth * 0.95
            : (realWhiteStoneDiameter / realCellWidth) * cellWidth * 0.95

        Image(imageName)
            .resizable()
            .frame(width: stoneSize, height: stoneSize)
            .opacity(isMouseDown ? 0.5 : 0.7)  // More transparent on mouse down
            .position(x: stoneX, y: stoneY)
    }
}
