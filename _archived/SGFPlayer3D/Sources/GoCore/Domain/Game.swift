// MARK: - Core Game Model
// Extracted from SGFPlayerEngine.swift and SGFKit.swift for reusability

import Foundation

/// Complete representation of a Go game
public struct Game: Equatable, Codable {
    public let info: GameInfo
    public let boardSize: Int
    public let setup: [PlacedStone]
    public let moves: MoveSequence

    public init(
        info: GameInfo = GameInfo(),
        boardSize: Int = 19,
        setup: [PlacedStone] = [],
        moves: MoveSequence = MoveSequence()
    ) {
        self.info = info
        self.boardSize = boardSize
        self.setup = setup
        self.moves = moves
    }

    /// Get the initial board state with setup stones
    public var initialBoard: Board {
        var board = Board(size: boardSize)
        for placedStone in setup {
            board = board.placing(placedStone.stone, at: placedStone.position)
        }
        return board
    }

    /// Get board state after applying moves up to given index
    public func boardState(after moveIndex: Int) -> Board {
        var board = initialBoard

        let maxIndex = min(moveIndex, moves.count - 1)
        guard maxIndex >= 0 else { return board }

        for i in 0...maxIndex {
            if let move = moves[i] {
                board = board.applyingMoveWithRules(move)
            }
        }

        return board
    }

    /// Get the final board state (after all moves)
    public var finalBoard: Board {
        return boardState(after: moves.count - 1)
    }

    /// Get move at specific index
    public func move(at index: Int) -> Move? {
        return moves[index]
    }

    /// Total number of moves
    public var moveCount: Int {
        return moves.count
    }

    /// Check if game has any moves
    public var hasMoves: Bool {
        return !moves.isEmpty
    }
}

/// Game metadata and information
public struct GameInfo: Equatable, Codable {
    public var event: String?
    public var playerBlack: String?
    public var playerWhite: String?
    public var result: String?
    public var date: String?
    public var rules: String?
    public var komi: Double?
    public var handicap: Int?
    public var timeSettings: String?

    public init(
        event: String? = nil,
        playerBlack: String? = nil,
        playerWhite: String? = nil,
        result: String? = nil,
        date: String? = nil,
        rules: String? = nil,
        komi: Double? = nil,
        handicap: Int? = nil,
        timeSettings: String? = nil
    ) {
        self.event = event
        self.playerBlack = playerBlack
        self.playerWhite = playerWhite
        self.result = result
        self.date = date
        self.rules = rules
        self.komi = komi
        self.handicap = handicap
        self.timeSettings = timeSettings
    }
}

/// Game state at a specific point in time
public struct GameState: Equatable {
    public let game: Game
    public let currentMoveIndex: Int
    public let board: Board
    public let lastMove: MoveReference?

    public init(game: Game, moveIndex: Int = 0) {
        self.game = game
        self.currentMoveIndex = max(0, min(moveIndex, game.moveCount))
        self.board = game.boardState(after: currentMoveIndex - 1)

        // Set last move reference if there is one
        if currentMoveIndex > 0,
           let move = game.move(at: currentMoveIndex - 1),
           case .place(let position) = move.action {
            self.lastMove = MoveReference(player: move.player, position: position)
        } else {
            self.lastMove = nil
        }
    }

    /// Move to next position in game
    public func next() -> GameState {
        let newIndex = min(currentMoveIndex + 1, game.moveCount)
        return GameState(game: game, moveIndex: newIndex)
    }

    /// Move to previous position in game
    public func previous() -> GameState {
        let newIndex = max(currentMoveIndex - 1, 0)
        return GameState(game: game, moveIndex: newIndex)
    }

    /// Jump to specific move index
    public func jumpTo(_ index: Int) -> GameState {
        return GameState(game: game, moveIndex: index)
    }

    /// Check if at beginning of game
    public var isAtBeginning: Bool {
        return currentMoveIndex == 0
    }

    /// Check if at end of game
    public var isAtEnd: Bool {
        return currentMoveIndex >= game.moveCount
    }

    /// Progress through game (0.0 to 1.0)
    public var progress: Double {
        guard game.moveCount > 0 else { return 0.0 }
        return Double(currentMoveIndex) / Double(game.moveCount)
    }
}

// MARK: - Compatibility with existing codebase

extension Game {
    /// Create from legacy SGFGame structure
    public init(legacyGame: SGFGame) {
        let gameInfo = GameInfo(
            event: legacyGame.info.event,
            playerBlack: legacyGame.info.playerBlack,
            playerWhite: legacyGame.info.playerWhite,
            result: legacyGame.info.result,
            date: legacyGame.info.date
        )

        let setupStones = legacyGame.setup.map { (stone, x, y) in
            PlacedStone(stone: stone, x: x, y: y)
        }

        var moveSequence = MoveSequence()
        for (stone, coords) in legacyGame.moves {
            let move = Move(legacyFormat: (stone, coords))
            moveSequence.append(move)
        }

        self.init(
            info: gameInfo,
            boardSize: legacyGame.boardSize,
            setup: setupStones,
            moves: moveSequence
        )
    }

    /// Convert to legacy SGFGame structure
    public var legacyGame: SGFGame {
        var sgfGame = SGFGame()
        sgfGame.boardSize = boardSize

        sgfGame.info = SGFGame.Info(
            event: info.event,
            playerBlack: info.playerBlack,
            playerWhite: info.playerWhite,
            result: info.result,
            date: info.date
        )

        sgfGame.setup = setup.map { ($0.stone, $0.position.x, $0.position.y) }
        sgfGame.moves = moves.allMoves.map { $0.legacyFormat }

        return sgfGame
    }
}

/// Legacy SGFGame structure for compatibility
public struct SGFGame {
    public struct Info {
        public var event: String?
        public var playerBlack: String?
        public var playerWhite: String?
        public var result: String?
        public var date: String?

        public init(event: String? = nil, playerBlack: String? = nil, playerWhite: String? = nil, result: String? = nil, date: String? = nil) {
            self.event = event
            self.playerBlack = playerBlack
            self.playerWhite = playerWhite
            self.result = result
            self.date = date
        }
    }

    public var boardSize: Int = 19
    public var info: Info = Info()
    public var setup: [(Stone, Int, Int)] = []
    public var moves: [(Stone, (Int,Int)?)] = []

    public init() {}
}