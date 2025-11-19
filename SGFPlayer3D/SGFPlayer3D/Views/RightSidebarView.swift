// MARK: - RightSidebarView
// Right sidebar for metadata and match controls (not settings)

import SwiftUI

struct RightSidebarView: View {
    // Pass-through bindings and objects
    @EnvironmentObject private var app: AppModel
    let player: SGFPlayer
    let ogsClient: OGSClient
    let timeControl: TimeControlManager
    let ogsGame: OGSGameViewModel?
    @ObservedObject var uiStateVM: UIStateViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top: Fullscreen button (in top-right corner of sidebar)
            HStack {
                Spacer()

                Button {
                    uiStateVM.toggleFullscreen()
                } label: {
                    Image(systemName: uiStateVM.isWindowFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 60)  // 60px from right edge
            .padding(.top, 16)
            .opacity(uiStateVM.buttonsVisible ? 1.0 : 0.0)
            .animation(.easeInOut(duration: uiStateVM.buttonsVisible ? 0.2 : 0.5), value: uiStateVM.buttonsVisible)

            // Game metadata
            HStack {
                Spacer()

                GameInfoOverlay(
                    ogsGame: ogsGame,
                    timeControl: timeControl,
                    player: player,
                    gameSelection: (ogsGame?.blackName == nil) ? app.selection : nil,
                    backgroundOpacity: 0.6
                )

                Spacer()
            }
            .padding(.top, 5)
            .padding(.horizontal, 10)

            Spacer()

            // Middle: Space for future chat panel

            Spacer()

            // Bottom: OGS Game Controls (when applicable)
            if ogsClient.currentGameID != nil, ogsClient.gamePhase == .playing {
                ogsGameControlButtons
                    .padding(.bottom, 20)
            }

            // Version badge
            Text("v3.189-2D")
                .foregroundColor(.white)
                .font(.caption)
                .fontWeight(.bold)
                .padding(6)
                .background(Color.red)
                .cornerRadius(5)
                .padding(.bottom, 10)
        }
        .frame(width: 300)
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
    }

    // MARK: - OGS Game Control Buttons

    private var ogsGameControlButtons: some View {
        VStack(spacing: 12) {
            Text("Match Controls")
                .foregroundColor(.white.opacity(0.8))
                .font(.caption)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                // Undo button
                Button(action: {
                    if let gameID = ogsClient.currentGameID {
                        ogsClient.requestUndo(gameID: gameID, moveNumber: player.currentIndex)
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
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
                    VStack(spacing: 2) {
                        Image(systemName: "forward.end")
                        Text("Pass")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Resign button
                Button(action: {
                    if let gameID = ogsClient.currentGameID {
                        resignConfirmation(gameID: gameID)
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "flag.fill")
                        Text("Resign")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.7))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
    }

    private func resignConfirmation(gameID: Int) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Resign Game?"
        alert.informativeText = "Are you sure you want to resign this game? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Resign")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ogsClient.sendResign(gameID: gameID)
        }
        #endif
    }
}
