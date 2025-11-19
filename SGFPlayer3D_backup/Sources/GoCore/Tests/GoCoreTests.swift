// MARK: - Core Domain Tests
// Comprehensive unit tests for extracted domain models

import XCTest
@testable import GoCore

final class StoneTests: XCTestCase {
    func testStoneOpposite() {
        XCTAssertEqual(Stone.black.opposite, Stone.white)
        XCTAssertEqual(Stone.white.opposite, Stone.black)
    }

    func testStoneSGFCode() {
        XCTAssertEqual(Stone.black.sgfCode, "B")
        XCTAssertEqual(Stone.white.sgfCode, "W")
    }

    func testStoneDescription() {
        XCTAssertEqual(Stone.black.description, "Black")
        XCTAssertEqual(Stone.white.description, "White")
    }
}

final class PositionTests: XCTestCase {
    func testPositionCreation() {
        let pos = Position(x: 3, y: 15)
        XCTAssertEqual(pos.x, 3)
        XCTAssertEqual(pos.y, 15)
    }

    func testSGFCoordinateConversion() {
        // Test known coordinate "pd" (15, 3)
        let pos = Position(sgfCoordinate: "pd")
        XCTAssertNotNil(pos)
        XCTAssertEqual(pos?.x, 15)
        XCTAssertEqual(pos?.y, 3)

        // Test reverse conversion
        let coordinate = pos?.sgfCoordinate
        XCTAssertEqual(coordinate, "pd")
    }

    func testSGFCoordinateInvalid() {
        XCTAssertNil(Position(sgfCoordinate: ""))
        XCTAssertNil(Position(sgfCoordinate: "z"))
        XCTAssertNil(Position(sgfCoordinate: "zz"))
        XCTAssertNil(Position(sgfCoordinate: "t")) // Single character should fail
        XCTAssertNil(Position(sgfCoordinate: "abc")) // Too long should fail
    }

    func testPositionNeighbors() {
        let center = Position(x: 3, y: 3)
        let neighbors = center.neighbors(boardSize: 19)
        XCTAssertEqual(neighbors.count, 4)
        XCTAssertTrue(neighbors.contains(Position(x: 2, y: 3)))
        XCTAssertTrue(neighbors.contains(Position(x: 4, y: 3)))
        XCTAssertTrue(neighbors.contains(Position(x: 3, y: 2)))
        XCTAssertTrue(neighbors.contains(Position(x: 3, y: 4)))
    }

    func testPositionEdgeNeighbors() {
        let corner = Position(x: 0, y: 0)
        let neighbors = corner.neighbors(boardSize: 19)
        XCTAssertEqual(neighbors.count, 2)
        XCTAssertTrue(neighbors.contains(Position(x: 1, y: 0)))
        XCTAssertTrue(neighbors.contains(Position(x: 0, y: 1)))
    }

    func testPositionValidation() {
        XCTAssertTrue(Position(x: 0, y: 0).isValid(boardSize: 19))
        XCTAssertTrue(Position(x: 18, y: 18).isValid(boardSize: 19))
        XCTAssertFalse(Position(x: -1, y: 0).isValid(boardSize: 19))
        XCTAssertFalse(Position(x: 0, y: 19).isValid(boardSize: 19))
        XCTAssertFalse(Position(x: 19, y: 0).isValid(boardSize: 19))
    }
}

final class MoveTests: XCTestCase {
    func testMoveCreation() {
        let position = Position(x: 3, y: 3)
        let move = Move(player: .black, at: position)

        XCTAssertEqual(move.player, .black)
        XCTAssertEqual(move.action.position, position)
        XCTAssertFalse(move.action.isPass)
    }

    func testPassMove() {
        let move = Move(player: .white, pass: true)

        XCTAssertEqual(move.player, .white)
        XCTAssertNil(move.action.position)
        XCTAssertTrue(move.action.isPass)
    }

    func testLegacyFormatConversion() {
        let move = Move(player: .black, at: Position(x: 3, y: 15))
        let legacy = move.legacyFormat

        XCTAssertEqual(legacy.0, .black)
        XCTAssertEqual(legacy.1?.0, 3)
        XCTAssertEqual(legacy.1?.1, 15)

        let recreated = Move(legacyFormat: legacy)
        XCTAssertEqual(recreated, move)
    }

    func testPassLegacyFormat() {
        let move = Move(player: .white, pass: true)
        let legacy = move.legacyFormat

        XCTAssertEqual(legacy.0, .white)
        XCTAssertNil(legacy.1)

        let recreated = Move(legacyFormat: legacy)
        XCTAssertEqual(recreated, move)
    }
}

final class MoveSequenceTests: XCTestCase {
    func testEmptySequence() {
        let sequence = MoveSequence()
        XCTAssertTrue(sequence.isEmpty)
        XCTAssertEqual(sequence.count, 0)
    }

    func testAddingMoves() {
        var sequence = MoveSequence()
        sequence.place(.black, at: Position(x: 3, y: 3))
        sequence.place(.white, at: Position(x: 15, y: 3))
        sequence.pass(.black)

        XCTAssertEqual(sequence.count, 3)
        XCTAssertFalse(sequence.isEmpty)

        XCTAssertEqual(sequence[0]?.player, .black)
        XCTAssertEqual(sequence[1]?.player, .white)
        XCTAssertEqual(sequence[2]?.player, .black)
        XCTAssertTrue(sequence[2]?.action.isPass ?? false)
    }

    func testSubscriptAccess() {
        var sequence = MoveSequence()
        sequence.place(.black, at: Position(x: 3, y: 3))

        XCTAssertNotNil(sequence[0])
        XCTAssertNil(sequence[1])
        XCTAssertNil(sequence[-1])
    }
}

final class BoardTests: XCTestCase {
    func testEmptyBoard() {
        let board = Board(size: 19)
        XCTAssertEqual(board.size, 19)
        XCTAssertTrue(board.isEmpty(at: Position(x: 3, y: 3)))
        XCTAssertNil(board.stone(at: Position(x: 3, y: 3)))
    }

    func testPlacingStones() {
        let board = Board(size: 19)
        let position = Position(x: 3, y: 3)
        let newBoard = board.placing(.black, at: position)

        XCTAssertEqual(newBoard.stone(at: position), .black)
        XCTAssertFalse(newBoard.isEmpty(at: position))

        // Original board unchanged
        XCTAssertTrue(board.isEmpty(at: position))
    }

    func testRemovingStones() {
        let board = Board(size: 19)
        let position = Position(x: 3, y: 3)
        let withStone = board.placing(.black, at: position)
        let removed = withStone.removing(at: position)

        XCTAssertEqual(withStone.stone(at: position), .black)
        XCTAssertNil(removed.stone(at: position))
    }

    func testGroupDetection() {
        var board = Board(size: 19)
        // Create a group of black stones
        board = board.placing(.black, at: Position(x: 3, y: 3))
        board = board.placing(.black, at: Position(x: 3, y: 4))
        board = board.placing(.black, at: Position(x: 4, y: 3))

        let group = board.group(at: Position(x: 3, y: 3))
        XCTAssertEqual(group.count, 3)
        XCTAssertTrue(group.contains(Position(x: 3, y: 3)))
        XCTAssertTrue(group.contains(Position(x: 3, y: 4)))
        XCTAssertTrue(group.contains(Position(x: 4, y: 3)))
    }

    func testLibertyCalculation() {
        var board = Board(size: 19)
        board = board.placing(.black, at: Position(x: 3, y: 3))

        let liberties = board.liberties(at: Position(x: 3, y: 3))
        XCTAssertEqual(liberties.count, 4) // Single stone has 4 liberties

        // Reduce liberties
        board = board.placing(.white, at: Position(x: 2, y: 3))
        let reducedLiberties = board.liberties(at: Position(x: 3, y: 3))
        XCTAssertEqual(reducedLiberties.count, 3)
    }

    func testCaptureDetection() {
        var board = Board(size: 19)

        // Set up a capture situation
        board = board.placing(.black, at: Position(x: 1, y: 1))
        board = board.placing(.white, at: Position(x: 0, y: 1))
        board = board.placing(.white, at: Position(x: 1, y: 0))
        board = board.placing(.white, at: Position(x: 2, y: 1))

        // White stone at (1,2) would capture black stone
        let capturedGroups = board.capturedGroups(if: .white, placedAt: Position(x: 1, y: 2))
        XCTAssertEqual(capturedGroups.count, 1)
        XCTAssertEqual(capturedGroups[0].count, 1)
        XCTAssertTrue(capturedGroups[0].contains(Position(x: 1, y: 1)))
    }

    func testApplyMoveWithRules() {
        var board = Board(size: 19)

        // Place stones to set up capture
        board = board.placing(.black, at: Position(x: 1, y: 1))
        board = board.placing(.white, at: Position(x: 0, y: 1))
        board = board.placing(.white, at: Position(x: 1, y: 0))
        board = board.placing(.white, at: Position(x: 2, y: 1))

        // Apply capturing move
        let move = Move(player: .white, at: Position(x: 1, y: 2))
        let resultBoard = board.applyingMoveWithRules(move)

        XCTAssertEqual(resultBoard.stone(at: Position(x: 1, y: 2)), .white)
        XCTAssertNil(resultBoard.stone(at: Position(x: 1, y: 1))) // Captured
    }
}

final class GameTests: XCTestCase {
    func testEmptyGame() {
        let game = Game()
        XCTAssertEqual(game.boardSize, 19)
        XCTAssertTrue(game.setup.isEmpty)
        XCTAssertEqual(game.moveCount, 0)
        XCTAssertFalse(game.hasMoves)
    }

    func testGameWithMoves() {
        var moves = MoveSequence()
        moves.place(.black, at: Position(x: 3, y: 3))
        moves.place(.white, at: Position(x: 15, y: 3))

        let game = Game(boardSize: 19, moves: moves)
        XCTAssertEqual(game.moveCount, 2)
        XCTAssertTrue(game.hasMoves)

        let move1 = game.move(at: 0)
        XCTAssertEqual(move1?.player, .black)
        XCTAssertEqual(move1?.action.position, Position(x: 3, y: 3))
    }

    func testBoardStateProgression() {
        var moves = MoveSequence()
        moves.place(.black, at: Position(x: 3, y: 3))
        moves.place(.white, at: Position(x: 15, y: 3))

        let game = Game(boardSize: 19, moves: moves)

        let initialBoard = game.boardState(after: -1)
        XCTAssertTrue(initialBoard.isEmpty(at: Position(x: 3, y: 3)))

        let afterMove1 = game.boardState(after: 0)
        XCTAssertEqual(afterMove1.stone(at: Position(x: 3, y: 3)), .black)
        XCTAssertTrue(afterMove1.isEmpty(at: Position(x: 15, y: 3)))

        let afterMove2 = game.boardState(after: 1)
        XCTAssertEqual(afterMove2.stone(at: Position(x: 3, y: 3)), .black)
        XCTAssertEqual(afterMove2.stone(at: Position(x: 15, y: 3)), .white)
    }
}

final class GameStateTests: XCTestCase {
    func testGameStateNavigation() {
        var moves = MoveSequence()
        moves.place(.black, at: Position(x: 3, y: 3))
        moves.place(.white, at: Position(x: 15, y: 3))

        let game = Game(boardSize: 19, moves: moves)
        let initialState = GameState(game: game, moveIndex: 0)

        XCTAssertTrue(initialState.isAtBeginning)
        XCTAssertFalse(initialState.isAtEnd)
        XCTAssertEqual(initialState.progress, 0.0, accuracy: 0.001)

        let nextState = initialState.next()
        XCTAssertFalse(nextState.isAtBeginning)
        XCTAssertFalse(nextState.isAtEnd)
        XCTAssertEqual(nextState.progress, 0.5, accuracy: 0.001)

        let endState = nextState.next()
        XCTAssertFalse(endState.isAtBeginning)
        XCTAssertTrue(endState.isAtEnd)
        XCTAssertEqual(endState.progress, 1.0, accuracy: 0.001)
    }

    func testGameStateLastMove() {
        var moves = MoveSequence()
        moves.place(.black, at: Position(x: 3, y: 3))

        let game = Game(boardSize: 19, moves: moves)
        let initialState = GameState(game: game, moveIndex: 0)
        XCTAssertNil(initialState.lastMove)

        let afterMove = GameState(game: game, moveIndex: 1)
        XCTAssertNotNil(afterMove.lastMove)
        XCTAssertEqual(afterMove.lastMove?.player, .black)
        XCTAssertEqual(afterMove.lastMove?.position, Position(x: 3, y: 3))
    }
}

// MARK: - Performance Tests

final class GoCorePerformanceTests: XCTestCase {
    func testLargeGamePerformance() throws {
        // Create a game with many moves
        var moves = MoveSequence()
        for i in 0..<200 {
            let x = i % 19
            let y = (i / 19) % 19
            let player: Stone = i % 2 == 0 ? .black : .white
            moves.place(player, at: Position(x: x, y: y))
        }

        let game = Game(boardSize: 19, moves: moves)

        self.measure {
            // Test performance of board state calculation
            let _ = game.finalBoard
        }
    }

    func testGroupDetectionPerformance() throws {
        // Create board with many connected stones
        var board = Board(size: 19)
        for x in 0..<10 {
            for y in 0..<10 {
                board = board.placing(.black, at: Position(x: x, y: y))
            }
        }

        self.measure {
            // Test performance of group detection on large group
            let _ = board.group(at: Position(x: 5, y: 5))
        }
    }
}