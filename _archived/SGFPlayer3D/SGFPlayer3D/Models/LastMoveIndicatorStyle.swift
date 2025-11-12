// MARK: - Last Move Indicator Effects
// Defines independent visual effects that can be combined for the last played move

import Foundation
import SwiftUI

/// Individual effect types that can be enabled/disabled independently
enum LastMoveEffect: String, CaseIterable, Identifiable, Codable {
    case boardGlow = "Board Glow"
    case enhancedGlow = "Enhanced Glow"
    case dropIn = "Drop In"
    case solidCircle = "Solid Circle"
    case hollowCircle = "Hollow Circle"

    var id: String { rawValue }

    /// User-facing description of each effect
    var description: String {
        switch self {
        case .boardGlow:
            return "Glowing disc underneath the stone"
        case .enhancedGlow:
            return "Enhanced glow with gradient and pulsing rings"
        case .dropIn:
            return "Stone drops in from above with animation"
        case .solidCircle:
            return "Solid red circle marker on the stone"
        case .hollowCircle:
            return "Hollow red circle outline on the stone"
        }
    }

    /// UserDefaults key for this effect
    var settingsKey: String {
        return "lastMoveEffect_\(rawValue)"
    }
}

// MARK: - Legacy Support for 2D Views

/// Legacy enum for 2D views (SimpleBoardView, GameBoardView)
/// 3D views use the new LastMoveEffect system with combinable effects
enum LastMoveIndicatorStyle: String, CaseIterable, Identifiable, Codable {
    case glowDisc = "Glow Disc"
    case glowDiscEnhanced = "Glow Disc (Enhanced)"
    case dropIn = "Drop In"
    case solidCircle = "Solid Circle"
    case hollowCircle = "Hollow Circle"
    case none = "None"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .glowDisc:
            return "Glowing disc underneath the stone"
        case .glowDiscEnhanced:
            return "Enhanced glow with gradient and adjusted transparency"
        case .dropIn:
            return "Stone drops in from above with fade animation"
        case .solidCircle:
            return "Solid circle marker on the stone"
        case .hollowCircle:
            return "Hollow circle outline on the stone"
        case .none:
            return "No indicator"
        }
    }

    static let `default` = LastMoveIndicatorStyle.glowDisc
}

/// Settings for last move indicator effects
struct LastMoveIndicatorSettings {
    // Legacy support - keep old enum for migration
    private static let legacyStyleKey = "lastMoveIndicatorStyle"

    /// Check if a specific effect is enabled
    static func isEffectEnabled(_ effect: LastMoveEffect) -> Bool {
        // Check if the key has ever been set
        if UserDefaults.standard.object(forKey: effect.settingsKey) == nil {
            // Never set - only default Board Glow to true
            return effect == .boardGlow
        }
        return UserDefaults.standard.bool(forKey: effect.settingsKey)
    }

    /// Enable or disable a specific effect
    static func setEffect(_ effect: LastMoveEffect, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: effect.settingsKey)
    }

    /// Get all currently enabled effects
    static func enabledEffects() -> Set<LastMoveEffect> {
        var effects = Set<LastMoveEffect>()
        for effect in LastMoveEffect.allCases {
            if isEffectEnabled(effect) {
                effects.insert(effect)
            }
        }
        return effects
    }

    /// Migrate from old single-style system to new multi-effect system
    static func migrateFromLegacyStyle() {
        // Only migrate if we haven't already
        guard UserDefaults.standard.object(forKey: "hasMigratedToEffects") == nil else {
            return
        }

        // Check if there's a legacy style set
        if let legacyStyleRaw = UserDefaults.standard.string(forKey: legacyStyleKey),
           let legacyStyle = LastMoveIndicatorStyle(rawValue: legacyStyleRaw) {

            // Map old style to new effect(s)
            switch legacyStyle {
            case .glowDisc:
                setEffect(.boardGlow, enabled: true)
            case .glowDiscEnhanced:
                setEffect(.enhancedGlow, enabled: true)
            case .dropIn:
                setEffect(.dropIn, enabled: true)
            case .solidCircle:
                setEffect(.solidCircle, enabled: true)
            case .hollowCircle:
                setEffect(.hollowCircle, enabled: true)
            case .none:
                break  // No effects enabled
            }
        } else {
            // No legacy style - enable board glow as default
            setEffect(.boardGlow, enabled: true)
        }

        UserDefaults.standard.set(true, forKey: "hasMigratedToEffects")
        NSLog("DEBUG3D: Migrated from legacy indicator style to new effects system")
    }

    // MARK: - Legacy 2D View Support

    /// Load the current style from UserDefaults (for 2D views)
    static func loadStyle() -> LastMoveIndicatorStyle {
        guard let styleRaw = UserDefaults.standard.string(forKey: legacyStyleKey),
              let style = LastMoveIndicatorStyle(rawValue: styleRaw) else {
            return .default
        }
        return style
    }

    /// Save the style to UserDefaults (for 2D views)
    static func saveStyle(_ style: LastMoveIndicatorStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: legacyStyleKey)
    }
}
