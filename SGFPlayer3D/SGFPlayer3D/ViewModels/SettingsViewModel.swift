// MARK: - Settings ViewModel
// Extracted from ContentView.swift to centralize all user preferences and settings

import SwiftUI
import Combine

/// ViewModel responsible for all user settings, preferences, and configuration
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Panel State
    @Published var isPanelOpen: Bool = false
    @Published var advancedExpanded: Bool = false

    // MARK: - Playback Settings
    @Published var randomOnStart: Bool = false
    @Published var autoNext: Bool = false
    @Published var randomNext: Bool = false
    @Published var uiMoveDelay: Double = 0.75

    // MARK: - Physics Model Selection
    @Published var activePhysicsModel: Int = 2
    @Published var legacyActivePhysicsModel: Int = 2

    // MARK: - Shadow Settings
    @Published var lidShadowOpacity: Double = 0.30
    @Published var lidShadowRadius: Double = 10
    @Published var lidShadowDX: Double = 5
    @Published var lidShadowDY: Double = 8
    @Published var stoneShadowOpacity: Double = 0.40
    @Published var stoneShadowRadius: Double = 3
    @Published var stoneShadowDX: Double = 2
    @Published var stoneShadowDY: Double = 8

    // MARK: - Physics Parameters (Model 1)
    @Published var m1_repel: Double = 1.60
    @Published var m1_spacing: Double = 2.12
    @Published var m1_centerPullK: Double = 0.0028
    @Published var m1_relaxIters: Int = 12
    @Published var m1_pressureRadiusXR: Double = 2.6
    @Published var m1_pressureKFactor: Double = 0.25
    @Published var m1_maxStepXR: Double = 0.06
    @Published var m1_damping: Double = 0.82
    @Published var m1_wallK: Double = 0.60
    @Published var m1_anim: Double = 0.6
    @Published var m1_stoneStoneK: Double = 0.15
    @Published var m1_stoneLidK: Double = 0.25

    // MARK: - UI Settings
    @Published var debugLayout: Bool = false
    @Published var showPhysicsDemo: Bool = false

    // MARK: - OGS Mode
    @Published var ogsMode: Bool = UserDefaults.standard.bool(forKey: "ogsMode")

    // MARK: - Background Settings
    @Published var backgroundType: BackgroundType = .stars

    // MARK: - AppStorage Synchronization Callbacks
    // These allow ContentView to sync with AppStorage while maintaining separation
    var randomOnStartChanged: ((Bool) -> Void)?
    var autoNextChanged: ((Bool) -> Void)?
    var randomNextChanged: ((Bool) -> Void)?
    var uiMoveDelayChanged: ((Double) -> Void)?
    var activePhysicsModelChanged: ((Int) -> Void)?
    var lidShadowOpacityChanged: ((Double) -> Void)?
    var lidShadowRadiusChanged: ((Double) -> Void)?
    var lidShadowDXChanged: ((Double) -> Void)?
    var lidShadowDYChanged: ((Double) -> Void)?
    var stoneShadowOpacityChanged: ((Double) -> Void)?
    var stoneShadowRadiusChanged: ((Double) -> Void)?
    var stoneShadowDXChanged: ((Double) -> Void)?
    var stoneShadowDYChanged: ((Double) -> Void)?
    var m1_repelChanged: ((Double) -> Void)?
    var m1_spacingChanged: ((Double) -> Void)?
    var m1_centerPullKChanged: ((Double) -> Void)?
    var m1_relaxItersChanged: ((Int) -> Void)?
    var m1_pressureRadiusXRChanged: ((Double) -> Void)?
    var m1_pressureKFactorChanged: ((Double) -> Void)?
    var m1_maxStepXRChanged: ((Double) -> Void)?
    var m1_dampingChanged: ((Double) -> Void)?
    var m1_wallKChanged: ((Double) -> Void)?
    var m1_animChanged: ((Double) -> Void)?
    var m1_stoneStoneKChanged: ((Double) -> Void)?
    var m1_stoneLidKChanged: ((Double) -> Void)?
    var ogsModeChanged: ((Bool) -> Void)?
    var backgroundTypeChanged: ((BackgroundType) -> Void)?

    // MARK: - Initialization
    init() {
        setupPropertyObservers()
    }

    // MARK: - Public Interface

    /// Toggle settings panel visibility
    func togglePanel() {
        isPanelOpen.toggle()
    }

    /// Open settings panel
    func openPanel() {
        isPanelOpen = true
    }

    /// Close settings panel
    func closePanel() {
        isPanelOpen = false
    }

    /// Toggle advanced settings expansion
    func toggleAdvanced() {
        advancedExpanded.toggle()
    }

    /// Reset physics parameters to defaults
    func resetPhysicsToDefaults() {
        m1_repel = 1.60
        m1_spacing = 2.12
        m1_centerPullK = 0.0028
        m1_relaxIters = 12
        m1_pressureRadiusXR = 2.6
        m1_pressureKFactor = 0.25
        m1_maxStepXR = 0.06
        m1_damping = 0.82
        m1_wallK = 0.60
        m1_anim = 0.6
        m1_stoneStoneK = 0.15
        m1_stoneLidK = 0.25
    }

    /// Reset shadow settings to defaults
    func resetShadowsToDefaults() {
        lidShadowOpacity = 0.30
        lidShadowRadius = 10
        lidShadowDX = 5
        lidShadowDY = 8
        stoneShadowOpacity = 0.40
        stoneShadowRadius = 3
        stoneShadowDX = 2
        stoneShadowDY = 8
    }

    /// Get current physics model configuration
    func getCurrentPhysicsConfig() -> PhysicsConfig {
        return PhysicsConfig(
            model: activePhysicsModel,
            repel: m1_repel,
            spacing: m1_spacing,
            centerPullK: m1_centerPullK,
            relaxIters: m1_relaxIters,
            pressureRadiusXR: m1_pressureRadiusXR,
            pressureKFactor: m1_pressureKFactor,
            maxStepXR: m1_maxStepXR,
            damping: m1_damping,
            wallK: m1_wallK,
            anim: m1_anim,
            stoneStoneK: m1_stoneStoneK,
            stoneLidK: m1_stoneLidK
        )
    }

    /// Get current shadow configuration
    func getCurrentShadowConfig() -> ShadowConfig {
        return ShadowConfig(
            lidOpacity: lidShadowOpacity,
            lidRadius: lidShadowRadius,
            lidDX: lidShadowDX,
            lidDY: lidShadowDY,
            stoneOpacity: stoneShadowOpacity,
            stoneRadius: stoneShadowRadius,
            stoneDX: stoneShadowDX,
            stoneDY: stoneShadowDY
        )
    }

    // MARK: - AppStorage Synchronization

    /// Sync with AppStorage values (called from ContentView)
    func syncWithAppStorage(
        randomOnStart: Bool,
        autoNext: Bool,
        randomNext: Bool,
        uiMoveDelay: Double,
        activePhysicsModel: Int,
        lidShadowOpacity: Double,
        lidShadowRadius: Double,
        lidShadowDX: Double,
        lidShadowDY: Double,
        stoneShadowOpacity: Double,
        stoneShadowRadius: Double,
        stoneShadowDX: Double,
        stoneShadowDY: Double,
        m1_repel: Double,
        m1_spacing: Double,
        m1_centerPullK: Double,
        m1_relaxIters: Int,
        m1_pressureRadiusXR: Double,
        m1_pressureKFactor: Double,
        m1_maxStepXR: Double,
        m1_damping: Double,
        m1_wallK: Double,
        m1_anim: Double,
        m1_stoneStoneK: Double,
        m1_stoneLidK: Double
    ) {
        self.randomOnStart = randomOnStart
        self.autoNext = autoNext
        self.randomNext = randomNext
        self.uiMoveDelay = uiMoveDelay
        self.activePhysicsModel = activePhysicsModel
        self.lidShadowOpacity = lidShadowOpacity
        self.lidShadowRadius = lidShadowRadius
        self.lidShadowDX = lidShadowDX
        self.lidShadowDY = lidShadowDY
        self.stoneShadowOpacity = stoneShadowOpacity
        self.stoneShadowRadius = stoneShadowRadius
        self.stoneShadowDX = stoneShadowDX
        self.stoneShadowDY = stoneShadowDY
        self.m1_repel = m1_repel
        self.m1_spacing = m1_spacing
        self.m1_centerPullK = m1_centerPullK
        self.m1_relaxIters = m1_relaxIters
        self.m1_pressureRadiusXR = m1_pressureRadiusXR
        self.m1_pressureKFactor = m1_pressureKFactor
        self.m1_maxStepXR = m1_maxStepXR
        self.m1_damping = m1_damping
        self.m1_wallK = m1_wallK
        self.m1_anim = m1_anim
        self.m1_stoneStoneK = m1_stoneStoneK
        self.m1_stoneLidK = m1_stoneLidK
    }

    // MARK: - Private Implementation

    private func setupPropertyObservers() {
        // Setup observers for all published properties to sync with AppStorage
        setupPlaybackObservers()
        setupPhysicsObservers()
        setupShadowObservers()
    }

    private func setupPlaybackObservers() {
        $randomOnStart
            .dropFirst()
            .sink { [weak self] value in
                self?.randomOnStartChanged?(value)
            }
            .store(in: &cancellables)

        $autoNext
            .dropFirst()
            .sink { [weak self] value in
                self?.autoNextChanged?(value)
            }
            .store(in: &cancellables)

        $randomNext
            .dropFirst()
            .sink { [weak self] value in
                self?.randomNextChanged?(value)
            }
            .store(in: &cancellables)

        $uiMoveDelay
            .dropFirst()
            .sink { [weak self] value in
                self?.uiMoveDelayChanged?(value)
            }
            .store(in: &cancellables)
    }

    private func setupPhysicsObservers() {
        $activePhysicsModel
            .dropFirst()
            .sink { [weak self] value in
                self?.activePhysicsModelChanged?(value)
                self?.notifyPhysicsModelChanged(value)
            }
            .store(in: &cancellables)

        // Setup observers for all physics parameters
        $m1_repel.dropFirst().sink { [weak self] in self?.m1_repelChanged?($0) }.store(in: &cancellables)
        $m1_spacing.dropFirst().sink { [weak self] in self?.m1_spacingChanged?($0) }.store(in: &cancellables)
        $m1_centerPullK.dropFirst().sink { [weak self] in self?.m1_centerPullKChanged?($0) }.store(in: &cancellables)
        $m1_relaxIters.dropFirst().sink { [weak self] in self?.m1_relaxItersChanged?($0) }.store(in: &cancellables)
        $m1_pressureRadiusXR.dropFirst().sink { [weak self] in self?.m1_pressureRadiusXRChanged?($0) }.store(in: &cancellables)
        $m1_pressureKFactor.dropFirst().sink { [weak self] in self?.m1_pressureKFactorChanged?($0) }.store(in: &cancellables)
        $m1_maxStepXR.dropFirst().sink { [weak self] in self?.m1_maxStepXRChanged?($0) }.store(in: &cancellables)
        $m1_damping.dropFirst().sink { [weak self] in self?.m1_dampingChanged?($0) }.store(in: &cancellables)
        $m1_wallK.dropFirst().sink { [weak self] in self?.m1_wallKChanged?($0) }.store(in: &cancellables)
        $m1_anim.dropFirst().sink { [weak self] in self?.m1_animChanged?($0) }.store(in: &cancellables)
        $m1_stoneStoneK.dropFirst().sink { [weak self] in self?.m1_stoneStoneKChanged?($0) }.store(in: &cancellables)
        $m1_stoneLidK.dropFirst().sink { [weak self] in self?.m1_stoneLidKChanged?($0) }.store(in: &cancellables)

        // OGS Mode
        $ogsMode.dropFirst().sink { [weak self] value in
            // Persist to UserDefaults
            UserDefaults.standard.set(value, forKey: "ogsMode")
            self?.ogsModeChanged?(value)
        }.store(in: &cancellables)

        // Background Type
        $backgroundType.dropFirst().sink { [weak self] in self?.backgroundTypeChanged?($0) }.store(in: &cancellables)
    }

    private func setupShadowObservers() {
        $lidShadowOpacity.dropFirst().sink { [weak self] in self?.lidShadowOpacityChanged?($0) }.store(in: &cancellables)
        $lidShadowRadius.dropFirst().sink { [weak self] in self?.lidShadowRadiusChanged?($0) }.store(in: &cancellables)
        $lidShadowDX.dropFirst().sink { [weak self] in self?.lidShadowDXChanged?($0) }.store(in: &cancellables)
        $lidShadowDY.dropFirst().sink { [weak self] in self?.lidShadowDYChanged?($0) }.store(in: &cancellables)
        $stoneShadowOpacity.dropFirst().sink { [weak self] in self?.stoneShadowOpacityChanged?($0) }.store(in: &cancellables)
        $stoneShadowRadius.dropFirst().sink { [weak self] in self?.stoneShadowRadiusChanged?($0) }.store(in: &cancellables)
        $stoneShadowDX.dropFirst().sink { [weak self] in self?.stoneShadowDXChanged?($0) }.store(in: &cancellables)
        $stoneShadowDY.dropFirst().sink { [weak self] in self?.stoneShadowDYChanged?($0) }.store(in: &cancellables)
    }

    private func notifyPhysicsModelChanged(_ model: Int) {
        NotificationCenter.default.post(
            name: .physicsModelChanged,
            object: nil,
            userInfo: ["model": model]
        )
    }

    // MARK: - Combine Support
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Configuration Structures

struct PhysicsConfig {
    let model: Int
    let repel: Double
    let spacing: Double
    let centerPullK: Double
    let relaxIters: Int
    let pressureRadiusXR: Double
    let pressureKFactor: Double
    let maxStepXR: Double
    let damping: Double
    let wallK: Double
    let anim: Double
    let stoneStoneK: Double
    let stoneLidK: Double
}

struct ShadowConfig {
    let lidOpacity: Double
    let lidRadius: Double
    let lidDX: Double
    let lidDY: Double
    let stoneOpacity: Double
    let stoneRadius: Double
    let stoneDX: Double
    let stoneDY: Double
}

// MARK: - Background Type

enum BackgroundType: Int, CaseIterable {
    case stars = 0
    case hdri = 1
    case solid = 2
}

// MARK: - Notifications

extension Notification.Name {
    static let physicsModelChanged = Notification.Name("physicsModelChanged")
}