// MARK: - Core Board Model
// Extracted from SGFPlayerEngine.swift and BoardViewport.swift for reusability

import Foundation

/// Immutable board state representing current position
public struct Board: Equatable, Codable {
    public let size: Int
    public private(set) var grid: [[Stone?]]

    public init(size: Int) {
        self.size = size
        self.grid = Array(repeating: Array(repeating: nil, count: size), count: size)
    }

    public init(size: Int, grid: [[Stone?]]) {
        self.size = size
        self.grid = grid
    }

    /// Get stone at position (nil if empty)
    public func stone(at position: Position) -> Stone? {
        guard position.isValid(boardSize: size) else { return nil }
        return grid[position.y][position.x]
    }

    /// Get stone at coordinates (nil if empty or invalid)
    public func stone(x: Int, y: Int) -> Stone? {
        guard x >= 0, x < size, y >= 0, y < size else { return nil }
        return grid[y][x]
    }

    /// Check if position is empty
    public func isEmpty(at position: Position) -> Bool {
        return stone(at: position) == nil
    }

    /// Place stone at position (returns new board)
    public func placing(_ stone: Stone, at position: Position) -> Board {
        guard position.isValid(boardSize: size) else { return self }
        var newGrid = grid
        newGrid[position.y][position.x] = stone
        return Board(size: size, grid: newGrid)
    }

    /// Remove stone at position (returns new board)
    public func removing(at position: Position) -> Board {
        guard position.isValid(boardSize: size) else { return self }
        var newGrid = grid
        newGrid[position.y][position.x] = nil
        return Board(size: size, grid: newGrid)
    }

    /// Remove multiple stones (returns new board)
    public func removing(at positions: [Position]) -> Board {
        var newGrid = grid
        for position in positions {
            if position.isValid(boardSize: size) {
                newGrid[position.y][position.x] = nil
            }
        }
        return Board(size: size, grid: newGrid)
    }

    /// Get all positions with stones of specified color
    public func positions(of stone: Stone) -> [Position] {
        var positions: [Position] = []
        for y in 0..<size {
            for x in 0..<size {
                if grid[y][x] == stone {
                    positions.append(Position(x: x, y: y))
                }
            }
        }
        return positions
    }

    /// Get all non-empty positions
    public func occupiedPositions() -> [PlacedStone] {
        var stones: [PlacedStone] = []
        for y in 0..<size {
            for x in 0..<size {
                if let stone = grid[y][x] {
                    stones.append(PlacedStone(stone: stone, position: Position(x: x, y: y)))
                }
            }
        }
        return stones
    }

    /// Apply a move to the board (returns new board with move applied)
    public func applying(_ move: Move) -> Board {
        switch move.action {
        case .pass:
            return self
        case .place(let position):
            return placing(move.player, at: position)
        }
    }
}

// MARK: - Board Rules and Logic

extension Board {
    /// Find all stones in the same group as the stone at given position
    public func group(at position: Position) -> [Position] {
        guard let stoneColor = stone(at: position) else { return [] }

        var visited = Set<Position>()
        var stack = [position]
        var group: [Position] = []

        while let current = stack.popLast() {
            if visited.contains(current) { continue }
            visited.insert(current)

            guard stone(at: current) == stoneColor else { continue }
            group.append(current)

            // Add unvisited neighbors of same color
            for neighbor in current.neighbors(boardSize: size) {
                if !visited.contains(neighbor) && stone(at: neighbor) == stoneColor {
                    stack.append(neighbor)
                }
            }
        }

        return group
    }

    /// Find all empty positions adjacent to a group (liberties)
    public func liberties(of group: [Position]) -> [Position] {
        var liberties = Set<Position>()

        for position in group {
            for neighbor in position.neighbors(boardSize: size) {
                if isEmpty(at: neighbor) {
                    liberties.insert(neighbor)
                }
            }
        }

        return Array(liberties)
    }

    /// Find liberties of the group containing the stone at given position
    public func liberties(at position: Position) -> [Position] {
        let group = group(at: position)
        return liberties(of: group)
    }

    /// Check if a group has any liberties (is alive)
    public func hasLiberties(at position: Position) -> Bool {
        return !liberties(at: position).isEmpty
    }

    /// Find all opponent groups that would be captured by placing a stone
    public func capturedGroups(if stone: Stone, placedAt position: Position) -> [[Position]] {
        let opponent = stone.opposite
        var capturedGroups: [[Position]] = []

        for neighbor in position.neighbors(boardSize: size) {
            if self.stone(at: neighbor) == opponent {
                let group = self.group(at: neighbor)
                // Check if group would have no liberties after our stone is placed
                let liberties = self.liberties(of: group).filter { $0 != position }
                if liberties.isEmpty {
                    capturedGroups.append(group)
                }
            }
        }

        return capturedGroups
    }

    /// Apply a move with proper Go rules (capture, suicide)
    public func applyingMoveWithRules(_ move: Move) -> Board {
        switch move.action {
        case .pass:
            return self
        case .place(let position):
            return applyingStoneWithRules(move.player, at: position)
        }
    }

    /// Apply stone placement with full Go rules
    private func applyingStoneWithRules(_ stone: Stone, at position: Position) -> Board {
        // Place the stone
        var board = placing(stone, at: position)

        // Capture opponent groups without liberties
        let capturedGroups = capturedGroups(if: stone, placedAt: position)
        for group in capturedGroups {
            board = board.removing(at: group)
        }

        // Handle suicide rule: if own group has no liberties and didn't capture anything
        let ownGroup = board.group(at: position)
        if board.liberties(of: ownGroup).isEmpty && capturedGroups.isEmpty {
            // Remove own group (some rulesets allow suicide)
            board = board.removing(at: ownGroup)
        }

        return board
    }
}

// MARK: - Compatibility with existing codebase

extension Board {
    /// Create from legacy BoardSnapshot
    public init(snapshot: BoardSnapshot) {
        self.size = snapshot.size
        self.grid = snapshot.grid
    }

    /// Convert to legacy BoardSnapshot
    public var snapshot: BoardSnapshot {
        return BoardSnapshot(size: size, grid: grid)
    }
}

/// Legacy BoardSnapshot for compatibility (from BoardViewport.swift)
public struct BoardSnapshot: Equatable {
    public let size: Int
    public let grid: [[Stone?]] // [y][x]

    public init(size: Int, grid: [[Stone?]]) {
        self.size = size
        self.grid = grid
    }
}