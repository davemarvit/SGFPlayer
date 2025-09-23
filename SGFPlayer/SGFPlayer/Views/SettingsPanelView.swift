// MARK: - Settings Panel View
// Extracted from ContentView to reduce complexity

import SwiftUI

struct SettingsPanelView: View {
    // ARCHITECTURAL IMPROVEMENT: Use service directly instead of 23+ individual bindings
    @ObservedObject var settingsService: SettingsPanelService
    @ObservedObject var physicsIntegration: PhysicsIntegration

    // Core dependencies for functionality
    @ObservedObject var player: SGFPlayer
    @ObservedObject var app: AppModel
    var onMoveChanged: ((Int) -> Void)?

    // Game cache manager for jitter controls
    var gameCacheManager: GameCacheManager? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gear icon
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        settingsService.isPanelOpen = false
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
                    withAnimation(.easeInOut(duration: 1.0)) {
                        settingsService.isPanelOpen = false
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
                    FolderSelectionSection(app: app)
                        .padding(.horizontal, 16)
                    GameSelectionSection(app: app)
                        .padding(.horizontal, 16)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Auto-play Controls  
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-play Controls")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            // Put both toggles on the same line with consistent blue color
                            HStack(spacing: 20) {
                                Toggle("Auto-play", isOn: $settingsService.autoNext)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))

                                Toggle("Random next", isOn: $settingsService.randomNext)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                            }
                            .padding(.horizontal, 16)
                            
                            if settingsService.autoNext {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Move Delay")
                                        Spacer()
                                        Text("\(String(format: "%.1f", settingsService.uiMoveDelay))s")
                                            .monospacedDigit()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)

                                    // Log scale slider: 0-10s with 1s at midpoint (0.5)
                                    Slider(
                                        value: Binding(
                                            get: {
                                                // Convert delay to log position (0.0 to 1.0)
                                                if settingsService.uiMoveDelay <= 0.1 { return 0.0 }
                                                let logValue = log10(settingsService.uiMoveDelay / 0.1) / log10(100.0) // 0.1s to 10s mapped to 0-1
                                                return min(max(logValue, 0.0), 1.0)
                                            },
                                            set: { sliderValue in
                                                // Convert log position back to delay (0.1s to 10s)
                                                let delay = 0.1 * pow(100.0, sliderValue) // 100x range: 0.1s to 10s
                                                settingsService.uiMoveDelay = min(max(delay, 0.1), 10.0)
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
                            .foregroundColor(.white)
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
                    if let gameCacheManager = gameCacheManager {
                        JitterControlsView(gameCacheManager: gameCacheManager)
                    }

                    // COMMENTED OUT: Board Spacing Controls (hard coded values used instead)
                    /*
                    if let gameCacheManager = gameCacheManager {
                        BoardSpacingControlsView(gameCacheManager: gameCacheManager)
                    }
                    */

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
                                settingsService.autoNext.toggle()
                            } label: {
                                Image(systemName: settingsService.autoNext ? "pause.fill" : "play.fill")
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
                    DisclosureGroup("Advanced Settings", isExpanded: $settingsService.advancedExpanded) {
                        VStack(alignment: .leading, spacing: 12) {

                            // Physics Model Selection (moved from main section)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Physics Model")
                                        .foregroundColor(.white)
                                    Spacer()
                                    // PERFORMANCE: Show active model name instead of expensive picker
                                    Text("Model \(physicsIntegration.activePhysicsModel + 1)")
                                        .foregroundColor(.blue)
                                        .onTapGesture {
                                            // Cycle to next model
                                            let nextModel = (physicsIntegration.activePhysicsModel + 1) % physicsIntegration.availableModels.count
                                            settingsService.activePhysicsModel = nextModel
                                        }
                                }

                                Text("Current: Physics Model \(physicsIntegration.activePhysicsModel + 1)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            
                            // Debug Layout Toggle
                            Toggle("Debug Layout", isOn: $settingsService.debugLayout)
                                .padding(.horizontal, 16)
                            
                            // PERFORMANCE: Simplified diagnostics - no expensive ForEach calculations
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

                                // Simplified diagnostics - avoid expensive stone iteration
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Move: \(player.currentIndex)/\(player.moves.count) • Model: \(physicsIntegration.activePhysicsModel + 1)")
                                        .font(.caption)
                                    Text("Stones: ⚫\(physicsIntegration.blackStones.count) ⚪\(physicsIntegration.whiteStones.count)")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
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

    private func formatGameDisplayText(_ info: SGFGame.Info) -> String {
        let blackPlayer = info.playerBlack ?? "Unknown"
        let whitePlayer = info.playerWhite ?? "Unknown"
        let date = info.date ?? ""

        if !date.isEmpty {
            return "\(blackPlayer) vs \(whitePlayer) · \(date)"
        } else {
            return "\(blackPlayer) vs \(whitePlayer)"
        }
    }
}

// MARK: - Component Sections

struct FolderSelectionSection: View {
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

                Button("Random game now") {
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

            // Include subfolders toggle
            Toggle("Include subfolders", isOn: .constant(true))
                .foregroundColor(.white)
                .toggleStyle(SwitchToggleStyle(tint: .blue))

            // Folder path display
            if let folderURL = app.folderURL {
                Text("📁 \(folderURL.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}

struct GameSelectionSection: View {
    @ObservedObject var app: AppModel
    @State private var visibleGames: [SGFGameWrapper] = []
    @State private var isLoadingMore = false

    var filteredGames: [SGFGameWrapper] {
        return visibleGames
    }

    var body: some View {
        if let selection = app.selection {
            VStack(alignment: .leading, spacing: 8) {
                // Search functionality temporarily disabled due to overlay text input issues
                Text("Game List:")
                    .foregroundColor(.white)
                    .font(.caption)

                // Game list with dark styling (scrollable) + progressive loading
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, gameWrapper in
                            GameListItem(
                                gameWrapper: gameWrapper,
                                isSelected: gameWrapper.id == selection.id,
                                onTap: { app.selection = gameWrapper }
                            )
                        }

                        // Loading indicator when more games are available
                        if isLoadingMore {
                            HStack {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Loading more games...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.vertical, 8)
                        } else if visibleGames.count < app.games.count {
                            Text("+ \(app.games.count - visibleGames.count) more games")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.7))
                                .padding(.vertical, 4)
                        }
                    }
                }
                .scrollIndicators(.visible) // Always show scrollbar when scrollable
                .frame(maxHeight: 200)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.3))
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .onAppear {
                    loadInitialGames()
                }
                .onChange(of: app.games) { _, _ in
                    loadInitialGames()
                }

                GameMetadataView(gameWrapper: selection)
            }
        }
    }

    // PERFORMANCE: Ultra-fast loading - minimal games initially
    private func loadInitialGames() {
        // Load only 1 game initially for ultra-fast panel opening
        let initialGames = Array(app.games.prefix(1))
        visibleGames = initialGames

        // Load ALL remaining games after panel slide animation completes
        if app.games.count > 1 {
            Task {
                // Wait for panel slide animation to complete (~500ms)
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
                await loadRemainingGames()
            }
        }
    }

    @MainActor
    private func loadRemainingGames() async {
        isLoadingMore = true

        // Load games in batches to avoid UI freezing
        let batchSize = 50
        let remaining = Array(app.games.dropFirst(1)) // Skip first 1 game already loaded

        for batch in remaining.chunked(into: batchSize) {
            visibleGames.append(contentsOf: batch)

            // Small delay between batches to keep UI responsive
            try? await Task.sleep(nanoseconds: 25_000_000) // 25ms between batches (faster)
        }

        isLoadingMore = false
    }
}

struct GameListItem: View {
    let gameWrapper: SGFGameWrapper
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let playerInfo = formatGameDisplayText(gameWrapper.game.info)

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
                .stroke(isSelected ? Color.cyan.opacity(0.8) : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture { onTap() }
    }

    private func formatGameDisplayText(_ info: SGFGame.Info) -> String {
        let blackPlayer = info.playerBlack ?? "Unknown"
        let whitePlayer = info.playerWhite ?? "Unknown"
        let date = info.date ?? ""

        if !date.isEmpty {
            return "\(blackPlayer) vs \(whitePlayer) · \(date)"
        } else {
            return "\(blackPlayer) vs \(whitePlayer)"
        }
    }
}

struct GameMetadataView: View {
    let gameWrapper: SGFGameWrapper

    var body: some View {
        let game = gameWrapper.game
        let blackPlayer = game.info.playerBlack ?? "—"
        let whitePlayer = game.info.playerWhite ?? "—"
        let result = game.info.result ?? "B+3"
        let filename = gameWrapper.url.lastPathComponent

        VStack(alignment: .leading, spacing: 2) {
            Text("Date: — · Black: \(blackPlayer) · White: \(whitePlayer)")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
            Text("· Result: \(result) · File: \(filename)")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// Move these methods back to SettingsPanelView where they belong
extension SettingsPanelView {
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
    @ObservedObject var gameCacheManager: GameCacheManager
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
                    Text(String(format: "%.1f", localMultiplier * 5.0))  // Display 0-10 scale with .5 increments
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 16)

                Slider(
                    value: Binding(
                        get: { localMultiplier * 5.0 },  // Convert 0-2 to 0-10 for display
                        set: { displayValue in
                            let actualValue = displayValue / 5.0  // Convert 0-10 back to 0-2
                            localMultiplier = actualValue
                            print("🎚️ SLIDER MOVED: display=\(displayValue), actual=\(actualValue), old=\(gameCacheManager.defaultJitterMultiplier)")
                            // Update immediately during dragging for real-time feedback
                            gameCacheManager.defaultJitterMultiplier = CGFloat(actualValue)
                            print("🎚️ SLIDER SET: new value=\(gameCacheManager.defaultJitterMultiplier)")
                        }
                    ),
                    in: 0.0...10.0,
                    step: 0.5  // 0.5 on 0-10 scale = 0.1 on 0-2 scale
                )
                .controlSize(.regular)
                .padding(.horizontal, 16)

                Text("Adjusts how naturally stones are placed off intersections")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
            }
        }
        .onAppear {
            localMultiplier = Double(gameCacheManager.defaultJitterMultiplier)
        }
        .onChange(of: gameCacheManager.defaultJitterMultiplier) { _, newValue in
            localMultiplier = Double(newValue)
        }
    }
}

// COMMENTED OUT: BoardSpacingControlsView (using hard coded spacing values instead)
/*
struct BoardSpacingControlsView: View {
    @ObservedObject var gameCacheManager: GameCacheManager
    @State private var localTopSpace: Double = 2.0
    @State private var localBottomSpace: Double = 4.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Board Spacing")
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 12) {
                // Top Space Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Space Above Board")
                        Spacer()
                        Text(String(format: "%.1f cells", localTopSpace))
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                    Slider(
                        value: Binding(
                            get: { localTopSpace },
                            set: { newValue in
                                localTopSpace = newValue
                                gameCacheManager.topSpaceCellUnits = CGFloat(newValue)
                            }
                        ),
                        in: 0.0...8.0,
                        step: 0.5
                    )
                    .controlSize(.regular)
                    .padding(.horizontal, 16)
                }

                // Bottom Space Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Space Below Board")
                        Spacer()
                        Text(String(format: "%.1f cells", localBottomSpace))
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                    Slider(
                        value: Binding(
                            get: { localBottomSpace },
                            set: { newValue in
                                localBottomSpace = newValue
                                gameCacheManager.bottomSpaceCellUnits = CGFloat(newValue)
                            }
                        ),
                        in: 1.0...10.0,
                        step: 0.5
                    )
                    .controlSize(.regular)
                    .padding(.horizontal, 16)
                }

                Text("Minimum spacing around the board, measured in cell heights")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
            }
        }
        .onAppear {
            localTopSpace = Double(gameCacheManager.topSpaceCellUnits)
            localBottomSpace = Double(gameCacheManager.bottomSpaceCellUnits)
        }
        .onChange(of: gameCacheManager.topSpaceCellUnits) { _, newValue in
            localTopSpace = Double(newValue)
        }
        .onChange(of: gameCacheManager.bottomSpaceCellUnits) { _, newValue in
            localBottomSpace = Double(newValue)
        }
    }
}
*/

// MARK: - Native Search Field
struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = "Type here to search..."
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textFieldDidChange(_:))
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: NativeSearchField

        init(_ parent: NativeSearchField) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: NSTextField) {
            DispatchQueue.main.async {
                self.parent.text = textField.stringValue
                print("🔍 Native field changed: '\(textField.stringValue)'")
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                DispatchQueue.main.async {
                    self.parent.text = textField.stringValue
                    print("🔍 Native field changed (delegate): '\(textField.stringValue)'")
                }
            }
        }
    }
}

// Preview
struct SettingsPanelView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPanelView(
            settingsService: SettingsPanelService(),
            physicsIntegration: PhysicsIntegration(),
            player: SGFPlayer(),
            app: AppModel(),
            onMoveChanged: { index in
                print("Preview move changed to: \(index)")
            }
        )
        .frame(width: 320, height: 600)
    }
}

// MARK: - Array Extension for Progressive Loading
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}