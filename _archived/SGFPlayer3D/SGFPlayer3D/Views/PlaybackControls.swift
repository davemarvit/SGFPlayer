// MARK: - PlaybackControls
// Handles game playback navigation: backward, play/pause, forward, and seek slider
//
// Extracted from ContentView3D.swift (Phase 3)
// Original lines: 478-520 (43 lines)

import SwiftUI

struct PlaybackControls: View {
    @ObservedObject var player: SGFPlayer
    @Binding var isPlaying: Bool

    // Callbacks
    let onSeek: () -> Void
    let onTogglePlayPause: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Backward button
            Button(action: {
                player.seek(to: max(0, player.currentIndex - 1))
                onSeek()
            }) {
                Image(systemName: "backward.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .disabled(player.currentIndex <= 0)

            // Play/Pause button
            Button(action: {
                onTogglePlayPause()
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            // Forward button
            Button(action: {
                player.seek(to: min(player.moves.count, player.currentIndex + 1))
                onSeek()
            }) {
                Image(systemName: "forward.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .disabled(player.currentIndex >= player.moves.count)

            // Seek slider
            Slider(value: Binding(
                get: { Double(player.currentIndex) },
                set: { newValue in
                    player.seek(to: Int(newValue))
                    onSeek()
                }
            ), in: 0...Double(max(1, player.moves.count)), step: 1)
            .frame(width: 300)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding(.bottom, 20)
    }
}
