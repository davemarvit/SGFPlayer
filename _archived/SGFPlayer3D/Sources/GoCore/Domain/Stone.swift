// MARK: - Core Stone Model
// Extracted from BoardViewport.swift for reusability across all Go applications

import Foundation

/// Represents a Go stone color
public enum Stone: Equatable, CaseIterable, Codable {
    case black
    case white

    /// Returns the opposite stone color
    public var opposite: Stone {
        switch self {
        case .black: return .white
        case .white: return .black
        }
    }

    /// String representation for debugging and display
    public var description: String {
        switch self {
        case .black: return "Black"
        case .white: return "White"
        }
    }

    /// Single character representation (used in SGF notation)
    public var sgfCode: String {
        switch self {
        case .black: return "B"
        case .white: return "W"
        }
    }
}

/// Represents a position on the Go board
public struct Position: Equatable, Hashable, Codable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Creates position from SGF coordinate notation (e.g., "pd" -> Position(15, 3))
    public init?(sgfCoordinate: String) {
        guard sgfCoordinate.count == 2 else { return nil }
        let chars = Array(sgfCoordinate)

        // SGF uses 'a'-'s' for coordinates (0-18 for 19x19 board)
        guard let xChar = chars.first?.asciiValue,
              let yChar = chars.last?.asciiValue,
              xChar >= 97, xChar <= 115, // 'a' to 's'
              yChar >= 97, yChar <= 115 else {
            return nil
        }

        self.x = Int(xChar - 97)
        self.y = Int(yChar - 97)
    }

    /// Converts position to SGF coordinate notation
    public var sgfCoordinate: String {
        let xChar = Character(UnicodeScalar(x + 97)!)
        let yChar = Character(UnicodeScalar(y + 97)!)
        return String([xChar, yChar])
    }

    /// Returns neighboring positions (up to 4 orthogonal neighbors)
    public func neighbors(boardSize: Int) -> [Position] {
        var neighbors: [Position] = []

        if x > 0 { neighbors.append(Position(x: x - 1, y: y)) }
        if x < boardSize - 1 { neighbors.append(Position(x: x + 1, y: y)) }
        if y > 0 { neighbors.append(Position(x: x, y: y - 1)) }
        if y < boardSize - 1 { neighbors.append(Position(x: x, y: y + 1)) }

        return neighbors
    }

    /// Checks if position is valid for given board size
    public func isValid(boardSize: Int) -> Bool {
        return x >= 0 && x < boardSize && y >= 0 && y < boardSize
    }
}

/// Represents a placed stone on the board
public struct PlacedStone: Equatable, Codable {
    public let stone: Stone
    public let position: Position

    public init(stone: Stone, position: Position) {
        self.stone = stone
        self.position = position
    }

    public init(stone: Stone, x: Int, y: Int) {
        self.stone = stone
        self.position = Position(x: x, y: y)
    }
}