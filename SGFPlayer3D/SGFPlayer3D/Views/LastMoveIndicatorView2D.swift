// MARK: - Last Move Indicator View (2D)
// Renders different visual indicators for the last played move in 2D view

import SwiftUI

struct LastMoveIndicatorView2D: View {
    let style: LastMoveIndicatorStyle  // Legacy support
    let stoneColor: Stone?
    let position: CGPoint
    let size: CGFloat
    var onlyGlowEffects: Bool = true  // Default to glow effects only

    // New: support for combinable effects
    var effects: Set<LastMoveEffect> {
        // Always use new effects system
        let allEffects = LastMoveIndicatorSettings.enabledEffects()

        if onlyGlowEffects {
            // Only return glow effects (boardGlow, enhancedGlow, dropIn)
            return allEffects.filter { effect in
                effect == .boardGlow || effect == .enhancedGlow || effect == .dropIn
            }
        } else {
            // Only return circle markers (solidCircle, hollowCircle)
            return allEffects.filter { effect in
                effect == .solidCircle || effect == .hollowCircle
            }
        }
    }

    var body: some View {
        ZStack {
            // Layer each enabled effect
            ForEach(Array(effects), id: \.self) { effect in
                effectView(for: effect)
            }
        }
    }

    @ViewBuilder
    private func effectView(for effect: LastMoveEffect) -> some View {
        switch effect {
        case .boardGlow:
            boardGlowIndicator
        case .enhancedGlow:
            enhancedGlowIndicator
        case .dropIn:
            // Drop-in doesn't work well in 2D, show board glow instead
            boardGlowIndicator
        case .solidCircle:
            solidCircleIndicator
        case .hollowCircle:
            hollowCircleIndicator
        }
    }

    // Board Glow: Strong glowing circle under the stone (extends beyond edges)
    private var boardGlowIndicator: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.red.opacity(0.8),
                        Color.red.opacity(0.6),
                        Color.red.opacity(0.4),
                        Color.red.opacity(0.2),
                        Color.red.opacity(0.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 1.0
                )
            )
            .frame(width: size * 2.0, height: size * 2.0)
            .position(position)
            .blur(radius: 6)
    }

    // Style 2: Solid circle on top of stone
    private var solidCircleIndicator: some View {
        Circle()
            .fill(Color.red)
            .frame(width: size * 0.3, height: size * 0.3)
            .position(position)
    }

    // Style 3: Hollow circle outline on top of stone
    private var hollowCircleIndicator: some View {
        Circle()
            .stroke(Color.red, lineWidth: size * 0.08)
            .frame(width: size * 0.3, height: size * 0.3)
            .position(position)
    }

    // Enhanced Glow: Light emitting from bottom of stone (halo extends slightly beyond)
    private var enhancedGlowIndicator: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.red.opacity(0.0),
                        Color.red.opacity(0.3),
                        Color.red.opacity(0.6),
                        Color.red.opacity(0.4),
                        Color.red.opacity(0.0)
                    ]),
                    center: .center,
                    startRadius: size * 0.3,
                    endRadius: size * 0.7
                )
            )
            .frame(width: size * 1.4, height: size * 1.4)
            .position(position)
            .blur(radius: 3)
    }

    // Warm amber color for both stones (matching 3D)
    private var warmAmberColor: Color {
        Color(red: 1.0, green: 0.8, blue: 0.4)
    }
}
