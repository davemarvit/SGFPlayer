// MARK: - UI State ViewModel
// Extracted from ContentView.swift to manage window state, overlays, and transient UI state

import SwiftUI
import Combine
import AppKit

/// ViewModel responsible for UI state, window management, and visual feedback
@MainActor
class UIStateViewModel: ObservableObject {
    // MARK: - Window State
    @Published var showFullscreen: Bool = false
    @Published var isWindowFullscreen: Bool = false
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

    // Mouse tracking timer - only active when needed
    private var mouseTrackingTimer: Timer?

    // MARK: - Initialization
    init() {
        // Don't start mouse tracking timer immediately - start on first mouse move
        setupWindowStateMonitoring()
    }

    // MARK: - Public Interface

    /// Toggle fullscreen mode
    func toggleFullscreen() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.toggleFullScreen(nil)
    }

    /// Enter fullscreen mode
    func enterFullscreen() {
        guard let window = NSApplication.shared.windows.first else { return }
        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }

    /// Exit fullscreen mode
    func exitFullscreen() {
        guard let window = NSApplication.shared.windows.first else { return }
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
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

        if isWindowFullscreen {
            showButtons()
            hideButtonsWithDelay()
        }

        // Start mouse tracking timer if not already running
        startMouseTrackingIfNeeded()
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
        let newDiameter = 20.0 * scaleFactor

        boardStoneDiameter = newDiameter

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
            isFullscreen: isWindowFullscreen,
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
        if isWindowFullscreen {
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

    private func startMouseTrackingIfNeeded() {
        // Only start timer if not already running
        guard mouseTrackingTimer == nil else { return }

        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMouseInactivity()
        }
    }

    private func stopMouseTracking() {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
    }

    private func checkMouseInactivity() {
        let timeSinceLastMove = Date().timeIntervalSince(lastMouseMoveTime)

        if timeSinceLastMove > 0.5 {
            if isMouseMoving {
                isMouseMoving = false
            }
            // Stop timer after period of inactivity to save resources
            if timeSinceLastMove > 2.0 {
                stopMouseTracking()
            }
        }
    }

    private func cancelFadeTimer() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    // MARK: - Window State Monitoring

    private func setupWindowStateMonitoring() {
        NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.onWindowEnteredFullscreen()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.onWindowExitedFullscreen()
                }
            }
            .store(in: &cancellables)
    }

    private func onWindowEnteredFullscreen() {
        isWindowFullscreen = true
        showFullscreen = true
        hideButtonsWithDelay()
    }

    private func onWindowExitedFullscreen() {
        isWindowFullscreen = false
        showFullscreen = false
        showButtons()
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