// MARK: - Compatibility Layer
// Maintains compatibility with existing ContentView while using new architecture

import Foundation
import SwiftUI

/// Convert between new modular architecture and existing ContentView expectations
struct CompatibilityLayer {
    
    /// Convert new UIStone to existing CapturedStone format
    static func convertToLegacyFormat(
        uiStones: [UIStone],
        bowlRadius: CGFloat
    ) -> [LegacyCapturedStone] {

        print("🔍 CompatibilityLayer: Converting \(uiStones.count) stones with bowlRadius=\(bowlRadius)")

        let result = uiStones.enumerated().map { index, uiStone in
            // uiStone.position is already relative to bowl center from the physics engine
            // GameBoardView expects stone.pos to be offset from bowl center
            let relativePos = uiStone.position

            // Create normalized position (relative to bowl center, -1.0 to 1.0)
            let normalizedPos = CGPoint(
                x: relativePos.x / bowlRadius,
                y: relativePos.y / bowlRadius
            )

            if index < 3 { // Log first 3 stones for debugging
                print("🔍 CompatibilityLayer: Stone \(index): UIStone.position=\(relativePos) → normalized=\(normalizedPos)")
                print("🔍 CompatibilityLayer: Stone \(index): Distance from center=\(sqrt(relativePos.x*relativePos.x + relativePos.y*relativePos.y)) vs bowlRadius=\(bowlRadius)")
            }

            return LegacyCapturedStone(
                isWhite: uiStone.imageName.contains("clam"),
                imageName: uiStone.imageName,
                pos: relativePos,  // Use relative position for bowl offset
                normalizedPos: normalizedPos
            )
        }

        print("🔍 CompatibilityLayer: Conversion complete: \(result.count) legacy stones")
        return result
    }
    
    /// Create a clean physics replacement that integrates with ContentView
    static func createPhysicsReplacement(appModel: AppModel? = nil) -> PhysicsReplacement {
        return PhysicsReplacement(appModel: appModel)
    }
}

/// Clean replacement for the tangled physics code in ContentView
class PhysicsReplacement: ObservableObject {

    private let bridge: ContentViewBridge

    // Published properties that ContentView can observe
    @Published var capUL: [LegacyCapturedStone] = [] // Black stones captured by white (upper-left bowl)
    @Published var capLR: [LegacyCapturedStone] = [] // White stones captured by black (lower-right bowl)
    @Published var physicsInfo: String = ""

    // Physics model selection compatible with ContentView
    var activePhysicsModelRaw: Int {
        get { bridge.activePhysicsModelIndex }
        set { bridge.activePhysicsModelIndex = newValue }
    }

    init(appModel: AppModel? = nil) {
        self.bridge = ContentViewBridge(appModel: appModel)
        // Monitor bridge changes and update legacy format
        bridge.$blackStoneUIPositions
            .sink { [weak self] uiStones in
                guard let self = self else { return }
                print("🔄 PhysicsReplacement: Converting black stones: \(uiStones.count), bowlRadius: \(self.currentBowlRadius)")

                // CRITICAL FIX: Only convert if we have a valid bowl radius
                if self.currentBowlRadius > 50.0 {  // Reasonable minimum bowl radius
                    self.capUL = CompatibilityLayer.convertToLegacyFormat(
                        uiStones: uiStones,
                        bowlRadius: self.currentBowlRadius
                    )
                    print("🔄 PhysicsReplacement: ✅ Updated black stones: \(self.capUL.count)")
                } else {
                    print("🔄 PhysicsReplacement: ⏳ Skipping black stones conversion - invalid bowl radius: \(self.currentBowlRadius)")
                }
            }
            .store(in: &cancellables)

        bridge.$whiteStoneUIPositions
            .sink { [weak self] uiStones in
                guard let self = self else { return }
                print("🔄 PhysicsReplacement: Converting white stones: \(uiStones.count), bowlRadius: \(self.currentBowlRadius)")

                // CRITICAL FIX: Only convert if we have a valid bowl radius
                if self.currentBowlRadius > 50.0 {  // Reasonable minimum bowl radius
                    self.capLR = CompatibilityLayer.convertToLegacyFormat(
                        uiStones: uiStones,
                        bowlRadius: self.currentBowlRadius
                    )
                    print("🔄 PhysicsReplacement: ✅ Updated white stones: \(self.capLR.count)")
                } else {
                    print("🔄 PhysicsReplacement: ⏳ Skipping white stones conversion - invalid bowl radius: \(self.currentBowlRadius)")
                }
            }
            .store(in: &cancellables)
        
        bridge.$physicsStatus
            .sink { [weak self] status in
                self?.physicsInfo = status
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var currentBowlRadius: CGFloat = 100.0
    
    /// Initialize with game (called by ContentView)
    func initializeWithGame(player: SGFPlayer) {
        // Convert Stone to LegacyStone
        let legacyGrid: [[LegacyStone?]] = player.board.grid.map { row in
            row.map { stone in
                switch stone {
                case .black: return .black
                case .white: return .white
                case nil: return nil
                }
            }
        }
        bridge.initializeWithGame(boardGrid: legacyGrid)
        print("🔄 PhysicsReplacement: Initialized with new architecture")
    }
    
    /// Update stone positions (called by ContentView during move changes)
    func updateStonePositions(
        currentMove: Int,
        blackCapturedCount: Int,
        whiteCapturedCount: Int,
        bowlRadius: CGFloat,
        gameSeed: UInt64,
        bowlCenters: (upperLeft: CGPoint, lowerRight: CGPoint)
    ) {
        let previousRadius = currentBowlRadius
        currentBowlRadius = bowlRadius

        print("🔍 PhysicsReplacement: ===== BOWL UPDATE START =====")
        print("🔍 PhysicsReplacement: Bowl radius: \(previousRadius) → \(bowlRadius)")
        print("🔍 PhysicsReplacement: Bowl centers: UL=\(bowlCenters.upperLeft), LR=\(bowlCenters.lowerRight)")
        print("🔍 PhysicsReplacement: Captured counts: Black=\(blackCapturedCount), White=\(whiteCapturedCount)")
        print("🔍 PhysicsReplacement: Current stone counts: capUL=\(capUL.count), capLR=\(capLR.count)")

        bridge.updateForGameState(
            currentMove: currentMove,
            blackCapturedCount: blackCapturedCount,
            whiteCapturedCount: whiteCapturedCount,
            bowlRadius: bowlRadius,
            gameSeed: gameSeed,
            bowlCenters: bowlCenters
        )

        print("🔍 PhysicsReplacement: After bridge update: Bridge stones - Black=\(bridge.blackStoneUIPositions.count), White=\(bridge.whiteStoneUIPositions.count)")

        // CRITICAL FIX: Force recalculation when bowl radius changes significantly
        let radiusChangeThreshold: CGFloat = 1.0 // Lowered threshold for better responsiveness
        let radiusChange = abs(bowlRadius - previousRadius)
        print("🔍 PhysicsReplacement: Radius change: \(radiusChange) (threshold: \(radiusChangeThreshold))")

        if radiusChange > radiusChangeThreshold {
            print("🔍 PhysicsReplacement: 🚀 SIGNIFICANT RADIUS CHANGE DETECTED!")
            print("🔍 PhysicsReplacement: Change: \(abs(bowlRadius - previousRadius)) > threshold \(radiusChangeThreshold)")

            // Log stone positions BEFORE forced recalculation
            if !bridge.blackStoneUIPositions.isEmpty {
                print("🔍 PhysicsReplacement: BEFORE recalc - Black stone sample: \(bridge.blackStoneUIPositions[0].position)")
            }
            if !bridge.whiteStoneUIPositions.isEmpty {
                print("🔍 PhysicsReplacement: BEFORE recalc - White stone sample: \(bridge.whiteStoneUIPositions[0].position)")
            }

            // Force complete recalculation by calling updateForGameState again with new radius
            bridge.updateForGameState(
                currentMove: currentMove,
                blackCapturedCount: blackCapturedCount,
                whiteCapturedCount: whiteCapturedCount,
                bowlRadius: bowlRadius,
                gameSeed: gameSeed,
                bowlCenters: bowlCenters
            )

            // Log stone positions AFTER forced recalculation
            if !bridge.blackStoneUIPositions.isEmpty {
                print("🔍 PhysicsReplacement: AFTER recalc - Black stone sample: \(bridge.blackStoneUIPositions[0].position)")
            }
            if !bridge.whiteStoneUIPositions.isEmpty {
                print("🔍 PhysicsReplacement: AFTER recalc - White stone sample: \(bridge.whiteStoneUIPositions[0].position)")
            }
        } else {
            print("🔍 PhysicsReplacement: Radius change \(radiusChange) below threshold \(radiusChangeThreshold)")
        }

        // ADDITIONAL FIX: Always force stone conversion when radius changes (even small changes)
        // This ensures consistent coordinate systems even for minor window adjustments
        if radiusChange > 0.1 { // Any change greater than 0.1 pixels
            print("🔍 PhysicsReplacement: 📐 Minor radius change detected - forcing stone position recalculation")
            forceStoneConversion()
        }

        print("🔍 PhysicsReplacement: Final stone counts: capUL=\(capUL.count), capLR=\(capLR.count)")
        print("🔍 PhysicsReplacement: ===== BOWL UPDATE END =====")
    }

    /// Force conversion of UI stones to legacy format (called when radius becomes valid)
    private func forceStoneConversion() {
        // Convert current black stones if any exist
        if !bridge.blackStoneUIPositions.isEmpty {
            capUL = CompatibilityLayer.convertToLegacyFormat(
                uiStones: bridge.blackStoneUIPositions,
                bowlRadius: currentBowlRadius
            )
            print("🔄 PhysicsReplacement: 🔥 FORCED black stones conversion: \(capUL.count)")
        }

        // Convert current white stones if any exist
        if !bridge.whiteStoneUIPositions.isEmpty {
            capLR = CompatibilityLayer.convertToLegacyFormat(
                uiStones: bridge.whiteStoneUIPositions,
                bowlRadius: currentBowlRadius
            )
            print("🔄 PhysicsReplacement: 🔥 FORCED white stones conversion: \(capLR.count)")
        }
    }
    
    /// Get available physics models (for ContentView settings)
    var availableModels: [(index: Int, name: String, description: String)] {
        return bridge.availablePhysicsModels
    }
    
    /// Compatibility method for existing ContentView reset logic
    func reset() {
        // Reset the underlying bridge and ViewModel first
        bridge.reset()

        // Clear our published arrays
        capUL.removeAll()
        capLR.removeAll()
        physicsInfo = "Reset"
        print("🔄 PhysicsReplacement: Complete reset (bridge + arrays)")
    }
    
    /// Get diagnostic info for debugging
    func getDiagnosticInfo() -> String {
        return bridge.getDiagnosticInfo()
    }
}

// MARK: - Legacy CapturedStone structure (maintaining compatibility)
struct LegacyCapturedStone: Identifiable {
    let id = UUID()
    let isWhite: Bool
    let imageName: String     // "stone_black" or "clam_0X"
    var pos: CGPoint          // absolute position in current view coordinates
    var normalizedPos: CGPoint // scale-independent position (-1.0 to 1.0 relative to bowl)
    
    init(isWhite: Bool, imageName: String, pos: CGPoint, normalizedPos: CGPoint = .zero) {
        self.isWhite = isWhite
        self.imageName = imageName
        self.pos = pos
        self.normalizedPos = normalizedPos
    }
}

// MARK: - Combine Import
import Combine