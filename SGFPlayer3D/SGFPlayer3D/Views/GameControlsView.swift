// MARK: - Game Controls View
// Provides Pass and Resign buttons for live game play

import SwiftUI

struct GameControlsView: View {
    @ObservedObject var ogsClient: OGSClient
    @State private var showResignConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // Pass button
            Button {
                handlePass()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                    Text("Pass")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!ogsClient.isMyTurn)
            .opacity(ogsClient.isMyTurn ? 1.0 : 0.5)

            // Resign button
            Button {
                showResignConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                    Text("Resign")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .alert("Resign Game?", isPresented: $showResignConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Resign", role: .destructive) {
                    handleResign()
                }
            } message: {
                Text("Are you sure you want to resign this game? This cannot be undone.")
            }
        }
    }

    // MARK: - Helper Methods

    private func handlePass() {
        NSLog("GameControls: 🤚 PASS BUTTON PRESSED")
        NSLog("GameControls: 🎮 currentGameID=\(ogsClient.currentGameID ?? -1)")
        NSLog("GameControls: 🎮 isMyTurn=\(ogsClient.isMyTurn)")
        NSLog("GameControls: 🎨 playerColor=\(String(describing: ogsClient.playerColor)), currentPlayerColor=\(ogsClient.currentPlayerColor)")

        guard let gameID = ogsClient.currentGameID else {
            NSLog("GameControls: ❌ No active game ID")
            return
        }

        guard ogsClient.isMyTurn else {
            NSLog("GameControls: ❌ Not your turn to pass")
            return
        }

        NSLog("GameControls: 🤚 Sending pass move to game \(gameID)")

        // OGS uses ".." as the move string for passing
        ogsClient.sendMove(gameID: gameID, move: "..")
    }

    private func handleResign() {
        guard let gameID = ogsClient.currentGameID else {
            NSLog("GameControls: ❌ No active game ID")
            return
        }

        NSLog("GameControls: 🏳️ Resigning game \(gameID)")

        // Send resign message to OGS
        ogsClient.resignGame(gameID: gameID)
    }
}
