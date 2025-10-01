// MARK: - Physics Integration Demo
// Demonstrates how the new architecture fixes stone clustering issues

import SwiftUI
import Foundation

/// Practical demonstration showing stone clustering resolution
struct PhysicsIntegrationDemo: View {
    
    @StateObject private var physicsIntegration = PhysicsIntegration()
    @State private var currentMove: Int = 1
    @State private var showDiagnostics = false
    @State private var simulationTimer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Stone Clustering Fix Demonstration")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Status and controls
            VStack {
                Text(physicsIntegration.physicsStatus)
                    .foregroundColor(.green)
                    .font(.headline)
                
                HStack {
                    Button("Start Game Simulation") {
                        startGameSimulation()
                    }
                    .disabled(simulationTimer != nil)
                    
                    Button("Stop Simulation") {
                        stopGameSimulation()
                    }
                    .disabled(simulationTimer == nil)
                    
                    Button("Reset") {
                        resetDemo()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Physics model selection
            VStack {
                Text("Active Physics Model")
                    .font(.headline)
                
                Picker("Physics Model", selection: $physicsIntegration.activePhysicsModel) {
                    ForEach(physicsIntegration.availableModels, id: \.index) { model in
                        Text("\(model.index): \(model.name)").tag(model.index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: physicsIntegration.activePhysicsModel) { _, newModel in
                    // Force recalculation when physics model changes
                    physicsIntegration.forceRecalculation()
                    
                    // Update positions immediately
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        updateCurrentPositions()
                    }
                }
            }
            
            // Stone bowls visualization
            HStack(spacing: 40) {
                // Black stones bowl (captured by white - upper left)
                VStack {
                    Text("Black Stones: \(physicsIntegration.blackStones.count)")
                        .font(.headline)
                    Text("(Captured by White)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        // Bowl visualization - LARGER for better visibility
                        Circle()
                            .stroke(Color.brown, lineWidth: 3)
                            .fill(Color.brown.opacity(0.1))
                            .frame(width: 300, height: 300)
                        
                        // Stone positions - LARGER stones with better spread
                        ForEach(physicsIntegration.blackStones, id: \.id) { stone in
                            Circle()
                                .fill(Color.black)
                                .frame(width: 24, height: 24) // Bigger stones
                                .position(
                                    x: 150 + (stone.pos.x - 100) * 1.2, // Larger bowl center + more spread
                                    y: 150 + (stone.pos.y - 100) * 1.2
                                )
                        }
                        
                        // Center reference
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                            .position(x: 150, y: 150)
                    }
                    .frame(width: 300, height: 300)
                }
                
                // White stones bowl (captured by black - lower right)
                VStack {
                    Text("White Stones: \(physicsIntegration.whiteStones.count)")
                        .font(.headline)
                    Text("(Captured by Black)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        // Bowl visualization - LARGER for better visibility
                        Circle()
                            .stroke(Color.gray, lineWidth: 3)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 300, height: 300)
                        
                        // Stone positions - LARGER stones with better spread
                        ForEach(physicsIntegration.whiteStones, id: \.id) { stone in
                            Circle()
                                .fill(Color.white)
                                .stroke(Color.black, lineWidth: 1)
                                .frame(width: 24, height: 24) // Bigger stones
                                .position(
                                    x: 150 + (stone.pos.x - 300) * 0.8, // Better spread for white stones
                                    y: 150 + (stone.pos.y - 300) * 0.8
                                )
                        }
                        
                        // Center reference
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                            .position(x: 150, y: 150)
                    }
                    .frame(width: 300, height: 300)
                }
            }
            
            // Diagnostic information
            if showDiagnostics {
                VStack(alignment: .leading) {
                    Text("Diagnostic Information")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Move: \(currentMove)")
                            Text("Architecture: New Modular Physics")
                            Text(physicsIntegration.getDiagnosticInfo())
                            
                            Button("📋 Copy All Diagnostics") {
                                copyDiagnostics()
                            }
                            .font(.caption)
                            .padding(.vertical, 4)
                            
                            if !physicsIntegration.blackStones.isEmpty {
                                Text("Black Stone Positions:")
                                    .fontWeight(.semibold)
                                ForEach(physicsIntegration.blackStones.prefix(8), id: \.id) { stone in
                                    Text("  • (\(String(format: "%.1f", stone.pos.x)), \(String(format: "%.1f", stone.pos.y)))")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                if physicsIntegration.blackStones.count > 8 {
                                    Text("  ... and \(physicsIntegration.blackStones.count - 8) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !physicsIntegration.whiteStones.isEmpty {
                                Text("White Stone Positions:")
                                    .fontWeight(.semibold)
                                ForEach(physicsIntegration.whiteStones.prefix(8), id: \.id) { stone in
                                    Text("  • (\(String(format: "%.1f", stone.pos.x)), \(String(format: "%.1f", stone.pos.y)))")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                if physicsIntegration.whiteStones.count > 8 {
                                    Text("  ... and \(physicsIntegration.whiteStones.count - 8) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            Text("Key Improvements:")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Text("✅ Physics models actually execute (no cache bypass)")
                                .font(.caption)
                            Text("✅ Proper seed differentiation prevents identical positioning")
                                .font(.caption)
                            Text("✅ Energy minimization prevents stone clustering")
                                .font(.caption)
                            Text("✅ Clean cache invalidation on model changes")
                                .font(.caption)
                            Text("✅ Modular architecture enables reliable physics")
                                .font(.caption)
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Toggle diagnostics
            Button(showDiagnostics ? "Hide Diagnostics" : "Show Diagnostics") {
                showDiagnostics.toggle()
            }
            .font(.caption)
        }
        .padding()
        .onAppear {
            initializeDemo()
        }
        .onDisappear {
            stopGameSimulation()
        }
    }
    
    private func initializeDemo() {
        // Initialize with a mock SGF player
        let mockPlayer = SGFPlayer()
        physicsIntegration.initializeWithGame(mockPlayer)
        
        // Set initial game state to show some stones
        physicsIntegration.updateStonePositions(
            currentMove: 1,
            blackStoneCount: 0,
            whiteStoneCount: 0,
            bowlRadius: 100,
            gameSeed: 12345,
            ulCenter: CGPoint(x: 100, y: 100),
            lrCenter: CGPoint(x: 300, y: 300)
        )
    }
    
    private func startGameSimulation() {
        currentMove = 1
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            simulateNextMove()
        }
    }
    
    private func simulateNextMove() {
        currentMove += 1
        
        // Simulate captures happening during game
        let blackCaptured = min(currentMove / 3, 12) // Gradual captures
        let whiteCaptured = min(currentMove / 4, 10)
        
        // Update with different seed each time to show position variety
        physicsIntegration.updateStonePositions(
            currentMove: currentMove,
            blackStoneCount: blackCaptured,
            whiteStoneCount: whiteCaptured,
            bowlRadius: 100,
            gameSeed: UInt64(12345 + currentMove * 1000), // Different seed each move
            ulCenter: CGPoint(x: 100, y: 100),
            lrCenter: CGPoint(x: 300, y: 300)
        )
        
        // Stop after reasonable number of moves
        if currentMove > 20 {
            stopGameSimulation()
        }
    }
    
    private func stopGameSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
    
    private func resetDemo() {
        stopGameSimulation()
        currentMove = 1
        physicsIntegration.reset()
        initializeDemo()
    }
    
    private func updateCurrentPositions() {
        // Force update with current stone counts
        let blackCount = physicsIntegration.blackStones.count
        let whiteCount = physicsIntegration.whiteStones.count
        
        physicsIntegration.updateStonePositions(
            currentMove: currentMove,
            blackStoneCount: blackCount,
            whiteStoneCount: whiteCount,
            bowlRadius: 100,
            gameSeed: UInt64(12345 + currentMove * 1000),
            ulCenter: CGPoint(x: 100, y: 100),
            lrCenter: CGPoint(x: 300, y: 300)
        )
    }
    
    private func copyDiagnostics() {
        var diagnostics = "SGF Player Physics Diagnostics\n"
        diagnostics += "Move: \(currentMove)\n"
        diagnostics += "Architecture: New Modular Physics\n"
        diagnostics += "\(physicsIntegration.getDiagnosticInfo())\n\n"
        
        if !physicsIntegration.blackStones.isEmpty {
            diagnostics += "Black Stone Positions:\n"
            for stone in physicsIntegration.blackStones {
                diagnostics += "  • (\(String(format: "%.1f", stone.pos.x)), \(String(format: "%.1f", stone.pos.y)))\n"
            }
            diagnostics += "\n"
        }
        
        if !physicsIntegration.whiteStones.isEmpty {
            diagnostics += "White Stone Positions:\n"
            for stone in physicsIntegration.whiteStones {
                diagnostics += "  • (\(String(format: "%.1f", stone.pos.x)), \(String(format: "%.1f", stone.pos.y)))\n"
            }
        }
        
        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
    }
}

// MARK: - Preview
struct PhysicsIntegrationDemo_Previews: PreviewProvider {
    static var previews: some View {
        PhysicsIntegrationDemo()
            .frame(width: 800, height: 900)
    }
}