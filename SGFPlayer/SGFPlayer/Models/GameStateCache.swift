// MARK: - GameStateCache.swift
// Comprehensive pre-calculated game state caching system

import Foundation
import CoreGraphics

// MARK: - Core Data Models

/// Represents the complete state of the game at a specific move
struct CachedGameState {
    let moveNumber: Int
    let boardPosition: BoardSnapshot
    let blackCaptured: Int
    let whiteCaptured: Int
    let bowlStonePositions: BowlPhysicsResult
    let stoneJitterOffsets: [BoardPosition: CGPoint]
    let lastMove: MoveRef?
}

/// Position on the board (for jitter indexing)
struct BoardPosition: Hashable {
    let x: Int
    let y: Int
}

/// Enhanced SGF game with pre-calculated states
final class EnhancedSGFGame: ObservableObject {
    // Original SGF data
    let originalGame: SGFGame
    let gameFingerprint: String

    // Pre-calculated game states (lazy loaded)
    @Published private(set) var gameStates: [CachedGameState] = []
    @Published private(set) var isCalculating: Bool = false
    @Published private(set) var calculationProgress: Double = 0.0

    // User settings
    @Published var jitterMultiplier: CGFloat = 1.0 {
        didSet {
            // When jitter multiplier changes, we only need to recalculate jitter offsets
            // Bowl physics and captures remain the same
            recalculateJitterOffsetsOnly()
        }
    }

    // Stone jitter generator (stable across scrubbing)
    private let stoneJitter = StoneJitter(size: 19, eccentricity: 1.0)

    init(game: SGFGame, fingerprint: String) {
        self.originalGame = game
        self.gameFingerprint = fingerprint
        self.stoneJitter.resizeIfNeeded(game.boardSize)
    }

    // MARK: - Public Interface

    /// Get the cached state for a specific move (blocking call)
    func getGameState(at moveIndex: Int) -> CachedGameState? {
        guard moveIndex >= 0 && moveIndex < gameStates.count else { return nil }
        return gameStates[moveIndex]
    }

    /// Get the game state, calculating if necessary
    func getOrCalculateGameState(at moveIndex: Int) async -> CachedGameState? {
        if moveIndex < gameStates.count {
            return gameStates[moveIndex]
        }

        // Calculate states up to the requested index
        await calculateGameStates(upTo: moveIndex)
        return getGameState(at: moveIndex)
    }

    /// Pre-calculate all game states in the background
    func preCalculateAllStates() async {
        // Disable background pre-calculation to prevent crashes with large folders
        // Game states will be calculated on-demand instead
        return
    }

    // MARK: - Calculation Logic

    private func calculateGameStates(upTo targetIndex: Int) async {
        await MainActor.run { isCalculating = true }

        let startIndex = gameStates.count
        let endIndex = min(targetIndex + 1, originalGame.moves.count + 1) // +1 for initial state

        for moveIndex in startIndex..<endIndex {
            await MainActor.run { calculationProgress = Double(moveIndex) / Double(endIndex) }

            let state = calculateGameState(at: moveIndex)

            await MainActor.run {
                gameStates.append(state)
            }
        }

        await MainActor.run {
            isCalculating = false
            calculationProgress = 1.0
        }
    }

    private func calculateGameState(at moveIndex: Int) -> CachedGameState {
        // Create a temporary engine to calculate this state
        let tempEngine = SGFPlayer()
        tempEngine.load(game: originalGame)
        tempEngine.seek(to: moveIndex)

        // Calculate captures by comparing with previous state
        let (blackCaptured, whiteCaptured) = calculateCaptures(at: moveIndex, using: tempEngine)

        // Calculate bowl physics
        let bowlPhysics = calculateBowlPhysics(blackCaptured: blackCaptured, whiteCaptured: whiteCaptured)

        // Calculate stone jitter offsets
        let jitterOffsets = calculateStoneJitterOffsets(board: tempEngine.board, moveIndex: moveIndex)

        return CachedGameState(
            moveNumber: moveIndex,
            boardPosition: tempEngine.board,
            blackCaptured: blackCaptured,
            whiteCaptured: whiteCaptured,
            bowlStonePositions: bowlPhysics,
            stoneJitterOffsets: jitterOffsets,
            lastMove: tempEngine.lastMove
        )
    }

    private func calculateCaptures(at moveIndex: Int, using engine: SGFPlayer) -> (black: Int, white: Int) {
        // Count stones on board at initial setup
        var initialBlackStones = 0
        var initialWhiteStones = 0

        for (stone, _, _) in originalGame.setup {
            if stone == .black { initialBlackStones += 1 }
            else { initialWhiteStones += 1 }
        }

        // Count moves played up to this point
        var blackMovesPlayed = 0
        var whiteMovesPlayed = 0

        for i in 0..<moveIndex {
            if i < originalGame.moves.count {
                let (stone, coord) = originalGame.moves[i]
                if coord != nil { // not a pass
                    if stone == .black { blackMovesPlayed += 1 }
                    else { whiteMovesPlayed += 1 }
                }
            }
        }

        // Count stones currently on board
        var currentBlackStones = 0
        var currentWhiteStones = 0

        for row in engine.board.grid {
            for stone in row {
                if stone == .black { currentBlackStones += 1 }
                else if stone == .white { currentWhiteStones += 1 }
            }
        }

        // Calculate captures
        let totalBlackStones = initialBlackStones + blackMovesPlayed
        let totalWhiteStones = initialWhiteStones + whiteMovesPlayed

        let blackCaptured = totalWhiteStones - currentWhiteStones // Black captured white stones
        let whiteCaptured = totalBlackStones - currentBlackStones // White captured black stones

        return (blackCaptured, whiteCaptured)
    }

    private func calculateBowlPhysics(blackCaptured: Int, whiteCaptured: Int) -> BowlPhysicsResult {
        // Use the existing physics system to calculate bowl stone positions
        let bowlRadius: CGFloat = 50.0 // This will be passed in from UI in practice
        let stoneRadius: CGFloat = bowlRadius * 0.18

        let physics = GroupDropPhysicsModel()

        // Calculate white stones captured by black (upper-left bowl)
        let whiteCapturedResult = physics.computeStonePositions(
            currentStoneCount: 0,
            targetStoneCount: blackCaptured,
            bowlRadius: bowlRadius,
            stoneRadius: stoneRadius,
            seed: UInt64(gameFingerprint.hashValue) + 1,
            isWhiteBowl: true // White stones in bowl
        )

        // Calculate black stones captured by white (lower-right bowl)
        let blackCapturedResult = physics.computeStonePositions(
            currentStoneCount: 0,
            targetStoneCount: whiteCaptured,
            bowlRadius: bowlRadius,
            stoneRadius: stoneRadius,
            seed: UInt64(gameFingerprint.hashValue) + 2,
            isWhiteBowl: false // Black stones in bowl
        )

        // Combine results (we'll need to extend BowlPhysicsResult to handle both bowls)
        return BowlPhysicsResult(
            stones: whiteCapturedResult.stones + blackCapturedResult.stones,
            convergenceInfo: "Cached: \(whiteCapturedResult.convergenceInfo) + \(blackCapturedResult.convergenceInfo)"
        )
    }

    private func calculateStoneJitterOffsets(board: BoardSnapshot, moveIndex: Int) -> [BoardPosition: CGPoint] {
        var offsets: [BoardPosition: CGPoint] = [:]

        // Calculate stable jitter offset for each stone on the board
        for row in 0..<board.size {
            for col in 0..<board.size {
                if board.grid[row][col] != nil {
                    let position = BoardPosition(x: col, y: row)

                    // Use deterministic seeding based on position and game fingerprint
                    var seed = UInt32(abs(col + 11)) &* 73856093
                    seed ^= UInt32(abs(row + 17)) &* 19349663
                    // Safely convert hashValue to UInt32 by truncating
                    let hashValue32 = UInt32(truncatingIfNeeded: abs(gameFingerprint.hashValue + 23))
                    seed ^= hashValue32 &* 83492791
                    seed = seed == 0 ? 0x9e3779b9 : seed

                    // Generate Gaussian jitter (same algorithm as StoneJitter)
                    let (gx, gy) = gaussianPair(&seed)

                    // Apply sigma and clamp (8% standard deviation, 22% max)
                    let sigma: CGFloat = 0.08
                    let clamp: CGFloat = 0.22
                    let ox = min(max(gx * sigma, -clamp), clamp)
                    let oy = min(max(gy * sigma, -clamp), clamp)

                    offsets[position] = CGPoint(x: ox, y: oy)
                }
            }
        }

        return offsets
    }

    // Box-Muller Gaussian generation (same as StoneJitter)
    private func gaussianPair(_ seed: inout UInt32) -> (CGFloat, CGFloat) {
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

    private func recalculateJitterOffsetsOnly() {
        // Jitter is now calculated on-demand, no need to recalculate cached values
        // This function is kept for API compatibility but does nothing
    }
}

// MARK: - Enhanced Game Manager

/// Manages multiple enhanced games with background pre-calculation
final class GameCacheManager: ObservableObject {
    @Published var currentGame: EnhancedSGFGame?

    private var gameCache: [String: EnhancedSGFGame] = [:]
    private let preCalculationQueue = DispatchQueue(label: "game.precalculation", qos: .background)

    /// Load a game and start background pre-calculation
    func loadGame(_ game: SGFGame, fingerprint: String) {
        let enhancedGame: EnhancedSGFGame

        if let cached = gameCache[fingerprint] {
            enhancedGame = cached
        } else {
            enhancedGame = EnhancedSGFGame(game: game, fingerprint: fingerprint)
            gameCache[fingerprint] = enhancedGame

            // Start background pre-calculation
            Task {
                await enhancedGame.preCalculateAllStates()
            }
        }

        currentGame = enhancedGame
    }

    /// Pre-calculate a game in the background (for upcoming games)
    func preCalculateGame(_ game: SGFGame, fingerprint: String) {
        guard gameCache[fingerprint] == nil else { return }

        let enhancedGame = EnhancedSGFGame(game: game, fingerprint: fingerprint)
        gameCache[fingerprint] = enhancedGame

        Task {
            await enhancedGame.preCalculateAllStates()
        }
    }

    /// Clear cache to manage memory usage
    func clearCache() {
        gameCache.removeAll()
    }

    /// Get cache statistics
    func getCacheInfo() -> (games: Int, totalStates: Int) {
        let games = gameCache.count
        let totalStates = gameCache.values.reduce(0) { $0 + $1.gameStates.count }
        return (games, totalStates)
    }
}