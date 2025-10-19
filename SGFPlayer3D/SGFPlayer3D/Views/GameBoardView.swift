// MARK: - Game Board View
// Extracted from ContentView to reduce complexity

import SwiftUI
import AppKit
import Combine

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

    // Auto-play binding for play/pause button
    @Binding var autoNext: Bool

    // Persistent jitter system that maintains cached offsets across renders
    @State private var stoneJitter: StoneJitter? = nil
    @State private var lastGameFingerprint: String = ""

    // Callback to report bowl positions to parent
    var onBowlPositionsCalculated: ((CGPoint, CGPoint, CGFloat) -> Void)?
    
    var body: some View {
        return GeometryReader { outerGeometry in
            ZStack {
                // Board area that fills full space
                GeometryReader { geometry in
            let L = geometry.size
            let shadowScale = L.width / 800.0
            
            // Traditional Go Board with proper Japanese ratio (1.07:1 - taller than wide)
            // SMART responsive layout: minimal negative space as fraction of board size

            // Calculate responsive board size with minimal margins
            let bowlSpaceWidth = min(L.width * 0.2, 180)  // 20% or max 180px for bowls
            let metadataSpaceHeight: CGFloat = 50  // 50px for metadata bar

            let availableWidth = L.width - bowlSpaceWidth
            let availableHeight = L.height - metadataSpaceHeight

            // Calculate board size with fractional margins
            let boardWidthFromWidth = availableWidth * 0.9  // Use 90% of available width
            let boardWidthFromHeight = (availableHeight * 0.85) / 1.07  // Use 85% of available height, adjusted for ratio

            let boardWidth = min(boardWidthFromWidth, boardWidthFromHeight)
            let boardHeight = boardWidth * 1.07

            // Calculate negative space
            let totalVerticalSpace = availableHeight
            let actualNegativeSpace = max(0, totalVerticalSpace - boardHeight)

            // Distribute negative space: 1/3 above, 2/3 below
            let negativeSpaceAbove = actualNegativeSpace / 3.0  // 1/3 above
            let boardCenterY = negativeSpaceAbove + boardHeight / 2
            // Position board center in the available space (excluding bowl area)
            let boardCenterX = availableWidth / 2  // Center within available width
            let boardCenter = CGPoint(x: boardCenterX, y: boardCenterY)
            
            // Calculate bowl positions aligned with specific grid lines
            let lidDiameter = boardHeight / 3  // Lid diameter is 1/3 of board's long side (height)
            let actualBowlRadius = lidDiameter / 2
            let lidSize = lidDiameter
            // Bowl stones sized to match board stone proportions (scaled up from 0.25 to 0.30)
            let baseBowlStoneSize = actualBowlRadius * 0.30
            
            // Calculate grid positioning for alignment
            let gridSize = player.board.size
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
            
            // Position bowls in the reserved bowl space area
            let ulCenter = CGPoint(
                x: availableWidth + (bowlSpaceWidth / 4),  // 1/4 into bowl space for left bowl
                y: ulLidY
            )
            let lrCenter = CGPoint(
                x: availableWidth + (bowlSpaceWidth * 3/4),  // 3/4 into bowl space for right bowl
                y: lrLidY
            )
            
            ZStack {
                // Tatami mat background image - scales properly without tiling
                Image("tatami")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false) // Prevent tatami from blocking clicks
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                
                // Real wood board image positioned at center - traditional rectangular shape
                ZStack {
                    Image("board_kaya")
                        .resizable()
                        .frame(width: boardWidth, height: boardHeight)
                        .clipShape(Rectangle())  // Right angles, no rounded corners
                        .shadow(color: .black.opacity(0.9), radius: 35, x: 16, y: 16)
                        .allowsHitTesting(false) // Prevent board from blocking clicks
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
                .allowsHitTesting(false) // Prevent entire board from blocking clicks
                
                // Note: BowlView integration removed - using simple Circle visualization instead
                
                // UL bowl (black stones captured by white) - positioned upper left
                ZStack {
                    // Real bowl lid image
                    Image("go_lid_1")
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(width: lidSize, height: lidSize)
                        .shadow(color: .black.opacity(0.8), radius: 12, x: 6, y: 6)
                        .position(ulCenter)
                    
                    // Black stone visualization with real images (traditional larger size)
                    ForEach(physicsIntegration.blackStones, id: \.id) { stone in
                        let blackBowlStoneSize = baseBowlStoneSize * 1.014 // Black stones slightly larger
                        Image("stone_black")
                            .resizable()
                            .aspectRatio(1.0, contentMode: .fit)
                            .frame(width: blackBowlStoneSize, height: blackBowlStoneSize)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                            .position(
                                x: ulCenter.x + stone.normalizedPos.x * actualBowlRadius,
                                y: ulCenter.y + stone.normalizedPos.y * actualBowlRadius
                            )
                    }
                    
                    // Black stone count display (commented out for cleaner UI)
                    // Text("\(blackCapturedCount)")
                    //     .font(.system(size: 16, weight: .bold))
                    //     .foregroundColor(.white)
                    //     .padding(.horizontal, 8)
                    //     .padding(.vertical, 4)
                    //     .background(Color.black.opacity(0.7))
                    //     .cornerRadius(8)
                    //     .position(x: ulCenter.x, y: ulCenter.y - actualBowlRadius - 30)
                }
                
                // LR bowl (white stones captured by black) - positioned lower right  
                ZStack {
                    // Real bowl lid image
                    Image("go_lid_2")
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(width: lidSize, height: lidSize)
                        .shadow(color: .black.opacity(0.8), radius: 12, x: 6, y: 6)
                        .position(lrCenter)
                    
                    // White stone visualization with clam images (traditional reference size)
                    ForEach(Array(physicsIntegration.whiteStones.enumerated()), id: \.element.id) { index, stone in
                        let whiteBowlStoneSize = baseBowlStoneSize // Reference size for white stones
                        // Use stable index-based clam selection instead of volatile hashValue
                        let clamIndex = (index % 5) + 1
                        Image("clam_0\(clamIndex)")
                            .resizable()
                            .aspectRatio(1.0, contentMode: .fit)
                            .frame(width: whiteBowlStoneSize, height: whiteBowlStoneSize)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                            .position(
                                x: lrCenter.x + stone.normalizedPos.x * actualBowlRadius,
                                y: lrCenter.y + stone.normalizedPos.y * actualBowlRadius
                            )
                    }
                    
                    // White stone count display (commented out for cleaner UI)
                    // Text("\(whiteCapturedCount)")
                    //     .font(.system(size: 16, weight: .bold))
                    //     .foregroundColor(.black)
                    //     .padding(.horizontal, 8)
                    //     .padding(.vertical, 4)
                    //     .background(Color.white.opacity(0.9))
                    //     .cornerRadius(8)
                    //     .position(x: lrCenter.x, y: lrCenter.y + actualBowlRadius + 30)
                }
                
                // Debug info removed - cleaner UI

            }
            .onAppear {
                // Report bowl positions to parent when view appears
                onBowlPositionsCalculated?(ulCenter, lrCenter, actualBowlRadius)
            }
            .onChange(of: geometry.size) { _, _ in
                // Report bowl positions when view size changes
                onBowlPositionsCalculated?(ulCenter, lrCenter, actualBowlRadius)
            }
                } // Close board GeometryReader
                .allowsHitTesting(false) // Prevent inner GeometryReader from blocking clicks

            }

        }
        .allowsHitTesting(false) // Disable outer GeometryReader hit-testing

    // Helper function to calculate metadata Y position midway between board bottom and window bottom
    func calculateMetadataY(geometry: GeometryProxy) -> CGFloat {
        // Replicate the board positioning calculation from the main view
        let maxBoardSize = min(geometry.size.width, geometry.size.height) * 0.85
        let boardHeight = maxBoardSize * 1.07  // Traditional Japanese ratio
        let totalVerticalSpace = geometry.size.height
        let actualNegativeSpace = totalVerticalSpace - boardHeight
        let negativeSpaceAbove = actualNegativeSpace / 3.0  // 1/3 above
        let boardCenterY = negativeSpaceAbove + boardHeight / 2

        // Calculate board bottom
        let boardBottom = boardCenterY + boardHeight / 2

        // Position metadata midway between board bottom and window bottom
        let windowBottom = geometry.size.height
        let metadataY = boardBottom + (windowBottom - boardBottom) / 2

        return metadataY
    }

    // Helper function to get stone at board position
    func getStone(row: Int, col: Int) -> Stone? {
        // Check if there's a stone at this position
        if row < player.board.size && col < player.board.size {
            return player.board.grid[row][col]
        }
        return nil
    }
    
    // Legacy color helper for compatibility
    func getStoneColor(row: Int, col: Int) -> Color {
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
            let gridSize = player.board.size
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

            ForEach(Array(starPoints.enumerated()), id: \.offset) { index, point in
                let x = offsetX + CGFloat(point.0) * cellWidth
                let y = offsetY + CGFloat(point.1) * cellHeight

                Circle()
                    .fill(Color.black)
                    .frame(width: min(cellWidth, cellHeight) * 0.15, height: min(cellWidth, cellHeight) * 0.15)
                    .position(x: x, y: y)
                    .zIndex(10) // Ensure star points render above grid lines and board
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
                                .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                                .zIndex(20) // Stones above star points
                        case .white:
                            // Use clam image for white stones - deterministic selection based on position
                            let clamIndex = (row * 19 + col) % 5 + 1
                            let whiteStoneSize = baseStoneSize // Reference size (22.1mm traditionally)
                            Image("clam_0\(clamIndex)")
                                .resizable()
                                .aspectRatio(1.0, contentMode: .fit)
                                .frame(width: whiteStoneSize, height: whiteStoneSize)
                                .position(x: finalPosition.x, y: finalPosition.y)
                                .shadow(color: .black.opacity(0.6), radius: 4, x: 2, y: 2)
                                .zIndex(20) // Stones above star points
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

        // TODO: Re-implement jitter using cached calculations to avoid infinite loop
        // For now, disable jitter to fix the infinite calculation loop that was causing crashes
        // The previous implementation was calculating jitter inside the view body which triggered
        // infinite re-renders due to print statements and state changes

        /*
        // Use precomputed jitter from game cache
        if let gameCache = gameCache,
           let currentGame = gameCache.currentGame,
           currentGame.jitterMultiplier > 0.0 {
            // Use cached jitter from StoneJitter system to avoid calculations in view body
            if let jitter = stoneJitter,
               let gameFingerprint = currentGame.gameFingerprint.isEmpty ? nil : currentGame.gameFingerprint,
               !gameFingerprint.isEmpty {

                let jitterOffset = jitter.jitterForPosition(x: col, y: row)

                // Apply jitter multiplier
                let scaledOffset = CGPoint(
                    x: jitterOffset.x * currentGame.jitterMultiplier,
                    y: jitterOffset.y * currentGame.jitterMultiplier
                )

                // Convert from radius units to pixels
                let stoneRadius = baseStoneSize / 2
                finalX += scaledOffset.x * stoneRadius
                finalY += scaledOffset.y * stoneRadius
            }
        }
        */

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
            gameCacheManager: nil,
            autoNext: .constant(false)
        )
        .frame(width: 800, height: 600)
    }
}

// Preview wrapper removed due to binding complexity
}