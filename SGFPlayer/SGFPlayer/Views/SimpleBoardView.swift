// MARK: - Simple Board View (Option A Implementation)
// Handles only board and game rendering - NO layout management

import SwiftUI

struct SimpleBoardView: View {
    @ObservedObject var player: SGFPlayer
    let physicsIntegration: PhysicsIntegration  // Only for bowl rendering, NOT board stones
    let boardStoneDiameter: CGFloat
    let gameCacheManager: GameCacheManager?

    // Explicit positioning from parent (ContentView)
    let boardFrame: CGRect
    let ulBowlCenter: CGPoint
    let lrBowlCenter: CGPoint
    let bowlRadius: CGFloat

    var body: some View {
        ZStack {
            // Board rendering at explicit position
            BoardContent(
                player: player,
                boardStoneDiameter: boardStoneDiameter,
                gameCacheManager: gameCacheManager,
                boardFrame: boardFrame
            )

            // Bowl rendering at explicit positions
            BowlContent(
                physicsIntegration: physicsIntegration,
                ulCenter: ulBowlCenter,
                lrCenter: lrBowlCenter,
                bowlRadius: bowlRadius
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Board Content
struct BoardContent: View {
    let player: SGFPlayer
    let boardStoneDiameter: CGFloat
    let gameCacheManager: GameCacheManager?
    let boardFrame: CGRect

    var body: some View {
        ZStack {
            // Board background with real wood texture
            Image("board_kaya")
                .resizable()
                .frame(width: boardFrame.width, height: boardFrame.height)
                .clipShape(Rectangle())
                .shadow(color: .black.opacity(0.9), radius: 35, x: 16, y: 16)
                .position(x: boardFrame.midX, y: boardFrame.midY)

            // Grid lines
            GridLines(boardFrame: boardFrame)

            // Hoshi points
            HoshiPoints(boardFrame: boardFrame)

            // Game stones
            GameStones(
                player: player,
                boardStoneDiameter: boardStoneDiameter,
                gameCacheManager: gameCacheManager,
                boardFrame: boardFrame
            )
        }
    }
}

// MARK: - Grid Lines
struct GridLines: View {
    let boardFrame: CGRect

    var body: some View {
        let gridSize = 19
        let cellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let cellHeight = boardFrame.height * 0.9 / CGFloat(gridSize - 1)
        let offsetX = boardFrame.width * 0.05
        let offsetY = boardFrame.height * 0.05

        ZStack {
            // Vertical lines
            ForEach(0..<gridSize, id: \.self) { i in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 1, height: boardFrame.height * 0.9)
                    .position(
                        x: boardFrame.minX + offsetX + CGFloat(i) * cellWidth,
                        y: boardFrame.midY
                    )
            }

            // Horizontal lines
            ForEach(0..<gridSize, id: \.self) { j in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: boardFrame.width * 0.9, height: 1)
                    .position(
                        x: boardFrame.midX,
                        y: boardFrame.minY + offsetY + CGFloat(j) * cellHeight
                    )
            }
        }
    }
}

// MARK: - Hoshi Points
struct HoshiPoints: View {
    let boardFrame: CGRect

    var body: some View {
        let gridSize = 19
        let cellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let cellHeight = boardFrame.height * 0.9 / CGFloat(gridSize - 1)
        let offsetX = boardFrame.width * 0.05
        let offsetY = boardFrame.height * 0.05

        let hoshiPoints = [(3, 3), (3, 9), (3, 15), (9, 3), (9, 9), (9, 15), (15, 3), (15, 9), (15, 15)]

        ZStack {
            ForEach(Array(hoshiPoints.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
                    .position(
                        x: boardFrame.minX + offsetX + CGFloat(point.0) * cellWidth,
                        y: boardFrame.minY + offsetY + CGFloat(point.1) * cellHeight
                    )
            }
        }
    }
}

// MARK: - Game Stones
struct GameStones: View {
    let player: SGFPlayer
    let boardStoneDiameter: CGFloat
    let gameCacheManager: GameCacheManager?
    let boardFrame: CGRect

    var body: some View {
        ZStack {
            // Render stones from game state
            let currentGrid = player.board.grid
            let gridSize = 19
            let cellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
            let cellHeight = boardFrame.height * 0.9 / CGFloat(gridSize - 1)
            let offsetX = boardFrame.width * 0.05
            let offsetY = boardFrame.height * 0.05

            // Debug: Count stones in grid (moved to onAppear to avoid state modification)
            let stoneCount = currentGrid.flatMap { $0 }.compactMap { $0 }.count

            ForEach(0..<gridSize, id: \.self) { row in
                ForEach(0..<gridSize, id: \.self) { col in
                    if let stone = currentGrid[row][col] {
                        let stoneX = boardFrame.minX + offsetX + CGFloat(col) * cellWidth
                        let stoneY = boardFrame.minY + offsetY + CGFloat(row) * cellHeight

                        Image(stone == .white ? "clam_01" : "stone_black")
                            .resizable()
                            .frame(width: boardStoneDiameter, height: boardStoneDiameter)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                            .position(x: stoneX, y: stoneY)
                            .onAppear {
                                print("🎯 STONE RENDER: \(stone) at (\(row),\(col)) -> screen (\(stoneX), \(stoneY)), frame: \(boardFrame), diameter: \(boardStoneDiameter)")
                            }
                    }
                }
            }
        }
        .onAppear {
            let stoneCount = player.board.grid.flatMap { $0 }.compactMap { $0 }.count
            print("🎯 ARCHITECTURE FIX: SimpleBoardView loaded - found \(stoneCount) stones on move \(player.currentIndex)")
            print("🎯 STONE CHECK: Board has \(player.board.grid.count) rows")
            for (rowIndex, row) in player.board.grid.enumerated() {
                let rowStones = row.compactMap { $0 }.count
                if rowStones > 0 {
                    print("🎯 ROW \(rowIndex): \(rowStones) stones")
                }
            }
        }
        .onChange(of: player.currentIndex) { _, newIndex in
            let stoneCount = player.board.grid.flatMap { $0 }.compactMap { $0 }.count
            print("🎯 MOVE UPDATE: Changed to move \(newIndex), board has \(stoneCount) stones")
        }
    }
}

// MARK: - Bowl Content
struct BowlContent: View {
    let physicsIntegration: PhysicsIntegration
    let ulCenter: CGPoint
    let lrCenter: CGPoint
    let bowlRadius: CGFloat

    var body: some View {
        ZStack {
            // Upper-left bowl (black stones captured by white)
            Image("go_lid_1")
                .resizable()
                .frame(width: bowlRadius * 2, height: bowlRadius * 2)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 8)
                .position(ulCenter)

            // Captured black stones
            ForEach(physicsIntegration.blackStones.indices, id: \.self) { index in
                Image("stone_black")
                    .resizable()
                    .frame(width: bowlRadius * 0.3, height: bowlRadius * 0.3)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                    .position(
                        x: ulCenter.x + physicsIntegration.blackStones[index].pos.x,
                        y: ulCenter.y + physicsIntegration.blackStones[index].pos.y
                    )
            }

            // Lower-right bowl (white stones captured by black)
            Image("go_lid_2")
                .resizable()
                .frame(width: bowlRadius * 2, height: bowlRadius * 2)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 8)
                .position(lrCenter)

            // Captured white stones
            ForEach(physicsIntegration.whiteStones.indices, id: \.self) { index in
                Image("clam_01")
                    .resizable()
                    .frame(width: bowlRadius * 0.3, height: bowlRadius * 0.3)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 1)
                    .position(
                        x: lrCenter.x + physicsIntegration.whiteStones[index].pos.x,
                        y: lrCenter.y + physicsIntegration.whiteStones[index].pos.y
                    )
            }
        }
    }
}