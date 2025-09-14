// MARK: - Settings Panel View
// Extracted from ContentView to reduce complexity

import SwiftUI

struct SettingsPanelView: View {
    @Binding var isPanelOpen: Bool
    @Binding var activePhysicsModelRaw: Int
    @ObservedObject var physicsIntegration: PhysicsIntegration
    
    // Physics model parameters - kept for compatibility
    @Binding var m1_repel: Double
    @Binding var m1_spacing: Double
    @Binding var m1_centerPullK: Double
    @Binding var m1_relaxIters: Int
    @Binding var m1_pressureRadiusXR: Double
    @Binding var m1_pressureKFactor: Double
    @Binding var m1_maxStepXR: Double
    @Binding var m1_damping: Double
    @Binding var m1_wallK: Double
    @Binding var m1_anim: Double
    @Binding var m1_stoneStoneK: Double
    @Binding var m1_stoneLidK: Double
    
    // Auto-play controls moved from main UI
    @Binding var autoNext: Bool
    @Binding var randomNext: Bool
    @Binding var uiMoveDelay: Double
    
    // Move controls moved from main UI
    @ObservedObject var player: SGFPlayer
    @ObservedObject var app: AppModel
    var onMoveChanged: ((Int) -> Void)?
    
    // Additional settings
    @Binding var debugLayout: Bool
    @Binding var advancedExpanded: Bool

    // Game cache manager for jitter controls
    var gameCacheManager: GameCacheManager? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Settings").font(.title2.bold())
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { 
                        isPanelOpen = false 
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill").imageScale(.large)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Game Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Game Folder")
                            Spacer()
                            Button("Choose Folder") {
                                app.promptForFolder()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if let folderURL = app.folderURL {
                            Text("📁 \(folderURL.path)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Select a folder containing SGF game files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Games List & Selection
                        if !app.games.isEmpty {
                            Text("Games Found: \(app.games.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            
                            // Game selection picker
                            HStack {
                                Text("Current:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("Select Game", selection: Binding(
                                    get: { app.selection?.id ?? UUID() },
                                    set: { selectedId in
                                        app.selection = app.games.first { $0.id == selectedId }
                                    }
                                )) {
                                    ForEach(app.games) { gameWrapper in
                                        let game = gameWrapper.game
                                        let playerInfo = formatGameInfo(game.info)
                                        Text(playerInfo)
                                            .tag(gameWrapper.id)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: 200)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Physics Model Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Physics Model")
                            Spacer()
                            Picker("Active model", selection: Binding(
                                get: { activePhysicsModelRaw },
                                set: { activePhysicsModelRaw = $0 }
                            )) {
                                // Use new physics system models
                                ForEach(Array(physicsIntegration.availableModels.enumerated()), id: \.offset) { index, model in
                                    Text("Model \(index + 1): \(model.name)").tag(index + 1)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        Text("Current: Physics Model \(physicsIntegration.activePhysicsModel + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Auto-play Controls  
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-play Controls")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            Toggle("Auto-play", isOn: $autoNext)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .padding(.horizontal, 16)

                            Toggle("Random next", isOn: $randomNext)
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .padding(.horizontal, 16)
                            
                            if autoNext {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Move Delay")
                                        Spacer()
                                        Text("\(String(format: "%.1f", uiMoveDelay))s")
                                            .monospacedDigit()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                    // Log scale slider: 0-10s with 1s at midpoint (0.5)
                                    Slider(
                                        value: Binding(
                                            get: {
                                                // Convert delay to log position (0.0 to 1.0)
                                                if uiMoveDelay <= 0.1 { return 0.0 }
                                                let logValue = log10(uiMoveDelay / 0.1) / log10(100.0) // 0.1s to 10s mapped to 0-1
                                                return min(max(logValue, 0.0), 1.0)
                                            },
                                            set: { sliderValue in
                                                // Convert log position back to delay (0.1s to 10s)
                                                let delay = 0.1 * pow(100.0, sliderValue) // 100x range: 0.1s to 10s
                                                uiMoveDelay = min(max(delay, 0.1), 10.0)
                                            }
                                        ),
                                        in: 0.0...1.0
                                    )
                                    .controlSize(.regular)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Move Control Slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Move Navigation")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Move")
                                Spacer()
                                Text("\(player.currentIndex) / \(max(1, player.moves.count))")
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            
                            Slider(
                                value: Binding(
                                    get: { Double(player.currentIndex) },
                                    set: { newValue in 
                                        let newIndex = Int(newValue)
                                        onMoveChanged?(newIndex)
                                        print("🎮 Settings move slider changed to: \(newIndex)")
                                    }
                                ),
                                in: 0...Double(max(1, player.moves.count)),
                                step: 1
                            )
                            .controlSize(.regular)
                            .padding(.horizontal, 16)
                        }
                    }

                    Divider()
                        .padding(.horizontal, 16)

                    // Stone Jitter Controls
                    if let gameCacheManager = gameCacheManager,
                       let currentGame = gameCacheManager.currentGame {
                        JitterControlsView(currentGame: currentGame)
                    }

                    Divider()
                        .padding(.horizontal, 16)

                    // Playback Controls (moved from main UI) - Traditional << < || > >>
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Playback Controls")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        HStack(spacing: 12) {
                            // Scan backward (10 moves back) - <<
                            Button {
                                let newIndex = max(0, player.currentIndex - 10)
                                onMoveChanged?(newIndex)
                            } label: {
                                Text("<<")
                                    .font(.system(.body, design: .monospaced))  // Reduced from title2 to body
                                    .frame(width: 35, height: 28)  // Reduced from 40x30 to 35x28
                            }
                            .disabled(player.currentIndex <= 0)
                            .buttonStyle(.bordered)
                            
                            // Step backward (1 move back) - <
                            Button {
                                let newIndex = max(0, player.currentIndex - 1)
                                onMoveChanged?(newIndex)
                            } label: {
                                Text("<")
                                    .font(.system(.body, design: .monospaced))  // Reduced from title2 to body
                                    .frame(width: 35, height: 28)  // Reduced from 40x30 to 35x28
                            }
                            .disabled(player.currentIndex <= 0)
                            .buttonStyle(.bordered)
                            
                            // Play/Pause - solid triangle / pause bars
                            Button {
                                // Toggle auto-play
                                autoNext.toggle()
                            } label: {
                                Image(systemName: autoNext ? "pause.fill" : "play.fill")
                                    .font(.system(.body))
                                    .frame(width: 35, height: 28)
                            }
                            .buttonStyle(.bordered)
                            
                            // Step forward (1 move forward) - >
                            Button {
                                let maxMoves = max(1, player.moves.count)
                                let newIndex = min(maxMoves - 1, player.currentIndex + 1)
                                onMoveChanged?(newIndex)
                            } label: {
                                Text(">")
                                    .font(.system(.body, design: .monospaced))  // Reduced from title2 to body
                                    .frame(width: 35, height: 28)  // Reduced from 40x30 to 35x28
                            }
                            .disabled(player.currentIndex >= max(1, player.moves.count) - 1)
                            .buttonStyle(.bordered)
                            
                            // Scan forward (10 moves forward) - >>
                            Button {
                                let maxMoves = max(1, player.moves.count)
                                let newIndex = min(maxMoves - 1, player.currentIndex + 10)
                                onMoveChanged?(newIndex)
                            } label: {
                                Text(">>")
                                    .font(.system(.body, design: .monospaced))  // Reduced from title2 to body
                                    .frame(width: 35, height: 28)  // Reduced from 40x30 to 35x28
                            }
                            .disabled(player.currentIndex >= max(1, player.moves.count) - 1)
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Advanced Settings
                    DisclosureGroup("Advanced Settings", isExpanded: $advancedExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            
                            // Physics Controls - Simplified for compiler
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Physics Model Controls (Legacy - being replaced)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Current Model: \(physicsIntegration.activePhysicsModel + 1)")
                                    .font(.body.bold())
                            }
                            .padding(.leading, 16)
                            
                            // Debug Layout Toggle
                            Toggle("Debug Layout", isOn: $debugLayout)
                                .padding(.horizontal, 16)
                            
                            // Diagnostics Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("🔍 Diagnostics")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Button("Export") {
                                        exportDiagnostics()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.mini)
                                }
                                
                                Group {
                                    Text("Player State:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("  • Current Move: \(player.currentIndex)")
                                        .font(.caption2)
                                    Text("  • Total Moves: \(player.moves.count)")
                                        .font(.caption2)
                                    Text("  • Board Size: \(player.board.size)")
                                        .font(.caption2)
                                    
                                    Text("Physics State:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("  • Active Model: \(physicsIntegration.activePhysicsModel + 1)")
                                        .font(.caption2)
                                    Text("  • Black Stones: \(physicsIntegration.blackStones.count)")
                                        .font(.caption2)
                                    Text("  • White Stones: \(physicsIntegration.whiteStones.count)")
                                        .font(.caption2)
                                    
                                    if !physicsIntegration.blackStones.isEmpty {
                                        Text("Black Stone Positions (first 3):")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        ForEach(physicsIntegration.blackStones.prefix(3), id: \.id) { stone in
                                            Text("  • (\\(String(format: \"%.1f\", stone.pos.x)), \\(String(format: \"%.1f\", stone.pos.y)))")
                                                .font(.caption2)
                                                .foregroundColor(stone.pos.x == 0 && stone.pos.y == 0 ? .red : .primary)
                                        }
                                    }
                                }
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 20)
            }
        }
        .frame(width: 320)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // Helper function to format game info for display
    private func formatGameInfo(_ info: SGFGame.Info) -> String {
        let blackPlayer = info.playerBlack ?? "Unknown"
        let whitePlayer = info.playerWhite ?? "Unknown"
        let date = info.date ?? ""

        if !date.isEmpty {
            return "\(blackPlayer) vs \(whitePlayer) (\(date))"
        } else {
            return "\(blackPlayer) vs \(whitePlayer)"
        }
    }

    private func exportDiagnostics() {
        let timestamp = DateFormatter().string(from: Date())
        let diagnosticData = generateDiagnosticReport()
        
        let panel = NSSavePanel()
        panel.title = "Export Diagnostics"
        panel.nameFieldStringValue = "SGFPlayer_Diagnostics_\(timestamp.replacingOccurrences(of: " ", with: "_")).txt"
        panel.allowedContentTypes = [.plainText]
        panel.message = "Choose location to save diagnostic report"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    try diagnosticData.write(to: url, atomically: true, encoding: .utf8)
                    print("✅ Diagnostics exported to: \(url.path)")
                } catch {
                    print("❌ Failed to export diagnostics: \(error)")
                }
            }
        }
    }
    
    private func generateDiagnosticReport() -> String {
        let timestamp = Date().description
        var report = "SGFPlayer Diagnostic Report\n"
        report += "Generated: \(timestamp)\n"
        report += "Version: v2.3\n\n"
        
        report += "=== Player State ===\n"
        report += "Current Move: \(player.currentIndex)\n"
        report += "Total Moves: \(player.moves.count)\n"
        report += "Board Size: \(player.board.size)\n\n"
        
        report += "=== Physics State ===\n"
        report += "Active Model: \(physicsIntegration.activePhysicsModel + 1)\n"
        report += "Black Stones: \(physicsIntegration.blackStones.count)\n"
        report += "White Stones: \(physicsIntegration.whiteStones.count)\n\n"
        
        if !physicsIntegration.blackStones.isEmpty {
            report += "=== Black Stone Positions (first 10) ===\n"
            for (index, stone) in physicsIntegration.blackStones.prefix(10).enumerated() {
                let status = (stone.pos.x == 0 && stone.pos.y == 0) ? " ⚠️ AT ORIGIN" : ""
                report += "\(index + 1): (\(String(format: "%.2f", stone.pos.x)), \(String(format: "%.2f", stone.pos.y)))\(status)\n"
            }
            report += "\n"
        }
        
        if !physicsIntegration.whiteStones.isEmpty {
            report += "=== White Stone Positions (first 10) ===\n"
            for (index, stone) in physicsIntegration.whiteStones.prefix(10).enumerated() {
                let status = (stone.pos.x == 0 && stone.pos.y == 0) ? " ⚠️ AT ORIGIN" : ""
                report += "\(index + 1): (\(String(format: "%.2f", stone.pos.x)), \(String(format: "%.2f", stone.pos.y)))\(status)\n"
            }
            report += "\n"
        }
        
        report += "=== Game Files ===\n"
        report += "Selected Folder: \(app.folderURL?.path ?? "None")\n"
        report += "Games Found: \(app.games.count)\n"
        if !app.games.isEmpty {
            let gameNames = app.games.map { $0.url.lastPathComponent }
            report += "Games: \(gameNames.prefix(20).joined(separator: ", "))\n"
            if app.games.count > 20 {
                report += "... and \(app.games.count - 20) more\n"
            }
        }
        
        return report
    }
}

// Separate view for jitter controls with proper SwiftUI observation
struct JitterControlsView: View {
    @ObservedObject var currentGame: EnhancedSGFGame
    @State private var localMultiplier: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stone Jitter")
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Natural Placement")
                    Spacer()
                    Text("\(String(format: "%.1f", localMultiplier))×")
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

                Slider(
                    value: $localMultiplier,
                    in: 0.0...3.0,
                    step: 0.1
                )
                .controlSize(.regular)
                .padding(.horizontal, 16)
                .onChange(of: localMultiplier) { _, newValue in
                    print("🎚️ Local Slider CHANGED: \(newValue)")
                    currentGame.jitterMultiplier = CGFloat(newValue)
                }

                Text("Adjusts how naturally stones are placed off intersections")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }
        }
        .onAppear {
            localMultiplier = Double(currentGame.jitterMultiplier)
        }
    }
}

// Preview
struct SettingsPanelView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPanelView(
            isPanelOpen: .constant(true),
            activePhysicsModelRaw: .constant(2),
            physicsIntegration: PhysicsIntegration(),
            m1_repel: .constant(1.6),
            m1_spacing: .constant(2.1),
            m1_centerPullK: .constant(0.003),
            m1_relaxIters: .constant(12),
            m1_pressureRadiusXR: .constant(2.6),
            m1_pressureKFactor: .constant(0.25),
            m1_maxStepXR: .constant(0.06),
            m1_damping: .constant(0.82),
            m1_wallK: .constant(0.6),
            m1_anim: .constant(0.6),
            m1_stoneStoneK: .constant(0.15),
            m1_stoneLidK: .constant(0.25),
            autoNext: .constant(true),
            randomNext: .constant(false),
            uiMoveDelay: .constant(1.0),
            player: SGFPlayer(),
            app: AppModel(),
            onMoveChanged: { index in
                print("Preview move changed to: \(index)")
            },
            debugLayout: .constant(false),
            advancedExpanded: .constant(false)
        )
        .frame(width: 320, height: 600)
    }
}