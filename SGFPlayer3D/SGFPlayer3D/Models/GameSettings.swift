import Foundation
import SwiftUI

// MARK: - Game Settings for Live Play

/// Rank range preference for matchmaking
enum RankRange: String, CaseIterable, Identifiable, Codable {
    case plusMinusOne = "±1"
    case plusMinusTwo = "±2"
    case plusMinusThree = "±3"
    case any = "Any"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Numeric value for API calls
    var numericValue: Int? {
        switch self {
        case .plusMinusOne: return 1
        case .plusMinusTwo: return 2
        case .plusMinusThree: return 3
        case .any: return nil
        }
    }
}

/// Time control presets for live games
enum TimeControlPreset: String, CaseIterable, Identifiable, Codable {
    case blitz = "Blitz"
    case rapid = "Rapid"
    case fischer = "Fischer"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Main time in seconds
    var mainTime: Int {
        switch self {
        case .blitz: return 3 * 60      // 3 minutes
        case .rapid: return 10 * 60     // 10 minutes
        case .fischer: return 5 * 60    // 5 minutes
        }
    }

    /// Time per move (Fischer only) or period time (Byo-yomi)
    var periodTime: Int {
        switch self {
        case .blitz: return 20          // 20 seconds per byo-yomi period
        case .rapid: return 30          // 30 seconds per byo-yomi period
        case .fischer: return 30        // 30 seconds increment per move
        }
    }

    /// Number of byo-yomi periods (Fischer doesn't use periods)
    var periods: Int {
        switch self {
        case .blitz: return 3
        case .rapid: return 3
        case .fischer: return 0         // Fischer uses increment, not periods
        }
    }

    /// Time system type
    var timeSystem: String {
        switch self {
        case .blitz, .rapid: return "byoyomi"
        case .fischer: return "fischer"
        }
    }
}

/// Color preference for matchmaking
enum ColorPreference: String, CaseIterable, Identifiable, Codable {
    case auto = "Auto"
    case black = "Black"
    case white = "White"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Value for OGS API ("automatic", "black", "white")
    var apiValue: String {
        switch self {
        case .auto: return "automatic"
        case .black: return "black"
        case .white: return "white"
        }
    }
}

/// Game settings for live play on OGS
struct GameSettings: Codable {
    var boardSize: Int
    var rankRange: RankRange
    var timeControl: TimeControlPreset
    var colorPreference: ColorPreference

    /// Default settings for quick play
    static let `default` = GameSettings(
        boardSize: 19,
        rankRange: .plusMinusThree,
        timeControl: .rapid,
        colorPreference: .auto
    )

    // MARK: - UserDefaults Keys
    private static let boardSizeKey = "livePlay.boardSize"
    private static let rankRangeKey = "livePlay.rankRange"
    private static let timeControlKey = "livePlay.timeControl"
    private static let colorPreferenceKey = "livePlay.colorPreference"

    /// Load settings from UserDefaults
    static func load() -> GameSettings {
        let boardSize = UserDefaults.standard.object(forKey: boardSizeKey) as? Int ?? 19

        let rankRangeRaw = UserDefaults.standard.string(forKey: rankRangeKey) ?? RankRange.plusMinusThree.rawValue
        let rankRange = RankRange(rawValue: rankRangeRaw) ?? .plusMinusThree

        let timeControlRaw = UserDefaults.standard.string(forKey: timeControlKey) ?? TimeControlPreset.rapid.rawValue
        let timeControl = TimeControlPreset(rawValue: timeControlRaw) ?? .rapid

        let colorPrefRaw = UserDefaults.standard.string(forKey: colorPreferenceKey) ?? ColorPreference.auto.rawValue
        let colorPreference = ColorPreference(rawValue: colorPrefRaw) ?? .auto

        return GameSettings(
            boardSize: boardSize,
            rankRange: rankRange,
            timeControl: timeControl,
            colorPreference: colorPreference
        )
    }

    /// Save settings to UserDefaults
    func save() {
        UserDefaults.standard.set(boardSize, forKey: Self.boardSizeKey)
        UserDefaults.standard.set(rankRange.rawValue, forKey: Self.rankRangeKey)
        UserDefaults.standard.set(timeControl.rawValue, forKey: Self.timeControlKey)
        UserDefaults.standard.set(colorPreference.rawValue, forKey: Self.colorPreferenceKey)
    }
}
