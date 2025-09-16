// MARK: - UI State ViewModel
// Extracted from ContentView.swift to manage window state, overlays, and transient UI state

import SwiftUI
import Combine

/// ViewModel responsible for UI state, window management, and visual feedback
@MainActor
class UIStateViewModel: ObservableObject {
    // MARK: - Window State
    @Published var showFullscreen: Bool = false
    @Published var buttonsVisible: Bool = true
    @Published var fadeTimer: Timer? = nil

    // MARK: - Board Positioning
    @Published var actualUlCenter: CGPoint = CGPoint(x: 150, y: 150)
    @Published var actualLrCenter: CGPoint = CGPoint(x: 650, y: 450)
    @Published var actualBowlRadius: CGFloat = 100.0
    @Published var currentBowlRadius: CGFloat = 100.0
    @Published var boardStoneDiameter: CGFloat = 20.0

    // MARK: - Animation and Visual State
    @Published var showPhysicsDemo: Bool = false
    @Published var debugLayout: Bool = false

    // MARK: - Input State
    @Published var isMouseMoving: Bool = false
    @Published var lastMouseMoveTime: Date = Date()

    // MARK: - Initialization
    init() {
        setupMouseTracking()
    }

    // MARK: - Public Interface

    /// Toggle fullscreen mode
    func toggleFullscreen() {
        showFullscreen.toggle()

        if showFullscreen {
            hideButtonsWithDelay()
        } else {
            showButtons()
        }
    }

    /// Enter fullscreen mode
    func enterFullscreen() {
        showFullscreen = true
        hideButtonsWithDelay()
    }

    /// Exit fullscreen mode
    func exitFullscreen() {
        showFullscreen = false
        showButtons()
    }

    /// Toggle physics demo visualization
    func togglePhysicsDemo() {
        showPhysicsDemo.toggle()
    }

    /// Toggle debug layout visualization
    func toggleDebugLayout() {
        debugLayout.toggle()
    }

    /// Update bowl positioning (called from GameBoardView)
    func updateBowlPositions(
        ulCenter: CGPoint,
        lrCenter: CGPoint,
        radius: CGFloat
    ) {
        actualUlCenter = ulCenter
        actualLrCenter = lrCenter
        actualBowlRadius = radius
        currentBowlRadius = radius
    }

    /// Handle mouse movement for button visibility
    func handleMouseMove() {
        lastMouseMoveTime = Date()
        isMouseMoving = true

        if showFullscreen {
            showButtons()
            hideButtonsWithDelay()
        }

        // Reset mouse moving flag after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isMouseMoving = false
        }
    }

    /// Show UI buttons
    func showButtons() {
        buttonsVisible = true
        cancelFadeTimer()
    }

    /// Hide UI buttons immediately
    func hideButtons() {
        buttonsVisible = false
        cancelFadeTimer()
    }

    /// Hide buttons with delay (for fullscreen mode)
    func hideButtonsWithDelay() {
        cancelFadeTimer()

        fadeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.buttonsVisible = false
            }
        }
    }

    /// Handle window resize
    func handleWindowResize(_ newSize: CGSize) {
        // Adjust board stone diameter based on window size
        let baseSize: CGFloat = 800
        let scaleFactor = min(newSize.width, newSize.height) / baseSize
        boardStoneDiameter = max(15.0, min(30.0, 20.0 * scaleFactor))

        // Notify observers of size change
        NotificationCenter.default.post(
            name: .windowSizeChanged,
            object: nil,
            userInfo: ["size": newSize]
        )
    }

    /// Get current window state for layout calculations
    func getWindowState() -> WindowState {
        return WindowState(
            isFullscreen: showFullscreen,
            buttonsVisible: buttonsVisible,
            debugLayout: debugLayout,
            boardStoneDiameter: boardStoneDiameter,
            bowlRadius: actualBowlRadius
        )
    }

    /// Calculate metadata bar position
    func calculateMetadataPosition(in geometry: GeometryProxy) -> CGFloat {
        let boardSize = min(geometry.size.width, geometry.size.height) * 0.8
        let boardBottom = (geometry.size.height + boardSize) / 2
        let windowBottom = geometry.size.height
        let metadataY = boardBottom + (windowBottom - boardBottom) / 2
        return metadataY
    }

    // MARK: - Keyboard Shortcuts

    /// Handle escape key (exit fullscreen)
    func handleEscapeKey() {
        if showFullscreen {
            exitFullscreen()
        }
    }

    /// Handle F key (toggle fullscreen)
    func handleFullscreenKey() {
        toggleFullscreen()
    }

    /// Handle D key (toggle debug)
    func handleDebugKey() {
        toggleDebugLayout()
    }

    // MARK: - Private Implementation

    private func setupMouseTracking() {
        // Set up timer to track mouse inactivity
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMouseInactivity()
        }
    }

    private func checkMouseInactivity() {
        let timeSinceLastMove = Date().timeIntervalSince(lastMouseMoveTime)

        if timeSinceLastMove > 0.5 {
            isMouseMoving = false
        }
    }

    private func cancelFadeTimer() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    // MARK: - Combine Support
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - State Structures

struct WindowState {
    let isFullscreen: Bool
    let buttonsVisible: Bool
    let debugLayout: Bool
    let boardStoneDiameter: CGFloat
    let bowlRadius: CGFloat
}

// MARK: - Notifications

extension Notification.Name {
    static let windowSizeChanged = Notification.Name("windowSizeChanged")
}

// MARK: - Key Handling Extensions

extension UIStateViewModel {
    /// Handle key press events
    func handleKeyPress(_ key: String) {
        switch key {
        case "Escape":
            handleEscapeKey()
        case "f", "F":
            handleFullscreenKey()
        case "d", "D":
            handleDebugKey()
        default:
            break
        }
    }
}