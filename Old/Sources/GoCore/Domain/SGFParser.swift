// MARK: - SGF Parser
// Extracted from SGFKit.swift for reusability across all Go applications

import Foundation

/// Errors that can occur during SGF parsing
public enum SGFParsingError: Error, LocalizedError {
    case parseError(String)
    case invalidFormat(String)
    case unsupportedFeature(String)

    public var errorDescription: String? {
        switch self {
        case .parseError(let message):
            return "SGF Parse Error: \(message)"
        case .invalidFormat(let message):
            return "Invalid SGF Format: \(message)"
        case .unsupportedFeature(let message):
            return "Unsupported SGF Feature: \(message)"
        }
    }
}

/// Lightweight SGF AST - represents the parsed structure
public struct SGFTree {
    public let nodes: [SGFNode]

    public init(nodes: [SGFNode]) {
        self.nodes = nodes
    }
}

/// Individual node in SGF tree
public struct SGFNode {
    public var properties: [String: [String]]

    public init(properties: [String: [String]] = [:]) {
        self.properties = properties
    }

    /// Get first value for a property
    public func getValue(_ key: String) -> String? {
        return properties[key]?.first
    }

    /// Get all values for a property
    public func getValues(_ key: String) -> [String] {
        return properties[key] ?? []
    }

    /// Check if property exists
    public func hasProperty(_ key: String) -> Bool {
        return properties[key] != nil
    }
}

/// Main SGF parser
public enum SGFParser {
    /// Parse SGF text into a game tree
    public static func parseTree(_ text: String) throws -> SGFTree {
        let normalizedText = text.replacingOccurrences(of: "\r", with: "")
        var index = normalizedText.startIndex

        func peek() -> Character? {
            return index < normalizedText.endIndex ? normalizedText[index] : nil
        }

        func advance() {
            if index < normalizedText.endIndex {
                index = normalizedText.index(after: index)
            }
        }

        func skipWhitespace() {
            while let char = peek(), char.isWhitespace {
                advance()
            }
        }

        var nodes: [SGFNode] = []

        func parseSubtree() throws {
            guard peek() == "(" else {
                throw SGFParsingError.parseError("Expected '(' at start of subtree")
            }
            advance() // Skip '('
            skipWhitespace()

            while let char = peek() {
                if char == ";" {
                    advance() // Skip ';'
                    nodes.append(try parseNode())
                    skipWhitespace()
                } else if char == "(" {
                    try skipSubtree() // Skip variations
                    skipWhitespace()
                } else if char == ")" {
                    advance() // Skip ')'
                    break
                } else {
                    advance() // Skip unexpected characters
                }
            }
        }

        func parseNode() throws -> SGFNode {
            var properties: [String: [String]] = [:]
            skipWhitespace()

            while let char = peek(), char.isLetter {
                let key = parseIdentifier()
                var values: [String] = []
                skipWhitespace()

                while peek() == "[" {
                    values.append(parseValue())
                    skipWhitespace()
                }

                if !values.isEmpty {
                    properties[key, default: []].append(contentsOf: values)
                }
                skipWhitespace()
            }

            return SGFNode(properties: properties)
        }

        func parseIdentifier() -> String {
            let start = index
            while let char = peek(), char.isLetter {
                advance()
            }
            return String(normalizedText[start..<index]).uppercased()
        }

        func parseValue() -> String {
            guard peek() == "[" else {
                return ""
            }
            advance() // Skip '['

            var result = ""
            while let char = peek() {
                advance()
                if char == "\\" {
                    if let nextChar = peek() {
                        result.append(nextChar)
                        advance()
                    }
                } else if char == "]" {
                    break
                } else {
                    result.append(char)
                }
            }
            return result
        }

        func skipSubtree() throws {
            guard peek() == "(" else {
                throw SGFParsingError.parseError("Expected '(' for subtree")
            }
            advance() // Skip '('

            var depth = 1
            while depth > 0 && peek() != nil {
                let char = peek()!
                advance()
                if char == "(" {
                    depth += 1
                } else if char == ")" {
                    depth -= 1
                }
            }
        }

        // Start parsing
        skipWhitespace()
        guard peek() == "(" else {
            throw SGFParsingError.parseError("SGF must start with '('")
        }

        try parseSubtree()
        return SGFTree(nodes: nodes)
    }

    /// Parse SGF text directly into a Game object
    public static func parseGame(_ text: String) throws -> Game {
        let tree = try parseTree(text)
        return try convertTreeToGame(tree)
    }

    /// Convert parsed SGF tree into Game object
    public static func convertTreeToGame(_ tree: SGFTree) throws -> Game {
        var gameInfo = GameInfo()
        var boardSize = 19
        var setup: [PlacedStone] = []
        var moves = MoveSequence()

        for node in tree.nodes {
            // Parse game info
            if let event = node.getValue("EV") {
                gameInfo.event = event
            }
            if let blackPlayer = node.getValue("PB") {
                gameInfo.playerBlack = blackPlayer
            }
            if let whitePlayer = node.getValue("PW") {
                gameInfo.playerWhite = whitePlayer
            }
            if let result = node.getValue("RE") {
                gameInfo.result = result
            }
            if let date = node.getValue("DT") {
                gameInfo.date = date
            }
            if let rules = node.getValue("RU") {
                gameInfo.rules = rules
            }
            if let komiStr = node.getValue("KM"), let komi = Double(komiStr) {
                gameInfo.komi = komi
            }
            if let handicapStr = node.getValue("HA"), let handicap = Int(handicapStr) {
                gameInfo.handicap = handicap
            }

            // Parse board size
            if let sizeStr = node.getValue("SZ") {
                if let colonIndex = sizeStr.firstIndex(of: ":") {
                    let leftStr = String(sizeStr[..<colonIndex])
                    let rightStr = String(sizeStr[sizeStr.index(after: colonIndex)...])
                    let left = Int(leftStr) ?? 19
                    let right = Int(rightStr) ?? left
                    boardSize = max(2, min(25, min(left, right)))
                } else if let size = Int(sizeStr) {
                    boardSize = max(2, min(25, size))
                }
            }

            // Parse setup stones
            for blackSetup in node.getValues("AB") {
                if let position = Position(sgfCoordinate: blackSetup) {
                    setup.append(PlacedStone(stone: .black, position: position))
                }
            }
            for whiteSetup in node.getValues("AW") {
                if let position = Position(sgfCoordinate: whiteSetup) {
                    setup.append(PlacedStone(stone: .white, position: position))
                }
            }

            // Parse moves
            if let blackMove = node.getValue("B") {
                if blackMove.isEmpty {
                    moves.pass(.black)
                } else if let position = Position(sgfCoordinate: blackMove) {
                    moves.place(.black, at: position)
                }
            }
            if let whiteMove = node.getValue("W") {
                if whiteMove.isEmpty {
                    moves.pass(.white)
                } else if let position = Position(sgfCoordinate: whiteMove) {
                    moves.place(.white, at: position)
                }
            }
        }

        return Game(
            info: gameInfo,
            boardSize: boardSize,
            setup: setup,
            moves: moves
        )
    }
}

// MARK: - Compatibility with existing codebase

extension SGFTree {
    /// Convert to legacy format
    public var legacyNodes: [SGFNode] {
        return nodes.map { node in
            var legacyNode = SGFNode()
            legacyNode.properties = node.properties
            return legacyNode
        }
    }
}

/// Legacy SGF parsing function for compatibility
public func parseSGF(_ text: String) throws -> SGFGame {
    let game = try SGFParser.parseGame(text)
    return game.legacyGame
}