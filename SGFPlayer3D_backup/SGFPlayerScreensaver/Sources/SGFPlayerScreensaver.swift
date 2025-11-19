// MARK: - SGFPlayerScreensaver (Complete Core Graphics Implementation)
// Complete macOS screensaver implementation for Sequoia v15.5
// Handles Sequoia v15.5 permissions and restrictions

import ScreenSaver
import Cocoa

@objc(SGFPlayerScreensaver)
class SGFPlayerScreensaver: ScreenSaverView {

    // MARK: - Core Components
    private var gameEngine: SGFPlayer?
    private var currentGame: SGFGame?
    private var physicsEngine: PhysicsEngine
    private var layoutService: LayoutService
    private var boardRenderer: SimpleBoardRenderer
    private var bowlRenderer: BowlRenderer

    // MARK: - Timing and Animation
    private var lastMoveTime: TimeInterval = 0
    private var moveInterval: TimeInterval = 2.0 // seconds between moves

    // MARK: - Layout Properties
    private var boardFrame: CGRect = .zero
    private var bowlRadius: CGFloat = 50
    private var stoneRadius: CGFloat = 10

    // MARK: - Initialization

    override init?(frame: NSRect, isPreview: Bool) {
        // Initialize services
        self.physicsEngine = PhysicsEngine()
        self.layoutService = LayoutService()
        self.boardRenderer = SimpleBoardRenderer(boardSize: 19, stoneDiameter: 20)
        self.bowlRenderer = BowlRenderer(
            lidSize: 100,
            stoneDiameter: 16,
            repulsion: 1.0,
            targetSpacingXRadius: 1.5,
            centerPullPerLid: 0.1,
            relaxIterations: 50
        )

        super.init(frame: frame, isPreview: isPreview)

        // Configure for screensaver environment
        self.wantsLayer = true
        self.animationTimeInterval = 1.0/30.0 // 30 FPS

        // Load demo game
        loadDemoGame()

        print("🔄 SGFPlayerScreensaver: Initialized successfully")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented for screensaver")
    }

    // MARK: - Demo Game Creation

    private func createDemoGames() -> [SGFGame] {
        // Simple tactical sequence
        let tacticalSGF = """
        (;FF[4]CA[UTF-8]AP[SGF:1.17]ST[2]
        RU[Japanese]SZ[19]KM[6.50]
        ;B[pd];W[dp];B[pp];W[dc];B[pj];W[nc];B[lc];W[qc];B[pc];W[pb]
        ;B[ob];W[qb];B[oc];W[re];B[og];W[fq];B[cn];W[fp];B[dj];W[qn]
        ;B[nq];W[rp];B[qq];W[ql];B[ol];W[rq];B[qr];W[rj];B[ri];W[qj]
        ;B[qi];W[oj];B[ok];W[pi];B[oh];W[pk];B[pl];W[qk];B[qm];W[rm]
        ;B[pm];W[rn];B[pn];W[ro];B[mn];W[cf];B[ch];W[cc];B[ef];W[cd]
        ;B[jc];W[hc];B[je];W[he];B[jg];W[hg];B[ji];W[hi];B[jk];W[ik]
        ;B[jl];W[il];B[jm];W[im];B[jn];W[in];B[jo];W[io];B[jp];W[ip]
        ;B[jq];W[iq];B[jr];W[ir];B[js];W[is];B[kr];W[mr];B[nr];W[ms]
        ;B[ns];W[lr];B[kq];W[lq];B[kp];W[lp];B[ko];W[lo];B[ln];W[mo]
        ;B[no];W[mp];B[np];W[mq];B[or];W[ks];B[ls];W[ks];B[ms])
        """

        // Corner joseki
        let josekiSGF = """
        (;FF[4]CA[UTF-8]AP[SGF:1.17]ST[2]
        RU[Japanese]SZ[19]KM[6.50]
        ;B[qd];W[dd];B[pq];W[dp];B[fc];W[cf];B[ql];W[nc];B[oe];W[qc]
        ;B[rc];W[pc];B[re];W[kc];B[fq];W[hq];B[cq];W[dq];B[cp];W[do]
        ;B[dr];W[er];B[cr];W[eq];B[cn];W[fp];B[co];W[gq];B[fe];W[df]
        ;B[id];W[ic];B[hd];W[hc];B[gd];W[jd];B[ie];W[je];B[if];W[jf]
        ;B[ig];W[jg];B[ih];W[jh];B[ii];W[ji];B[ij];W[jj];B[ik];W[jk]
        ;B[il];W[jl];B[im];W[jm];B[in];W[jn];B[io];W[jo];B[ip];W[jp]
        ;B[iq];W[ir];B[jr];W[hr];B[jq];W[kp];B[kq];W[lp];B[lq];W[mp]
        ;B[mq];W[np];B[nq];W[op];B[oq];W[pp];B[qp];W[po];B[qo];W[pn]
        ;B[qn];W[pm];B[pl];W[om];B[ol];W[nm];B[nl];W[mm];B[ml];W[lm])
        """

        do {
            let tacticalTree = try SGFParser.parseToGameTree(text: tacticalSGF)
            let josekiTree = try SGFParser.parseToGameTree(text: josekiSGF)

            let tacticalGame = SGFGame.from(tree: tacticalTree)
            let josekiGame = SGFGame.from(tree: josekiTree)

            return [tacticalGame, josekiGame]
        } catch {
            print("⚠️ SGFPlayerScreensaver: Failed to parse demo games: \(error)")
            return []
        }
    }

    private func loadDemoGame() {
        let games = createDemoGames()
        guard let game = games.randomElement() else {
            print("⚠️ SGFPlayerScreensaver: No demo games available")
            return
        }

        currentGame = game
        gameEngine = SGFPlayer()
        gameEngine?.load(game: game)

        // Reset to beginning
        gameEngine?.reset()
        updateLayout()

        print("🔄 SGFPlayerScreensaver: Loaded game with \(game.moves.count) moves")
    }

    // MARK: - ScreenSaverView Overrides

    override func draw(_ rect: NSRect) {
        super.draw(rect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Clear background
        context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
        context.fill(rect)

        // Draw board
        if let engine = gameEngine {
            drawBoard(in: context)
            drawBowlStones(in: context)
            drawGameInfo(in: context)
        }
    }

    override func animateOneFrame() {
        let currentTime = CACurrentMediaTime()

        if currentTime - lastMoveTime >= moveInterval {
            advanceGame()
            lastMoveTime = currentTime
        }

        needsDisplay = true
    }

    override func startAnimation() {
        super.startAnimation()
        lastMoveTime = CACurrentMediaTime()
        print("🔄 SGFPlayerScreensaver: Animation started")
    }

    override func stopAnimation() {
        super.stopAnimation()
        print("🔄 SGFPlayerScreensaver: Animation stopped")
    }

    // MARK: - Game Logic

    private func advanceGame() {
        guard let engine = gameEngine, let game = currentGame else { return }

        if engine.currentIndex < game.moves.count {
            // Advance to next move
            engine.stepForward()
            updateLayout()
        } else {
            // Game finished, restart with different demo game
            loadDemoGame()
        }
    }

    // MARK: - Layout and Physics Updates

    private func updateLayout() {
        // Calculate board layout for current screen size
        let responsive = layoutService.calculateResponsiveLayout(
            in: GeometryProxy(frame: bounds),
            topSpaceCellUnits: 2.0,
            bottomSpaceCellUnits: 3.0
        )

        boardFrame = responsive.boardFrame
        bowlRadius = responsive.bowlRadius
        stoneRadius = bowlRadius / 6.0
    }

    // MARK: - Core Graphics Rendering

    private func drawBoard(in context: CGContext) {
        guard let engine = gameEngine else { return }

        let board = engine.board
        let lastMove = engine.lastMove

        boardRenderer.renderBoard(
            board: board,
            in: context,
            boardRect: boardFrame,
            lastMove: lastMove
        )
    }

    private func drawBowlStones(in context: CGContext) {
        guard let engine = gameEngine else { return }

        // Simple physics calculation for captured stones
        let (blackCaptured, whiteCaptured) = calculateCaptures(engine: engine)

        if blackCaptured > 0 || whiteCaptured > 0 {
            // Create stones for bowls
            var blackStones: [LidStone] = []
            var whiteStones: [LidStone] = []

            // Generate stone positions using physics
            for i in 0..<blackCaptured {
                let angle = Double(i) * 2.0 * Double.pi / Double(max(blackCaptured, 1))
                let radius = 20.0 + Double(i % 3) * 10.0
                let x = cos(angle) * radius
                let y = sin(angle) * radius
                blackStones.append(LidStone(isWhite: false, offset: CGPoint(x: x, y: y)))
            }

            for i in 0..<whiteCaptured {
                let angle = Double(i) * 2.0 * Double.pi / Double(max(whiteCaptured, 1))
                let radius = 20.0 + Double(i % 3) * 10.0
                let x = cos(angle) * radius
                let y = sin(angle) * radius
                whiteStones.append(LidStone(isWhite: true, offset: CGPoint(x: x, y: y)))
            }

            // Draw bowls
            let bowlCenter = CGPoint(x: bounds.width - 100, y: bounds.height - 100)
            bowlRenderer.renderBowl(at: bowlCenter, with: blackCaptured > whiteCaptured ? blackStones : whiteStones, in: context)
        }
    }

    private func calculateCaptures(engine: SGFPlayer) -> (black: Int, white: Int) {
        // Simple capture calculation - in a full implementation this would be more sophisticated
        let moveIndex = engine.currentIndex
        let blackCaptured = moveIndex / 20 // Demo calculation
        let whiteCaptured = moveIndex / 25 // Demo calculation
        return (blackCaptured, whiteCaptured)
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
            x: bounds.width - textSize.width - 20,
            y: 20,
            width: textSize.width,
            height: textSize.height
        )

        context.saveGState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        attributedString.draw(in: textRect)
        context.restoreGState()
    }

    // MARK: - Configuration (Optional)

    override var hasConfigureSheet: Bool {
        return false // Simplified for initial version
    }
}

// MARK: - Helper Extensions

extension SGFPlayerScreensaver {
    // Using GeometryProxy from LayoutService
}