// MARK: - Screensaver Extensions
// Essential extensions and compatibility shims for screensaver environment

import Foundation
import Cocoa

// MARK: - ObservableObject Compatibility

// Simple ObservableObject protocol for screensaver (no Combine dependency)
protocol ObservableObject: AnyObject {
    // Marker protocol - in screensaver we don't need reactive updates
}

// MARK: - Stone and Game Types

enum Stone: Equatable, Hashable {
    case black
    case white
}

struct BoardSnapshot {
    let size: Int
    let grid: [[Stone?]]
}

// MARK: - Physics Support Types

struct StonePosition {
    let id = UUID()
    let position: CGPoint
    let isWhite: Bool
}

struct BowlPhysicsResult {
    let stones: [StonePosition]
    let convergenceInfo: String
}

// MARK: - Move Reference

struct MoveRef {
    let stone: Stone
    let coordinate: (Int, Int)?
    let moveNumber: Int
}

// MARK: - Game Wrapper

struct SGFGameWrapper: Identifiable {
    let id = UUID()
    let url: URL
    let game: SGFGame

    var fingerprint: String {
        return url.lastPathComponent + "_" + String(url.path.hashValue)
    }
}

// MARK: - Extensions for Core Graphics

extension NSColor {
    static var systemBackground: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.controlBackgroundColor
        } else {
            return NSColor.windowBackgroundColor
        }
    }
}

// MARK: - SGF Parser Support

enum SGFParseError: Error {
    case invalidFormat
    case unsupportedVersion
    case missingGameTree
}

class SGFParser {
    static func parse(text: String) throws -> SGFGameTree {
        // Simplified SGF parser for demo games
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanText.hasPrefix("(;") && cleanText.hasSuffix(")") else {
            throw SGFParseError.invalidFormat
        }

        // Extract moves - very basic parsing for demo
        let moves = extractMoves(from: cleanText)
        return SGFGameTree(moves: moves)
    }

    private static func extractMoves(from sgf: String) -> [(Stone, (Int, Int)?)] {
        var moves: [(Stone, (Int, Int)?)] = []
        let pattern = try! NSRegularExpression(pattern: "[BW]\\[[a-s]{0,2}\\]", options: [])
        let range = NSRange(sgf.startIndex..., in: sgf)

        pattern.enumerateMatches(in: sgf, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range,
                  let swiftRange = Range(matchRange, in: sgf) else { return }

            let moveString = String(sgf[swiftRange])
            let isBlack = moveString.starts(with: "B")
            let stone: Stone = isBlack ? .black : .white

            // Extract coordinates if present
            if let coordStart = moveString.firstIndex(of: "["),
               let coordEnd = moveString.firstIndex(of: "]") {
                let coordString = String(moveString[sgf.index(after: coordStart)..<coordEnd])

                if coordString.count == 2 {
                    let chars = Array(coordString)
                    let x = Int(chars[0].asciiValue! - 97) // 'a' = 0
                    let y = Int(chars[1].asciiValue! - 97)
                    moves.append((stone, (x, y)))
                } else {
                    moves.append((stone, nil)) // Pass move
                }
            }
        }

        return moves
    }
}

struct SGFGameTree {
    let moves: [(Stone, (Int, Int)?)]
}

// MARK: - Simplified SGF Game

struct SGFGame {
    let boardSize: Int
    let moves: [(Stone, (Int, Int)?)]
    let setup: [(Stone, Int, Int)]

    static func from(tree: SGFGameTree) -> SGFGame {
        return SGFGame(
            boardSize: 19, // Default to 19x19
            moves: tree.moves,
            setup: [] // No setup stones in demo
        )
    }
}

// MARK: - Simplified SGF Player

class SGFPlayer: ObservableObject {
    private var game: SGFGame?
    private var moveIndex: Int = 0

    var board: BoardSnapshot {
        return calculateCurrentBoard()
    }

    var currentMoveIndex: Int {
        return moveIndex
    }

    var lastMove: MoveRef? {
        guard let game = game, moveIndex > 0, moveIndex <= game.moves.count else {
            return nil
        }

        let (stone, coord) = game.moves[moveIndex - 1]
        return MoveRef(stone: stone, coordinate: coord, moveNumber: moveIndex)
    }

    func load(game: SGFGame) {
        self.game = game
        self.moveIndex = 0
    }

    func stepForward() {
        guard let game = game, moveIndex < game.moves.count else { return }
        moveIndex += 1
    }

    func stepBackward() {
        guard moveIndex > 0 else { return }
        moveIndex -= 1
    }

    func seekToBeginning() {
        moveIndex = 0
    }

    func seek(to index: Int) {
        guard let game = game else { return }
        moveIndex = max(0, min(index, game.moves.count))
    }

    private func calculateCurrentBoard() -> BoardSnapshot {
        guard let game = game else {
            return BoardSnapshot(size: 19, grid: Array(repeating: Array(repeating: nil, count: 19), count: 19))
        }

        var grid: [[Stone?]] = Array(repeating: Array(repeating: nil, count: game.boardSize), count: game.boardSize)

        // Apply setup stones
        for (stone, x, y) in game.setup {
            if x >= 0 && x < game.boardSize && y >= 0 && y < game.boardSize {
                grid[y][x] = stone
            }
        }

        // Apply moves up to current index
        for i in 0..<moveIndex {
            let (stone, coord) = game.moves[i]
            if let (x, y) = coord,
               x >= 0 && x < game.boardSize && y >= 0 && y < game.boardSize {
                grid[y][x] = stone
            }
        }

        return BoardSnapshot(size: game.boardSize, grid: grid)
    }
}