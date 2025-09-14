// MARK: - Game Board View
// Extracted from ContentView to reduce complexity

import SwiftUI

struct GameBoardView: View {
    @ObservedObject var player: SGFPlayer
    @ObservedObject var physicsIntegration: PhysicsIntegration

    // Board configuration
    let boardStoneDiameter: CGFloat
    let currentBowlRadius: CGFloat

    // Capture counts (stable, calculated values)
    let blackCapturedCount: Int
    let whiteCapturedCount: Int

    // Shadow parameters
    let lidShadowOpacity: Double
    let lidShadowRadius: Double
    let lidShadowDX: Double
    let lidShadowDY: Double
    let stoneShadowOpacity: Double
    let stoneShadowRadius: Double
    let stoneShadowDX: Double
    let stoneShadowDY: Double

    // Game cache for jitter system
    var gameCacheManager: GameCacheManager? = nil

    // Persistent jitter system that maintains cached offsets across renders
    @State private var stoneJitter: StoneJitter? = nil
    @State private var lastGameFingerprint: String = ""

    // Callback to report bowl positions to parent
    var onBowlPositionsCalculated: ((CGPoint, CGPoint, CGFloat) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            let L = geometry.size
            let shadowScale = L.width / 800.0
            
            // Traditional Go Board with proper Japanese ratio (1.07:1 - taller than wide)
            // Calculate board size based on available space, ensuring it fits
            let maxBoardSize = min(geometry.size.width, geometry.size.height) * 0.85
            let boardWidth = maxBoardSize
            let boardHeight = boardWidth * 1.07  // Traditional Japanese ratio

            // Calculate negative space based on the ACTUAL height available for the board
            // We want the board + negative space to use the full height when height is the limiting factor
            let totalVerticalSpace = L.height
            let actualNegativeSpace = totalVerticalSpace - boardHeight

            // Distribute negative space: 1/3 above, 2/3 below
            let negativeSpaceAbove = actualNegativeSpace / 3.0  // 1/3 above
            let boardCenterY = negativeSpaceAbove + boardHeight / 2
            let boardCenter = CGPoint(x: L.width / 2, y: boardCenterY)
            
            // Calculate bowl positions aligned with specific grid lines
            let lidDiameter = boardHeight / 3  // Lid diameter is 1/3 of board's long side (height)
            let actualBowlRadius = lidDiameter / 2
            let lidSize = lidDiameter
            // Bowl stones sized to match board stone proportions (scaled up from 0.25 to 0.30)
            let baseBowlStoneSize = actualBowlRadius * 0.30
            
            // Calculate grid positioning for alignment
            let gridSize = 19
            let _ = boardWidth * 0.9 / CGFloat(gridSize - 1)  // cellWidth for future use
            let cellHeight = boardHeight * 0.9 / CGFloat(gridSize - 1)
            let _ = boardWidth * 0.05  // offsetX for future use
            let offsetY = boardHeight * 0.05
            
            // Position bowls aligned with grid lines - moved 4 lines closer to center
            // UL lid: upper edge aligns with 7th line from top (index 6) - was 3rd, now 4 lines closer
            let seventhLineY = boardCenter.y - boardHeight/2 + offsetY + CGFloat(6) * cellHeight
            let ulLidY = seventhLineY - actualBowlRadius
            
            // LR lid: lower edge aligns with 6th line from bottom (index 13) - was 2nd, now 4 lines closer  
            let sixthFromBottomY = boardCenter.y - boardHeight/2 + offsetY + CGFloat(13) * cellHeight  
            let lrLidY = sixthFromBottomY + actualBowlRadius
            
            // Position bowls beside the board with grid line alignment
            let boardHalfWidth = boardWidth / 2
            let bowlOffsetX = boardHalfWidth + actualBowlRadius + 20  // 20px margin from board edge
            
            // For upper right lid (lrCenter), cut the distance in half
            let lrBowlOffsetX = boardHalfWidth + actualBowlRadius + 10  // Half the margin (10px instead of 20px)
            
            let ulCenter = CGPoint(
                x: boardCenter.x - bowlOffsetX,
                y: ulLidY
            )
            let lrCenter = CGPoint(
                x: boardCenter.x + lrBowlOffsetX,  // Using reduced offset for upper right lid
                y: lrLidY
            )
            
            ZStack {
                // Tatami mat background image - scales properly without tiling
                Image("tatami")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                
                // Real wood board image positioned at center - traditional rectangular shape
                ZStack {
                    Image("board_kaya")
                        .resizable()
                        .frame(width: boardWidth, height: boardHeight)
                        .clipShape(Rectangle())  // Right angles, no rounded corners
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 4, y: 4)
                        .overlay(
                            // Grid lines and hoshi points
                            GoGridView(
                                width: boardWidth,
                                height: boardHeight,
                                player: player,
                                getStoneColor: getStoneColor,
                                gameCache: gameCacheManager,
                                currentMoveIndex: player.currentIndex,
                                stoneJitter: $stoneJitter,
                                lastGameFingerprint: $lastGameFingerprint
                            )
                        )
                        .position(boardCenter)
                }
                
                // Note: BowlView integration removed - using simple Circle visualization instead
                
                // UL bowl (black stones captured by white) - positioned upper left
                ZStack {
                    // Real bowl lid image
                    Image("go_lid_1")
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(width: lidSize, height: lidSize)
                        .shadow(color: .black.opacity(lidShadowOpacity), radius: CGFloat(lidShadowRadius) * shadowScale)
                        .position(ulCenter)
                    
                    // Black stone visualization with real images (traditional larger size)
                    ForEach(physicsIntegration.blackStones, id: \.id) { stone in
                        let blackBowlStoneSize = baseBowlStoneSize * 1.014 // Black stones slightly larger
                        Image("stone_black")
                            .resizable()
                            .aspectRatio(1.0, contentMode: .fit)
                            .frame(width: blackBowlStoneSize, height: blackBowlStoneSize)
                            .shadow(color: .black.opacity(stoneShadowOpacity), radius: CGFloat(stoneShadowRadius) * shadowScale)
                            .position(
                                x: ulCenter.x + stone.normalizedPos.x * actualBowlRadius,
                                y: ulCenter.y + stone.normalizedPos.y * actualBowlRadius
                            )
                    }
                    
                    // Black stone count display (from calculated captures, not physics array)
                    Text("\(blackCapturedCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .position(x: ulCenter.x, y: ulCenter.y - actualBowlRadius - 30)
                }
                
                // LR bowl (white stones captured by black) - positioned lower right  
                ZStack {
                    // Real bowl lid image
                    Image("go_lid_2")
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(width: lidSize, height: lidSize)
                        .shadow(color: .black.opacity(lidShadowOpacity), radius: CGFloat(lidShadowRadius) * shadowScale)
                        .position(lrCenter)
                    
                    // White stone visualization with clam images (traditional reference size)
                    ForEach(physicsIntegration.whiteStones, id: \.id) { stone in
                        let whiteBowlStoneSize = baseBowlStoneSize // Reference size for white stones
                        Image("clam_01")
                            .resizable()
                            .aspectRatio(1.0, contentMode: .fit)
                            .frame(width: whiteBowlStoneSize, height: whiteBowlStoneSize)
                            .shadow(color: .black.opacity(stoneShadowOpacity), radius: CGFloat(stoneShadowRadius) * shadowScale)
                            .position(
                                x: lrCenter.x + stone.normalizedPos.x * actualBowlRadius,
                                y: lrCenter.y + stone.normalizedPos.y * actualBowlRadius
                            )
                    }
                    
                    // White stone count display (from calculated captures, not physics array)
                    Text("\(whiteCapturedCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                        .position(x: lrCenter.x, y: lrCenter.y + actualBowlRadius + 30)
                }
                
                // Game info overlay
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Physics Model \(physicsIntegration.activePhysicsModel + 1)")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("Move: \(player.currentIndex)")
                                .font(.caption) 
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.leading, 20)
                    
                    Spacer()
                }

                // Game info display below the board - centered
                VStack(spacing: 8) {
                    // Player names and date - centered
                    if let gameWrapper = gameCacheManager?.currentGame {
                        let game = gameWrapper.originalGame
                        let blackPlayer = game.info.playerBlack ?? "Unknown"
                        let whitePlayer = game.info.playerWhite ?? "Unknown"
                        let date = game.info.date ?? ""

                        VStack(spacing: 2) {
                            Text("\(blackPlayer) (Black) vs \(whitePlayer) (White)")
                                .font(.system(size: max(12, min(L.width * 0.015, 18))))
                                .foregroundColor(.primary.opacity(0.8))

                            if !date.isEmpty {
                                Text(date)
                                    .font(.system(size: max(10, min(L.width * 0.012, 14))))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Game result and captured stones - centered, responsive layout
                    HStack(spacing: 16) {
                        // Game result
                        if let gameWrapper = gameCacheManager?.currentGame,
                           let result = gameWrapper.originalGame.info.result, !result.isEmpty {
                            Text("Result: \(result)")
                                .font(.system(size: max(10, min(L.width * 0.012, 14))))
                                .foregroundColor(.secondary)
                        }

                        // Captured stones - always visible
                        HStack(spacing: 8) {
                            Text("Captured:")
                                .font(.system(size: max(10, min(L.width * 0.012, 14))))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Text("\(blackCapturedCount)")
                                    .font(.system(size: max(10, min(L.width * 0.012, 14))))
                                    .foregroundColor(.primary)
                                Image("stone_black")
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(width: max(8, min(L.width * 0.01, 16)), height: max(8, min(L.width * 0.01, 16)))
                            }

                            HStack(spacing: 4) {
                                Text("\(whiteCapturedCount)")
                                    .font(.system(size: max(10, min(L.width * 0.012, 14))))
                                    .foregroundColor(.primary)
                                Image("clam_01")
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(width: max(8, min(L.width * 0.01, 16)), height: max(8, min(L.width * 0.01, 16)))
                            }
                        }
                    }
                }
                .position(x: L.width / 2, y: boardCenter.y + boardHeight/2 + min(40, actualNegativeSpace * 0.3))
            }
            .onAppear {
                // Report bowl positions to parent when view appears
                onBowlPositionsCalculated?(ulCenter, lrCenter, actualBowlRadius)
            }
            .onChange(of: geometry.size) { _, _ in
                // Report bowl positions when view size changes
                onBowlPositionsCalculated?(ulCenter, lrCenter, actualBowlRadius)
            }
        }
    }
    
    // Helper function to get stone at board position
    private func getStone(row: Int, col: Int) -> Stone? {
        // Check if there's a stone at this position
        if row < player.board.size && col < player.board.size {
            return player.board.grid[row][col]
        }
        return nil
    }
    
    // Legacy color helper for compatibility
    private func getStoneColor(row: Int, col: Int) -> Color {
        if let stone = getStone(row: row, col: col) {
            switch stone {
            case .black:
                return .black
            case .white:
                return .white
            }
        }
        return Color.clear
    }
}

// MARK: - Go Grid View Component
struct GoGridView: View {
    let width: CGFloat
    let height: CGFloat
    let player: SGFPlayer
    let getStoneColor: (Int, Int) -> Color

    // Optional jitter system for natural stone placement
    var gameCache: GameCacheManager? = nil
    var currentMoveIndex: Int = 0

    // Persistent jitter state passed from parent
    @Binding var stoneJitter: StoneJitter?
    @Binding var lastGameFingerprint: String

    
    var body: some View {
        ZStack {
            // Calculate cell dimensions once for use across all elements
            let gridSize = 19
            // Traditional Japanese Go board proportions: cells are 23.7mm tall x 22mm wide
            let traditionalCellRatio: CGFloat = 23.7 / 22.0 // Height/Width = 1.077

            // Calculate cell dimensions maintaining traditional aspect ratio
            let availableWidth = width * 0.9
            let availableHeight = height * 0.9

            // Determine limiting dimension to fit traditional proportions
            let cellWidthFromWidth = availableWidth / CGFloat(gridSize - 1)
            let cellHeightFromWidth = cellWidthFromWidth * traditionalCellRatio

            let cellHeightFromHeight = availableHeight / CGFloat(gridSize - 1)
            let cellWidthFromHeight = cellHeightFromHeight / traditionalCellRatio

            let (cellWidth, cellHeight) = cellHeightFromWidth <= availableHeight
                ? (cellWidthFromWidth, cellHeightFromWidth)  // Width is limiting
                : (cellWidthFromHeight, cellHeightFromHeight) // Height is limiting

            let gridWidth = CGFloat(gridSize - 1) * cellWidth
            let gridHeight = CGFloat(gridSize - 1) * cellHeight
            let offsetX = (width - gridWidth) / 2
            let offsetY = (height - gridHeight) / 2

            // Grid lines
            Path { path in
                
                // Vertical lines
                for i in 0..<gridSize {
                    let x = offsetX + CGFloat(i) * cellWidth
                    path.move(to: CGPoint(x: x, y: offsetY))
                    path.addLine(to: CGPoint(x: x, y: height - offsetY))
                }
                
                // Horizontal lines
                for i in 0..<gridSize {
                    let y = offsetY + CGFloat(i) * cellHeight
                    path.move(to: CGPoint(x: offsetX, y: y))
                    path.addLine(to: CGPoint(x: width - offsetX, y: y))
                }
            }
            .stroke(Color.black.opacity(0.8), lineWidth: 1.0)
            
            // Star points (traditional 9 points) - correct positions for 19x19 board
            let starPoints = [(3,3), (3,9), (3,15), (9,3), (9,9), (9,15), (15,3), (15,9), (15,15)]

            ForEach(starPoints, id: \.0) { point in
                let x = offsetX + CGFloat(point.0) * cellWidth
                let y = offsetY + CGFloat(point.1) * cellHeight
                
                Circle()
                    .fill(Color.black)
                    .frame(width: min(cellWidth, cellHeight) * 0.15, height: min(cellWidth, cellHeight) * 0.15) // Proportional star points
                    .position(x: x, y: y)
            }
            
            // Stones using rectangular grid with actual PNG images and optional jitter
            ForEach(0..<gridSize, id: \.self) { row in
                ForEach(0..<gridSize, id: \.self) { col in
                    if let stone = player.board.grid[row][col] {
                        let baseX = offsetX + CGFloat(col) * cellWidth
                        let baseY = offsetY + CGFloat(row) * cellHeight
                        // Traditional Japanese stones are larger than cell width:
                        // White: 22.1mm, Black: 22.4mm, Cell width: 22mm
                        // Base size on cell width since stones should overlap grid lines
                        let baseStoneSize = cellWidth * 1.005 // White stone size (22.1mm/22mm)

                        // Apply jitter if available from game cache
                        let finalPosition = calculateFinalPosition(
                            baseX: baseX,
                            baseY: baseY,
                            baseStoneSize: baseStoneSize,
                            cellWidth: cellWidth,
                            col: col,
                            row: row,
                            currentMoveIndex: player.currentIndex
                        )

                        switch stone {
                        case .black:
                            // Black stones slightly larger (22.4mm vs 22.1mm traditionally)
                            let blackStoneSize = cellWidth * 1.018 // 22.4mm/22mm = 1.018
                            Image("stone_black")
                                .resizable()
                                .aspectRatio(1.0, contentMode: .fit)
                                .frame(width: blackStoneSize, height: blackStoneSize)
                                .position(x: finalPosition.x, y: finalPosition.y)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        case .white:
                            // Use clam image for white stones - deterministic selection based on position
                            let clamIndex = (row * 19 + col) % 5 + 1
                            let whiteStoneSize = baseStoneSize // Reference size (22.1mm traditionally)
                            Image("clam_0\(clamIndex)")
                                .resizable()
                                .aspectRatio(1.0, contentMode: .fit)
                                .frame(width: whiteStoneSize, height: whiteStoneSize)
                                .position(x: finalPosition.x, y: finalPosition.y)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initialize StoneJitter when view appears
            initializeStoneJitter()
        }
        .onChange(of: gameCache?.currentGame?.gameFingerprint) { _, _ in
            // Reinitialize when game changes
            initializeStoneJitter()
        }
    }

    // Initialize StoneJitter safely outside of view rendering
    private func initializeStoneJitter() {
        guard let gameCache = gameCache,
              let currentGame = gameCache.currentGame else {
            print("🔥 Cannot initialize StoneJitter: gameCache or currentGame is nil")
            return
        }

        let currentFingerprint = currentGame.gameFingerprint

        if stoneJitter == nil || lastGameFingerprint != currentFingerprint {
            print("🔧 CREATING StoneJitter: size=\(player.board.size), eccentricity=\(Double(currentGame.jitterMultiplier))")
            stoneJitter = StoneJitter(size: player.board.size, eccentricity: Double(currentGame.jitterMultiplier))
            lastGameFingerprint = currentFingerprint
            print("🔧 CREATED StoneJitter: \(stoneJitter != nil ? "SUCCESS" : "FAILED")")
        }
    }

    // Helper function to calculate final stone position with jitter
    private func calculateFinalPosition(
        baseX: CGFloat,
        baseY: CGFloat,
        baseStoneSize: CGFloat,
        cellWidth: CGFloat,
        col: Int,
        row: Int,
        currentMoveIndex: Int
    ) -> CGPoint {
        var finalX = baseX
        var finalY = baseY

        // Use precomputed jitter from game cache
        if let gameCache = gameCache,
           let currentGame = gameCache.currentGame,
           currentGame.jitterMultiplier > 0.0 {

            // For now, let's calculate jitter directly here instead of relying on cache
            // This gives us immediate jitter while we work on the caching system
            let safeMoveIndex = max(0, currentMoveIndex)

            // Generate deterministic jitter based on position and game
            if let gameFingerprint = currentGame.gameFingerprint.isEmpty ? nil : currentGame.gameFingerprint {
                print("🎯 CALCULATING REAL-TIME JITTER: multiplier=\(currentGame.jitterMultiplier) for stone(\(col),\(row))")

                // Use same algorithm as GameStateCache
                var seed = UInt32(abs(col + 11)) &* 73856093
                seed ^= UInt32(abs(row + 17)) &* 19349663
                // Safely convert hashValue to UInt32 by truncating
                let hashValue32 = UInt32(truncatingIfNeeded: abs(gameFingerprint.hashValue + 23))
                seed ^= hashValue32 &* 83492791
                seed = seed == 0 ? 0x9e3779b9 : seed

                // Generate Gaussian jitter
                let (gx, gy) = generateGaussianPair(&seed)

                // Apply sigma, clamp, and multiplier
                let sigma: CGFloat = 0.08
                let clamp: CGFloat = 0.22
                let baseOffsetX = min(max(gx * sigma, -clamp), clamp)
                let baseOffsetY = min(max(gy * sigma, -clamp), clamp)

                // Apply jitter multiplier
                let scaledOffset = CGPoint(
                    x: baseOffsetX * currentGame.jitterMultiplier,
                    y: baseOffsetY * currentGame.jitterMultiplier
                )

                // Convert from radius units to pixels
                let stoneRadius = baseStoneSize / 2
                finalX += scaledOffset.x * stoneRadius
                finalY += scaledOffset.y * stoneRadius

                print("🎯 APPLIED REAL-TIME: base=(\(baseOffsetX), \(baseOffsetY)), scaled=(\(scaledOffset.x), \(scaledOffset.y)), final=(\(finalX), \(finalY))")
            } else {
                print("🚫 NO GAME FINGERPRINT: cannot calculate jitter")
            }
        } else {
            // Debug why jitter is not being applied
            if gameCache == nil {
                print("🚫 NO JITTER: gameCache is nil")
            } else if gameCache?.currentGame == nil {
                print("🚫 NO JITTER: currentGame is nil")
            } else if let currentGame = gameCache?.currentGame {
                if currentGame.jitterMultiplier <= 0.0 {
                    print("🚫 NO JITTER: multiplier=\(currentGame.jitterMultiplier) (≤0.0)")
                } else {
                    print("🚫 NO JITTER: unknown reason")
                }
            }
        }

        return CGPoint(x: finalX, y: finalY)
    }

    // Gaussian generation for jitter (same as StoneJitter and GameStateCache)
    private func generateGaussianPair(_ seed: inout UInt32) -> (CGFloat, CGFloat) {
        let u1 = max(xorshift32(&seed), 1e-9)
        let u2 = xorshift32(&seed)
        let mag = sqrt(-2.0 * log(u1))
        let a = 2.0 * Double.pi * u2
        return (CGFloat(mag * cos(a)), CGFloat(mag * sin(a)))
    }

    private func xorshift32(_ s: inout UInt32) -> Double {
        s ^= s << 13
        s ^= s >> 17
        s ^= s << 5
        return Double(s) / 4294967296.0
    }
}

// Extension for geometry calculations (removed - defined in ContentView)

// Preview
struct GameBoardView_Previews: PreviewProvider {
    static var previews: some View {
        let mockPlayer = SGFPlayer()
        let mockPhysics = PhysicsIntegration()

        GameBoardView(
            player: mockPlayer,
            physicsIntegration: mockPhysics,
            boardStoneDiameter: 20,
            currentBowlRadius: 100,
            blackCapturedCount: 5,
            whiteCapturedCount: 3,
            lidShadowOpacity: 0.3,
            lidShadowRadius: 10,
            lidShadowDX: 5,
            lidShadowDY: 8,
            stoneShadowOpacity: 0.4,
            stoneShadowRadius: 3,
            stoneShadowDX: 2,
            stoneShadowDY: 3,
            gameCacheManager: nil
        )
        .frame(width: 800, height: 600)
    }
}

// Preview wrapper removed due to binding complexity