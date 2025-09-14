// MARK: - Controls View
// Extracted from ContentView to reduce complexity

import SwiftUI

struct ControlsView: View {
    @ObservedObject var player: SGFPlayer
    @Binding var isPanelOpen: Bool
    @Binding var showFullscreen: Bool
    
    // Function to update move - passed from parent
    var onMoveChanged: ((Int) -> Void)?
    
    var body: some View {
        VStack(spacing: 12) {
            // Top controls row
            HStack(spacing: 16) {
                // Settings button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isPanelOpen = true
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .imageScale(.large)
                        .foregroundColor(.white)
                }
                .buttonStyle(GlassPillButton(emphasis: .normal))
                
                Spacer()
                
                // Fullscreen button
                Button {
                    showFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .imageScale(.medium)
                        .foregroundColor(.white)
                }
                .buttonStyle(GlassPillButton(emphasis: .normal))
            }
            
            // All playback controls moved to settings panel
            VStack(spacing: 8) {
                Text("All controls moved to Settings panel")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("Move: \(player.currentIndex) / \(max(1, player.moves.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            // Version info
            HStack {
                Text("v2.3")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
        .cornerRadius(12)
    }
}

// Glass Pill Button Style
struct GlassPillButton: ButtonStyle {
    enum Emphasis {
        case normal
    }
    
    var emphasis: Emphasis = .normal
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Preview
struct ControlsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockPlayer = SGFPlayer()
        
        VStack {
            ControlsView(
                player: mockPlayer,
                isPanelOpen: .constant(false),
                showFullscreen: .constant(false),
                onMoveChanged: { index in
                    print("Preview move changed to: \(index)")
                }
            )
            Spacer()
        }
        .frame(width: 400, height: 200)
        .background(Color.gray.opacity(0.1))
    }
}