import SwiftUI

/// Overlay view that displays the final game result
struct GameResultOverlay: View {
    @ObservedObject var ogsClient: OGSClient
    var ogsGame: OGSGameViewModel?

    @State private var isVisible = false

    var body: some View {
        if let result = ogsClient.gameResult, isVisible {
            ZStack {
                // Semi-transparent background overlay
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // Dismiss on background tap
                        withAnimation {
                            isVisible = false
                        }
                    }

                // Result card
                VStack(spacing: 20) {
                    // Title
                    Text("Game Finished")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    // Separator
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 40)

                    // Winner announcement
                    if let winner = result.winner {
                        HStack(spacing: 8) {
                            // Winner stone icon
                            Circle()
                                .fill(winner == .black ? Color.black : Color.white)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 2)
                                )

                            Text(result.winDescription)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Text("Game ended in a tie")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // Score details
                    VStack(spacing: 12) {
                        HStack {
                            Text("Black:")
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 80, alignment: .trailing)

                            Text(String(format: "%.1f", result.blackScore))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 80, alignment: .leading)
                        }

                        HStack {
                            Text("White:")
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 80, alignment: .trailing)

                            Text(String(format: "%.1f", result.whiteScore))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 80, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 10)

                    // Player names (if available from OGSGameViewModel)
                    if let game = ogsGame,
                       let blackName = game.blackName,
                       let whiteName = game.whiteName {
                        VStack(spacing: 8) {
                            HStack {
                                Text(blackName)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("vs")
                                    .foregroundColor(.white.opacity(0.5))
                                Text(whiteName)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .font(.system(size: 14))
                        }
                    }

                    // Dismiss button
                    Button(action: {
                        withAnimation {
                            isVisible = false
                        }
                    }) {
                        Text("Dismiss")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                )
                .frame(maxWidth: 400)
            }
            .transition(.opacity)
            .zIndex(1000)
        }
    }
}

// Extension to make GameResultOverlay reactive to gameResult changes
extension GameResultOverlay {
    /// Show the overlay when gameResult is set
    func showWhenResultAvailable() -> some View {
        self.onReceive(ogsClient.$gameResult) { result in
            if result != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = true
                }
            }
        }
    }
}

#Preview {
    // Preview with sample data
    let client = OGSClient()
    client.gameResult = GameResult(
        gameID: 12345,
        outcome: .blackWins,
        winner: .black,
        blackScore: 65.5,
        whiteScore: 50.0,
        winReason: "points"
    )

    return GameResultOverlay(ogsClient: client)
        .showWhenResultAvailable()
}
