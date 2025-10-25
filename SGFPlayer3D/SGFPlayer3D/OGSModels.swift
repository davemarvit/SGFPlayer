import Foundation

/// Represents an available game/challenge on OGS
struct OGSChallenge: Codable, Identifiable {
    let id: Int
    let name: String?
    let ranked: Bool
    let width: Int
    let height: Int
    let handicap: Int
    let komi: Double?
    let timeControl: String?
    let challenger: ChallengerInfo?
    let gameId: Int?

    var boardSize: String {
        "\(width)×\(height)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ranked
        case width
        case height
        case handicap
        case komi
        case timeControl = "time_control"
        case challenger
        case gameId = "game_id"
    }
}

/// Information about the player who created the challenge
struct ChallengerInfo: Codable {
    let id: Int
    let username: String
    let ranking: Int?

    var displayRank: String {
        guard let rank = ranking else { return "?" }
        if rank < 0 {
            return "\(abs(rank))k"
        } else {
            return "\(rank + 1)d"
        }
    }
}

/// Response from the challenges list endpoint
struct OGSChallengesResponse: Codable {
    let results: [OGSChallenge]
    let count: Int?
}
