//
//  GameInfoAndControlsView.swift
//  SGFPlayer3D
//
//  Created by Claude Code on 2025-11-19.
//  Extracted from ContentView as part of incremental refactoring.
//

import SwiftUI

/// Overlay view containing game info, OGS controls, and playback controls
struct GameInfoAndControlsView: View {
    // Dependencies
    @ObservedObject var app: AppModel
    @ObservedObject var player: SGFPlayer
    @ObservedObject var ogsClient: OGSClient
    @ObservedObject var uiStateVM: UIStateViewModel

    // State
    @Binding var autoNext: Bool
    var boardCenterX: CGFloat

    // Callbacks
    var onUpdatePhysics: (Int) -> Void
    var onResignConfirmation: (Int) -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()

                // Game info with fullscreen button overlay
                ZStack(alignment: .topTrailing) {
                    GameInfoOverlay(
                        ogsGame: app.ogsGame,
                        timeControl: app.timeControl,
                        player: player,
                        gameSelection: ogsClient.isConnected ? nil : app.selection,  // Hide local game metadata when OGS is connected
                        backgroundOpacity: 0.6  // 2D mode: matches settings panel opacity
                    )

                    // Fullscreen button overlaid on top-right of metadata
                    Button {
                        uiStateVM.toggleFullscreen()
                    } label: {
                        Image(systemName: uiStateVM.isWindowFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(uiStateVM.buttonsVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: uiStateVM.buttonsVisible ? 0.2 : 0.5), value: uiStateVM.buttonsVisible)
                }
                .padding(.trailing, 20)
                .padding(.top, 20)
            }

            Spacer()

            // OGS Game Control Buttons (only visible during OGS gameplay)
            if ogsClient.currentGameID != nil, ogsClient.gamePhase == .playing {
                HStack(spacing: 20) {
                    // Undo button
                    Button(action: {
                        if let gameID = ogsClient.currentGameID {
                            // Pass current move number as validation
                            ogsClient.requestUndo(gameID: gameID, moveNumber: player.currentIndex)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Pass button
                    Button(action: {
                        if let gameID = ogsClient.currentGameID {
                            ogsClient.sendPass(gameID: gameID)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.end")
                            Text("Pass")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Resign button
                    Button(action: {
                        if let gameID = ogsClient.currentGameID {
                            // Show confirmation before resigning
                            onResignConfirmation(gameID)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                            Text("Resign")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 10)
                .opacity(uiStateVM.buttonsVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: uiStateVM.buttonsVisible)
            }

            // Playback controls centered under the board
            GeometryReader { geometry in
                HStack {
                    Spacer()
                    PlaybackControls(
                        player: player,
                        isPlaying: $autoNext,
                        onSeek: {
                            // Update physics when seeking in 2D view
                            onUpdatePhysics(player.currentIndex)
                        },
                        onTogglePlayPause: {
                            autoNext.toggle()
                        }
                    )
                    Spacer()
                }
                .frame(width: geometry.size.width)
                .offset(x: boardCenterX - (geometry.size.width / 2))
            }
            .frame(height: 60) // Fixed height for controls
        }
        .allowsHitTesting(true)
        .zIndex(15) // Above settings panel (10) to ensure button clicks work
    }
}
