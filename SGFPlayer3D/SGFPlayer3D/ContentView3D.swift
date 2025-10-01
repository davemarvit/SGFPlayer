// MARK: - ContentView3D - 3D Go Board Viewer
// This is a new 3D version of SGFPlayer that uses SceneKit for 3D board rendering

import SwiftUI
import SceneKit

// Helper for logging to file
extension String {
    func appendToFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            handle.write(self.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try self.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct ContentView3D: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var player = SGFPlayer()
    @StateObject private var sceneManager = SceneManager3D()

    // Rotation tracking
    @State private var lastDragPosition: CGPoint = .zero
    @State private var currentRotationX: Float = 0.0
    @State private var currentRotationY: Float = 0.0

    // Playback control
    @State private var isPlaying: Bool = false
    @State private var playbackSpeed: Double = UserDefaults.standard.object(forKey: "playbackSpeed") as? Double ?? 1.0
    @State private var playbackTimer: Timer? = nil
    @State private var gameEndTimer: Timer? = nil

    // UI State
    @State private var isFullscreen: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        let _ = {
            let log = "DEBUG3D: 🚀 ContentView3D body is rendering\n"
            try? log.appendToFile(at: "/tmp/sgfplayer3d_debug.log")
            print(log)
        }()
        return ZStack {
            sceneView
                .contentShape(Rectangle())
                .onTapGesture {
                    if showSettings {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings = false
                        }
                    }
                }

            if showSettings {
                settingsPanel
            }

            overlayUI
        }
        .onChange(of: player.currentIndex) { _, newIndex in
            updateStonesWithJitter()

            // Check if game has ended
            if newIndex >= player.moves.count - 1 {
                gameEndTimer?.invalidate()
                gameEndTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    advanceToNextGame()
                }
            }
        }
        .onChange(of: app.selection) { _, newSelection in
            if let gameWrapper = newSelection {
                player.load(game: gameWrapper.game)
                app.selectGame(gameWrapper)  // Load into cache manager
                updateStonesWithJitter()
            }
        }
        .onChange(of: playbackSpeed) { _, newSpeed in
            UserDefaults.standard.set(newSpeed, forKey: "playbackSpeed")
        }
        .onChange(of: app.gameCacheManager.defaultJitterMultiplier) { _, newJitter in
            NSLog("DEBUG3D: 🎲 Jitter changed to: \(newJitter)")
            updateStonesWithJitter()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
        .onAppear {
            sceneManager.setupInitialScene(player: player)

            // Load the initial game if one is selected
            if let gameWrapper = app.selection {
                NSLog("DEBUG3D: 🎮 Loading initial game on appear: \(gameWrapper.url.lastPathComponent)")
                player.load(game: gameWrapper.game)
                app.selectGame(gameWrapper)  // Load into cache manager with jitter calculation
                updateStonesWithJitter()
            } else {
                NSLog("DEBUG3D: ⚠️ No game selected on appear")
            }
        }
    }

    var sceneView: some View {
        SceneView(
            scene: sceneManager.scene,
            pointOfView: sceneManager.cameraNode,
            options: [.autoenablesDefaultLighting]
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    let sensitivity: CGFloat = 0.005
                    let deltaX = CGFloat(value.translation.width) * sensitivity
                    let deltaY = CGFloat(value.translation.height) * sensitivity

                    currentRotationY = Float(-deltaX)
                    currentRotationX = Float(-deltaY)

                    sceneManager.pivotNode.eulerAngles.y = CGFloat(currentRotationY)
                    sceneManager.pivotNode.eulerAngles.x = CGFloat(currentRotationX)
                }
                .onEnded { _ in
                    // Keep current rotation
                }
        )
        .ignoresSafeArea()
    }

    var settingsPanel: some View {
        HStack {
            SettingsPanelView3D(
                isPanelOpen: $showSettings,
                app: app,
                player: player,
                autoPlay: $isPlaying,
                playbackSpeed: $playbackSpeed,
                onGameSelected: { game in
                    player.load(game: game.game)
                    player.seek(to: 0)
                    updateStonesWithJitter()
                },
                onJitterChanged: {
                    NSLog("DEBUG3D: 🎲 onJitterChanged callback triggered")
                    updateStonesWithJitter()
                }
            )
            .transition(.move(edge: .leading))

            Spacer()
        }
        .zIndex(100)
    }

    var overlayUI: some View {
        VStack {
                // Top bar
                HStack {
                    // Settings button (left side)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings.toggle()
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .padding()

                    Text("SGFPlayer 3D")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.leading, -8)

                    Spacer()

                    // Game info
                    if let selection = app.selection {
                        VStack(alignment: .trailing) {
                            Text("\(selection.game.info.playerBlack ?? "?") vs \(selection.game.info.playerWhite ?? "?")")
                                .foregroundColor(.white)
                                .font(.headline)
                            Text("Move \(player.currentIndex) / \(player.moves.count)")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                        }
                        .padding()
                    }

                    // Fullscreen button (right side)
                    Button(action: {
                        toggleFullscreen()
                    }) {
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }

                Spacer()

                // Version number in lower right
                HStack {
                    Spacer()
                    Text("v0.10.2")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .padding(.trailing, 20)
                        .padding(.bottom, 8)
                }

                // Bottom controls
                HStack(spacing: 20) {
                    // Playback controls
                    VStack {
                        Text("Playback")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.bottom, 4)

                        HStack(spacing: 12) {
                            Button(action: {
                                player.seek(to: max(0, player.currentIndex - 1))
                                updateStonesWithJitter()
                            }) {
                                Image(systemName: "backward.fill")
                                    .foregroundColor(.white)
                            }
                            .disabled(player.currentIndex <= 0)

                            Button(action: {
                                togglePlayPause()
                            }) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(.white)
                            }
                            .keyboardShortcut(.space, modifiers: [])

                            Button(action: {
                                player.seek(to: min(player.moves.count, player.currentIndex + 1))
                                updateStonesWithJitter()
                            }) {
                                Image(systemName: "forward.fill")
                                    .foregroundColor(.white)
                            }
                            .disabled(player.currentIndex >= player.moves.count)
                        }

                        Slider(value: Binding(
                            get: { Double(player.currentIndex) },
                            set: { newValue in
                                player.seek(to: Int(newValue))
                                updateStonesWithJitter()
                            }
                        ), in: 0...Double(max(1, player.moves.count)), step: 1)
                        .frame(width: 200)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .padding()
        }
    }

    private func toggleFullscreen() {
        guard let window = NSApplication.shared.windows.first else {
            return
        }
        window.toggleFullScreen(nil)
    }

    private func advanceToNextGame() {
        guard !app.games.isEmpty else { return }

        if let currentSelection = app.selection,
           let currentIndex = app.games.firstIndex(where: { $0.id == currentSelection.id }) {
            // Move to next game, or loop to beginning
            let nextIndex = (currentIndex + 1) % app.games.count
            app.selection = app.games[nextIndex]
            player.load(game: app.games[nextIndex].game)
            app.selectGame(app.games[nextIndex])  // Load into cache manager
            player.seek(to: 0)
            updateStonesWithJitter()

            // Start playing the new game if autoplay was on
            if isPlaying {
                startPlayback()
            }
        } else if let first = app.games.first {
            // No selection, start with first game
            app.selection = first
            player.load(game: first.game)
            app.selectGame(first)  // Load into cache manager
            player.seek(to: 0)
            updateStonesWithJitter()

            // Start playing if autoplay was on
            if isPlaying {
                startPlayback()
            }
        }
    }

    private func startPlayback() {
        print("🎬 startPlayback called - currentIndex: \(player.currentIndex), moves: \(player.moves.count), speed: \(playbackSpeed)")

        // If we're at the end, go back to start
        if player.currentIndex >= player.moves.count - 1 {
            print("🎬 At end of game, resetting to start")
            player.seek(to: 0)
            updateStonesWithJitter()
        }

        playbackTimer?.invalidate()
        scheduleNextMove()
    }

    private func scheduleNextMove() {
        // Use a non-repeating timer so we can respect playbackSpeed changes
        playbackTimer = Timer.scheduledTimer(withTimeInterval: playbackSpeed, repeats: false) { [self] _ in
            print("🎬 Timer fired - currentIndex: \(player.currentIndex), moves: \(player.moves.count)")
            if player.currentIndex < player.moves.count - 1 {
                player.seek(to: player.currentIndex + 1)
                updateStonesWithJitter()

                // Schedule next move if still playing
                if isPlaying {
                    scheduleNextMove()
                }
            } else {
                print("🎬 Reached end of game - auto-advance will handle next game")
                // Don't set isPlaying = false here - let auto-advance continue to next game
            }
        }
    }

    private func togglePlayPause() {
        print("🎬 togglePlayPause called - isPlaying will become: \(!isPlaying)")
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            playbackTimer?.invalidate()
        }
    }

    private func updateStonesWithJitter() {
        // Generate jitter offsets on-the-fly based on board positions
        let jitterMultiplier = app.gameCacheManager.defaultJitterMultiplier

        // Generate stable jitter for each stone position
        var jitterOffsets: [BoardPosition: CGPoint] = [:]
        let board = player.board

        for row in 0..<board.size {
            for col in 0..<board.size {
                if board.grid[row][col] != nil {
                    let position = BoardPosition(x: col, y: row)

                    // Generate deterministic jitter based on position
                    let seed = UInt32(col * 73856093 + row * 19349663)
                    var rng = seed
                    let jitterX = CGFloat(Double(rng % 1000) / 1000.0 - 0.5) * 0.22 // -0.11 to +0.11
                    rng = rng &* 1103515245 &+ 12345
                    let jitterY = CGFloat(Double(rng % 1000) / 1000.0 - 0.5) * 0.22

                    jitterOffsets[position] = CGPoint(x: jitterX, y: jitterY)
                }
            }
        }

        sceneManager.updateStones(from: player, jitterMultiplier: jitterMultiplier, jitterOffsets: jitterOffsets)
    }
}


// MARK: - SceneManager3D
// Manages the 3D scene, board, and stones

class SceneManager3D: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let pivotNode = SCNNode()  // Pivot for camera rotation around board center
    private var boardNode: SCNNode?
    private var stoneNodes: [SCNNode] = []
    private var currentPlayer: SGFPlayer?

    // Board configuration
    private let boardSize: Int = 19
    private let cellSize: CGFloat = 1.0
    private let boardThickness: CGFloat = 2.0
    private let stoneRadius: CGFloat = 0.45

    init() {
        setupCamera()
        setupLighting()
        setupBackground()
        createBoard()

        NSLog("DEBUG3D: v0.1.6 SceneManager init complete - NOT loading test game here")
    }

    private func setupBackground() {
        // Create stars as actual 3D geometry objects
        NSLog("DEBUG3D: Creating 3D star field v0.8.6")

        // Dark blue background
        scene.background.contents = NSColor(red: 0.01, green: 0.01, blue: 0.05, alpha: 1.0)

        let starCount = 2000
        let starFieldRadius: CGFloat = 150.0

        for _ in 0..<starCount {
            // Random position on sphere surface
            let theta = CGFloat.random(in: 0...(2 * .pi))
            let phi = CGFloat.random(in: 0...(CGFloat.pi))

            let x = starFieldRadius * sin(phi) * cos(theta)
            let y = starFieldRadius * sin(phi) * sin(theta)
            let z = starFieldRadius * cos(phi)

            // Smaller stars with varied brightness
            let starSize = CGFloat.random(in: 0.15...0.4)
            let brightness = CGFloat.random(in: 0.5...1.0)

            let starMaterial = SCNMaterial()
            starMaterial.diffuse.contents = NSColor(white: brightness, alpha: 1.0)
            starMaterial.lightingModel = .constant  // Unlit
            starMaterial.emission.contents = NSColor(white: brightness, alpha: 1.0)

            let star = SCNSphere(radius: starSize)
            star.materials = [starMaterial]

            let starNode = SCNNode(geometry: star)
            starNode.position = SCNVector3(x, y, z)
            starNode.renderingOrder = -100  // Render behind everything
            scene.rootNode.addChildNode(starNode)
        }

        NSLog("DEBUG3D: Created \(starCount) 3D stars at radius \(starFieldRadius)")
    }

    private func loadTestGame() {
        NSLog("DEBUG3D: v0.1.3 loadTestGame START - creating embedded test game")

        // Create a simple embedded test game instead of loading from file
        let testSGF = "(;FF[4]GM[1]SZ[19];B[pd];W[dd];B[pq];W[dp];B[qo];W[nc];B[pf];W[pb];B[qc];W[kc])"

        do {
            let tree = try SGFParser.parse(text: testSGF)
            NSLog("DEBUG3D: v0.1.3 Test SGF parsed successfully")

            let game = SGFGame.from(tree: tree)
            NSLog("DEBUG3D: v0.1.3 Game created, moves: \(game.moves.count)")

            // Create a temporary player to get the board state
            let tempPlayer = SGFPlayer()
            tempPlayer.load(game: game)
            NSLog("DEBUG3D: v0.1.3 Game loaded into player")

            tempPlayer.seek(to: game.moves.count)  // Show all moves
            NSLog("DEBUG3D: v0.1.3 Seeked to move \(game.moves.count)")

            let board = tempPlayer.board
            NSLog("DEBUG3D: v0.1.3 Board size: \(board.size)")

            // Count stones on board
            var stoneCount = 0
            for row in 0..<board.size {
                for col in 0..<board.size {
                    if board.grid[row][col] != nil {
                        stoneCount += 1
                    }
                }
            }
            NSLog("DEBUG3D: v0.1.3 Stones on board before addStones: \(stoneCount)")

            // Add stones from the player
            NSLog("DEBUG3D: v0.1.4 About to call addStonesFromBoard")
            addStonesFromBoard(tempPlayer.board)
            NSLog("DEBUG3D: v0.1.4 Returned from addStonesFromBoard")

            NSLog("DEBUG3D: v0.1.3 loadTestGame COMPLETE")
        } catch {
            NSLog("DEBUG3D: v0.1.3 Failed to load test game: \(error)")
        }
    }

    private func addStonesFromBoard(_ board: BoardSnapshot) {
        NSLog("DEBUG3D: v0.1.4 addStonesFromBoard START - board size: \(board.size)")
        let totalSize = CGFloat(boardSize - 1) * cellSize
        let offset = -totalSize / 2.0
        let boardTopY = boardThickness / 2.0
        NSLog("DEBUG3D: v0.1.4 Calculated offset: \(offset), boardTopY: \(boardTopY)")

        var count = 0
        for row in 0..<board.size {
            for col in 0..<board.size {
                if let stone = board.grid[row][col] {
                    let x = CGFloat(col) * cellSize + offset
                    let z = CGFloat(row) * cellSize + offset
                    // Position stone so bottom just touches board
                    // Stone is ellipsoid scaled by thicknessRatio (0.486) in Y
                    let thicknessRatio: CGFloat = 0.486
                    let stoneScaledHalfHeight = stoneRadius * thicknessRatio
                    let y = boardTopY + stoneScaledHalfHeight

                    NSLog("DEBUG3D: v0.1.4 Creating stone #\(count+1) at (\(col),\(row)) - position (\(x),\(y),\(z)) - color: \(stone)")
                    let stoneNode = createStone(color: stone, at: SCNVector3(x: x, y: y, z: z))
                    NSLog("DEBUG3D: v0.1.4 Stone node created, adding to scene")
                    scene.rootNode.addChildNode(stoneNode)
                    stoneNodes.append(stoneNode)
                    count += 1
                    NSLog("DEBUG3D: v0.1.4 Stone #\(count) added successfully")
                }
            }
        }
        NSLog("DEBUG3D: v0.1.4 Added \(count) stones to scene.rootNode")
        NSLog("DEBUG3D: v0.1.4 Total nodes in scene: \(scene.rootNode.childNodes.count)")
    }

    private func setupCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 1000.0  // Allow seeing stars at distance
        cameraNode.camera = camera

        // Position pivot at board center (y=0 is center of 2.0 thick board)
        pivotNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(pivotNode)

        // Add camera to pivot so it rotates around board center
        pivotNode.addChildNode(cameraNode)

        // Position camera relative to pivot (board center)
        cameraNode.position = SCNVector3(x: 0, y: 15, z: 20)
        cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
    }

    private func setupLighting() {
        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = NSColor(white: 0.4, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // Directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = NSColor(white: 0.8, alpha: 1.0)
        directionalLight.position = SCNVector3(x: 10, y: 20, z: 10)
        directionalLight.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(directionalLight)
    }

    func setupInitialScene(player: SGFPlayer) {
        self.currentPlayer = player
        updateStones(from: player)
    }

    func updateStones(from player: SGFPlayer, jitterMultiplier: CGFloat = 1.0, jitterOffsets: [BoardPosition: CGPoint] = [:]) {
        // Remove all existing stones
        stoneNodes.forEach { $0.removeFromParentNode() }
        stoneNodes.removeAll()

        // Create stones based on current board state
        let board = player.board
        let totalSize = CGFloat(boardSize - 1) * cellSize
        let offset = -totalSize / 2.0
        let boardTopY = boardThickness / 2.0

        NSLog("DEBUG3D: 🎯 updateStones called - board size: \(board.size), current index: \(player.currentIndex), jitter: \(jitterMultiplier)")

        var stoneCount = 0
        for row in 0..<board.size {
            for col in 0..<board.size {
                if let stone = board.grid[row][col] {
                    var x = CGFloat(col) * cellSize + offset
                    var z = CGFloat(row) * cellSize + offset

                    // Apply jitter if available
                    let position = BoardPosition(x: col, y: row)
                    if let jitterOffset = jitterOffsets[position] {
                        // Jitter is in fraction of stone radius (0-0.22 range)
                        // Scale by stone diameter for more visible effect
                        let stoneDiameter = stoneRadius * 2.0  // ~0.9 units
                        let jitterX = jitterOffset.x * jitterMultiplier * stoneDiameter
                        let jitterZ = jitterOffset.y * jitterMultiplier * stoneDiameter
                        x += jitterX
                        z += jitterZ
                        if jitterMultiplier > 0.1 && stoneCount < 5 {
                            NSLog("DEBUG3D: 🎲 Applying jitter to stone at (\(col),\(row)): offset=(\(jitterOffset.x), \(jitterOffset.y)), scaled=(\(jitterX), \(jitterZ))")
                        }
                    }

                    // Position stone so bottom just touches board
                    // Stone is ellipsoid scaled by thicknessRatio (0.486) in Y
                    let thicknessRatio: CGFloat = 0.486
                    let stoneScaledHalfHeight = stoneRadius * thicknessRatio
                    let y = boardTopY + stoneScaledHalfHeight

                    let stoneNode = createStone(color: stone, at: SCNVector3(x: x, y: y, z: z))
                    scene.rootNode.addChildNode(stoneNode)
                    stoneNodes.append(stoneNode)
                    stoneCount += 1
                }
            }
        }
        NSLog("DEBUG3D: 🎯 Created \(stoneCount) stone nodes")
    }

    private func createStone(color: Stone, at position: SCNVector3) -> SCNNode {
        // Create bi-convex lens shape (like M&M or lentil)
        // Real Go stones: ~22mm diameter, 10.7mm thick for size 36
        // Our scale: cellSize = 1.0 unit, stoneRadius = 0.45 (diameter ~0.9)
        // Thickness ratio: 10.7 / 22 = 0.486

        let stoneDiameter = stoneRadius * 2.0  // 0.9 units
        let thicknessRatio: CGFloat = 0.486  // 10.7mm / 22mm from real stones

        // Create ellipsoid (sphere scaled to lens shape)
        let sphere = SCNSphere(radius: stoneRadius)
        sphere.segmentCount = 48  // More segments for smoother appearance

        let material = SCNMaterial()

        switch color {
        case .black:
            // Solid black for now - textures have transparency issues
            material.diffuse.contents = NSColor.black
            material.specular.contents = NSColor(white: 0.3, alpha: 1.0)
            material.shininess = 0.8
        case .white:
            // Solid white for now - textures have transparency issues
            material.diffuse.contents = NSColor.white
            material.specular.contents = NSColor(white: 0.9, alpha: 1.0)
            material.shininess = 1.0
        }

        // Configure material properties
        material.isDoubleSided = false
        material.lightingModel = .blinn

        sphere.materials = [material]

        let stoneNode = SCNNode(geometry: sphere)

        // Scale to create bi-convex lens shape
        // The Y scale determines thickness relative to diameter
        stoneNode.scale = SCNVector3(1.0, thicknessRatio, 1.0)

        stoneNode.position = position
        stoneNode.castsShadow = true

        return stoneNode
    }

    private func createBoard() {
        // Create a 3D Go board
        let boardSize: CGFloat = 19.0
        let cellSize: CGFloat = 1.0
        let boardThickness: CGFloat = 2.0  // Thicker board for better appearance

        // Board base
        let boardGeometry = SCNBox(
            width: boardSize * cellSize,
            height: boardThickness,
            length: boardSize * cellSize,
            chamferRadius: 0.15
        )

        // Load kaya texture
        let material = SCNMaterial()
        if let kayaImage = NSImage(named: "board_kaya") {
            material.diffuse.contents = kayaImage
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.diffuse.contentsTransform = SCNMatrix4MakeScale(1.0, 1.0, 1.0)
        } else {
            // Fallback to wood color if image not found
            material.diffuse.contents = NSColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0)
        }
        material.specular.contents = NSColor(white: 0.3, alpha: 1.0)
        material.shininess = 0.1
        boardGeometry.materials = [material]

        let boardNode = SCNNode(geometry: boardGeometry)
        boardNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(boardNode)
        self.boardNode = boardNode

        // Create grid lines
        createGridLines(boardSize: Int(boardSize), cellSize: cellSize, boardThickness: boardThickness)
    }

    private func createGridLines(boardSize: Int, cellSize: CGFloat, boardThickness: CGFloat) {
        let lineThickness: CGFloat = 0.02
        let lineHeight: CGFloat = 0.01
        let lineColor = NSColor.black
        let boardTopY = boardThickness / 2.0 + 0.01  // Position lines on top of board

        let totalSize = CGFloat(boardSize - 1) * cellSize
        let offset = -totalSize / 2.0

        // Horizontal lines
        for i in 0..<boardSize {
            let z = CGFloat(i) * cellSize + offset
            let line = SCNBox(
                width: totalSize,
                height: lineHeight,
                length: lineThickness,
                chamferRadius: 0
            )
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            line.materials = [material]

            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x: 0, y: boardTopY, z: z)
            scene.rootNode.addChildNode(lineNode)
        }

        // Vertical lines
        for i in 0..<boardSize {
            let x = CGFloat(i) * cellSize + offset
            let line = SCNBox(
                width: lineThickness,
                height: lineHeight,
                length: totalSize,
                chamferRadius: 0
            )
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            line.materials = [material]

            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x: x, y: boardTopY, z: 0)
            scene.rootNode.addChildNode(lineNode)
        }

        // Star points (for 19x19 board)
        let starPoints = [(3, 3), (3, 9), (3, 15), (9, 3), (9, 9), (9, 15), (15, 3), (15, 9), (15, 15)]
        for (x, z) in starPoints {
            let xPos = CGFloat(x) * cellSize + offset
            let zPos = CGFloat(z) * cellSize + offset

            let star = SCNSphere(radius: 0.08)
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            star.materials = [material]

            let starNode = SCNNode(geometry: star)
            starNode.position = SCNVector3(x: xPos, y: boardTopY + 0.01, z: zPos)
            scene.rootNode.addChildNode(starNode)
        }
    }

    func updateCamera(angleX: Double, angleY: Double, distance: Double) {
        let x = distance * cos(angleX * .pi / 180) * sin(angleY * .pi / 180)
        let y = distance * sin(angleX * .pi / 180)
        let z = distance * cos(angleX * .pi / 180) * cos(angleY * .pi / 180)

        cameraNode.position = SCNVector3(x: CGFloat(x), y: CGFloat(y), z: CGFloat(z))
        cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
    }
}

// MARK: - Preview
struct ContentView3D_Previews: PreviewProvider {
    static var previews: some View {
        ContentView3D()
            .environmentObject(AppModel())
    }
}
