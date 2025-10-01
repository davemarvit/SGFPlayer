// MARK: - Settings Panel View for SGFPlayer3D
// Simplified version focused on game selection and 3D-specific settings

import SwiftUI

struct SettingsPanelView3D: View {
    @Binding var isPanelOpen: Bool
    @ObservedObject var app: AppModel
    @ObservedObject var player: SGFPlayer

    // Playback controls
    @Binding var autoPlay: Bool
    @Binding var playbackSpeed: Double

    var onGameSelected: ((SGFGameWrapper) -> Void)?
    var onJitterChanged: (() -> Void)?

    @State private var localJitterMultiplier: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Background for entire panel
            Rectangle()
                .fill(.thinMaterial)

            VStack(spacing: 0) {
                // Header with gear icon
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPanelOpen = false
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Text("Settings")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPanelOpen = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 32)
                .padding(.trailing, 50)
                .padding(.top, 32)
                .padding(.bottom, 16)

                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Folder selection
                        FolderSelectionSection3D(app: app)
                            .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Game selection list
                        GameSelectionSection3D(app: app, onGameSelected: onGameSelected)
                            .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Auto-play controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Playback")
                                .font(.headline)
                                .foregroundColor(.white)

                            Toggle("Auto-play", isOn: $autoPlay)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Move Delay")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.1fs", playbackSpeed))")
                                        .monospacedDigit()
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .font(.caption)

                                // Log scale slider: 0.1-10s with ~1s at midpoint
                                Slider(
                                    value: Binding(
                                        get: {
                                            // Convert playbackSpeed to log position (0.0 to 1.0)
                                            if playbackSpeed <= 0.1 { return 0.0 }
                                            let logValue = log10(playbackSpeed / 0.1) / log10(100.0) // 0.1s to 10s mapped to 0-1
                                            return min(max(logValue, 0.0), 1.0)
                                        },
                                        set: { sliderValue in
                                            // Convert log position back to delay (0.1s to 10s)
                                            let delay = 0.1 * pow(100.0, sliderValue) // 100x range: 0.1s to 10s
                                            playbackSpeed = min(max(delay, 0.1), 10.0)
                                        }
                                    ),
                                    in: 0.0...1.0
                                )
                                .controlSize(.regular)
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Jitter controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stone Jitter")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Amount")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.1f", localJitterMultiplier))")
                                        .monospacedDigit()
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .font(.caption)

                                Slider(
                                    value: $localJitterMultiplier,
                                    in: 0.0...2.0,
                                    step: 0.1
                                )
                                .controlSize(.regular)
                                .onChange(of: localJitterMultiplier) { oldValue, newValue in
                                    NSLog("DEBUG3D: 🎲 Jitter slider changed from \(oldValue) to \(newValue)")
                                    app.gameCacheManager.defaultJitterMultiplier = newValue
                                    onJitterChanged?()
                                }
                            }
                            .onAppear {
                                localJitterMultiplier = app.gameCacheManager.defaultJitterMultiplier
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Move navigation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Move Navigation")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Move")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(player.currentIndex) / \(max(1, player.moves.count))")
                                        .monospacedDigit()
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .font(.caption)

                                Slider(
                                    value: Binding(
                                        get: { Double(player.currentIndex) },
                                        set: { newValue in
                                            let newIndex = Int(newValue)
                                            player.seek(to: newIndex)
                                        }
                                    ),
                                    in: 0...Double(max(1, player.moves.count)),
                                    step: 1
                                )
                                .controlSize(.regular)
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Camera controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Camera (3D View)")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Use mouse drag to rotate camera around board")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.automatic)
            }
        }
        .frame(width: 320)
    }
}

struct FolderSelectionSection3D: View {
    @ObservedObject var app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Folder selection buttons
            HStack(spacing: 12) {
                Button("Open folder...") {
                    app.promptForFolder()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.8))
                .cornerRadius(8)
                .buttonStyle(.plain)

                Button("Random game") {
                    if !app.games.isEmpty {
                        app.selection = app.games.randomElement()
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.8))
                .cornerRadius(8)
                .buttonStyle(.plain)
            }

            // Folder path display
            if let folderURL = app.folderURL {
                Text("📁 \(folderURL.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Text("\(app.games.count) games")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct GameSelectionSection3D: View {
    @ObservedObject var app: AppModel
    var onGameSelected: ((SGFGameWrapper) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Games")
                .font(.headline)
                .foregroundColor(.white)

            // Game list (scrollable, showing ~7 games)
            if !app.games.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(app.games.enumerated()), id: \.element.id) { index, gameWrapper in
                            GameListItem3D(
                                gameWrapper: gameWrapper,
                                isSelected: app.selection?.id == gameWrapper.id,
                                onTap: {
                                    app.selection = gameWrapper
                                    onGameSelected?(gameWrapper)
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 200)  // ~7 games at 28px each
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.3))
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                Text("No games available")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.3))
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            }

            // Show selected game metadata
            if let selection = app.selection {
                VStack(alignment: .leading, spacing: 6) {
                    let info = selection.game.info
                    let moveCount = selection.game.moves.count

                    HStack {
                        Text("Moves: \(moveCount)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        if let date = info.date {
                            Text("Date: \(date)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    if let result = info.result {
                        Text("Result: \(result)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

struct GameListItem3D: View {
    let gameWrapper: SGFGameWrapper
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let blackPlayer = gameWrapper.game.info.playerBlack ?? "?"
        let whitePlayer = gameWrapper.game.info.playerWhite ?? "?"
        let playerInfo = "\(blackPlayer) vs \(whitePlayer)"

        HStack {
            Text(playerInfo)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? Color.cyan.opacity(0.9) : .white.opacity(0.9))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.cyan.opacity(0.15) : Color.clear)
        )
        .onTapGesture {
            onTap()
        }
    }
}
