// MARK: - SceneManager3D
// Manages the 3D scene, board, and stones
//
// Extracted from ContentView3D.swift (Phase 4)
// Handles all SceneKit rendering logic for the 3D Go board

import Foundation
import SceneKit
import AppKit

class SceneManager3D: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let pivotNode = SCNNode()  // Pivot for camera rotation around board center
    private var boardNode: SCNNode?
    private var stoneNodes: [SCNNode] = []
    private var currentPlayer: SGFPlayer?

    // Board configuration
    private var boardSize: Int = 19  // Default to 19, will update based on loaded game
    // Traditional Japanese board: cells are taller than they are wide
    // Ratio is approximately 1:1.0773 (width:height)
    // Base cell sizes for 19x19 board
    private let baseCellWidth: CGFloat = 1.0
    private let baseCellHeight: CGFloat = 1.0773
    private let boardThickness: CGFloat = 2.0

    // Computed effective cell sizes - scale smaller boards to fill same space as 19x19
    private var effectiveCellWidth: CGFloat {
        let scaleFactor = CGFloat(18) / CGFloat(boardSize - 1)  // 18 = 19-1 cells on standard board
        return baseCellWidth * scaleFactor
    }
    private var effectiveCellHeight: CGFloat {
        let scaleFactor = CGFloat(18) / CGFloat(boardSize - 1)
        return baseCellHeight * scaleFactor
    }

    // Traditional Japanese stone sizes: black 22.2mm, white 21.9mm
    // Scale to our units and scale with board size to maintain proportion
    private var effectiveBlackStoneRadius: CGFloat {
        let scaleFactor = CGFloat(18) / CGFloat(boardSize - 1)
        return 0.456 * scaleFactor  // 22.2mm / 22mm * 0.45
    }
    private var effectiveWhiteStoneRadius: CGFloat {
        let scaleFactor = CGFloat(18) / CGFloat(boardSize - 1)
        return 0.450 * scaleFactor  // 21.9mm / 22mm * 0.45
    }

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

        // Directional light from upper left (180 degrees from upper right)
        // Was (10, 20, 10) - now (-10, 20, -10) for upper left
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = NSColor(white: 0.8, alpha: 1.0)
        directionalLight.light!.castsShadow = true
        directionalLight.light!.shadowMode = .deferred
        directionalLight.light!.shadowRadius = 3.0  // Soft shadow edges
        directionalLight.light!.shadowSampleCount = 16  // Smooth shadows
        directionalLight.light!.shadowColor = NSColor(white: 0.0, alpha: 0.3)  // Gentle shadow opacity
        directionalLight.position = SCNVector3(x: -10, y: 20, z: -10)
        directionalLight.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(directionalLight)
    }

    func setupInitialScene(player: SGFPlayer) {
        self.currentPlayer = player
        updateStones(from: player)
    }

    func updateStones(from player: SGFPlayer, jitterMultiplier: CGFloat = 1.0, jitterOffsets: [BoardPosition: CGPoint] = [:]) {
        // Check if board size has changed
        let board = player.board
        if boardSize != board.size {
            NSLog("DEBUG3D: Board size changed from \(boardSize) to \(board.size) - recreating board")
            boardSize = board.size
            createBoard()  // Recreate the board with new size
        }

        // Remove all existing stones
        stoneNodes.forEach { $0.removeFromParentNode() }
        stoneNodes.removeAll()

        // Create stones based on current board state
        let totalWidth = CGFloat(boardSize - 1) * effectiveCellWidth
        let totalHeight = CGFloat(boardSize - 1) * effectiveCellHeight
        let offsetX = -totalWidth / 2.0
        let offsetZ = -totalHeight / 2.0
        let boardTopY = boardThickness / 2.0

        NSLog("DEBUG3D: 🎯 updateStones called - board size: \(board.size), current index: \(player.currentIndex), jitter: \(jitterMultiplier)")

        // Track stone positions and radii for collision detection
        var stonePositions: [(position: SCNVector3, radius: CGFloat)] = []

        var stoneCount = 0
        for row in 0..<board.size {
            for col in 0..<board.size {
                if let stone = board.grid[row][col] {
                    let stoneRadius = stone == .black ? effectiveBlackStoneRadius : effectiveWhiteStoneRadius

                    var x = CGFloat(col) * effectiveCellWidth + offsetX
                    var z = CGFloat(row) * effectiveCellHeight + offsetZ

                    // Apply jitter if available
                    let position = BoardPosition(x: col, y: row)
                    if let jitterOffset = jitterOffsets[position] {
                        // Jitter is in fraction of stone radius (0-0.22 range)
                        // Scale by stone diameter for more visible effect
                        let stoneDiameter = stoneRadius * 2.0
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

                    var finalPosition = SCNVector3(x: x, y: y, z: z)

                    // Check for collisions with existing stones and resolve
                    finalPosition = resolveCollisions(proposedPosition: finalPosition, radius: stoneRadius, existingStones: stonePositions)

                    let stoneNode = createStone(color: stone, at: finalPosition)

                    // Add halo to the last played stone
                    if let lastMove = player.lastMove, lastMove.x == col && lastMove.y == row {
                        addHaloToStone(stoneNode, color: stone, radius: stoneRadius)
                    }

                    scene.rootNode.addChildNode(stoneNode)
                    stoneNodes.append(stoneNode)
                    stonePositions.append((finalPosition, stoneRadius))
                    stoneCount += 1
                }
            }
        }
        NSLog("DEBUG3D: 🎯 Created \(stoneCount) stone nodes")
    }

    private func resolveCollisions(proposedPosition: SCNVector3, radius: CGFloat, existingStones: [(position: SCNVector3, radius: CGFloat)]) -> SCNVector3 {
        var adjustedPosition = proposedPosition

        // Try to resolve collisions by nudging the stone
        for _ in 0..<10 {  // Max 10 iterations
            var hasCollision = false

            for existing in existingStones {
                let dx = adjustedPosition.x - existing.position.x
                let dz = adjustedPosition.z - existing.position.z
                let distance = sqrt(dx * dx + dz * dz)

                // Minimum distance is sum of both radii
                let minDistance = radius + existing.radius

                if distance < minDistance {
                    hasCollision = true

                    // Push the stone away from the collision
                    if distance > 0.001 {
                        let pushDistance = (minDistance - distance) / 2.0
                        let pushX = (dx / distance) * pushDistance
                        let pushZ = (dz / distance) * pushDistance
                        adjustedPosition.x += pushX
                        adjustedPosition.z += pushZ
                    } else {
                        // Stones exactly on top of each other - push in random direction
                        adjustedPosition.x += CGFloat.random(in: -0.1...0.1)
                        adjustedPosition.z += CGFloat.random(in: -0.1...0.1)
                    }
                }
            }

            if !hasCollision {
                break
            }
        }

        return adjustedPosition
    }

    private func createStone(color: Stone, at position: SCNVector3) -> SCNNode {
        // Create bi-convex lens shape (like M&M or lentil)
        // Real Go stones: black 22.2mm, white 21.9mm diameter, 10.7mm thick for size 36
        // Our scale: cellSize = 1.0 unit
        // Thickness ratio: 10.7 / 22 = 0.486

        // Use appropriate radius for stone color (scaled based on board size)
        let stoneRadius = color == .black ? effectiveBlackStoneRadius : effectiveWhiteStoneRadius
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

    private func addHaloToStone(_ stoneNode: SCNNode, color: Stone, radius: CGFloat) {
        NSLog("DEBUG3D: ✨ Adding halo to \(color) stone with radius \(radius)")

        let thicknessRatio: CGFloat = 0.486
        let stoneHalfHeight = radius * thicknessRatio

        // 1. Create permanent glow disc UNDER the stone
        let underGlowRadius = radius * 1.4
        let underGlowHeight: CGFloat = 0.03

        let underDisc = SCNCylinder(radius: underGlowRadius, height: underGlowHeight)
        let underNode = SCNNode(geometry: underDisc)

        let underMaterial = SCNMaterial()
        // Use complementary colors: amber for black stones, bright cyan/blue for white stones
        if color == .white {
            underMaterial.emission.contents = NSColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.25)
            underMaterial.diffuse.contents = NSColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 0.12)
        } else {
            underMaterial.emission.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.25)
            underMaterial.diffuse.contents = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.12)
        }
        underMaterial.isDoubleSided = true
        underMaterial.transparency = 0.88
        underMaterial.lightingModel = .constant
        underMaterial.blendMode = .add
        underMaterial.writesToDepthBuffer = false
        underMaterial.readsFromDepthBuffer = true
        underDisc.materials = [underMaterial]

        underNode.position = SCNVector3(0, -stoneHalfHeight - underGlowHeight/2 + 0.002, 0)
        underNode.opacity = 0.25

        // Add a subtle pulsing animation to the under-glow
        let pulse = SCNAction.sequence([
            SCNAction.fadeOpacity(to: 0.35, duration: 0.8),
            SCNAction.fadeOpacity(to: 0.25, duration: 0.8)
        ])
        let repeatPulse = SCNAction.repeatForever(pulse)
        underNode.runAction(repeatPulse)

        stoneNode.addChildNode(underNode)

        // 2. Create expanding circle rings that move upward (ripple effect)
        let numRings = 3
        for i in 0..<numRings {
            let delay = Double(i) * 0.15

            let ringRadius = radius * 0.8
            let ringThickness: CGFloat = 0.08

            let torus = SCNTorus(ringRadius: ringRadius, pipeRadius: ringThickness)
            torus.ringSegmentCount = 48
            torus.pipeSegmentCount = 12

            let ringNode = SCNNode(geometry: torus)

            let ringMaterial = SCNMaterial()
            // Use darker blue for white stones, bright amber for black stones
            if color == .white {
                ringMaterial.emission.contents = NSColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 0.5)
                ringMaterial.diffuse.contents = NSColor(red: 0.05, green: 0.2, blue: 0.4, alpha: 0.3)
            } else {
                ringMaterial.emission.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.5)
                ringMaterial.diffuse.contents = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.3)
            }
            ringMaterial.isDoubleSided = true
            ringMaterial.transparency = 0.7
            ringMaterial.lightingModel = .constant
            ringMaterial.blendMode = .add
            ringMaterial.writesToDepthBuffer = false
            ringMaterial.readsFromDepthBuffer = true
            torus.materials = [ringMaterial]

            ringNode.position = SCNVector3(0, stoneHalfHeight * 0.5, 0)
            ringNode.opacity = 0
            ringNode.eulerAngles.x = .pi / 2

            // Animation: fade in, expand and rise, fade out
            let fadeIn = SCNAction.fadeOpacity(to: 0.8, duration: 0.15)
            let fadeOut = SCNAction.fadeOut(duration: 0.4)
            let opacitySequence = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                fadeIn,
                SCNAction.wait(duration: 0.1),
                fadeOut
            ])

            let scaleAction = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                SCNAction.scale(to: 2.0, duration: 0.65)
            ])

            let moveUp = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                SCNAction.moveBy(x: 0, y: radius * 1.5, z: 0, duration: 0.65)
            ])

            ringNode.runAction(opacitySequence)
            ringNode.runAction(scaleAction)
            ringNode.runAction(moveUp)

            stoneNode.addChildNode(ringNode)
        }
    }

    private func createBoard() {
        // Remove old board and grid nodes if they exist
        boardNode?.removeFromParentNode()
        scene.rootNode.childNodes.filter { node in
            // Remove grid lines (SCNBox), hoshi points (SCNSphere), and blocker planes
            (node.geometry is SCNBox || node.geometry is SCNSphere) && node.position.y >= -boardThickness
        }.forEach { $0.removeFromParentNode() }

        // Create a 3D Go board with traditional Japanese proportions
        // Board has (boardSize - 1) cells, plus 1 cell width border on each side
        // So total = (boardSize - 1) * cellWidth + 2 * cellWidth = (boardSize + 1) * cellWidth
        // Use effectiveCellWidth/Height so all board sizes have same physical dimensions
        let boardWidth = CGFloat(boardSize + 1) * effectiveCellWidth
        let boardLength = CGFloat(boardSize + 1) * effectiveCellHeight

        // Board base
        let boardGeometry = SCNBox(
            width: boardWidth,
            height: boardThickness,
            length: boardLength,
            chamferRadius: 0.0  // Square corners
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

        // Make board fully opaque - no transparency
        material.transparency = 1.0
        material.isDoubleSided = false  // Only render front face
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true

        boardGeometry.materials = [material]

        let boardNode = SCNNode(geometry: boardGeometry)
        boardNode.position = SCNVector3(x: 0, y: 0, z: 0)
        boardNode.castsShadow = false  // Board doesn't cast shadows
        scene.rootNode.addChildNode(boardNode)
        self.boardNode = boardNode

        // Add opaque blocker plane INSIDE the board to prevent see-through
        // Make it slightly smaller so it's hidden inside
        let blockerPlane = SCNBox(
            width: boardWidth * 0.98,  // Slightly smaller
            height: 0.01,  // Very thin
            length: boardLength * 0.98,  // Slightly smaller
            chamferRadius: 0
        )
        let blockerMaterial = SCNMaterial()
        blockerMaterial.diffuse.contents = NSColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0)  // Wood color
        blockerMaterial.isDoubleSided = false
        blockerMaterial.transparency = 1.0  // Fully opaque
        blockerMaterial.writesToDepthBuffer = true
        blockerPlane.materials = [blockerMaterial]

        let blockerNode = SCNNode(geometry: blockerPlane)
        blockerNode.position = SCNVector3(x: 0, y: -boardThickness / 4.0, z: 0)  // Inside the board, halfway down
        blockerNode.renderingOrder = -1  // Render before everything else
        scene.rootNode.addChildNode(blockerNode)

        // Create grid lines
        createGridLines(boardThickness: boardThickness)
    }

    private func createGridLines(boardThickness: CGFloat) {
        let lineThickness: CGFloat = 0.02
        let lineHeight: CGFloat = 0.002  // Very thin lines
        let lineColor = NSColor.black
        let boardTopY = boardThickness / 2.0 + 0.02  // Position lines well above board surface

        let totalWidth = CGFloat(boardSize - 1) * effectiveCellWidth
        let totalHeight = CGFloat(boardSize - 1) * effectiveCellHeight
        let offsetX = -totalWidth / 2.0
        let offsetZ = -totalHeight / 2.0

        // Horizontal lines (run along X axis, spaced in Z direction)
        for i in 0..<boardSize {
            let z = CGFloat(i) * effectiveCellHeight + offsetZ
            let line = SCNBox(
                width: totalWidth,
                height: lineHeight,
                length: lineThickness,
                chamferRadius: 0
            )
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            material.isDoubleSided = false
            material.writesToDepthBuffer = true
            line.materials = [material]

            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x: 0, y: boardTopY, z: z)
            lineNode.renderingOrder = 1  // Render on top
            scene.rootNode.addChildNode(lineNode)
        }

        // Vertical lines (run along Z axis, spaced in X direction)
        for i in 0..<boardSize {
            let x = CGFloat(i) * effectiveCellWidth + offsetX
            let line = SCNBox(
                width: lineThickness,
                height: lineHeight,
                length: totalHeight,
                chamferRadius: 0
            )
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            material.isDoubleSided = false
            material.writesToDepthBuffer = true
            line.materials = [material]

            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x: x, y: boardTopY, z: 0)
            lineNode.renderingOrder = 1  // Render on top
            scene.rootNode.addChildNode(lineNode)
        }

        // Star points (hoshi points) - vary by board size
        let starPoints: [(Int, Int)] = {
            switch boardSize {
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

        for (col, row) in starPoints {
            let xPos = CGFloat(col) * effectiveCellWidth + offsetX
            let zPos = CGFloat(row) * effectiveCellHeight + offsetZ

            let star = SCNSphere(radius: 0.08)
            let material = SCNMaterial()
            material.diffuse.contents = lineColor
            material.isDoubleSided = false
            material.writesToDepthBuffer = true
            star.materials = [material]

            let starNode = SCNNode(geometry: star)
            starNode.position = SCNVector3(x: xPos, y: boardTopY + 0.01, z: zPos)
            starNode.renderingOrder = 1  // Render on top
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

    func updateCameraPosition(distance: CGFloat, rotationX: Float, rotationY: Float, panX: CGFloat, panY: CGFloat) {
        // Update pivot rotation
        pivotNode.eulerAngles.y = CGFloat(rotationY)
        pivotNode.eulerAngles.x = CGFloat(rotationX)

        // Update camera distance and pan
        // Calculate base position at distance
        let baseY: CGFloat = 15
        let baseZ: CGFloat = 20

        // Scale the base position by the distance ratio
        let distanceRatio = distance / 25.0  // 25 was the original distance

        cameraNode.position = SCNVector3(
            x: panX,
            y: baseY * distanceRatio + panY,
            z: baseZ * distanceRatio
        )

        // Look at the pan offset point
        cameraNode.look(at: SCNVector3(x: panX, y: panY, z: 0))
    }
}
