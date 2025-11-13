// MARK: - Simple Board View (Option A Implementation)
// Handles only board and game rendering - NO layout management

import SwiftUI

struct SimpleBoardView: View {
    @ObservedObject var player: SGFPlayer
    let physicsIntegration: PhysicsIntegration  // Only for bowl rendering, NOT board stones
    let boardStoneDiameter: CGFloat
    @ObservedObject var gameCacheManager: GameCacheManager
    @ObservedObject var ogsClient: OGSClient  // For sending moves

    // Explicit positioning from parent (ContentView)
    let boardFrame: CGRect
    let ulBowlCenter: CGPoint
    let lrBowlCenter: CGPoint
    let bowlRadius: CGFloat

    // v3.122: Phantom stone implementation
    @State private var hoverLocation: CGPoint?
    @State private var phantomStonePos: (x: Int, y: Int)?

    var body: some View {
        NSLog("🟦 SimpleBoardView.body CALLED v3.122")

        let _ = {
            if DebugConfig.enableUIDebugging {
                Logger.debug("SimpleBoardView: BODY COMPUTED - blackStones: \(physicsIntegration.blackStones.count), whiteStones: \(physicsIntegration.whiteStones.count)")
            }
        }()

        return ZStack {
            // Board rendering at explicit position (no hit testing)
            BoardContent(
                player: player,
                boardStoneDiameter: boardStoneDiameter,
                gameCacheManager: gameCacheManager,
                boardFrame: boardFrame
            )

            // Bowl rendering at explicit positions (no hit testing)
            BowlContent(
                physicsIntegration: physicsIntegration,
                ulCenter: ulBowlCenter,
                lrCenter: lrBowlCenter,
                bowlRadius: bowlRadius,
                boardFrame: boardFrame,
                gridSize: player.board.size
            )

            // v3.122: Phantom stone overlay
            PhantomStoneOverlay(
                player: player,
                ogsClient: ogsClient,
                boardFrame: boardFrame,
                boardStoneDiameter: boardStoneDiameter
            )
        }
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
        let gridSize = player.board.size
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
            GridLines(boardFrame: boardFrame, gridSize: gridSize)

            // Hoshi points
            HoshiPoints(boardFrame: boardFrame, gridSize: gridSize)

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
    let gridSize: Int

    var body: some View {
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
    let gridSize: Int

    var body: some View {
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

        // Hoshi points depend on board size
        let hoshiPoints: [(Int, Int)] = {
            switch gridSize {
            case 19:
                return [(3, 3), (3, 9), (3, 15), (9, 3), (9, 9), (9, 15), (15, 3), (15, 9), (15, 15)]
            case 13:
                return [(3, 3), (3, 9), (6, 6), (9, 3), (9, 9)]
            case 9:
                return [(2, 2), (2, 6), (4, 4), (6, 2), (6, 6)]
            default:
                return []
            }
        }()

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
            let gridSize = player.board.size
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

            // Last move glow effects - DRAW FIRST (underneath stones)
            if let lastMove = player.lastMove {
                let indicatorStyle = LastMoveIndicatorSettings.loadStyle()
                let row = lastMove.y
                let col = lastMove.x
                let baseX = boardFrame.minX + offsetX + CGFloat(col) * cellWidth
                let baseY = boardFrame.minY + offsetY + CGFloat(row) * cellHeight

                // Use the same stone size calculation
                let gridSize = player.board.size
                let stoneToCell = CGFloat(0.95)  // Stones are 95% of cell size
                let stoneSize = min(cellWidth, cellHeight) * stoneToCell

                // Get actual stone radius for this position
                let actualStoneRadius = stoneSize / 2

                // Apply same jitter as stone
                let currentGrid = player.board.grid
                let jitterOffset = getJitterOffset(x: col, y: row, radius: actualStoneRadius, currentGrid: currentGrid, currentMove: player.currentIndex, updateTrigger: jitterUpdateTrigger)
                let indicatorX = baseX + jitterOffset.x
                let indicatorY = baseY + jitterOffset.y

                // Only render glow effects here (underneath)
                LastMoveIndicatorView2D(
                    style: indicatorStyle,
                    stoneColor: player.board.grid[row][col],
                    position: CGPoint(x: indicatorX, y: indicatorY),
                    size: stoneSize,
                    onlyGlowEffects: true
                )
            }

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

            // Last move circle markers - DRAW LAST (on top of stones)
            if let lastMove = player.lastMove {
                let indicatorStyle = LastMoveIndicatorSettings.loadStyle()
                let row = lastMove.y
                let col = lastMove.x
                let baseX = boardFrame.minX + offsetX + CGFloat(col) * cellWidth
                let baseY = boardFrame.minY + offsetY + CGFloat(row) * cellHeight

                // Use the same stone size calculation
                let gridSize = player.board.size
                let stoneToCell = CGFloat(0.95)  // Stones are 95% of cell size
                let stoneSize = min(cellWidth, cellHeight) * stoneToCell

                // Get actual stone radius for this position
                let actualStoneRadius = stoneSize / 2

                // Apply same jitter as stone
                let currentGrid = player.board.grid
                let jitterOffset = getJitterOffset(x: col, y: row, radius: actualStoneRadius, currentGrid: currentGrid, currentMove: player.currentIndex, updateTrigger: jitterUpdateTrigger)
                let indicatorX = baseX + jitterOffset.x
                let indicatorY = baseY + jitterOffset.y

                // Only render circle markers here (on top)
                LastMoveIndicatorView2D(
                    style: indicatorStyle,
                    stoneColor: player.board.grid[row][col],
                    position: CGPoint(x: indicatorX, y: indicatorY),
                    size: stoneSize,
                    onlyGlowEffects: false
                )
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
            boardSize: player.board.size,
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
    @AppStorage("verboseLogging") private var verboseLogging: Bool = false
    let ulCenter: CGPoint
    let lrCenter: CGPoint
    let bowlRadius: CGFloat
    let boardFrame: CGRect
    let gridSize: Int

    var body: some View {
        // Calculate stone size based on board cell size for consistency
        let cellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let realBlackStoneDiameter = 22.2 // mm
        let realWhiteStoneDiameter = 21.9 // mm
        let realCellWidth = 22.0 // mm
        let blackBowlStoneSize = (realBlackStoneDiameter / realCellWidth) * cellWidth
        let whiteBowlStoneSize = (realWhiteStoneDiameter / realCellWidth) * cellWidth

        let _ = {
            if verboseLogging {
                Logger.warning("🎨 BowlContent: BODY COMPUTED - blackStones: \(physicsIntegration.blackStones.count), whiteStones: \(physicsIntegration.whiteStones.count), bowlRadius: \(bowlRadius)")
            }
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
                .shadow(color: .black.opacity(0.5), radius: 15, x: 8, y: 12)
                .position(ulCenter)

            // Captured black stones
            ForEach(physicsIntegration.blackStones, id: \.id) { stone in
                // Physics positions are already in correct coordinate system - no scaling needed
                let finalX = round(ulCenter.x + stone.pos.x)
                let finalY = round(ulCenter.y + stone.pos.y)
                let _ = {
                    if DebugConfig.enableUIDebugging {
                        Logger.debug("🎨🔵 BLACK STONE FOREACH - Stone ID: \(stone.id.uuidString.prefix(8)), pos: \(stone.pos)")
                    }
                }()

                Image("stone_black")
                    .resizable()
                    .frame(width: blackBowlStoneSize, height: blackBowlStoneSize)
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
                .shadow(color: .black.opacity(0.5), radius: 15, x: 8, y: 12)
                .position(lrCenter)

            // Captured white stones
            ForEach(Array(physicsIntegration.whiteStones.enumerated()), id: \.element.id) { index, stone in
                // Physics positions are already in correct coordinate system - no scaling needed
                let finalX = round(lrCenter.x + stone.pos.x)
                let finalY = round(lrCenter.y + stone.pos.y)
                let _ = {
                    if DebugConfig.enableUIDebugging {
                        Logger.debug("🎨⚪ WHITE STONE FOREACH - Stone ID: \(stone.id.uuidString.prefix(8)), pos: \(stone.pos)")
                    }
                }()

                // Use stable index-based clam selection instead of volatile hashValue
                Image("clam_0\((index % 5) + 1)")
                    .resizable()
                    .frame(width: whiteBowlStoneSize, height: whiteBowlStoneSize)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 1)
                    .position(x: finalX, y: finalY)
                    .onAppear {
                        Logger.warning("🎨 WHITE STONE RENDERED - ID: \(stone.id.uuidString.prefix(8)), finalPos: (\(finalX), \(finalY))")
                    }
            }
        }
    }
}

// MARK: - Phantom Stone Overlay (v3.122)
struct PhantomStoneOverlay: View {
    @ObservedObject var player: SGFPlayer
    @ObservedObject var ogsClient: OGSClient
    let boardFrame: CGRect
    let boardStoneDiameter: CGFloat

    @State private var hoverLocation: CGPoint?
    @State private var phantomBoardPos: (x: Int, y: Int)?

    var body: some View {
        // Only show phantom stones in OGS mode
        let isOGSMode = ogsClient.currentGameID != nil
        guard isOGSMode else {
            return AnyView(EmptyView())
        }

        let gridSize = player.board.size

        // Calculate grid dimensions (same as BoardContent)
        let cellRatio: CGFloat = 15.0 / 14.0
        let baseCellWidth = boardFrame.width * 0.9 / CGFloat(gridSize - 1)
        let cellWidth = baseCellWidth
        let cellHeight = baseCellWidth * cellRatio
        let gridWidth = cellWidth * CGFloat(gridSize - 1)
        let gridHeight = cellHeight * CGFloat(gridSize - 1)
        let offsetX = (boardFrame.width - gridWidth) / 2
        let offsetY = (boardFrame.height - gridHeight) / 2

        // Calculate stone sizes
        let realCellWidth = 22.0 // mm
        let realBlackStoneDiameter = 22.2 // mm
        let realWhiteStoneDiameter = 21.9 // mm
        let blackStoneSize = (realBlackStoneDiameter / realCellWidth) * cellWidth
        let whiteStoneSize = (realWhiteStoneDiameter / realCellWidth) * cellWidth

        return AnyView(ZStack {
            // Invisible hover capture rectangle over entire board area
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .allowsHitTesting(true)
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            handleClick()
                        }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoverLocation = location

                        // Convert screen coordinates to board coordinates
                        let relativeX = location.x - boardFrame.minX - offsetX
                        let relativeY = location.y - boardFrame.minY - offsetY

                        // Convert to grid position (round to nearest intersection)
                        let col = Int(round(relativeX / cellWidth))
                        let row = Int(round(relativeY / cellHeight))

                        // Check if position is valid and empty
                        if col >= 0 && col < gridSize && row >= 0 && row < gridSize {
                            if player.board.grid[row][col] == nil {
                                // Only update if position actually changed
                                if phantomBoardPos?.x != col || phantomBoardPos?.y != row {
                                    phantomBoardPos = (x: col, y: row)
                                    NSLog("👻 v3.122: Phantom stone at board (\(col), \(row))")
                                }
                            } else {
                                // Occupied position
                                if phantomBoardPos != nil {
                                    phantomBoardPos = nil
                                }
                            }
                        } else {
                            // Outside board bounds
                            if phantomBoardPos != nil {
                                phantomBoardPos = nil
                            }
                        }

                    case .ended:
                        hoverLocation = nil
                        phantomBoardPos = nil
                        NSLog("👻 v3.122: Phantom stone cleared")
                    }
                }

            // Show phantom stone if we have a valid position
            if let pos = phantomBoardPos {
                let stoneX = boardFrame.minX + offsetX + CGFloat(pos.x) * cellWidth
                let stoneY = boardFrame.minY + offsetY + CGFloat(pos.y) * cellHeight

                // Determine stone color based on OGS player assignment (not turn)
                let stoneColor = ogsClient.playerColor ?? ((player.currentIndex % 2 == 0) ? Stone.black : Stone.white)

                // Log color selection (using let _ = pattern to avoid ViewBuilder issues)
                let _ = {
                    NSLog("👻 Phantom color: \(stoneColor == .black ? "BLACK" : "WHITE"), playerColor: \(ogsClient.playerColor.map { $0 == .black ? "BLACK" : "WHITE" } ?? "nil"), currentIndex: \(player.currentIndex)")
                }()

                let stoneSize = stoneColor == .black ? blackStoneSize : whiteStoneSize
                let imageName = stoneColor == .black ? "stone_black" : "clam_01"
                let opacity = stoneColor == .black ? 0.4 : 0.6  // Black more transparent in 2D

                Image(imageName)
                    .resizable()
                    .frame(width: stoneSize, height: stoneSize)
                    .opacity(opacity)
                    .position(x: stoneX, y: stoneY)
                    .allowsHitTesting(false) // Don't interfere with hover detection
            }
        })
    }

    // MARK: - Click Handler
    private func handleClick() {
        NSLog("👻 2D Click detected!")
        NSLog("👻   isMyTurn: \(ogsClient.isMyTurn)")
        NSLog("👻   gamePhase: \(ogsClient.gamePhase.rawValue)")
        NSLog("👻   phantomBoardPos: \(phantomBoardPos.map { "(\($0.x), \($0.y))" } ?? "nil")")
        NSLog("👻   currentGameID: \(ogsClient.currentGameID.map { String($0) } ?? "nil")")

        // Only send move if it's our turn and game is in progress
        guard ogsClient.isMyTurn,
              ogsClient.gamePhase == .playing,
              let position = phantomBoardPos,
              let gameID = ogsClient.currentGameID else {
            NSLog("👻 ❌ Click ignored - conditions not met")
            return
        }

        // Convert board position to SGF notation (a-s for both x and y)
        let letters = "abcdefghijklmnopqrs"
        let xChar = letters[letters.index(letters.startIndex, offsetBy: position.x)]
        let yChar = letters[letters.index(letters.startIndex, offsetBy: position.y)]
        let sgfMove = "\(xChar)\(yChar)"

        // Send move to OGS
        NSLog("👻 🎯 2D: Sending move \(sgfMove) at board position (\(position.x), \(position.y))")
        ogsClient.sendMove(gameID: gameID, move: sgfMove)

        // Clear phantom stone after sending
        phantomBoardPos = nil
    }
}