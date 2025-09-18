// MARK: - Physics ViewModel
// Extracted from ContentView.swift to manage stone positioning, animation, and physics integration

import SwiftUI
import Combine

/// ViewModel responsible for physics integration, stone positioning, and layout caching
@MainActor
class PhysicsViewModel: ObservableObject {
    // MARK: - Physics Integration
    @Published var physicsIntegration = PhysicsIntegration()
    @Published var activePhysicsModel: Int = 2

    // MARK: - Layout Caching
    @Published var layoutAtMove: [Int: LidLayout] = [:]

    // MARK: - Stone Positioning
    @Published var capturedStones: [CapturedStone] = []

    // MARK: - Physics State
    @Published var isPhysicsEnabled: Bool = true
    @Published var isAnimating: Bool = false

    // MARK: - Performance Monitoring
    @Published var lastUpdateTime: Date = Date()
    @Published var updateDuration: TimeInterval = 0
    @Published var stoneCount: Int = 0

    // MARK: - Initialization
    init() {
        setupPhysicsBindings()
        setupNotificationObservers()
    }

    // MARK: - Public Interface

    /// Update physics for current move
    func updatePhysics(
        moveIndex: Int,
        gameGrid: [[Stone?]],
        captures: (whiteByBlack: Int, blackByWhite: Int)
    ) {
        let startTime = Date()

        // Cache layout for this move if not already cached
        if layoutAtMove[moveIndex] == nil {
            calculateAndCacheLayout(moveIndex: moveIndex, grid: gameGrid, captures: captures)
        }

        // Update physics integration
        physicsIntegration.updateForMove(moveIndex, grid: gameGrid)

        // Update captured stones
        updateCapturedStones(captures: captures, moveIndex: moveIndex)

        // Record performance metrics
        updateDuration = Date().timeIntervalSince(startTime)
        lastUpdateTime = Date()
        stoneCount = countStonesInGrid(gameGrid)
    }

    /// Force recalculate physics for current state
    func recalculatePhysics(
        moveIndex: Int,
        gameGrid: [[Stone?]],
        captures: (whiteByBlack: Int, blackByWhite: Int)
    ) {
        // Clear cached layout to force recalculation
        layoutAtMove.removeValue(forKey: moveIndex)

        // Update with fresh calculation
        updatePhysics(moveIndex: moveIndex, gameGrid: gameGrid, captures: captures)
    }

    /// Get cached layout for a specific move
    func getLayoutForMove(_ moveIndex: Int) -> LidLayout? {
        return layoutAtMove[moveIndex]
    }

    /// Switch physics model
    func switchPhysicsModel(_ newModel: Int) {
        guard newModel != activePhysicsModel else { return }

        activePhysicsModel = newModel
        physicsIntegration.switchModel(newModel)

        // Clear all cached layouts when model changes
        clearLayoutCache()

        // Notify observers
        NotificationCenter.default.post(
            name: .physicsModelChanged,
            object: nil,
            userInfo: ["model": newModel]
        )
    }

    /// Clear all cached physics data
    func clearLayoutCache() {
        layoutAtMove.removeAll()
    }

    /// Reset physics to initial state
    func resetPhysics() {
        clearLayoutCache()
        capturedStones.removeAll()
        physicsIntegration.reset()
        isAnimating = false
    }

    /// Enable/disable physics processing
    func setPhysicsEnabled(_ enabled: Bool) {
        isPhysicsEnabled = enabled
        physicsIntegration.setEnabled(enabled)
    }

    /// Get current physics performance metrics
    func getPerformanceMetrics() -> PhysicsPerformanceMetrics {
        return PhysicsPerformanceMetrics(
            lastUpdateTime: lastUpdateTime,
            updateDuration: updateDuration,
            stoneCount: stoneCount,
            cachedMoves: layoutAtMove.count,
            activeModel: activePhysicsModel,
            isEnabled: isPhysicsEnabled
        )
    }

    // MARK: - Physics Configuration

    /// Update physics parameters
    func updatePhysicsParameters(_ config: PhysicsConfig) {
        physicsIntegration.updateParameters(config)

        // Clear cache when parameters change
        clearLayoutCache()
    }

    /// Apply physics parameters from settings
    func applyPhysicsSettings(from settings: SettingsViewModel) {
        let config = settings.getCurrentPhysicsConfig()
        updatePhysicsParameters(config)

        if settings.activePhysicsModel != activePhysicsModel {
            switchPhysicsModel(settings.activePhysicsModel)
        }
    }

    // MARK: - Private Implementation

    private func setupPhysicsBindings() {
        // Bind physics integration changes
        physicsIntegration.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func setupNotificationObservers() {
        // Listen for game state changes
        NotificationCenter.default.publisher(for: .gameStateChanged)
            .sink { [weak self] notification in
                if let moveIndex = notification.userInfo?["moveIndex"] as? Int {
                    self?.handleGameStateChange(moveIndex: moveIndex)
                }
            }
            .store(in: &cancellables)

        // Listen for physics model changes from settings
        NotificationCenter.default.publisher(for: .physicsModelChanged)
            .sink { [weak self] notification in
                if let model = notification.userInfo?["model"] as? Int {
                    self?.switchPhysicsModel(model)
                }
            }
            .store(in: &cancellables)
    }

    private func handleGameStateChange(moveIndex: Int) {
        // This will be called when SGFPlayerViewModel changes moves
        // We'll need to get game data from the player
        DispatchQueue.main.async {
            // The actual grid and captures will be provided by ContentView
            // This is just to mark that we need an update
            self.objectWillChange.send()
        }
    }

    private func calculateAndCacheLayout(
        moveIndex: Int,
        grid: [[Stone?]],
        captures: (whiteByBlack: Int, blackByWhite: Int)
    ) {
        // Calculate stone positions using current physics model
        let layout = physicsIntegration.calculateLayout(
            grid: grid,
            captures: captures,
            moveIndex: moveIndex
        )

        // Cache the result
        layoutAtMove[moveIndex] = layout
    }

    private func updateCapturedStones(
        captures: (whiteByBlack: Int, blackByWhite: Int),
        moveIndex: Int
    ) {
        // Update captured stones collection based on captures
        let totalCaptured = captures.whiteByBlack + captures.blackByWhite

        // Ensure we have the right number of captured stone objects
        while capturedStones.count < totalCaptured {
            let isWhite = capturedStones.filter { $0.isWhite }.count < captures.whiteByBlack
            let stone = CapturedStone(
                isWhite: isWhite,
                imageName: isWhite ? "white_stone" : "black_stone"
            )
            capturedStones.append(stone)
        }

        // Remove excess stones if captures decreased
        if capturedStones.count > totalCaptured {
            capturedStones = Array(capturedStones.prefix(totalCaptured))
        }

        // Update positions using cached layout if available
        if let layout = layoutAtMove[moveIndex] {
            updateCapturedStonePositions(layout: layout)
        }
    }

    private func updateCapturedStonePositions(layout: LidLayout) {
        // Update black stones
        let blackStones = capturedStones.filter { !$0.isWhite }
        for (index, stone) in blackStones.enumerated() {
            if index < layout.blackStones.count {
                stone.pos = layout.blackStones[index]
            }
        }

        // Update white stones
        let whiteStones = capturedStones.filter { $0.isWhite }
        for (index, stone) in whiteStones.enumerated() {
            if index < layout.whiteStones.count {
                stone.pos = layout.whiteStones[index]
            }
        }
    }

    private func countStonesInGrid(_ grid: [[Stone?]]) -> Int {
        return grid.flatMap { $0 }.compactMap { $0 }.count
    }

    // MARK: - Combine Support
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Performance Metrics

struct PhysicsPerformanceMetrics {
    let lastUpdateTime: Date
    let updateDuration: TimeInterval
    let stoneCount: Int
    let cachedMoves: Int
    let activeModel: Int
    let isEnabled: Bool

    var updatesPerSecond: Double {
        guard updateDuration > 0 else { return 0 }
        return 1.0 / updateDuration
    }

    var cacheHitRatio: Double {
        guard stoneCount > 0 else { return 0 }
        return Double(cachedMoves) / Double(stoneCount)
    }
}

// MARK: - Legacy Compatibility

extension PhysicsViewModel {
    /// Get captured stone positions for legacy bowl rendering
    func getCapturedStonePositions() -> (black: [CGPoint], white: [CGPoint]) {
        let blackPositions = capturedStones.filter { !$0.isWhite }.map { $0.pos }
        let whitePositions = capturedStones.filter { $0.isWhite }.map { $0.pos }
        return (black: blackPositions, white: whitePositions)
    }

    /// Update from legacy layout format
    func updateFromLegacyLayout(_ layout: LidLayout, moveIndex: Int) {
        layoutAtMove[moveIndex] = layout
        updateCapturedStonePositions(layout: layout)
    }
}