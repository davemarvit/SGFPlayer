// MARK: - Minimal Test Screensaver
// Simple test to verify screensaver framework compatibility on macOS Sequoia v15.5

import ScreenSaver
import Cocoa

@objc(TestScreensaver)
class TestScreensaver: ScreenSaverView {

    private var boxX: CGFloat = 50
    private var boxY: CGFloat = 50
    private var boxVelocityX: CGFloat = 2
    private var boxVelocityY: CGFloat = 3
    private var boxSize: CGFloat = 50
    private var frameCount: Int = 0

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

        // Configure for both preview and fullscreen
        self.wantsLayer = false  // Force non-layer backed
        self.animationTimeInterval = 1.0/30.0 // 30 FPS for compatibility

        // Start in center
        boxX = frame.width / 2 - boxSize / 2
        boxY = frame.height / 2 - boxSize / 2

        print("🔄 TestScreensaver: Initialized with frame \(frame), isPreview: \(isPreview)")

        // Force immediate layout
        self.needsDisplay = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented for screensaver")
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)

        print("🎨 TestScreensaver: Starting draw for frame \(frameCount), rect: \(rect)")

        // Try multiple ways to get graphics context
        var context: CGContext?

        if let cgContext = NSGraphicsContext.current?.cgContext {
            context = cgContext
            print("✅ Got CGContext from NSGraphicsContext.current")
        } else {
            // Fallback - create our own context
            print("⚠️ No current graphics context, creating fallback")
            NSGraphicsContext.saveGraphicsState()

            // Use NSView's lockFocus method for direct drawing
            self.lockFocus()
            context = NSGraphicsContext.current?.cgContext
            if context != nil {
                print("✅ Got CGContext via lockFocus")
            }
        }

        guard let ctx = context else {
            print("❌ TestScreensaver: Could not get graphics context")
            if NSGraphicsContext.current != nil {
                self.unlockFocus()
            }
            return
        }

        // Clear background with dark blue
        ctx.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0))
        ctx.fill(bounds) // Use bounds instead of rect for fullscreen compatibility

        // Draw bouncing red box
        ctx.setFillColor(CGColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0))
        let boxRect = CGRect(x: boxX, y: boxY, width: boxSize, height: boxSize)
        ctx.fill(boxRect)

        // Draw white border
        ctx.setStrokeColor(CGColor.white)
        ctx.setLineWidth(2.0)
        ctx.stroke(boxRect)

        // Draw frame counter as simple dots (avoid text complexity)
        let dotsX = 20.0
        let dotsY = bounds.height - 40
        let dotCount = min(frameCount % 60, 20) // Show up to 20 dots cycling

        ctx.setFillColor(CGColor.white)
        for i in 0..<dotCount {
            let dotRect = CGRect(x: dotsX + CGFloat(i * 6), y: dotsY, width: 4, height: 4)
            ctx.fillEllipse(in: dotRect)
        }

        print("🎨 TestScreensaver: Drew frame \(frameCount) - box at (\(Int(boxX)), \(Int(boxY))), bounds: \(bounds)")

        // Clean up if we used lockFocus
        if NSGraphicsContext.current != nil {
            self.unlockFocus()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    override func animateOneFrame() {
        frameCount += 1

        // Update box position
        boxX += boxVelocityX
        boxY += boxVelocityY

        // Bounce off edges
        if boxX <= 0 || boxX >= bounds.width - boxSize {
            boxVelocityX = -boxVelocityX
            boxX = max(0, min(boxX, bounds.width - boxSize))
        }

        if boxY <= 0 || boxY >= bounds.height - boxSize {
            boxVelocityY = -boxVelocityY
            boxY = max(0, min(boxY, bounds.height - boxSize))
        }

        // Request redraw
        needsDisplay = true

        if frameCount % 60 == 0 {
            print("🔄 TestScreensaver: Animation frame \(frameCount)")
        }
    }

    override func startAnimation() {
        super.startAnimation()
        print("▶️ TestScreensaver: Animation started")
    }

    override func stopAnimation() {
        super.stopAnimation()
        print("⏹️ TestScreensaver: Animation stopped")
    }

    override var hasConfigureSheet: Bool {
        return false
    }
}