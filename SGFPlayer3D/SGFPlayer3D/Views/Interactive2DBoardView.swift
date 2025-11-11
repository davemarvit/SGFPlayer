// MARK: - Interactive 2D Board View
// Adds tap handling for live game play to the 2D board

import SwiftUI

struct Interactive2DBoardView: View {
    @ObservedObject var player: SGFPlayer
    @ObservedObject var ogsClient: OGSClient
    let physicsIntegration: PhysicsIntegration
    let boardStoneDiameter: CGFloat
    @ObservedObject var gameCacheManager: GameCacheManager

    // Board positioning
    let boardFrame: CGRect
    let ulBowlCenter: CGPoint
    let lrBowlCenter: CGPoint
    let bowlRadius: CGFloat

    // Hover state for phantom stone
    @State private var hoverPosition: CGPoint? = nil
    @State private var hoverBoardCoords: (row: Int, col: Int)? = nil

    var body: some View {
        ZStack {
            // Existing board rendering
            SimpleBoardView(
                player: player,
                physicsIntegration: physicsIntegration,
                boardStoneDiameter: boardStoneDiameter,
                gameCacheManager: gameCacheManager,
                boardFrame: boardFrame,
                ulBowlCenter: ulBowlCenter,
                lrBowlCenter: lrBowlCenter,
                bowlRadius: bowlRadius
            )
            .allowsHitTesting(false) // Disable hit testing on the board itself

            // Phantom stone preview
            if let coords = hoverBoardCoords, isValidPlacement(row: coords.row, col: coords.col) {
                PhantomStone(
                    boardFrame: boardFrame,
                    gridSize: player.board.size,
                    row: coords.row,
                    col: coords.col,
                    color: currentPlayerColor,
                    stoneDiameter: boardStoneDiameter
                )
            }

            // Invisible overlay for tap/hover detection
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleHover(at: value.location)
                        }
                        .onEnded { value in
                            handleTap(at: value.location)
                            hoverPosition = nil
                            hoverBoardCoords = nil
                        }
                )
                .onHover { isHovering in
                    if !isHovering {
                        hoverPosition = nil
                        hoverBoardCoords = nil
                    }
                }
        }
    }

    // MARK: - Helper Methods

    private var currentPlayerColor: Stone {
        // In live games, use OGSClient as source of truth for whose turn it is
        return ogsClient.currentPlayerColor
    }

    private var isLiveGame: Bool {
        return ogsClient.currentGameID != nil
    }

    private var isMyTurn: Bool {
        guard isLiveGame else { return false }
        // Use OGSClient's isMyTurn property which compares currentPlayerColor with playerColor
        return ogsClient.isMyTurn
    }

    private func handleHover(at location: CGPoint) {
        hoverPosition = location
        hoverBoardCoords = screenToBoardCoords(location)
    }

    private func handleTap(at location: CGPoint) {
        guard isLiveGame, isMyTurn else {
            NSLog("Interactive2DBoard: ❌ Not a live game or not player's turn")
            return
        }

        guard let coords = screenToBoardCoords(location) else {
            NSLog("Interactive2DBoard: ❌ Tap outside board boundaries")
            return
        }

        guard isValidPlacement(row: coords.row, col: coords.col) else {
            NSLog("Interactive2DBoard: ❌ Invalid move at (\(coords.row), \(coords.col))")
            return
        }

        // Send move to OGS
        sendMove(row: coords.row, col: coords.col)
    }

    private func screenToBoardCoords(_ location: CGPoint) -> (row: Int, col: Int)? {
        let gridSize = player.board.size

        // Calculate grid cell dimensions (matching SimpleBoardView calculations)
        let cellRatio: CGFloat = 15.0 / 14.0
        let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let cellWidth = baseCellWidth
        let cellHeight = baseCellWidth * cellRatio
        let gridWidth = cellWidth * CGFloat(gridSize - 1)
        let gridHeight = cellHeight * CGFloat(gridSize - 1)

        // Calculate offset (uniform borders)
        let offsetX = (boardFrame.width - gridWidth) / 2
        let offsetY = (boardFrame.height - gridHeight) / 2

        // Convert tap location to grid coordinates
        let relativeX = location.x - boardFrame.minX - offsetX
        let relativeY = location.y - boardFrame.minY - offsetY

        // Find nearest intersection
        let col = Int(round(relativeX / cellWidth))
        let row = Int(round(relativeY / cellHeight))

        // Validate bounds
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else {
            return nil
        }

        return (row, col)
    }

    private func isValidPlacement(row: Int, col: Int) -> Bool {
        // Check if position is already occupied
        let grid = player.board.grid
        guard row < grid.count, col < grid[row].count else {
            return false
        }

        // Position must be empty (nil means empty, .black/.white means occupied)
        return grid[row][col] == nil
        // TODO: Add ko rule, suicide rule, and other validation
    }

    private func sendMove(row: Int, col: Int) {
        guard let gameID = ogsClient.currentGameID else {
            NSLog("Interactive2DBoard: ❌ No active game ID")
            return
        }

        // Convert board coordinates to OGS move string
        // OGS uses column letters (a-s) and row numbers (1-19)
        let colLetter = String(UnicodeScalar(UInt8(col) + UInt8(ascii: "a")))
        let rowNumber = player.board.size - row  // OGS counts from bottom
        let moveString = "\(colLetter)\(rowNumber)"

        NSLog("Interactive2DBoard: 🎯 Sending move: \(moveString) (row:\(row), col:\(col)) to game \(gameID)")

        // Send move to OGS server
        // Note: We don't apply the move locally - we wait for server confirmation
        // The server will send back the move via WebSocket, which will trigger a board update
        ogsClient.sendMove(gameID: gameID, move: moveString)
    }
}

// MARK: - Phantom Stone View
struct PhantomStone: View {
    let boardFrame: CGRect
    let gridSize: Int
    let row: Int
    let col: Int
    let color: Stone
    let stoneDiameter: CGFloat

    var body: some View {
        let cellRatio: CGFloat = 15.0 / 14.0
        let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let cellWidth = baseCellWidth
        let cellHeight = baseCellWidth * cellRatio
        let gridWidth = cellWidth * CGFloat(gridSize - 1)
        let gridHeight = cellHeight * CGFloat(gridSize - 1)
        let offsetX = (boardFrame.width - gridWidth) / 2
        let offsetY = (boardFrame.height - gridHeight) / 2

        let x = boardFrame.minX + offsetX + CGFloat(col) * cellWidth
        let y = boardFrame.minY + offsetY + CGFloat(row) * cellHeight

        Circle()
            .fill(color == .black ? Color.black.opacity(0.5) : Color.white.opacity(0.7))
            .frame(width: stoneDiameter, height: stoneDiameter)
            .position(x: x, y: y)
            .allowsHitTesting(false)
    }
}
