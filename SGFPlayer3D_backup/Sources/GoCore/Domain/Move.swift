// MARK: - Core Move Model
// Extracted from SGFPlayerEngine.swift for reusability across all Go applications

import Foundation

/// Represents a single move in a Go game
public struct Move: Equatable, Codable {
    public let player: Stone
    public let action: MoveAction

    public init(player: Stone, action: MoveAction) {
        self.player = player
        self.action = action
    }

    /// Convenience initializer for stone placement
    public init(player: Stone, at position: Position) {
        self.player = player
        self.action = .place(position)
    }

    /// Convenience initializer for pass move
    public init(player: Stone, pass: Bool) {
        self.player = player
        self.action = .pass
    }
}

/// Represents the action taken in a move
public enum MoveAction: Equatable, Codable {
    case place(Position)
    case pass

    /// Returns the position if this is a placement move
    public var position: Position? {
        switch self {
        case .place(let pos):
            return pos
        case .pass:
            return nil
        }
    }

    /// Returns true if this is a pass move
    public var isPass: Bool {
        switch self {
        case .pass:
            return true
        case .place:
            return false
        }
    }
}

/// Reference to a move for UI coordination (preserves existing interface)
public struct MoveReference: Equatable {
    public let player: Stone
    public let position: Position

    public init(player: Stone, position: Position) {
        self.player = player
        self.position = position
    }

    public init(player: Stone, x: Int, y: Int) {
        self.player = player
        self.position = Position(x: x, y: y)
    }

    /// Compatibility with existing MoveRef structure
    public var color: Stone { player }
    public var x: Int { position.x }
    public var y: Int { position.y }
}

/// Represents a sequence of moves in a game
public struct MoveSequence: Equatable, Codable {
    public private(set) var moves: [Move]

    public init(moves: [Move] = []) {
        self.moves = moves
    }

    /// Add a move to the sequence
    public mutating func append(_ move: Move) {
        moves.append(move)
    }

    /// Add a stone placement move
    public mutating func place(_ stone: Stone, at position: Position) {
        moves.append(Move(player: stone, at: position))
    }

    /// Add a pass move
    public mutating func pass(_ stone: Stone) {
        moves.append(Move(player: stone, pass: true))
    }

    /// Get move at specific index
    public subscript(index: Int) -> Move? {
        guard index >= 0 && index < moves.count else { return nil }
        return moves[index]
    }

    /// Number of moves in sequence
    public var count: Int { moves.count }

    /// Check if sequence is empty
    public var isEmpty: Bool { moves.isEmpty }

    /// Get all moves as array
    public var allMoves: [Move] { moves }
}

/// Compatibility extensions for existing codebase
extension Move {
    /// Convert to legacy tuple format (Stone, (Int,Int)?)
    public var legacyFormat: (Stone, (Int,Int)?) {
        switch action {
        case .place(let pos):
            return (player, (pos.x, pos.y))
        case .pass:
            return (player, nil)
        }
    }

    /// Create from legacy tuple format
    public init(legacyFormat: (Stone, (Int,Int)?)) {
        self.player = legacyFormat.0
        if let coords = legacyFormat.1 {
            self.action = .place(Position(x: coords.0, y: coords.1))
        } else {
            self.action = .pass
        }
    }
}