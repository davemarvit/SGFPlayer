// MARK: - SGFPlayerScreensaver.swift
// macOS Screensaver implementation using SGFPlayer engine
// Handles Sequoia v15.5 permissions and restrictions

import ScreenSaver
import Cocoa
// SwiftUI not needed for screensaver

@objc(SGFPlayerScreensaver)
class SGFPlayerScreensaver: ScreenSaverView {

    // MARK: - Core Components

    private var gameEngine: SGFPlayer?
    private var physicsEngine: PhysicsEngine
    private var layoutService: LayoutService
    private var displayLink: CVDisplayLink?

    // MARK: - Game State

    private var currentGame: SGFGame?
    private var gameLibrary: [SGFGame] = []
    private var currentGameIndex = 0
    private var autoPlayTimer: Timer?
    private var moveInterval: TimeInterval = 2.0

    // MARK: - Rendering State

    private var stonePositions: [StonePosition] = []
    private var bowlStonePositions: BowlPhysicsResult?
    private var lastUpdateTime: CFTimeInterval = 0
    private let targetFPS: Double = 60.0

    // MARK: - Layout Configuration

    private var boardFrame: CGRect = .zero
    private var bowlRadius: CGFloat = 50
    private var stoneRadius: CGFloat = 10

    // MARK: - Initialization

    override init?(frame: NSRect, isPreview: Bool) {
        // Initialize services
        self.physicsEngine = PhysicsEngine()
        self.layoutService = LayoutService()

        super.init(frame: frame, isPreview: isPreview)

        // Configure for screensaver environment
        setupScreensaverConfiguration()
        loadEmbeddedGames()
        startGamePlayback()
    }

    required init?(coder: NSCoder) {
        // Initialize services
        self.physicsEngine = PhysicsEngine()
        self.layoutService = LayoutService()

        super.init(coder: coder)

        setupScreensaverConfiguration()
        loadEmbeddedGames()
        startGamePlayback()
    }

    // MARK: - Screensaver Configuration

    private func setupScreensaverConfiguration() {
        // Configure animation timing interval
        animationTimeInterval = 1.0 / targetFPS

        // Set physics model (GroupDrop for balance of realism and performance)
        physicsEngine.activeModelIndex = 1

        // Configure auto-play settings optimized for screensaver
        moveInterval = 1.5 // Slightly faster than normal gameplay

        // Prepare for full-screen rendering
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        print("🖥️ SGFPlayerScreensaver: Initialized for Sequoia v15.5")
    }

    // MARK: - Game Loading (Embedded for Sandbox Compliance)

    private func loadEmbeddedGames() {
        // TODO: Embed sample SGF games as resources to avoid file system permissions
        // For now, create a simple demonstration game programmatically
        gameLibrary = createDemoGames()

        if let firstGame = gameLibrary.first {
            loadGame(firstGame)
        }

        print("🎮 SGFPlayerScreensaver: Loaded \(gameLibrary.count) demo games")
    }

    private func createDemoGames() -> [SGFGame] {
        // Create simple demo games programmatically to avoid file system access
        var games: [SGFGame] = []

        // Demo Game 1: Small tactical sequence
        let demoSGF1 = "(;FF[4]SZ[19]PB[Demo Player]PW[AI Player];B[pd];W[dp];B[pq];W[dc];B[fq];W[cn];B[jp];W[qf];B[nd];W[rd])"

        // Demo Game 2: Corner joseki sequence
        let demoSGF2 = "(;FF[4]SZ[19]PB[Black]PW[White];B[dd];W[pp];B[pd];W[dq];B[co];W[cp];B[do];W[fp];B[ck];W[cf])"

        // Parse demo games
        for sgfString in [demoSGF1, demoSGF2] {
            do {
                let tree = try SGFParser.parse(text: sgfString)
                let game = SGFGame.from(tree: tree)
                games.append(game)
            } catch {
                print("❗️ Failed to parse demo SGF: \(error)")
            }
        }

        return games
    }

    // MARK: - Game Management

    private func loadGame(_ game: SGFGame) {
        currentGame = game
        gameEngine = SGFPlayer()
        gameEngine?.load(game: game)

        // Reset to beginning
        gameEngine?.reset()
        updatePhysicsForCurrentMove()

        print("🔄 SGFPlayerScreensaver: Loaded game with \(game.moves.count) moves")
    }

    private func startGamePlayback() {
        stopGamePlayback() // Ensure no existing timer

        autoPlayTimer = Timer.scheduledTimer(withTimeInterval: moveInterval, repeats: true) { [weak self] _ in
            self?.advanceGame()
        }
    }

    private func stopGamePlayback() {
        autoPlayTimer?.invalidate()
        autoPlayTimer = nil
    }

    private func advanceGame() {
        guard let engine = gameEngine, let game = currentGame else { return }

        if engine.currentIndex < game.moves.count {
            // Advance to next move
            engine.stepForward()
            updatePhysicsForCurrentMove()
        } else {
            // Game finished, move to next game
            nextGame()
        }
    }

    private func nextGame() {
        currentGameIndex = (currentGameIndex + 1) % gameLibrary.count
        let nextGame = gameLibrary[currentGameIndex]
        loadGame(nextGame)
    }

    // MARK: - Physics and Layout Updates

    private func updatePhysicsForCurrentMove() {
        guard let engine = gameEngine else { return }

        // Calculate board layout for current screen size
        let responsive = layoutService.calculateResponsiveLayout(
            in: GeometryProxy(frame: bounds),
            topSpaceCellUnits: 2.0,
            bottomSpaceCellUnits: 3.0
        )

        boardFrame = responsive.boardFrame
        bowlRadius = responsive.bowlRadius
        stoneRadius = bowlRadius * 0.15 // Proportional stone size

        // Calculate captures for bowl physics
        let (blackCaptured, whiteCaptured) = calculateCaptures(engine: engine)

        // Update bowl stone positions using physics
        if blackCaptured > 0 || whiteCaptured > 0 {
            bowlStonePositions = physicsEngine.computeStonePositions(
                currentStoneCount: 0,
                targetStoneCount: max(blackCaptured, whiteCaptured),
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                seed: UInt64(engine.currentIndex),
                isWhiteBowl: blackCaptured > whiteCaptured
            )
        }

        // Extract stone positions for board rendering
        updateBoardStonePositions(engine: engine)
    }

    private func calculateCaptures(engine: SGFPlayer) -> (black: Int, white: Int) {
        // Simple capture calculation - in a full implementation this would be more sophisticated
        let moveIndex = engine.currentIndex
        let blackCaptured = moveIndex / 20 // Demo calculation
        let whiteCaptured = moveIndex / 25 // Demo calculation
        return (blackCaptured, whiteCaptured)
    }

    private func updateBoardStonePositions(engine: SGFPlayer) {
        stonePositions = []
        let board = engine.board
        let cellSize = boardFrame.width / CGFloat(board.size)

        for row in 0..<board.size {
            for col in 0..<board.size {
                if let stone = board.grid[row][col] {
                    let x = boardFrame.minX + CGFloat(col) * cellSize + cellSize / 2
                    let y = boardFrame.minY + CGFloat(row) * cellSize + cellSize / 2

                    let position = StonePosition(
                        id: UUID(),
                        position: CGPoint(x: x, y: y),
                        isWhite: stone == .white
                    )
                    stonePositions.append(position)
                }
            }
        }
    }

    // MARK: - Rendering

    override func draw(_ rect: NSRect) {
        super.draw(rect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Clear background
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)

        // Draw the Go board
        drawBoard(in: context)

        // Draw stones on board
        drawBoardStones(in: context)

        // Draw bowl stones (captured pieces)
        drawBowlStones(in: context)

        // Draw game info (minimal for screensaver)
        drawGameInfo(in: context)
    }

    private func drawBoard(in context: CGContext) {
        guard boardFrame.width > 0 && boardFrame.height > 0 else { return }

        // Draw board background
        context.setFillColor(NSColor(red: 0.85, green: 0.7, blue: 0.4, alpha: 1.0).cgColor)
        context.fill(boardFrame)

        // Draw grid lines
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)

        let boardSize = currentGame?.boardSize ?? 19
        let cellSize = boardFrame.width / CGFloat(boardSize)

        // Vertical lines
        for i in 0..<boardSize {
            let x = boardFrame.minX + CGFloat(i) * cellSize + cellSize / 2
            context.move(to: CGPoint(x: x, y: boardFrame.minY + cellSize / 2))
            context.addLine(to: CGPoint(x: x, y: boardFrame.maxY - cellSize / 2))
        }

        // Horizontal lines
        for i in 0..<boardSize {
            let y = boardFrame.minY + CGFloat(i) * cellSize + cellSize / 2
            context.move(to: CGPoint(x: boardFrame.minX + cellSize / 2, y: y))
            context.addLine(to: CGPoint(x: boardFrame.maxX - cellSize / 2, y: y))
        }

        context.strokePath()
    }

    private func drawBoardStones(in context: CGContext) {
        for stone in stonePositions {
            let stoneRect = CGRect(
                x: stone.position.x - stoneRadius,
                y: stone.position.y - stoneRadius,
                width: stoneRadius * 2,
                height: stoneRadius * 2
            )

            // Draw stone shadow
            context.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
            let shadowRect = stoneRect.offsetBy(dx: 2, dy: 2)
            context.fillEllipse(in: shadowRect)

            // Draw stone
            let stoneColor = stone.isWhite ? NSColor.white : NSColor.black
            context.setFillColor(stoneColor.cgColor)
            context.fillEllipse(in: stoneRect)

            // Draw stone border
            context.setStrokeColor(NSColor.gray.cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: stoneRect)
        }
    }

    private func drawBowlStones(in context: CGContext) {
        guard let bowlResult = bowlStonePositions else { return }

        // Draw stones in bowls (simplified positioning for demo)
        let bowlCenter = CGPoint(x: bounds.width - 100, y: bounds.height - 100)

        for (index, stonePos) in bowlResult.stones.enumerated() {
            let x = bowlCenter.x + stonePos.position.x * bowlRadius
            let y = bowlCenter.y + stonePos.position.y * bowlRadius

            let stoneRect = CGRect(
                x: x - stoneRadius * 0.8,
                y: y - stoneRadius * 0.8,
                width: stoneRadius * 1.6,
                height: stoneRadius * 1.6
            )

            let stoneColor = stonePos.isWhite ? NSColor.white : NSColor.black
            context.setFillColor(stoneColor.cgColor)
            context.fillEllipse(in: stoneRect)
        }
    }

    private func drawGameInfo(in context: CGContext) {
        // Minimal game info for screensaver
        guard let engine = gameEngine else { return }

        let infoText = "Move \(engine.currentIndex) of \(currentGame?.moves.count ?? 0)"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 18)
        ]

        let attributedString = NSAttributedString(string: infoText, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: 20,
            y: bounds.height - textSize.height - 20,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)
    }

    // MARK: - Animation Loop

    override func animateOneFrame() {
        // Update any smooth animations here
        let currentTime = CACurrentMediaTime()
        if currentTime - lastUpdateTime >= 1.0 / targetFPS {
            needsDisplay = true
            lastUpdateTime = currentTime
        }
    }

    // MARK: - Lifecycle

    override func startAnimation() {
        super.startAnimation()
        startGamePlayback()
        print("🚀 SGFPlayerScreensaver: Animation started")
    }

    override func stopAnimation() {
        super.stopAnimation()
        stopGamePlayback()
        print("⏹️ SGFPlayerScreensaver: Animation stopped")
    }

    deinit {
        stopGamePlayback()
        print("🔄 SGFPlayerScreensaver: Deinitialized")
    }
}

// MARK: - Helper Extensions

extension SGFPlayerScreensaver {

    // Using GeometryProxy from LayoutService

    // Stone position for rendering
    private struct StonePosition {
        let id: UUID
        let position: CGPoint
        let isWhite: Bool
    }
}

// MARK: - Configuration Sheet (Optional)

extension SGFPlayerScreensaver {

    override var hasConfigureSheet: Bool {
        return true
    }

    override var configureSheet: NSWindow? {
        // Create minimal configuration sheet
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "SGF Player Screensaver Settings"
        window.isReleasedWhenClosed = false

        // Add basic configuration UI
        let contentView = NSView(frame: window.contentView!.bounds)

        // Move speed slider
        let speedLabel = NSTextField(labelWithString: "Game Speed:")
        speedLabel.frame = NSRect(x: 20, y: 220, width: 100, height: 20)
        contentView.addSubview(speedLabel)

        let speedSlider = NSSlider(frame: NSRect(x: 130, y: 220, width: 200, height: 20))
        speedSlider.minValue = 0.5
        speedSlider.maxValue = 5.0
        speedSlider.doubleValue = moveInterval
        speedSlider.target = self
        speedSlider.action = #selector(speedChanged(_:))
        contentView.addSubview(speedSlider)

        // Physics model selector
        let physicsLabel = NSTextField(labelWithString: "Physics Model:")
        physicsLabel.frame = NSRect(x: 20, y: 180, width: 100, height: 20)
        contentView.addSubview(physicsLabel)

        let physicsPopup = NSPopUpButton(frame: NSRect(x: 130, y: 180, width: 200, height: 25))
        physicsPopup.addItems(withTitles: ["Spiral", "Group Drop", "Energy Minimization"])
        physicsPopup.selectItem(at: physicsEngine.activeModelIndex)
        physicsPopup.target = self
        physicsPopup.action = #selector(physicsChanged(_:))
        contentView.addSubview(physicsPopup)

        window.contentView = contentView
        return window
    }

    @objc private func speedChanged(_ sender: NSSlider) {
        moveInterval = sender.doubleValue
        startGamePlayback() // Restart with new interval
    }

    @objc private func physicsChanged(_ sender: NSPopUpButton) {
        physicsEngine.activeModelIndex = sender.indexOfSelectedItem
        updatePhysicsForCurrentMove() // Apply immediately
    }
}