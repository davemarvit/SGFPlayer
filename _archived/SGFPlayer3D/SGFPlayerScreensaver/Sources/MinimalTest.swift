// MARK: - Ultra Minimal Screensaver Test
// Absolute simplest possible screensaver to test basic functionality

import ScreenSaver
import Cocoa

@objc(MinimalTest)
class MinimalTest: ScreenSaverView {

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

        print("🔄 MinimalTest: Starting initialization")
        print("🔄 MinimalTest: Frame = \(frame)")
        print("🔄 MinimalTest: IsPreview = \(isPreview)")

        // Minimal setup
        self.animationTimeInterval = 1.0

        print("🔄 MinimalTest: Initialization complete")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func draw(_ rect: NSRect) {
        print("🎨 MinimalTest: draw() called with rect: \(rect)")
        print("🎨 MinimalTest: bounds: \(bounds)")

        // Use AppKit instead of Core Graphics for better Sequoia compatibility
        NSColor.red.setFill()
        bounds.fill()

        print("🎨 MinimalTest: Red fill complete with NSColor")
    }

    override func animateOneFrame() {
        print("🔄 MinimalTest: animateOneFrame() called")
        needsDisplay = true
    }

    override func startAnimation() {
        super.startAnimation()
        print("▶️ MinimalTest: startAnimation() called")
    }

    override func stopAnimation() {
        super.stopAnimation()
        print("⏹️ MinimalTest: stopAnimation() called")
    }
}