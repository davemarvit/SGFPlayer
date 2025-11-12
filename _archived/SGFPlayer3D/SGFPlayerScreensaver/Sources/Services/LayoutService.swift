// MARK: - Layout Service (Screensaver Version)
// Simplified layout service for screensaver use

import Foundation
import CoreGraphics

// MARK: - Layout Data Models

public struct ResponsiveLayout {
    let boardFrame: CGRect
    let ulBowlCenter: CGPoint
    let lrBowlCenter: CGPoint
    let bowlRadius: CGFloat
    let metadataY: CGFloat
}

public struct LayoutConfiguration {
    let boardAspectRatio: CGFloat
    let screenWidthMultiplier: CGFloat
    let screenHeightMultiplier: CGFloat
    let bowlSizeRatio: CGFloat
    let bowlOffsetMultiplier: CGFloat

    public static let standard = LayoutConfiguration(
        boardAspectRatio: 1.07,
        screenWidthMultiplier: 0.9,
        screenHeightMultiplier: 0.75,
        bowlSizeRatio: 1.0 / 3.0 / 2.0,
        bowlOffsetMultiplier: 1.1
    )
}

// MARK: - Simple GeometryProxy for Screensaver

public struct GeometryProxy {
    public let size: CGSize

    public init(frame: CGRect) {
        self.size = frame.size
    }
}

// MARK: - Layout Service

final class LayoutService: ObservableObject {

    private let configuration: LayoutConfiguration

    init(configuration: LayoutConfiguration = .standard) {
        self.configuration = configuration
    }

    func calculateResponsiveLayout(
        in geometry: GeometryProxy,
        topSpaceCellUnits: CGFloat,
        bottomSpaceCellUnits: CGFloat
    ) -> ResponsiveLayout {

        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height

        // Calculate available space for board (80% of screen)
        let availableWidth = screenWidth * configuration.screenWidthMultiplier
        let availableHeight = screenHeight * configuration.screenHeightMultiplier

        // Calculate board dimensions maintaining aspect ratio
        let boardWidth: CGFloat
        let boardHeight: CGFloat

        let widthConstrainedHeight = availableWidth / configuration.boardAspectRatio
        let heightConstrainedWidth = availableHeight * configuration.boardAspectRatio

        if widthConstrainedHeight <= availableHeight {
            // Width constrained
            boardWidth = availableWidth
            boardHeight = widthConstrainedHeight
        } else {
            // Height constrained
            boardHeight = availableHeight
            boardWidth = heightConstrainedWidth
        }

        // Center the board
        let boardX = (screenWidth - boardWidth) / 2
        let boardY = (screenHeight - boardHeight) / 2
        let boardFrame = CGRect(x: boardX, y: boardY, width: boardWidth, height: boardHeight)

        // Calculate bowl positions
        let bowlRadius = max(boardWidth, boardHeight) * configuration.bowlSizeRatio
        let bowlOffset = bowlRadius * configuration.bowlOffsetMultiplier

        let upperLeftCenter = CGPoint(
            x: boardFrame.minX - bowlOffset,
            y: boardFrame.minY + bowlOffset
        )

        let lowerRightCenter = CGPoint(
            x: boardFrame.maxX + bowlOffset,
            y: boardFrame.maxY - bowlOffset + bowlRadius * 1.25
        )

        // Calculate metadata position
        let metadataY = boardFrame.maxY + (screenHeight - boardFrame.maxY) / 2

        return ResponsiveLayout(
            boardFrame: boardFrame,
            ulBowlCenter: upperLeftCenter,
            lrBowlCenter: lowerRightCenter,
            bowlRadius: bowlRadius,
            metadataY: metadataY
        )
    }
}