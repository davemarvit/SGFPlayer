// MARK: - Simple Board View (Option A Implementation)
// Handles only board and game rendering - NO layout management

import SwiftUI

struct SimpleBoardView: View {
    @ObservedObject var player: SGFPlayer
    let physicsIntegration: PhysicsIntegration  // Only for bowl rendering, NOT board stones
    let boardStoneDiameter: CGFloat
    @ObservedObject var gameCacheManager: GameCacheManager

    // Explicit positioning from parent (ContentView)
    let boardFrame: CGRect
    let ulBowlCenter: CGPoint
    let lrBowlCenter: CGPoint
    let bowlRadius: CGFloat

    var body: some View {
        let _ = {
            if DebugConfig.enableUIDebugging {
                Logger.debug("SimpleBoardView: BODY COMPUTED - blackStones: \(physicsIntegration.blackStones.count), whiteStones: \(physicsIntegration.whiteStones.count)")
            }
        }()

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
                bowlRadius: bowlRadius,
                boardFrame: boardFrame
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Board Content
struct BoardContent: View {
    @ObservedObject var player: SGFPlayer
    let boardStoneDiameter: CGFloat
    @ObservedObject var gameCacheManager: GameCacheManager
    let boardFrame: CGRect

    var body: some View {
        // Calculate proper board size to match grid proportions with uniform borders
        let gridSize = 19
        let cellRatio: CGFloat = 15.0 / 14.0
        let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let cellWidth = baseCellWidth
        let cellHeight = baseCellWidth * cellRatio
        let gridWidth = cellWidth * CGFloat(gridSize - 1)
        let gridHeight = cellHeight * CGFloat(gridSize - 1)

        // Calculate border size from current side borders (10% of original width)
        let borderX = (boardFrame.width - gridWidth) / 2
        let borderY = borderX  // Use same border size for uniform appearance

        // Calculate board image size to accommodate grid + uniform borders
        let boardImageWidth = gridWidth + (borderX * 2)
        let boardImageHeight = gridHeight + (borderY * 2)

        ZStack {
            // Board background with real wood texture - sized to match grid + borders
            Image("board_kaya")
                .resizable()
                .frame(width: boardImageWidth, height: boardImageHeight)
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
        // Traditional Go board cell ratio: height/width = 15/14 ≈ 1.071
        let cellRatio: CGFloat = 15.0 / 14.0

        // Calculate base cell width from board width
        let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)

        // Set proper cell dimensions with traditional ratio
        let cellWidth = baseCellWidth
        let cellHeight = baseCellWidth * cellRatio

        // Calculate grid area with proper proportions
        let gridWidth = cellWidth * CGFloat(gridSize - 1)
        let gridHeight = cellHeight * CGFloat(gridSize - 1)

        // Center the grid within the board frame
        let offsetX = (boardFrame.width - gridWidth) / 2
        let offsetY = (boardFrame.height - gridHeight) / 2

        ZStack {
            // Vertical lines
            ForEach(0..<gridSize, id: \.self) { i in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 1, height: gridHeight)
                    .position(
                        x: boardFrame.minX + offsetX + CGFloat(i) * cellWidth,
                        y: boardFrame.minY + offsetY + gridHeight / 2
                    )
            }

            // Horizontal lines
            ForEach(0..<gridSize, id: \.self) { j in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: gridWidth, height: 1)
                    .position(
                        x: boardFrame.minX + offsetX + gridWidth / 2,
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
        // Traditional Go board cell ratio: height/width = 15/14 ≈ 1.071
        let cellRatio: CGFloat = 15.0 / 14.0

        // Calculate base cell width from board width
        let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)

        // Set proper cell dimensions with traditional ratio
        let cellWidth = baseCellWidth
        let cellHeight = baseCellWidth * cellRatio

        // Calculate grid area with proper proportions
        let gridWidth = cellWidth * CGFloat(gridSize - 1)
        let gridHeight = cellHeight * CGFloat(gridSize - 1)

        // Center the grid within the board frame
        let offsetX = (boardFrame.width - gridWidth) / 2
        let offsetY = (boardFrame.height - gridHeight) / 2

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
    @ObservedObject var player: SGFPlayer
    let boardStoneDiameter: CGFloat
    @ObservedObject var gameCacheManager: GameCacheManager
    let boardFrame: CGRect

    @State private var stoneJitter: StoneJitter?
    @State private var jitterUpdateTrigger: Int = 0

    var body: some View {
        ZStack {
            // Render stones from game state
            let currentGrid = player.board.grid
            let gridSize = 19
            let totalStones = currentGrid.flatMap { $0 }.compactMap { $0 }.count
            let _ = {
                let stoneDescription = currentGrid[0][0] == nil ? "nil" : (currentGrid[0][0] == .black ? "black" : "white")
                Logger.warning("🎨 GAMESTONES BODY - totalStones: \(totalStones), grid[0][0]: \(stoneDescription)")
            }()
            // Traditional Go board cell ratio: height/width = 15/14 ≈ 1.071
            let cellRatio: CGFloat = 15.0 / 14.0

            // Calculate base cell width from board width
            let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)

            // Set proper cell dimensions with traditional ratio
            let cellWidth = baseCellWidth
            let cellHeight = baseCellWidth * cellRatio

            // Calculate grid area with proper proportions
            let gridWidth = cellWidth * CGFloat(gridSize - 1)
            let gridHeight = cellHeight * CGFloat(gridSize - 1)

            // Center the grid within the board frame
            let offsetX = (boardFrame.width - gridWidth) / 2
            let offsetY = (boardFrame.height - gridHeight) / 2
            // Calculate stone sizes based on real Go stone dimensions
            // Black stones: 22.2mm diameter, White stones: 21.9mm diameter
            // Cell width: 22mm, Cell height: 23.7mm
            let realCellWidth = 22.0 // mm
            let realCellHeight = 23.7 // mm
            let realBlackStoneDiameter = 22.2 // mm
            let realWhiteStoneDiameter = 21.9 // mm

            // Scale to our grid dimensions
            let blackStoneSize = (realBlackStoneDiameter / realCellWidth) * cellWidth
            let whiteStoneSize = (realWhiteStoneDiameter / realCellWidth) * cellWidth
            let stoneRadius = blackStoneSize / 2 // Use black stone size for jitter calculations

            // Render stones from current grid state
            ForEach(0..<gridSize, id: \.self) { row in
                ForEach(0..<gridSize, id: \.self) { col in
                    if let stone = currentGrid[row][col] {
                        let _ = {
                            // Log first few stones found to verify rendering
                            if (row < 3 && col < 3) || (row == 0 && col == 0) {
                                Logger.warning("🎨 STONE RENDERING at (\(col),\(row)) - stone: \(stone)")
                            }
                        }()

                        let baseX = boardFrame.minX + offsetX + CGFloat(col) * cellWidth
                        let baseY = boardFrame.minY + offsetY + CGFloat(row) * cellHeight

                        // Use realistic stone sizes based on color
                        let stoneSize = stone == .white ? whiteStoneSize : blackStoneSize
                        let actualStoneRadius = stoneSize / 2

                        // Apply jitter offset using the actual stone radius for this stone
                        let jitterOffset = getJitterOffset(x: col, y: row, radius: actualStoneRadius, currentGrid: currentGrid, currentMove: player.currentIndex, updateTrigger: jitterUpdateTrigger)
                        let stoneX = baseX + jitterOffset.x
                        let stoneY = baseY + jitterOffset.y

                        Image(stone == .white ? "clam_0\((row * 19 + col) % 5 + 1)" : "stone_black")
                            .resizable()
                            .frame(width: stoneSize, height: stoneSize)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                            .position(x: stoneX, y: stoneY)
                    }
                }
            }
        }
        .onAppear {
            setupJitterIfNeeded()
        }
        .onChange(of: gameCacheManager.defaultJitterMultiplier) { oldValue, newValue in
            if newValue != oldValue {
                print("🚨 JITTER CHANGED: \(oldValue) -> \(newValue)")
                Logger.warning("🎲 DEFAULT JITTER MULTIPLIER CHANGED: \(oldValue) -> \(newValue)")

                // Update jitter eccentricity and clear ALL cache to force fresh calculations
                if let existingJitter = stoneJitter {
                    existingJitter.eccentricity = newValue
                    existingJitter.clearCache() // Clear ALL jitter data to force complete recalculation
                }

                print("🚨 JITTER UPDATED AND CACHE CLEARED")
                Logger.warning("🎲 JITTER UPDATED - eccentricity: \(newValue), full cache cleared")
            }
        }
    }

    // MARK: - Jitter Helper Functions

    private func setupJitterIfNeeded() {
        guard stoneJitter == nil else {
            Logger.warning("🎲 JITTER SETUP FAILED - stoneJitter already exists")
            return
        }

        let jitterMultiplier = gameCacheManager.defaultJitterMultiplier
        // Use direct jitter multiplier from slider for more visible effect
        let adjustedJitterMultiplier = jitterMultiplier
        let newJitter = StoneJitter(size: 19, eccentricity: adjustedJitterMultiplier)
        stoneJitter = newJitter

        Logger.warning("🎲 JITTER SETUP SUCCESS - slider: \(jitterMultiplier), adjusted: \(adjustedJitterMultiplier), StoneJitter created: \(stoneJitter != nil)")
        Logger.warning("🎲 JITTER DEBUG - newJitter.eccentricity: \(newJitter.eccentricity)")
    }

    private func recreateJitter() {

        let jitterMultiplier = gameCacheManager.defaultJitterMultiplier
        // Use direct jitter multiplier from slider for more visible effect
        let adjustedJitterMultiplier = jitterMultiplier

        // Update existing jitter instance or create new one
        if let existingJitter = stoneJitter {
            existingJitter.eccentricity = adjustedJitterMultiplier
            existingJitter.clearFinalOffsetsOnly() // Force recalculation of collision effects only
            Logger.warning("🎲 JITTER UPDATED - eccentricity set to: \(adjustedJitterMultiplier), final offsets cleared")
        } else {
            stoneJitter = StoneJitter(size: 19, eccentricity: adjustedJitterMultiplier)
            Logger.warning("🎲 JITTER CREATED - eccentricity: \(adjustedJitterMultiplier)")
        }
    }


    private func getJitterOffset(x: Int, y: Int, radius: CGFloat, currentGrid: [[Stone?]], currentMove: Int, updateTrigger: Int) -> CGPoint {

        // Use state-managed jitter instance, but recreate if multiplier changed
        if stoneJitter == nil {
            setupJitterIfNeeded()
        }

        guard let jitter = stoneJitter else {
            return .zero
        }

        // Only calculate jitter for positions that have stones
        guard currentGrid[y][x] != nil else {
            return .zero
        }

        // Convert Stone grid to Bool occupancy grid
        let occupied = currentGrid.map { row in
            row.map { $0 != nil }
        }

        // Prepare jitter for current move
        jitter.prepare(
            forMove: currentMove,
            boardSize: 19,
            occupied: occupied
        )

        // Debug logging for first call
        if x < 3 && y < 3 {
            Logger.warning("🎲 CALLING jitter.offset - x:\(x), y:\(y), moveIndex:\(currentMove), radius:\(radius), eccentricity:\(jitter.eccentricity)")
        }

        // Get jitter offset for this position (returns offset in radius units)
        let offsetInRadiusUnits = jitter.offset(
            forX: x,
            y: y,
            moveIndex: currentMove,
            radius: radius,
            occupied: occupied
        )

        // Convert from radius units to pixel units (jitter multiplier already applied in StoneJitter)
        let pixelOffset = CGPoint(
            x: offsetInRadiusUnits.x * radius,
            y: offsetInRadiusUnits.y * radius
        )

        if (x < 3 && y < 3) || (x == 0 && y == 0) {
            Logger.warning("🎲 JITTER OFFSET for (\(x),\(y)): move=\(currentMove), radius=\(radius), radiusUnits=\(offsetInRadiusUnits), pixels=\(pixelOffset)")
        }

        return pixelOffset
    }
}

// MARK: - Bowl Content
struct BowlContent: View {
    @ObservedObject var physicsIntegration: PhysicsIntegration
    let ulCenter: CGPoint
    let lrCenter: CGPoint
    let bowlRadius: CGFloat
    let boardFrame: CGRect

    var body: some View {
        // Calculate stone size based on board cell size for consistency
        let gridSize = 19
        let cellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let boardStoneSize = cellWidth * 0.95
        let bowlStoneSize = boardStoneSize  // Bowl stones same size as board stones

        let _ = {
            Logger.warning("🎨 BowlContent: BODY COMPUTED - blackStones: \(physicsIntegration.blackStones.count), whiteStones: \(physicsIntegration.whiteStones.count), bowlRadius: \(bowlRadius)")
            if DebugConfig.enableUIDebugging {
                Logger.debug("BowlContent: Stone arrays - BLACK IDs: \(physicsIntegration.blackStones.map { $0.id.uuidString.prefix(8) })")
                Logger.debug("BowlContent: Stone arrays - WHITE IDs: \(physicsIntegration.whiteStones.map { $0.id.uuidString.prefix(8) })")
            }
        }()

        ZStack {
            // Upper-left bowl (black stones captured by white)
            Image("go_lid_1")
                .resizable()
                .frame(width: bowlRadius * 2, height: bowlRadius * 2)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 8)
                .position(ulCenter)

            // Captured black stones
            ForEach(physicsIntegration.blackStones, id: \.id) { stone in
                // Physics positions are already in correct coordinate system - no scaling needed
                let finalX = ulCenter.x + stone.pos.x
                let finalY = ulCenter.y + stone.pos.y
                let _ = {
                    if DebugConfig.enableUIDebugging {
                        Logger.debug("🎨🔵 BLACK STONE FOREACH - Stone ID: \(stone.id.uuidString.prefix(8)), pos: \(stone.pos)")
                    }
                }()

                Image("stone_black")
                    .resizable()
                    .frame(width: bowlStoneSize, height: bowlStoneSize)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                    .position(x: finalX, y: finalY)
                    .onAppear {
                        Logger.warning("🎨 BLACK STONE RENDERED - ID: \(stone.id.uuidString.prefix(8)), finalPos: (\(finalX), \(finalY))")
                    }
            }

            // Lower-right bowl (white stones captured by black)
            Image("go_lid_2")
                .resizable()
                .frame(width: bowlRadius * 2, height: bowlRadius * 2)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 8)
                .position(lrCenter)

            // Captured white stones
            ForEach(physicsIntegration.whiteStones, id: \.id) { stone in
                // Physics positions are already in correct coordinate system - no scaling needed
                let finalX = lrCenter.x + stone.pos.x
                let finalY = lrCenter.y + stone.pos.y
                let _ = {
                    if DebugConfig.enableUIDebugging {
                        Logger.debug("🎨⚪ WHITE STONE FOREACH - Stone ID: \(stone.id.uuidString.prefix(8)), pos: \(stone.pos)")
                    }
                }()

                Image("clam_0\((stone.id.hashValue.magnitude % 5) + 1)")
                    .resizable()
                    .frame(width: bowlStoneSize, height: bowlStoneSize)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 1)
                    .position(x: finalX, y: finalY)
                    .onAppear {
                        Logger.warning("🎨 WHITE STONE RENDERED - ID: \(stone.id.uuidString.prefix(8)), finalPos: (\(finalX), \(finalY))")
                    }
            }
        }
    }
}