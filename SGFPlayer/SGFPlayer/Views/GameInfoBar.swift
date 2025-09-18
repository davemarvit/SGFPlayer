// MARK: - Game Info Bar Component
// Extracted from GameBoardView for reuse in ContentView

import SwiftUI

struct GameInfoBar: View {
    var gameCacheManager: GameCacheManager?
    let blackCapturedCount: Int
    let whiteCapturedCount: Int
    @ObservedObject var player: SGFPlayer
    @Binding var autoNext: Bool

    var body: some View {
        if let gameWrapper = gameCacheManager?.currentGame {
            let game = gameWrapper.originalGame
            let blackPlayer = game.info.playerBlack ?? "Unknown"
            let whitePlayer = game.info.playerWhite ?? "Unknown"
            let result = game.info.result ?? "B+3"

            HStack(spacing: 12) {
                Text("\(blackPlayer) vs \(whitePlayer)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                Text("—")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))

                Text("\(result)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))

                Button(action: {
                    autoNext.toggle()
                }) {
                    Image(systemName: autoNext ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(autoNext ? "Pause autoplay" : "Start autoplay")

                Text("Captures")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 6) {
                    Text("\(blackCapturedCount)")
                        .font(.system(size: 13))
                        .foregroundColor(.white)

                    Image("stone_black")
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(width: 14, height: 14)

                    Spacer()
                        .frame(width: 12) // Add spacing between black and white stone sections

                    Text("\(whiteCapturedCount)")
                        .font(.system(size: 13))
                        .foregroundColor(.white)

                    Image("clam_01")
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
        } else {
            // Debug fallback - always show something
            HStack(spacing: 12) {
                Text("DEBUG: No game data")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                Button(action: {
                    autoNext.toggle()
                }) {
                    Image(systemName: autoNext ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(autoNext ? "Pause autoplay" : "Start autoplay")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.5))  // Red background for debug
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}