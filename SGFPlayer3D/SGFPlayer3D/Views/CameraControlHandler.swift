// MARK: - CameraControlHandler
// Helper view to capture all camera control events
//
// Extracted from ContentView3D.swift (Phase 4 Step 2)
// Handles mouse drag (rotate/pan), scroll wheel (zoom), and pinch-to-zoom gestures

import SwiftUI
import AppKit

struct CameraControlHandler: NSViewRepresentable {
    @Binding var rotationX: Float
    @Binding var rotationY: Float
    @Binding var distance: CGFloat
    @Binding var panX: CGFloat
    @Binding var panY: CGFloat
    let sceneManager: SceneManager3D

    func makeNSView(context: Context) -> NSView {
        let view = CameraControlView()
        view.rotationX = rotationX
        view.rotationY = rotationY
        view.distance = distance
        view.panX = panX
        view.panY = panY
        view.sceneManager = sceneManager
        view.onUpdate = { rotX, rotY, dist, pX, pY in
            DispatchQueue.main.async {
                self.rotationX = rotX
                self.rotationY = rotY
                self.distance = dist
                self.panX = pX
                self.panY = pY
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let controlView = nsView as? CameraControlView {
            controlView.rotationX = rotationX
            controlView.rotationY = rotationY
            controlView.distance = distance
            controlView.panX = panX
            controlView.panY = panY
        }
    }

    class CameraControlView: NSView {
        var rotationX: Float = 0
        var rotationY: Float = 0
        var distance: CGFloat = 25
        var panX: CGFloat = 0
        var panY: CGFloat = 0
        var sceneManager: SceneManager3D?
        var onUpdate: ((Float, Float, CGFloat, CGFloat, CGFloat) -> Void)?

        private var lastDragPoint: NSPoint = .zero
        private var magnification: CGFloat = 1.0

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            // Accept mouse events but allow them to pass through when not handled
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func mouseDown(with event: NSEvent) {
            // If we reach here, hitTest already filtered for Cmd/Shift held
            NSLog("DEBUG3D: 🎥 Camera control mode - starting drag")
        }

        override func mouseDragged(with event: NSEvent) {
            // hitTest ensures we only get here with Cmd or Shift held
            let isShiftPressed = event.modifierFlags.contains(.shift)
            let isCommandPressed = event.modifierFlags.contains(.command)

            if isShiftPressed && !isCommandPressed {
                // Shift alone = Pan mode
                let panSensitivity: CGFloat = 0.02
                panX -= event.deltaX * panSensitivity  // Negate for correct direction
                panY += event.deltaY * panSensitivity

                sceneManager?.updateCameraPosition(
                    distance: distance,
                    rotationX: rotationX,
                    rotationY: rotationY,
                    panX: panX,
                    panY: panY
                )
            } else if isCommandPressed {
                // Command (with or without Shift) = Rotate mode
                let sensitivity: CGFloat = 0.005
                rotationY -= Float(event.deltaX * sensitivity)  // Negate for correct direction
                rotationX -= Float(event.deltaY * sensitivity)  // Negate for correct direction

                sceneManager?.pivotNode.eulerAngles.y = CGFloat(rotationY)
                sceneManager?.pivotNode.eulerAngles.x = CGFloat(rotationX)
            }

            onUpdate?(rotationX, rotationY, distance, panX, panY)
        }

        override func scrollWheel(with event: NSEvent) {
            // Zoom with scroll wheel
            let zoomSensitivity: CGFloat = 0.5
            distance -= event.scrollingDeltaY * zoomSensitivity
            distance = max(10, min(100, distance))

            sceneManager?.updateCameraPosition(
                distance: distance,
                rotationX: rotationX,
                rotationY: rotationY,
                panX: panX,
                panY: panY
            )

            onUpdate?(rotationX, rotationY, distance, panX, panY)
        }

        override func magnify(with event: NSEvent) {
            // Pinch to zoom
            distance /= (1.0 + event.magnification)
            distance = max(10, min(100, distance))

            sceneManager?.updateCameraPosition(
                distance: distance,
                rotationX: rotationX,
                rotationY: rotationY,
                panX: panX,
                panY: panY
            )

            onUpdate?(rotationX, rotationY, distance, panX, panY)
        }

        override var acceptsFirstResponder: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // Only capture events if Command or Shift is held (for camera control)
            // Otherwise return nil to let events pass through to SwiftUI board interaction
            let modifiers = NSEvent.modifierFlags
            if modifiers.contains(.command) || modifiers.contains(.shift) {
                return self
            }
            // Pass through for normal clicks (board interaction)
            return nil
        }
    }
}
