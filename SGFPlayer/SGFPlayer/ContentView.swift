// MARK: - File: ContentView.swift
import SwiftUI
import AppKit

// Bridges to NSWindow so we can tweak size & autosave behavior.
struct WindowConfigurator: NSViewRepresentable {
    let apply: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let w = v.window { apply(w) }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Captured Stone Model
struct CapturedStone: Identifiable {
    let id = UUID()
    let isWhite: Bool
    let imageName: String     // "stone_black" or "clam_0X"
    var pos: CGPoint          // absolute position in current view coordinates
    var normalizedPos: CGPoint // scale-independent position (-1.0 to 1.0 relative to bowl)
    
    init(isWhite: Bool, imageName: String, pos: CGPoint = .zero, normalizedPos: CGPoint = .zero) {
        self.isWhite = isWhite
        self.imageName = imageName
        self.pos = pos
        self.normalizedPos = normalizedPos
    }
}

// MARK: - Scale-Independent Position Cache
struct LidLayout: Codable {
    let blackStones: [CGPoint]  // normalized positions (-1.0 to 1.0)
    let whiteStones: [CGPoint]  // normalized positions (-1.0 to 1.0)
}

struct ContentView: View {
    @EnvironmentObject var app: AppModel
    @StateObject private var player = SGFPlayer()
    @StateObject private var bowls = PlayerCapturesAdapter()

    @State private var isPanelOpen: Bool = false
    @State private var marginPercent: CGFloat = 0.041
    
    // Version tracking for physics changes
    private let physicsVersion = "v1.7.3-normalized-scaling"

    // Settings
    @AppStorage("includeSubfolders") private var includeSubfolders = true
    @AppStorage("autoNext") private var autoNext = true
    @AppStorage("randomOnStart") private var randomOnStart = false
    @AppStorage("randomNext") private var randomNext = true
    @AppStorage("eccentricity") private var eccentricity: Double = 1.0

    @AppStorage("panelTintAlpha") private var panelTintAlpha: Double = 0.18   // 0.00–0.60 feels good
    @AppStorage("panelFrost")     private var panelFrost: Double = 0.50       // 0 = ultraThin, 1 = thin

    // Board shadow (user values are in "reference points"; we scale at render time)
    @AppStorage("boardShadowOpacity") private var boardShadowOpacity: Double = 0.35
    @AppStorage("boardShadowRadius")  private var boardShadowRadius:  Double = 22
    @AppStorage("boardShadowDX")      private var boardShadowDX:      Double = 0
    @AppStorage("boardShadowDY")      private var boardShadowDY:      Double = 8

    // Stone shadow (scaling applied inside BoardViewport and here for captured stones)
    @AppStorage("stoneShadowOpacity") private var stoneShadowOpacity: Double = 0.35
    @AppStorage("stoneShadowRadius")  private var stoneShadowRadius:  Double = 5
    @AppStorage("stoneShadowDX")      private var stoneShadowDX:      Double = 0.5
    @AppStorage("stoneShadowDY")      private var stoneShadowDY:      Double = 1.5

    // Grid aspect (H/W). 1.04 is a tasteful traditional look (rectangular cells)
    @AppStorage("cellAspect") private var cellAspect: Double = 1.04

    // Bowl lids: size (fraction of board side), per-lid positions (× board side), and shadows
    @AppStorage("lidScale") private var lidScale: Double = 0.20
    @AppStorage("lidULX")   private var lidULX:   Double = -0.06
    @AppStorage("lidULY")   private var lidULY:   Double = -0.06
    @AppStorage("lidLRX")   private var lidLRX:   Double =  0.06
    @AppStorage("lidLRY")   private var lidLRY:   Double =  0.06

    @AppStorage("lidShadowOpacity") private var lidShadowOpacity: Double = 0.35
    @AppStorage("lidShadowRadius")  private var lidShadowRadius:  Double = 22
    @AppStorage("lidShadowDX")      private var lidShadowDX:      Double = 0
    @AppStorage("lidShadowDY")      private var lidShadowDY:      Double = 8

    // ------------------------------------------
    // Physics model infrastructure (4 variants)
    // ------------------------------------------
    enum PhysicsModel: Int, CaseIterable, Identifiable {
        case model1 = 1, model2 = 2, model3 = 3, model4 = 4, model5 = 5, model6 = 6
        var id: Int { rawValue }
        var label: String { "Physics \(rawValue)" }
        var storagePrefix: String { "m\(rawValue)_" }
    }

    @AppStorage("activePhysicsModel") private var activePhysicsModelRaw: Int = PhysicsModel.model5.rawValue
    private var activeModel: PhysicsModel { PhysicsModel(rawValue: activePhysicsModelRaw) ?? .model1 }

    // Per-model @AppStorage (defaults same as original; ranges doubled in UI)
    // --- Model 1
    @AppStorage("m1_repel") private var m1_repel: Double = 1.60
    @AppStorage("m1_spacing") private var m1_spacing: Double = 2.12
    @AppStorage("m1_centerPullK") private var m1_centerPullK: Double = 0.0028
    @AppStorage("m1_relaxIters") private var m1_relaxIters: Int = 12
    @AppStorage("m1_pressureRadiusXR") private var m1_pressureRadiusXR: Double = 2.6
    @AppStorage("m1_pressureKFactor") private var m1_pressureKFactor: Double = 0.25
    @AppStorage("m1_maxStepXR") private var m1_maxStepXR: Double = 0.06
    @AppStorage("m1_damping") private var m1_damping: Double = 0.82
    @AppStorage("m1_wallK") private var m1_wallK: Double = 0.60
    @AppStorage("m1_anim") private var m1_anim: Double = 0.6
    @AppStorage("m1_stoneStoneK") private var m1_stoneStoneK: Double = 0.15
    @AppStorage("m1_stoneLidK") private var m1_stoneLidK: Double = 0.25

    // --- Model 2 (Improved Natural Placement)
    @AppStorage("m2_repel") private var m2_repel: Double = 1.70
    @AppStorage("m2_spacing") private var m2_spacing: Double = 2.00
    @AppStorage("m2_centerPullK") private var m2_centerPullK: Double = 0.0032
    @AppStorage("m2_relaxIters") private var m2_relaxIters: Int = 15
    @AppStorage("m2_pressureRadiusXR") private var m2_pressureRadiusXR: Double = 2.4
    @AppStorage("m2_pressureKFactor") private var m2_pressureKFactor: Double = 0.28
    @AppStorage("m2_maxStepXR") private var m2_maxStepXR: Double = 0.065
    @AppStorage("m2_damping") private var m2_damping: Double = 0.91
    @AppStorage("m2_wallK") private var m2_wallK: Double = 0.55
    @AppStorage("m2_anim") private var m2_anim: Double = 0.7

    // --- Model 3 (Enhanced BowlPhysics - Balanced)
    @AppStorage("m3_repel") private var m3_repel: Double = 1.40
    @AppStorage("m3_spacing") private var m3_spacing: Double = 1.80
    @AppStorage("m3_centerPullK") private var m3_centerPullK: Double = 0.0025
    @AppStorage("m3_relaxIters") private var m3_relaxIters: Int = 15
    @AppStorage("m3_pressureRadiusXR") private var m3_pressureRadiusXR: Double = 2.4
    @AppStorage("m3_pressureKFactor") private var m3_pressureKFactor: Double = 0.20
    @AppStorage("m3_maxStepXR") private var m3_maxStepXR: Double = 0.08
    @AppStorage("m3_damping") private var m3_damping: Double = 0.88
    @AppStorage("m3_wallK") private var m3_wallK: Double = 0.45
    @AppStorage("m3_anim") private var m3_anim: Double = 0.8

    // --- Model 4 (Natural Realistic Physics - Optimal)
    @AppStorage("m4_repel") private var m4_repel: Double = 1.20
    @AppStorage("m4_spacing") private var m4_spacing: Double = 1.60
    @AppStorage("m4_centerPullK") private var m4_centerPullK: Double = 0.0020
    @AppStorage("m4_relaxIters") private var m4_relaxIters: Int = 10
    @AppStorage("m4_pressureRadiusXR") private var m4_pressureRadiusXR: Double = 2.0
    @AppStorage("m4_pressureKFactor") private var m4_pressureKFactor: Double = 0.15
    @AppStorage("m4_maxStepXR") private var m4_maxStepXR: Double = 0.10
    @AppStorage("m4_damping") private var m4_damping: Double = 0.85
    @AppStorage("m4_wallK") private var m4_wallK: Double = 0.35
    @AppStorage("m4_anim") private var m4_anim: Double = 0.9

    // --- Model 5 (Simple Grid-Based Physics - New)
    @AppStorage("m5_repel") private var m5_repel: Double = 0.0
    @AppStorage("m5_spacing") private var m5_spacing: Double = 0.0
    @AppStorage("m5_centerPullK") private var m5_centerPullK: Double = 0.0
    @AppStorage("m5_relaxIters") private var m5_relaxIters: Int = 5
    @AppStorage("m5_pressureRadiusXR") private var m5_pressureRadiusXR: Double = 0.0
    @AppStorage("m5_pressureKFactor") private var m5_pressureKFactor: Double = 0.0
    @AppStorage("m5_maxStepXR") private var m5_maxStepXR: Double = 0.0
    @AppStorage("m5_damping") private var m5_damping: Double = 0.0
    @AppStorage("m5_wallK") private var m5_wallK: Double = 0.0
    @AppStorage("m5_anim") private var m5_anim: Double = 1.0
    
    // Model 6 (Improved Grid - Less Stacking)
    @AppStorage("m6_repel") private var m6_repel: Double = 0.0
    @AppStorage("m6_spacing") private var m6_spacing: Double = 0.0
    @AppStorage("m6_centerPullK") private var m6_centerPullK: Double = 0.0
    @AppStorage("m6_relaxIters") private var m6_relaxIters: Int = 5
    @AppStorage("m6_pressureRadiusXR") private var m6_pressureRadiusXR: Double = 0.0
    @AppStorage("m6_pressureKFactor") private var m6_pressureKFactor: Double = 0.0
    @AppStorage("m6_maxStepXR") private var m6_maxStepXR: Double = 0.0
    @AppStorage("m6_damping") private var m6_damping: Double = 0.0
    @AppStorage("m6_wallK") private var m6_wallK: Double = 0.0
    @AppStorage("m6_anim") private var m6_anim: Double = 1.0

    // Unified physics view model for convenience
    struct LidPhysics {
        var repel: Double
        var spacing: Double
        var centerPullK: Double
        var relaxIters: Int
        var pressureRadiusXR: Double
        var pressureKFactor: Double
        var maxStepXR: Double
        var damping: Double
        var wallK: Double
        var anim: Double
        var stoneStoneK: Double
        var stoneLidK: Double
    }

    private var cfg: LidPhysics {
        switch activeModel {
        case .model1: return .init(
            repel: m1_repel, spacing: m1_spacing, centerPullK: m1_centerPullK, relaxIters: m1_relaxIters,
            pressureRadiusXR: m1_pressureRadiusXR, pressureKFactor: m1_pressureKFactor,
            maxStepXR: m1_maxStepXR, damping: m1_damping, wallK: m1_wallK, anim: m1_anim,
            stoneStoneK: m1_stoneStoneK, stoneLidK: m1_stoneLidK
        )
        case .model2: return .init(
            repel: m2_repel, spacing: m2_spacing, centerPullK: m2_centerPullK, relaxIters: m2_relaxIters,
            pressureRadiusXR: m2_pressureRadiusXR, pressureKFactor: m2_pressureKFactor,
            maxStepXR: m2_maxStepXR, damping: m2_damping, wallK: m2_wallK, anim: m2_anim,
            stoneStoneK: 0.15, stoneLidK: 0.25
        )
        case .model3: return .init(
            repel: m3_repel, spacing: m3_spacing, centerPullK: m3_centerPullK, relaxIters: m3_relaxIters,
            pressureRadiusXR: m3_pressureRadiusXR, pressureKFactor: m3_pressureKFactor,
            maxStepXR: m3_maxStepXR, damping: m3_damping, wallK: m3_wallK, anim: m3_anim,
            stoneStoneK: 0.15, stoneLidK: 0.25
        )
        case .model4: return .init(
            repel: m4_repel, spacing: m4_spacing, centerPullK: m4_centerPullK, relaxIters: m4_relaxIters,
            pressureRadiusXR: m4_pressureRadiusXR, pressureKFactor: m4_pressureKFactor,
            maxStepXR: m4_maxStepXR, damping: m4_damping, wallK: m4_wallK, anim: m4_anim,
            stoneStoneK: 0.15, stoneLidK: 0.25
        )
        case .model5: return .init(
            repel: m5_repel, spacing: m5_spacing, centerPullK: m5_centerPullK, relaxIters: m5_relaxIters,
            pressureRadiusXR: m5_pressureRadiusXR, pressureKFactor: m5_pressureKFactor,
            maxStepXR: m5_maxStepXR, damping: m5_damping, wallK: m5_wallK, anim: m5_anim,
            stoneStoneK: 0.15, stoneLidK: 0.25
        )
        case .model6: return .init(
            repel: m6_repel, spacing: m6_spacing, centerPullK: m6_centerPullK, relaxIters: m6_relaxIters,
            pressureRadiusXR: m6_pressureRadiusXR, pressureKFactor: m6_pressureKFactor,
            maxStepXR: m6_maxStepXR, damping: m6_damping, wallK: m6_wallK, anim: m6_anim,
            stoneStoneK: 0.15, stoneLidK: 0.25
        )
        }
    }

    @State private var uiMoveDelay: Double = 0.75   // seconds
    @State private var debugLayout = false

    // Advanced disclosure state
    @State private var advancedExpanded: Bool = false
    @State private var advStonesOpen:   Bool = false
    @State private var advGridOpen:     Bool = false
    @State private var advShadowsOpen:  Bool = false
    @State private var advBowlOpen:     Bool = false

    // --- Captured stones in lids ---
    @State private var capUL: [CapturedStone] = [] // black bowl (upper-left) contains black stones captured by white
    @State private var capLR: [CapturedStone] = [] // white bowl (lower-right) contains white stones captured by black
    @State private var lastGrid: [[Stone?]]? = nil

    // Cumulative capture tallies and per-move cache (so jumping is stable)
    @State private var tallyWByB: Int = 0   // white stones captured by black
    @State private var tallyBByW: Int = 0   // black stones captured by white
    @State private var tallyAtMove: [Int:(w:Int,b:Int)] = [0:(0,0)]
    @State private var gridAtMove: [Int : [[Stone?]]] = [:]   // cached canonical boards by move
    @State private var layoutAtMove: [Int: LidLayout] = [:]   // cached normalized stone positions by move
    @State private var isRestoringFromCache: Bool = false  // flag to skip physics when restoring cache
    @State private var currentBowlRadius: CGFloat = 100.0  // store actual bowl radius from rendering
    @State private var lastWindowSize: CGSize = CGSize.zero  // track window size for scaling detection
    @State private var lastIndex: Int = 0
    @State private var previousMoveIndex: Int = 0

    // Cursor-idle chrome fade
    @State private var chromeVisible = true
    @State private var lastMouseMove = Date()

    // Keyboard monitor handle / auto-next work item
    @State private var keyMonitor: Any?
    @State private var nextTimer: DispatchWorkItem?

    // MARK: - Panel palette + pill buttons
    private var panelTint: Color {
        Color(.sRGB, red: 0.24, green: 0.52, blue: 0.44, opacity: 1.0)
    }

    private struct GlassPillButton: ButtonStyle {
        enum Emphasis { case normal, prominent }
        var emphasis: Emphasis = .normal
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.vertical, 8)
                .padding(.horizontal, emphasis == .prominent ? 14 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((emphasis == .prominent ? Color.black.opacity(0.36)
                                                      : Color.black.opacity(0.28)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(configuration.isPressed ? 0.18 : 0.12), lineWidth: 1)
                )
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }

    // MARK: - Natural Stone Positioning
    private func generateNaturalStonePosition(index: Int, totalStones: Int, bowlRadius: CGFloat, isWhite: Bool) -> CGPoint {
        guard totalStones > 0 else { return CGPoint.zero }
        
        // Ensure proper stone separation with multiple strategies
        let stoneRadius = bowlRadius * 0.15 // Approximate stone radius
        let minSeparation = stoneRadius * 2.2 // Minimum distance between stone centers
        
        // Strategy 1: Spiral placement for deterministic separation
        if totalStones <= 12 {
            return generateSpiralPosition(index: index, totalStones: totalStones, bowlRadius: bowlRadius, minSeparation: minSeparation, isWhite: isWhite)
        }
        
        // Strategy 2: Grid-based placement for larger counts
        return generateGridPosition(index: index, totalStones: totalStones, bowlRadius: bowlRadius, isWhite: isWhite, minSeparation: minSeparation)
    }
    
    private func generateSpiralPosition(index: Int, totalStones: Int, bowlRadius: CGFloat, minSeparation: CGFloat, isWhite: Bool) -> CGPoint {
        // Create an Archimedean spiral with proper spacing, but offset for different colors
        let spiralTightness = minSeparation / (2.0 * Double.pi) // Space between spiral arms
        let t = Double(index) * 0.8 // Parameter along spiral
        
        // Offset spiral starting angle based on stone color for separation
        let colorOffset = isWhite ? Double.pi * 0.4 : 0.0 // 72° offset for white stones
        
        let radius = min(spiralTightness * t, Double(bowlRadius) * 0.35) // Keep within 35% of bowl
        let angle = t * 2.0 * Double.pi + colorOffset
        
        let x = radius * cos(angle)
        let y = radius * sin(angle)
        
        return CGPoint(x: x, y: y)
    }
    
    private func generateGridPosition(index: Int, totalStones: Int, bowlRadius: CGFloat, isWhite: Bool, minSeparation: CGFloat) -> CGPoint {
        // Use game fingerprint for consistent but varied positioning
        let gameHash = currentFingerprint().hashValue
        let colorSeed = isWhite ? 104729 : 104743 // Large primes for color separation
        let indexSeed = index * (isWhite ? 104759 : 104773) // Different primes for each color
        let seed = abs(gameHash) + colorSeed + indexSeed
        
        // Create hex grid-like placement with proper spacing
        let gridSpacing = minSeparation * 1.1 // Add 10% buffer
        let maxRadius = Double(bowlRadius) * 0.32 // Keep stones within bowl
        
        // Calculate how many stones fit in concentric rings
        var ring = 0
        var positionInRing = index
        var stonesInPreviousRings = 0
        
        while positionInRing >= (ring == 0 ? 1 : 6 * ring) {
            let stonesInThisRing = ring == 0 ? 1 : 6 * ring
            positionInRing -= stonesInThisRing
            stonesInPreviousRings += stonesInThisRing
            ring += 1
        }
        
        if ring == 0 {
            // Center stone
            return CGPoint.zero
        }
        
        // Position in ring
        let ringRadius = Double(ring) * gridSpacing
        let angularStep = 2.0 * Double.pi / Double(6 * ring)
        let baseAngle = Double(positionInRing) * angularStep
        
        // Add controlled randomness to break up the rigid grid
        let rng1 = Double((seed &* 982451653) % 982451669) / 982451669.0
        let rng2 = Double((seed &* 982451687) % 982451703) / 982451703.0
        
        let angleJitter = (rng1 - 0.5) * angularStep * 0.3 // ±30% of angular step
        let radiusJitter = (rng2 - 0.5) * gridSpacing * 0.4 // ±40% of grid spacing
        
        let finalAngle = baseAngle + angleJitter
        let finalRadius = min(ringRadius + radiusJitter, maxRadius)
        
        let x = finalRadius * cos(finalAngle)
        let y = finalRadius * sin(finalAngle)
        
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Scaling Helper Function
    private func rescaleStonePositionsIfNeeded(newBowlRadius: CGFloat) -> Bool {
        let radiusChanged = abs(newBowlRadius - currentBowlRadius) > 10.0 && currentBowlRadius > 0  // Larger threshold
        
        print("🔍 BOWL RADIUS: current=\(currentBowlRadius), new=\(newBowlRadius), changed=\(radiusChanged)")
        
        if radiusChanged {
            print("🔄 SAFE SCALING: Bowl radius changed significantly")
            
            // Use simple ratio scaling - no cache operations to avoid infinite loops
            let scaleFactor = newBowlRadius / currentBowlRadius
            print("🔄 SAFE SCALING: Scale factor = \(scaleFactor)")
            
            // Scale existing stone positions directly
            for i in 0..<capUL.count {
                let oldPos = capUL[i].pos
                capUL[i].pos = CGPoint(x: oldPos.x * scaleFactor, y: oldPos.y * scaleFactor)
            }
            
            for i in 0..<capLR.count {
                let oldPos = capLR[i].pos  
                capLR[i].pos = CGPoint(x: oldPos.x * scaleFactor, y: oldPos.y * scaleFactor)
            }
            
            print("🔄 SAFE SCALING: Scaled \(capUL.count) UL + \(capLR.count) LR stones by \(scaleFactor)")
        }
        
        currentBowlRadius = newBowlRadius
        return radiusChanged
    }

    var body: some View {
        ZStack {
            // Main board + bottom metadata
            detail

            // Tap-to-dismiss overlay for the settings panel (clicking outside closes)
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isPanelOpen = false }
                }
                .allowsHitTesting(isPanelOpen)
                .zIndex(2)

            // Top-left gear — fades with mouse inactivity; disabled when no games are loaded
            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isPanelOpen.toggle()
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                            .padding(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(app.games.isEmpty)
                    .opacity(app.games.isEmpty ? 0.5 : 1.0)

                    Spacer()
                }
                .padding(.leading, 12)
                .padding(.top, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)
            .animation(.easeOut(duration: 0.5), value: chromeVisible)
            .zIndex(3)

            // Top-right fullscreen toggle — fades with mouse inactivity
            VStack {
                HStack {
                    Spacer()
                    Button {
                        NSApp.keyWindow?.toggleFullScreen(nil)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .imageScale(.large)
                            .padding(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.trailing, 12)
                .padding(.top, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)
            .animation(.easeOut(duration: 0.5), value: chromeVisible)
            .zIndex(3)

            // Slide-out panel (from the left)
            sidePanel
                .offset(x: isPanelOpen ? 0 : -(360 + 12 + 16)) // 360 + paddings
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPanelOpen)
                .shadow(radius: 16, x: 4, y: 0)
                .zIndex(4)
        }
        .frame(minWidth: 550, minHeight: 410)

        // Start new selection at move 0 and auto-play
        .onChange(of: app.selection) { _, newValue in
            if let g = newValue?.game { player.load(game: g) }
            player.setPlayInterval(uiMoveDelay)
            player.seek(to: 0)
            if player.isPlaying { player.togglePlay() } // normalize to paused
            player.togglePlay()                         // then play
            nextTimer?.cancel()
            lastGrid = player.board.grid
            capUL.removeAll()
            capLR.removeAll()
            scheduleAutoNextIfNeeded()

            tallyWByB = 0
            tallyBByW = 0
            tallyAtMove = [0:(0,0)]
            gridAtMove.removeAll()
            gridAtMove[0] = player.board.grid
            layoutAtMove.removeAll()
            layoutAtMove[0] = LidLayout(blackStones: [], whiteStones: [])

            // NEW: seed bowls deterministically for the newly-selected game
            bowls.refresh(using: player, gameFingerprint: currentFingerprint())
        }
        .onChange(of: player.currentIndex) { oldIndex, newIndex in
            print("🔄 MOVE CHANGE: \(oldIndex) → \(newIndex)")
            print("🔄 Current tallies - WByB: \(tallyWByB), BByW: \(tallyBByW)")
            print("🔄 Current stone counts - UL: \(capUL.count), LR: \(capLR.count)")
            
            // If we've seen this move before, restore exact tallies + grid + stone positions.
            if let t = tallyAtMove[player.currentIndex],
               let g = gridAtMove[player.currentIndex],
               let layout = layoutAtMove[player.currentIndex] {

                print("🔄 CACHE HIT in move change: Found cached move \(player.currentIndex)")
                print("🔄 Cached tallies - WByB: \(t.w), BByW: \(t.b)")
                print("🔄 Cached layout - black: \(layout.blackStones.count), white: \(layout.whiteStones.count)")

                // Update direction tracking even for cached moves
                previousMoveIndex = player.currentIndex
                
                tallyWByB = t.w
                tallyBByW = t.b
                lastGrid = g

                // Directly restore stone arrays from cache without running capture detection
                print("🔄 CACHE HIT: Directly restoring stone arrays from cache")
                
                // Use actual bowl radius from rendering instead of estimates
                let bowlR = currentBowlRadius
                
                print("🔄 CACHE HIT: Using actual bowl radius \(bowlR) for restoration (stored from rendering)")
                
                // Restore stone positions directly
                restoreStonePositionsFromCache(layout: layout, bowlRadius: bowlR)
                
                scheduleAutoNextIfNeeded()
                print("🔄 CACHE HIT: Completed move change to cached move")
                return
            }

            // Track movement direction and compute deltas
            let isMovingForward = player.currentIndex > previousMoveIndex
            previousMoveIndex = player.currentIndex
            detectCapturesAndUpdateLids(isMovingForward: isMovingForward)
            tallyAtMove[player.currentIndex] = (tallyWByB, tallyBByW)
            gridAtMove[player.currentIndex] = player.board.grid

            scheduleAutoNextIfNeeded()
            bowls.refresh(using: player, gameFingerprint: currentFingerprint())
            
            print("🔄 CACHE MISS: Completed move change to new move \(player.currentIndex)")
            print("🔄 Final tallies - WByB: \(tallyWByB), BByW: \(tallyBByW)")
            print("🔄 Final stone counts - UL: \(capUL.count), LR: \(capLR.count)")
            // NOTE: Position caching now happens in syncLidsToTallies with proper bowl radius
        }
        .onChange(of: player.isPlaying) { _, _ in
            scheduleAutoNextIfNeeded()
        }
        // Real-time physics parameter updates
        .onChange(of: m1_stoneStoneK) { _, _ in bowls.refresh(using: player, gameFingerprint: currentFingerprint()) }
        .onChange(of: m1_stoneLidK) { _, _ in bowls.refresh(using: player, gameFingerprint: currentFingerprint()) }
        .onChange(of: m1_repel) { _, _ in bowls.refresh(using: player, gameFingerprint: currentFingerprint()) }
        .onChange(of: m1_spacing) { _, _ in bowls.refresh(using: player, gameFingerprint: currentFingerprint()) }
        .onChange(of: m1_damping) { _, _ in bowls.refresh(using: player, gameFingerprint: currentFingerprint()) }
        .onChange(of: activePhysicsModelRaw) { _, _ in 
            // Clear ALL cached results when physics model changes
            tallyAtMove = [0:(0,0)]
            gridAtMove.removeAll()
            gridAtMove[0] = player.board.grid
            layoutAtMove.removeAll()
            layoutAtMove[0] = LidLayout(blackStones: [], whiteStones: [])
            print("🔄 CACHE CLEARED: Physics model changed, cleared all cached results and reset to initial state")
            bowls.refresh(using: player, gameFingerprint: currentFingerprint()) 
        }
        .onAppear {
            if randomOnStart, app.selection == nil { pickRandomGame() }
            if let g = app.selection?.game { player.load(game: g) }
            if autoNext && !player.isPlaying { player.togglePlay() }
            lastGrid = player.board.grid
            scheduleAutoNextIfNeeded()

            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKey(event)
                return event
            }
            // NEW: seed + initial bowl build
            bowls.refresh(using: player, gameFingerprint: currentFingerprint())
        }
        .onDisappear {
            if let m = keyMonitor { NSEvent.removeMonitor(m) }
            keyMonitor = nil
            nextTimer?.cancel()
            nextTimer = nil
        }
        .onHover { hovering in
            if hovering {
                chromeVisible = true
                lastMouseMove = Date()
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(_):
                chromeVisible = true
                lastMouseMove = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // if no further movement for ~3s, fade
                    if Date().timeIntervalSince(lastMouseMove) >= 2.95 {
                        withAnimation(.easeOut(duration: 0.5)) { chromeVisible = false }
                    }
                }
            case .ended:
                withAnimation(.easeOut(duration: 0.5)) { chromeVisible = true }
            }
        }
        // Force a fresh size each launch and disable autosave of window frame
        .background(
            WindowConfigurator { w in
                w.setFrameAutosaveName("") // disable autosave
                let target = NSSize(width: 900, height: 640)
                w.setContentSize(target)
                w.center()
            }
        )
    }

    // MARK: - Left slide-out panel (files + controls)
    private var sidePanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Settings").font(.title2.bold())
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isPanelOpen = false }
                } label: {
                    Image(systemName: "xmark.circle.fill").imageScale(.large)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Row of quick actions
                    HStack(spacing: 10) {
                        Button("Open folder…") { app.promptForFolder() }
                            .buttonStyle(GlassPillButton(emphasis: .prominent))

                        Button("Random game now") { pickRandomGame() }
                            .buttonStyle(GlassPillButton())
                    }

                    Toggle("include subfolders", isOn: $includeSubfolders)


                    // Games list – styled to look like the panel (no mismatched bg)
                    List(app.games, selection: $app.selection) { item in
                        let g = item.game
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayDate(g.info.date) ?? (g.info.event ?? ""))
                                .font(.headline)
                            HStack(spacing: 12) {
                                Text("B: \(g.info.playerBlack ?? "?")")
                                Text("W: \(g.info.playerWhite ?? "?")")
                                if let re = g.info.result, !re.isEmpty { Text(re) }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            app.selection = item
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.thinMaterial.opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(height: 7 * 44)

                    // Move delay (log slider 0.2–10s)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Move delay: \(String(format: "%.1f", uiMoveDelay)) seconds")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                        Slider(
                            value: Binding(
                                get: { normFromDelay(uiMoveDelay) },
                                set: { t in
                                    uiMoveDelay = delayFromNorm(t)
                                    player.setPlayInterval(uiMoveDelay)
                                }
                            ),
                            in: 0...1
                        )
                        .tint(.white)
                        .controlSize(.large)
                    }

                    // Auto-next options
                    HStack(spacing: 18) {
                        Toggle("auto-next", isOn: $autoNext)
                        Toggle("random next game", isOn: $randomNext)
                        Toggle("random game on start", isOn: $randomOnStart)
                    }

                    // Move slider + readout
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Move: \(player.currentIndex)/\(player.maxIndex)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                        Slider(
                            value: Binding(
                                get: { Double(player.currentIndex) },
                                set: { v in player.seek(to: Int(v.rounded())) }
                            ),
                            in: 0...Double(max(0, player.maxIndex))
                        )
                        .tint(.white)
                        .controlSize(.large)
                    }

                    // Transport controls (in-panel)
                    HStack(spacing: 10) {
                        Button("<<") { stepBack(10) }.buttonStyle(GlassPillButton())
                        Button("<")  { stepBack(1)  }.buttonStyle(GlassPillButton())
                        Button(action: { player.togglePlay() }) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .imageScale(.medium)
                        }
                            .buttonStyle(GlassPillButton(emphasis: .prominent))
                        Button(">")  { stepForward(1)  }.buttonStyle(GlassPillButton())
                        Button(">>") { stepForward(10) }.buttonStyle(GlassPillButton())
                        Spacer()
                    }

                    // Panel appearance
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Appearance").font(.headline)

                        HStack {
                            Text("Tint opacity")
                            Spacer()
                            Text(String(format: "%.2f", panelTintAlpha)).monospacedDigit()
                        }
                        Slider(value: $panelTintAlpha, in: 0.0...0.60)
                            .controlSize(.large)

                        HStack {
                            Text("Frostiness")
                            Spacer()
                            Text(String(format: "%.2f", panelFrost)).monospacedDigit()
                        }
                        Slider(value: $panelFrost, in: 0.0...1.0)
                            .controlSize(.large)
                    }
                    .padding(.top, 6)

                    // Advanced
                    DisclosureGroup(isExpanded: $advancedExpanded) {
                        VStack(alignment: .leading, spacing: 10) {

                            // STONES ------------------------------------------------------------
                            DisclosureGroup("Stones", isExpanded: $advStonesOpen) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Eccentricity")
                                        Spacer()
                                        Text("\(String(format: "%.2fx", eccentricity))").monospacedDigit()
                                    }
                                    Slider(value: $eccentricity, in: 0.0...5.0, step: 0.01)
                                        .tint(.white)
                                        .controlSize(.large)

                                    HStack {
                                        Button("Reset to preset") { eccentricity = 1.0 }
                                            .buttonStyle(GlassPillButton())
                                        Spacer()
                                    }
                                }
                                .padding(.top, 6)
                            }
                            .padding(.leading, 16)

                            // GRID & LIDS -------------------------------------------------------
                            DisclosureGroup("Grid & Lids", isExpanded: $advGridOpen) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack { Text("Cell aspect (H/W)"); Spacer(); Text(String(format: "%.3f", cellAspect)).monospacedDigit() }
                                    Slider(value: $cellAspect, in: 0.95...1.10).controlSize(.large)

                                    HStack { Text("Lid scale"); Spacer(); Text(String(format: "%.2f", lidScale)).monospacedDigit() }
                                    Slider(value: $lidScale, in: 0.12...0.60).controlSize(.large)

                                    Text("Upper-left lid").font(.subheadline.bold()).padding(.top, 4)
                                    HStack { Text("X"); Spacer(); Text(String(format: "%.3f", lidULX)).monospacedDigit() }
                                    Slider(value: $lidULX, in: -0.30...0.30).controlSize(.large)
                                    HStack { Text("Y"); Spacer(); Text(String(format: "%.3f", lidULY)).monospacedDigit() }
                                    Slider(value: $lidULY, in: -0.30...0.30).controlSize(.large)

                                    Text("Lower-right lid").font(.subheadline.bold()).padding(.top, 2)
                                    HStack { Text("X"); Spacer(); Text(String(format: "%.3f", lidLRX)).monospacedDigit() }
                                    Slider(value: $lidLRX, in: -0.30...0.30).controlSize(.large)
                                    HStack { Text("Y"); Spacer(); Text(String(format: "%.3f", lidLRY)).monospacedDigit() }
                                    Slider(value: $lidLRY, in: -0.30...0.30).controlSize(.large)
                                }
                                .padding(.top, 6)
                            }
                            .padding(.leading, 16)

                            // SHADOWS -----------------------------------------------------------
                            DisclosureGroup("Shadows", isExpanded: $advShadowsOpen) {
                                VStack(alignment: .leading, spacing: 10) {
                                    // Board
                                    Text("Board").font(.subheadline.bold())
                                    HStack { Text("Opacity"); Spacer(); Text(String(format: "%.2f", boardShadowOpacity)).monospacedDigit() }
                                    Slider(value: $boardShadowOpacity, in: 0...0.9).controlSize(.large)
                                    HStack { Text("Radius"); Spacer(); Text(String(format: "%.1f", boardShadowRadius)).monospacedDigit() }
                                    Slider(value: $boardShadowRadius, in: 0...40).controlSize(.large)
                                    HStack { Text("Offset X"); Spacer(); Text(String(format: "%.1f", boardShadowDX)).monospacedDigit() }
                                    Slider(value: $boardShadowDX, in: -20...20).controlSize(.large)
                                    HStack { Text("Offset Y"); Spacer(); Text(String(format: "%.1f", boardShadowDY)).monospacedDigit() }
                                    Slider(value: $boardShadowDY, in: -20...20).controlSize(.large)

                                    // Stones
                                    Text("Stones").font(.subheadline.bold()).padding(.top, 4)
                                    HStack { Text("Opacity"); Spacer(); Text(String(format: "%.2f", stoneShadowOpacity)).monospacedDigit() }
                                    Slider(value: $stoneShadowOpacity, in: 0...0.9).controlSize(.large)
                                    HStack { Text("Radius"); Spacer(); Text(String(format: "%.1f", stoneShadowRadius)).monospacedDigit() }
                                    Slider(value: $stoneShadowRadius, in: 0...20).controlSize(.large)
                                    HStack { Text("Offset X"); Spacer(); Text(String(format: "%.1f", stoneShadowDX)).monospacedDigit() }
                                    Slider(value: $stoneShadowDX, in: -8...8).controlSize(.large)
                                    HStack { Text("Offset Y"); Spacer(); Text(String(format: "%.1f", stoneShadowDY)).monospacedDigit() }
                                    Slider(value: $stoneShadowDY, in: -8...8).controlSize(.large)

                                    // Lids
                                    Text("Lids").font(.subheadline.bold()).padding(.top, 4)
                                    HStack { Text("Opacity"); Spacer(); Text(String(format: "%.2f", lidShadowOpacity)).monospacedDigit() }
                                    Slider(value: $lidShadowOpacity, in: 0...0.9).controlSize(.large)
                                    HStack { Text("Radius"); Spacer(); Text(String(format: "%.1f", lidShadowRadius)).monospacedDigit() }
                                    Slider(value: $lidShadowRadius, in: 0...40).controlSize(.large)
                                    HStack { Text("Offset X"); Spacer(); Text(String(format: "%.1f", lidShadowDX)).monospacedDigit() }
                                    Slider(value: $lidShadowDX, in: -20...20).controlSize(.large)
                                    HStack { Text("Offset Y"); Spacer(); Text(String(format: "%.1f", lidShadowDY)).monospacedDigit() }
                                    Slider(value: $lidShadowDY, in: -20...20).controlSize(.large)
                                }
                                .padding(.top, 6)
                            }
                            .padding(.leading, 16)

                            // PHYSICS ENGINES ---------------------------------------------------
                            DisclosureGroup("Lid and stone physics", isExpanded: $advBowlOpen) {
                                VStack(alignment: .leading, spacing: 12) {

                                    // Active model picker
                                    HStack {
                                        Text("Active model")
                                        Spacer()
                                        Picker("Active model", selection: Binding(
                                            get: { activePhysicsModelRaw },
                                            set: { activePhysicsModelRaw = $0 }
                                        )) {
                                            ForEach(PhysicsModel.allCases) { m in
                                                Text(m.label).tag(m.rawValue)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                    }

                                    // Per-model editors (sliders) — ranges DOUBLED
                                    VStack(alignment: .leading, spacing: 12) {
                                        physicsEditor(title: "Physics 1",
                                                  isActive: activeModel == .model1,
                                                  physicsModel: .model1,
                                                  repel: $m1_repel,
                                                  spacing: $m1_spacing,
                                                  centerPullK: $m1_centerPullK,
                                                  relaxIters: $m1_relaxIters,
                                                  pressureRadiusXR: $m1_pressureRadiusXR,
                                                  pressureKFactor: $m1_pressureKFactor,
                                                  maxStepXR: $m1_maxStepXR,
                                                  damping: $m1_damping,
                                                  wallK: $m1_wallK,
                                                  anim: $m1_anim,
                                                  stoneStoneK: $m1_stoneStoneK,
                                                  stoneLidK: $m1_stoneLidK)

                                    physicsEditor(title: "Physics 2",
                                                  isActive: activeModel == .model2,
                                                  physicsModel: .model2,
                                                  repel: $m2_repel,
                                                  spacing: $m2_spacing,
                                                  centerPullK: $m2_centerPullK,
                                                  relaxIters: $m2_relaxIters,
                                                  pressureRadiusXR: $m2_pressureRadiusXR,
                                                  pressureKFactor: $m2_pressureKFactor,
                                                  maxStepXR: $m2_maxStepXR,
                                                  damping: $m2_damping,
                                                  wallK: $m2_wallK,
                                                  anim: $m2_anim)

                                    physicsEditor(title: "Physics 3",
                                                  isActive: activeModel == .model3,
                                                  physicsModel: .model3,
                                                  repel: $m3_repel,
                                                  spacing: $m3_spacing,
                                                  centerPullK: $m3_centerPullK,
                                                  relaxIters: $m3_relaxIters,
                                                  pressureRadiusXR: $m3_pressureRadiusXR,
                                                  pressureKFactor: $m3_pressureKFactor,
                                                  maxStepXR: $m3_maxStepXR,
                                                  damping: $m3_damping,
                                                  wallK: $m3_wallK,
                                                  anim: $m3_anim)

                                    physicsEditor(title: "Physics 4",
                                                  isActive: activeModel == .model4,
                                                  physicsModel: .model4,
                                                  repel: $m4_repel,
                                                  spacing: $m4_spacing,
                                                  centerPullK: $m4_centerPullK,
                                                  relaxIters: $m4_relaxIters,
                                                  pressureRadiusXR: $m4_pressureRadiusXR,
                                                  pressureKFactor: $m4_pressureKFactor,
                                                  maxStepXR: $m4_maxStepXR,
                                                  damping: $m4_damping,
                                                  wallK: $m4_wallK,
                                                  anim: $m4_anim)

                                    physicsEditor(title: "Physics 5 (Grid)",
                                                  isActive: activeModel == .model5,
                                                  physicsModel: .model5,
                                                  repel: $m5_repel,
                                                  spacing: $m5_spacing,
                                                  centerPullK: $m5_centerPullK,
                                                  relaxIters: $m5_relaxIters,
                                                  pressureRadiusXR: $m5_pressureRadiusXR,
                                                  pressureKFactor: $m5_pressureKFactor,
                                                  maxStepXR: $m5_maxStepXR,
                                                  damping: $m5_damping,
                                                  wallK: $m5_wallK,
                                                  anim: $m5_anim)

                                    physicsEditor(title: "Physics 6 (Less Stacking)",
                                                  isActive: activeModel == .model6,
                                                  physicsModel: .model6,
                                                  repel: $m6_repel,
                                                  spacing: $m6_spacing,
                                                  centerPullK: $m6_centerPullK,
                                                  relaxIters: $m6_relaxIters,
                                                  pressureRadiusXR: $m6_pressureRadiusXR,
                                                  pressureKFactor: $m6_pressureKFactor,
                                                  maxStepXR: $m6_maxStepXR,
                                                  damping: $m6_damping,
                                                  wallK: $m6_wallK,
                                                  anim: $m6_anim)
                                    }
                                    .padding(.leading, 16)
                                }
                                .padding(.top, 6)
                            }
                            .padding(.leading, 16)

                        }
                        .padding(.top, 6)
                    } label: {
                        // Make the whole label row clickable (text OR chevron)
                        HStack(spacing: 8) {
                            Text("Advanced").font(.headline)
                            Spacer()
                            Image(systemName: advancedExpanded ? "chevron.down" : "chevron.right")
                                .font(.headline)
                                .opacity(0.8)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { advancedExpanded.toggle() }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } // ScrollView
        } // VStack(spacing: 0) header + scroll

        // Panel chrome & layout
        .frame(width: 360, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial).opacity(1 - panelFrost)
                Rectangle().fill(.thinMaterial).opacity(panelFrost)
                Rectangle().fill(panelTint.opacity(panelTintAlpha))
                LinearGradient(
                    colors: [.clear, .black.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(16)
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    } // end of `private var sidePanel: some View`

    // MARK: - Physics editor (reusable view)
    private func physicsEditor(
        title: String,
        isActive: Bool,
        physicsModel: PhysicsModel,
        repel: Binding<Double>,
        spacing: Binding<Double>,
        centerPullK: Binding<Double>,
        relaxIters: Binding<Int>,
        pressureRadiusXR: Binding<Double>,
        pressureKFactor: Binding<Double>,
        maxStepXR: Binding<Double>,
        damping: Binding<Double>,
        wallK: Binding<Double>,
        anim: Binding<Double>,
        stoneStoneK: Binding<Double>? = nil,
        stoneLidK: Binding<Double>? = nil
    ) -> some View {
        DisclosureGroup(title) {
            VStack(alignment: .leading, spacing: 8) {
                // Physics 1-4: Traditional force-based physics sliders
                if physicsModel == .model1 || physicsModel == .model2 || physicsModel == .model3 || physicsModel == .model4 {
                    HStack { Text("Repulsion"); Spacer(); Text(String(format: "%.2f", repel.wrappedValue)).monospacedDigit() }
                    Slider(value: repel, in: 0.25...6.00, step: 0.01).controlSize(.large)

                    HStack { Text("Target spacing (× radius)"); Spacer(); Text(String(format: "%.2f", spacing.wrappedValue)).monospacedDigit() }
                    Slider(value: spacing, in: 0.10...4.80, step: 0.01).controlSize(.large)

                    HStack { Text("Center pull (× lid size)"); Spacer(); Text(String(format: "%.4f", centerPullK.wrappedValue)).monospacedDigit() }
                    Slider(value: centerPullK, in: 0.0000...0.0120, step: 0.0001).controlSize(.large)
                }
                
                // Physics 1-3: Advanced physics controls
                if physicsModel == .model1 || physicsModel == .model2 || physicsModel == .model3 {
                    HStack { Text("Pressure radius (× r)"); Spacer(); Text(String(format: "%.2f", pressureRadiusXR.wrappedValue)).monospacedDigit() }
                    Slider(value: pressureRadiusXR, in: 0.60...8.00, step: 0.01).controlSize(.large)

                    HStack { Text("Pressure strength (× Repel)"); Spacer(); Text(String(format: "%.2f", pressureKFactor.wrappedValue)).monospacedDigit() }
                    Slider(value: pressureKFactor, in: 0.00...2.00, step: 0.01).controlSize(.large)

                    HStack { Text("Max step (× r / iter)"); Spacer(); Text(String(format: "%.3f", maxStepXR.wrappedValue)).monospacedDigit() }
                    Slider(value: maxStepXR, in: 0.005...0.40, step: 0.005).controlSize(.large)

                    HStack { Text("Damping"); Spacer(); Text(String(format: "%.3f", damping.wrappedValue)).monospacedDigit() }
                    Slider(value: damping, in: 0.40...0.995, step: 0.001).controlSize(.large)

                    HStack { Text("Wall softness"); Spacer(); Text(String(format: "%.2f", wallK.wrappedValue)).monospacedDigit() }
                    Slider(value: wallK, in: 0.05...2.00, step: 0.01).controlSize(.large)
                }

                // Common: Animation speed for all models
                HStack { Text("Settle animation (s)"); Spacer(); Text(String(format: "%.2f", anim.wrappedValue)).monospacedDigit() }
                Slider(value: anim, in: 0.00...0.60, step: 0.01).controlSize(.large)

                HStack {
                    Text("Relax iterations"); Spacer()
                    Text("\(relaxIters.wrappedValue)").monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(relaxIters.wrappedValue) },
                        set: { relaxIters.wrappedValue = Int($0.rounded()) }
                    ),
                    in: 2...60, step: 1 // doubled
                )
                .controlSize(.large)

                // Friction controls (only shown for Physics 1)
                if let stoneStoneKBinding = stoneStoneK {
                    HStack { Text("Stone-stone friction"); Spacer(); Text(String(format: "%.3f", stoneStoneKBinding.wrappedValue)).monospacedDigit() }
                    Slider(value: stoneStoneKBinding, in: 0.05...0.50, step: 0.01).controlSize(.large)
                }
                
                if let stoneLidKBinding = stoneLidK {
                    HStack { Text("Stone-lid friction"); Spacer(); Text(String(format: "%.3f", stoneLidKBinding.wrappedValue)).monospacedDigit() }
                    Slider(value: stoneLidKBinding, in: 0.10...0.80, step: 0.01).controlSize(.large)
                }

                if isActive {
                    Text("Active").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Main content: board with negative space + bottom metadata
    private var detail: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let L = boardLayout(for: geo.size)
                
                // DISABLED: Window scaling causing crashes - focus on fixing basic positioning first
                let _ = {
                    lastWindowSize = geo.size
                    print("🪟 Window size: \(geo.size) (scaling disabled for stability)")
                }()

                // Diameter for a stone drawn on the board at the current size.
                // Matches the tile used by BoardViewport (min(stepX, stepY)).
                let n = CGFloat(max(1, player.board.size - 1))
                let innerSide = L.side * (1 - 2 * marginPercent)      // BoardViewport's innerRect width/height
                let stepX = innerSide / n

                // Match BoardViewport exactly:
                let proposedStepY = stepX * max(0.75, CGFloat(cellAspect))
                let maxStepY = innerSide / n
                let stepY = min(proposedStepY, maxStepY)

                // Final diameter used for BOTH board and bowl stones:
                let boardStoneDiameter = min(stepX, stepY)
                
                // REMOVED: Bowl radius update moved to after lidSize calculation

                // Scale factor so board/lid shadows grow with board size.
                let shadowScale = L.side / 900.0

                if debugLayout {
                    Path { p in
                        let cx = geo.size.width / 2
                        let cy = (geo.size.height - 44) / 2
                        p.move(to: CGPoint(x: cx, y: cy - 200)); p.addLine(to: CGPoint(x: cx, y: cy + 200))
                        p.move(to: CGPoint(x: cx - 200, y: cy)); p.addLine(to: CGPoint(x: cx + 200, y: cy))
                    }
                    .stroke(.red.opacity(0.6), lineWidth: 1)

                    Rectangle()
                        .stroke(Color.pink.opacity(0.6), lineWidth: 1)
                        .frame(width: L.side, height: L.side)
                        .position(x: geo.size.width / 2, y: (geo.size.height - 44) / 2)
                }

                ZStack {
                    Image("tatami")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .clipped()

                    let boardCenterX = geo.size.width / 2
                    let boardCenterY = L.topInset + L.side / 2

                    BoardViewport(
                        boardSize: player.board.size,
                        state: player.board,
                        textures: Textures.default,
                        marginPercent: marginPercent,
                        eccentricity: CGFloat(eccentricity),
                        cellAspect: CGFloat(cellAspect),
                        stoneShadowOpacity: CGFloat(stoneShadowOpacity),
                        stoneShadowRadius:  CGFloat(stoneShadowRadius),
                        stoneShadowOffsetX: CGFloat(stoneShadowDX),
                        stoneShadowOffsetY: CGFloat(stoneShadowDY)
                    )
                    .frame(width: L.side, height: L.side)
                    .shadow(
                        color: .black.opacity(boardShadowOpacity),
                        radius: boardShadowRadius * shadowScale,
                        x: boardShadowDX * shadowScale,
                        y: boardShadowDY * shadowScale
                    )
                    .position(x: boardCenterX, y: boardCenterY)

                    // Bowl lids anchored to board corners (fixed relative to board)
                    let lidSize = L.side * lidScale
                    let actualBowlRadius = lidSize * 0.46
                    
                    // UPDATE currentBowlRadius with actual rendered value
                    let _ = {
                        currentBowlRadius = actualBowlRadius
                        print("🔧 UPDATED currentBowlRadius to \(actualBowlRadius) (lidSize=\(lidSize))")
                    }()
                    
                    // SAFE SCALING: Re-enabled with improved logic
                    let _ = rescaleStonePositionsIfNeeded(newBowlRadius: actualBowlRadius)
                    let ulCornerX = boardCenterX - L.side / 2
                    let ulCornerY = boardCenterY - L.side / 2
                    let lrCornerX = boardCenterX + L.side / 2
                    let lrCornerY = boardCenterY + L.side / 2

                    let ulCenter = CGPoint(
                        x: ulCornerX + L.side * lidULX,
                        y: ulCornerY + L.side * lidULY
                    )
                    let lrCenter = CGPoint(
                        x: lrCornerX + L.side * lidLRX,
                        y: lrCornerY + L.side * lidLRY
                    )

                    // Map your ContentView.CapturedStone → BowlView.Stone
                    // DIAGNOSTIC: Stone positioning analysis
                    let _ = {
                        print("🔍 STONE POSITIONING DIAGNOSTIC:")
                        print("🔍 Bowl radius: \(actualBowlRadius)")
                        print("🔍 Lid size: \(lidSize)")
                        print("🔍 UL center: \(ulCenter), LR center: \(lrCenter)")
                    }()
                    
                    // SIMPLIFIED: Use algorithmic stone placement instead of complex physics
                    let ulStones = capUL.enumerated().map { (index, s) in
                        // Generate natural-looking position algorithmically
                        let naturalPos = generateNaturalStonePosition(
                            index: index, 
                            totalStones: capUL.count, 
                            bowlRadius: actualBowlRadius,
                            isWhite: false
                        )
                        let distance = sqrt(naturalPos.x*naturalPos.x + naturalPos.y*naturalPos.y)
                        print("🔍 UL Stone \(index): algorithmic pos=(\(String(format: "%.1f", naturalPos.x)), \(String(format: "%.1f", naturalPos.y))), distance=\(String(format: "%.1f", distance))")
                        return BowlView.LidStone(id: s.id, imageName: s.imageName, offset: naturalPos)
                    }
                    let lrStones = capLR.enumerated().map { (index, s) in
                        // Generate natural-looking position algorithmically  
                        let naturalPos = generateNaturalStonePosition(
                            index: index,
                            totalStones: capLR.count,
                            bowlRadius: actualBowlRadius, 
                            isWhite: true
                        )
                        let distance = sqrt(naturalPos.x*naturalPos.x + naturalPos.y*naturalPos.y)
                        print("🔍 LR Stone \(index): algorithmic pos=(\(String(format: "%.1f", naturalPos.x)), \(String(format: "%.1f", naturalPos.y))), distance=\(String(format: "%.1f", distance))")
                        return BowlView.LidStone(id: s.id, imageName: s.imageName, offset: naturalPos)
                    }

                    // UL bowl with tunables from ACTIVE physics model + stone count display
                    ZStack {
                        BowlView(
                            lidImageName: "go_lid_1",
                            center: ulCenter,
                            lidSize: lidSize,
                            stones: ulStones,
                            lidShadowOpacity: CGFloat(lidShadowOpacity),
                            lidShadowRadius:  CGFloat(lidShadowRadius) * shadowScale,
                            lidShadowDX:      CGFloat(lidShadowDX)     * shadowScale,
                            lidShadowDY:      CGFloat(lidShadowDY)     * shadowScale,
                            stoneShadowOpacity: CGFloat(stoneShadowOpacity),
                            stoneShadowRadius:  CGFloat(stoneShadowRadius) * shadowScale,
                            stoneShadowDX:      CGFloat(stoneShadowDX)     * shadowScale,
                            stoneShadowDY:      CGFloat(stoneShadowDY)     * shadowScale,
                            stoneDiameter: boardStoneDiameter,
                            repulsion: CGFloat(cfg.repel),
                            targetSpacingXRadius: CGFloat(cfg.spacing),
                            centerPullPerLid: CGFloat(cfg.centerPullK),
                            relaxIterations: 5, // Force external physics to use our algorithmic positioning
                            // spread/squish
                            pressureRadiusXR: CGFloat(cfg.pressureRadiusXR),
                            pressureKFactor:  CGFloat(cfg.pressureKFactor),
                            maxStepXR:        CGFloat(cfg.maxStepXR),
                            damping:          CGFloat(cfg.damping),
                            wallK:            CGFloat(cfg.wallK),
                            animDuration:     cfg.anim
                        )
                        
                        // Stone count display for black bowl (UL)
                        Text("\(capUL.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(6)
                            .position(x: ulCenter.x - lidSize/2 + 25, y: ulCenter.y - lidSize/2 + 20)
                    }

                    // LR bowl with same ACTIVE physics model + stone count display
                    ZStack {
                        BowlView(
                            lidImageName: "go_lid_2",
                            center: lrCenter,
                            lidSize: lidSize,
                            stones: lrStones,
                            lidShadowOpacity: CGFloat(lidShadowOpacity),
                            lidShadowRadius:  CGFloat(lidShadowRadius) * shadowScale,
                            lidShadowDX:      CGFloat(lidShadowDX)     * shadowScale,
                            lidShadowDY:      CGFloat(lidShadowDY)     * shadowScale,
                            stoneShadowOpacity: CGFloat(stoneShadowOpacity),
                            stoneShadowRadius:  CGFloat(stoneShadowRadius) * shadowScale,
                            stoneShadowDX:      CGFloat(stoneShadowDX)     * shadowScale,
                            stoneShadowDY:      CGFloat(stoneShadowDY)     * shadowScale,
                            stoneDiameter: boardStoneDiameter,
                            repulsion: CGFloat(cfg.repel),
                            targetSpacingXRadius: CGFloat(cfg.spacing),
                            centerPullPerLid: CGFloat(cfg.centerPullK),
                            relaxIterations: 5, // Force external physics to use our algorithmic positioning
                            pressureRadiusXR: CGFloat(cfg.pressureRadiusXR),
                            pressureKFactor:  CGFloat(cfg.pressureKFactor),
                            maxStepXR:        CGFloat(cfg.maxStepXR),
                            damping:          CGFloat(cfg.damping),
                            wallK:            CGFloat(cfg.wallK),
                            animDuration:     cfg.anim
                        )
                        
                        // Stone count display for white bowl (LR)
                        Text("\(capLR.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(6)
                            .position(x: lrCenter.x + lidSize/2 - 25, y: lrCenter.y - lidSize/2 + 20)
                    }

                    // Metadata label centered in the gap to bottom
                    if let g = app.selection?.game {
                        let usableH     = max(1, geo.size.height - L.bottomReserved - L.topInset)
                        let boardCenter = L.topInset + usableH / 2
                        let boardBottom = boardCenter + L.side / 2
                        let safeBottom  = geo.size.height - 12
                        let labelY      = (boardBottom + safeBottom) / 2

                        let fontSize = max(11, min(18, L.side * 0.018))

                        let dateOrEvent = displayDate(g.info.date) ?? (g.info.event ?? "")
                        let parts: [String?] = [
                            dateOrEvent,
                            "B: \(g.info.playerBlack ?? "?")",
                            "W: \(g.info.playerWhite ?? "?")",
                            (g.info.result?.isEmpty == false ? g.info.result! : nil)
                        ]
                        let baseMeta = parts.compactMap { $0 }.joined(separator: "    •    ")

                        HStack(spacing: 8) {
                            Text(baseMeta)
                                .font(.system(size: fontSize))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            // Captures display with tiny stone images
                            if tallyBByW > 0 || tallyWByB > 0 {
                                Text("•")
                                    .font(.system(size: fontSize))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                                
                                HStack(spacing: 4) {
                                    Text("Captures:")
                                        .font(.system(size: fontSize))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                                    
                                    Text("  ")  // Extra space after colon
                                        .font(.system(size: fontSize))
                                    
                                    if tallyBByW > 0 {
                                        HStack(spacing: 2) {
                                            Image("stone_black")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: fontSize * 0.8, height: fontSize * 0.8)
                                            Text("\(tallyBByW)")
                                                .font(.system(size: fontSize))
                                                .foregroundStyle(.white.opacity(0.9))
                                                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                                        }
                                    }
                                    
                                    Text("  ")  // Space between black and white
                                        .font(.system(size: fontSize))
                                    
                                    if tallyWByB > 0 {
                                        HStack(spacing: 2) {
                                            Image("clam_01")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: fontSize * 0.8, height: fontSize * 0.8)
                                            Text("\(tallyWByB)")
                                                .font(.system(size: fontSize))
                                                .foregroundStyle(.white.opacity(0.9))
                                                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                                        }
                                    }
                                }
                            }
                            
                            // Physics version display (smaller, dimmer)
                            Text("•")
                                .font(.system(size: fontSize * 0.7))
                                .foregroundStyle(.white.opacity(0.4))
                                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
                            
                            Text(physicsVersion)
                                .font(.system(size: fontSize * 0.7))
                                .foregroundStyle(.white.opacity(0.4))
                                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
                        }
                        .frame(maxWidth: geo.size.width * 0.94)
                        .position(x: geo.size.width / 2, y: labelY)
                    }
                }
            }
        }
    }

    // MARK: - Utility
    private func displayDate(_ s: String?) -> String? {
        guard let s else { return nil }
        if let comma = s.firstIndex(of: ",") { return String(s[..<comma]) }
        return s
    }

    // Stable per-game fingerprint so bowl layout is deterministic per SGF.
    private func currentFingerprint() -> String {
        guard let g = app.selection?.game else { return "no-game" }
        let pB = g.info.playerBlack ?? ""
        let pW = g.info.playerWhite ?? ""
        let dt = g.info.date ?? ""
        let ev = g.info.event ?? ""
        return [pB, pW, dt, ev].joined(separator: "|")
    }

}

// MARK: - Physics Protocol and Implementations
protocol LidPhysics {
    func simulateStones(
        stones: inout [CapturedStone], 
        targetCount: Int,
        bowlRadius: CGFloat, 
        stoneRadius: CGFloat, 
        gameSeed: UInt64,
        animDuration: Double,
        isWhiteStones: Bool
    )
}

// Physics Model 1: Real Biconvex Stone Physics with Force Transfer and Friction
struct Physics1: LidPhysics {
    let repel: Double
    let spacing: Double
    let centerPullK: Double
    let relaxIters: Int
    let damping: Double
    let stoneStoneK: Double
    let stoneLidK: Double
    
    func simulateStones(
        stones: inout [CapturedStone], 
        targetCount: Int,
        bowlRadius: CGFloat, 
        stoneRadius: CGFloat, 
        gameSeed: UInt64,
        animDuration: Double,
        isWhiteStones: Bool
    ) {
        print("🔥 Physics 1 (Real Physics): Target \(targetCount), Current \(stones.count), isWhite: \(isWhiteStones)")
        
        if stones.count > targetCount {
            stones.removeLast(stones.count - targetCount)
        } else if stones.count < targetCount {
            let existingCount = stones.count
            let newStonesCount = targetCount - existingCount
            
            if newStonesCount > 0 {
                print("🔥 Physics 1: Adding \(newStonesCount) stones with real biconvex physics")
                
                var rng = SimpleRNG(seed: gameSeed &+ (isWhiteStones ? 34567 : 76543))
                
                // Add stones one at a time with proper physics simulation
                for i in 0..<newStonesCount {
                    print("🔥 Physics 1: Simulating stone \(i+1)/\(newStonesCount)")
                    
                    // Start with a random drop position
                    let dropAngle = 2 * Double.pi * rng.nextUnit()
                    let dropRadius = Double(bowlRadius * 0.3) * rng.nextUnit() // Drop in inner area
                    let startPos = CGPoint(
                        x: CGFloat(cos(dropAngle) * dropRadius),
                        y: CGFloat(sin(dropAngle) * dropRadius)
                    )
                    
                    // Create new stone
                    let newStone = CapturedStone(
                        isWhite: isWhiteStones,
                        imageName: isWhiteStones ? String(format: "clam_%02d", 1 + Int(rng.nextRaw() % 5)) : "stone_black",
                        pos: startPos
                    )
                    
                    // Add it temporarily to simulate with existing stones
                    stones.append(newStone)
                    
                    // Run real physics simulation to settle all stones
                    simulateBiconvexPhysics(stones: &stones, bowlRadius: bowlRadius, stoneRadius: stoneRadius)
                    
                    print("🔥 Physics 1: Stone \(i+1) settled after physics simulation")
                }
                
                print("🔥 Physics 1: Final stone count: \(stones.count)")
            }
        }
    }
    
    // Real physics simulation for biconvex stones with proper friction and force transfer
    private func simulateBiconvexPhysics(
        stones: inout [CapturedStone],
        bowlRadius: CGFloat,
        stoneRadius: CGFloat
    ) {
        // NOTE: Window scaling is now handled universally before physics simulation
        
        // NEW: Natural dropping behavior - only the last stone is newly dropped
        let newStoneIndex = stones.count > 0 ? stones.count - 1 : -1
        let _: CGFloat = 9.8 // Gravitational acceleration (unused in current physics model)
        let timeStep: CGFloat = 0.01 // Small time step for stability
        let iterations = max(100, relaxIters) // More iterations for settling
        
        // Biconvex stone properties
        let stoneHeight = stoneRadius * 0.4 // Height of biconvex stone
        let contactRadius = stoneRadius * 0.95 // Contact area
        let _ = bowlRadius - stoneRadius * 0.8 // Unused safe boundary (legacy code)
        
        // Initialize velocities and state with natural dropping for new stones
        var velocities = stones.enumerated().map { (index, stone) -> CGPoint in
            if index == newStoneIndex {
                // NEW STONE: Very gentle dropping motion - minimal velocity
                let dropAngle = Double.random(in: 0...(2 * Double.pi))
                let dropSpeed: CGFloat = stoneRadius * 0.3 // Much gentler dropping speed
                let horizontalDrift: CGFloat = CGFloat.random(in: -0.1...0.1) * stoneRadius  // Less drift
                return CGPoint(
                    x: CGFloat(cos(dropAngle)) * dropSpeed * 0.3 + horizontalDrift,  // Even gentler
                    y: CGFloat(sin(dropAngle)) * dropSpeed * 0.3 + CGFloat.random(in: -0.05...0.05) * stoneRadius  // Minimal variation
                )
            } else {
                // EXISTING STONES: Start at rest (stable unless contacted)
                return CGPoint.zero
            }
        }
        
        // Track which stones are stable vs moving
        var stoneStable = stones.indices.map { $0 != newStoneIndex } // All except new stone start stable
        var isSettled = false
        var settlementCount = 0
        
        print("🔥 Physics 1: Starting biconvex simulation with \(stones.count) stones")
        
        for _ in 0..<iterations {
            var forces = stones.map { _ in CGPoint.zero }
            var maxForce: CGFloat = 0
            var newlyActivated = Set<Int>() // Track stones activated by contact this iteration
            
            // Calculate forces for each stone
            for i in 0..<stones.count {
                // STABILITY: Only calculate forces for moving stones or newly contacted ones
                if stoneStable[i] {
                    continue // Skip stable stones until they're contacted
                }
                let stone = stones[i]
                var totalForce = CGPoint.zero
                
                // 1. CENTER PULL FORCE - simple inward attraction (uses centerPullK slider)
                let distFromCenter = sqrt(stone.pos.x * stone.pos.x + stone.pos.y * stone.pos.y)
                if distFromCenter > 0.001 {
                    // Simple radial inward force (not gradient-based to avoid rings)
                    let pullStrength = CGFloat(self.centerPullK) * 10000.0 // Scale up the slider value
                    totalForce.x -= (stone.pos.x / distFromCenter) * pullStrength
                    totalForce.y -= (stone.pos.y / distFromCenter) * pullStrength
                }
                
                // 2. STONE-STONE FORCES (collision + support)
                for j in 0..<stones.count {
                    if i == j { continue }
                    let otherStone = stones[j]
                    let dx = stone.pos.x - otherStone.pos.x
                    let dy = stone.pos.y - otherStone.pos.y
                    let distance = sqrt(dx * dx + dy * dy)
                    
                    // CONTACT DETECTION: Activate stable stones when contacted by moving stones
                    let contactDistance = stoneRadius * 2.0
                    if distance < contactDistance {
                        if !stoneStable[i] && stoneStable[j] {
                            // Moving stone i contacts stable stone j - activate j
                            newlyActivated.insert(j)
                        }
                    }
                    
                    let desiredSpacing = CGFloat(self.spacing) * stoneRadius
                    if distance < desiredSpacing {
                        let overlap = desiredSpacing - distance
                        
                        if overlap > 0 {
                            // Repulsion force to prevent overlap (uses repel slider)
                            let repelForce = overlap * CGFloat(self.repel) * 10.0
                            totalForce.x += (dx / max(distance, 0.001)) * repelForce
                            totalForce.y += (dy / max(distance, 0.001)) * repelForce
                        }
                        
                        // AGGRESSIVE ANTI-STACKING - multiple measures to prevent stone stacking
                        
                        // REALISTIC PHYSICS - only repel when actually overlapping
                        
                        // 1. Contact-only repulsion - only when stones actually overlap
                        let actualOverlap = desiredSpacing - distance
                        if actualOverlap > 0 {  // Only repel when actually overlapping
                            let contactForce = actualOverlap * CGFloat(self.repel) * 5.0  // Gentle contact force
                            totalForce.x += (dx / max(distance, 0.001)) * contactForce
                            totalForce.y += (dy / max(distance, 0.001)) * contactForce
                        }
                        
                        // 2. Height-based separation - gentle detection without randomness
                        let myHeight = calculateBiconvexHeight(at: stone.pos, stones: stones)
                        let otherHeight = calculateBiconvexHeight(at: otherStone.pos, stones: stones)
                        
                        if myHeight > stoneHeight * 0.9 || otherHeight > stoneHeight * 0.9 {  // Higher threshold
                            // Gentle lateral separation - NO randomness
                            let stackingPenalty = max(myHeight, otherHeight) * 15.0  // Reduced from 100.0
                            let separationForce = stackingPenalty * (dx / max(distance, 0.001))
                            let separationForceY = stackingPenalty * (dy / max(distance, 0.001))
                            
                            totalForce.x += separationForce
                            totalForce.y += separationForceY
                        }
                        
                        // 3. BICONVEX INSTABILITY - much gentler instability forces
                        let heightDiff = myHeight - otherHeight
                        if abs(heightDiff) > stoneHeight * 0.3 && distance < contactRadius * 1.5 {  // Stricter conditions
                            let instabilityForce = abs(heightDiff) * 12.0  // Reduced from 80.0
                            totalForce.x += (dx / max(distance, 0.001)) * instabilityForce
                            totalForce.y += (dy / max(distance, 0.001)) * instabilityForce
                        }
                        
                        // 4. Realistic collision - only when stones actually touch
                        let stoneContactDistance = stoneRadius * 2.0  // Actual stone diameter
                        if distance < stoneContactDistance {
                            let penetration = stoneContactDistance - distance
                            let collisionForce = penetration * 15.0  // Realistic collision response
                            totalForce.x += (dx / max(distance, 0.001)) * collisionForce
                            totalForce.y += (dy / max(distance, 0.001)) * collisionForce
                        }
                    }
                }
                
                // 3. STRICT BOUNDARY CONTAINMENT - prevent escapes during window resize
                let maxAllowedRadius = bowlRadius - stoneRadius * 1.2  // Conservative boundary
                
                // IMMEDIATE CLAMPING - prevent any stone from escaping
                if distFromCenter > maxAllowedRadius {
                    let clampRadius = maxAllowedRadius
                    stones[i].pos.x = (stone.pos.x / distFromCenter) * clampRadius
                    stones[i].pos.y = (stone.pos.y / distFromCenter) * clampRadius
                    velocities[i] = CGPoint.zero // Stop motion when clamped
                }
                
                // Gentle inward force for stones near boundary
                let safeRadius = maxAllowedRadius * 0.8
                if distFromCenter > safeRadius {
                    let excursion = distFromCenter - safeRadius
                    let maxExcursion = maxAllowedRadius - safeRadius
                    let forceRatio = excursion / maxExcursion
                    let boundaryForce = forceRatio * 20.0  // Gentle inward nudge
                    
                    totalForce.x -= (stone.pos.x / max(distFromCenter, 0.001)) * boundaryForce
                    totalForce.y -= (stone.pos.y / max(distFromCenter, 0.001)) * boundaryForce
                }
                
                forces[i] = totalForce
                let forceMag = sqrt(totalForce.x * totalForce.x + totalForce.y * totalForce.y)
                maxForce = max(maxForce, forceMag)
            }
            
            // Activate newly contacted stones
            for idx in newlyActivated {
                stoneStable[idx] = false
                print("🔥 Physics 1: Activated stone \(idx) due to contact")
            }
            
            // Update positions using velocity integration (only for moving stones)
            for i in 0..<stones.count {
                if stoneStable[i] { continue } // Skip stable stones completely
                
                // Update velocity from forces
                velocities[i].x += forces[i].x * timeStep
                velocities[i].y += forces[i].y * timeStep
                
                // Apply friction based on stone shape and contact
                let height = calculateBiconvexHeight(at: stones[i].pos, stones: stones)
                let frictionMultiplier = height > 0 ? CGFloat(self.stoneStoneK) : CGFloat(self.stoneLidK)
                let frictionForce = frictionMultiplier * 0.8 // Higher friction for settling
                
                velocities[i].x *= (1.0 - frictionForce)
                velocities[i].y *= (1.0 - frictionForce)
                
                // Limit maximum velocity for stability
                let speed = sqrt(velocities[i].x * velocities[i].x + velocities[i].y * velocities[i].y)
                if speed > stoneRadius * 0.5 {
                    let scale = (stoneRadius * 0.5) / speed
                    velocities[i].x *= scale
                    velocities[i].y *= scale
                }
                
                // Update position
                stones[i].pos.x += velocities[i].x * timeStep
                stones[i].pos.y += velocities[i].y * timeStep
                
                // SETTLING: Mark stone as stable if velocity and force are low (more lenient)
                let forceSquared = forces[i].x * forces[i].x + forces[i].y * forces[i].y
                if speed < 0.2 && forceSquared < 2.0 {  // More lenient thresholds for easier settling
                    stoneStable[i] = true
                    velocities[i] = CGPoint.zero
                }
            }
            
            // REALISTIC COLLISION DETECTION - only separate when stones actually overlap
            for i in 0..<stones.count {
                for j in (i+1)..<stones.count {
                    let dx = stones[i].pos.x - stones[j].pos.x
                    let dy = stones[i].pos.y - stones[j].pos.y
                    let distance = sqrt(dx * dx + dy * dy)
                    let minDistance = stoneRadius * 1.9 // Just barely touching threshold
                    
                    if distance < minDistance && distance > 0.001 {
                        // Only apply collision correction if at least one stone is moving
                        let iMoving = !stoneStable[i]
                        let jMoving = !stoneStable[j]
                        
                        if iMoving || jMoving {
                            // Calculate separation vector
                            let overlap = minDistance - distance
                            let separationX = (dx / distance) * overlap * 0.5
                            let separationY = (dy / distance) * overlap * 0.5
                            
                            // Move stones apart (only move the moving ones)
                            if iMoving {
                                stones[i].pos.x += separationX
                                stones[i].pos.y += separationY
                                velocities[i] = CGPoint.zero
                            }
                            if jMoving {
                                stones[j].pos.x -= separationX
                                stones[j].pos.y -= separationY
                                velocities[j] = CGPoint.zero
                            }
                            
                            // Activate stable stones that get pushed - NO JITTER
                            if iMoving && stoneStable[j] {
                                stoneStable[j] = false
                                // No random jitter - let physics handle positioning naturally
                            }
                            if jMoving && stoneStable[i] {
                                stoneStable[i] = false
                                // No random jitter - let physics handle positioning naturally
                            }
                        }
                    }
                }
            }
            
            // Check for settlement (consider both force and stability)
            let movingStones = stoneStable.enumerated().filter { !$0.element }.count
            if maxForce < 0.1 || movingStones == 0 {
                settlementCount += 1
                if settlementCount > 10 {
                    isSettled = true
                    print("🔥 Physics 1: Natural settlement achieved, \(movingStones) stones still moving")
                    break
                }
            } else {
                settlementCount = 0
            }
        }
        
        print("🔥 Physics 1: Biconvex simulation complete, settled=\(isSettled), stones=\(stones.count)")
    }
    
    // Calculate height considering biconvex stone shape and realistic support
    private func calculateBiconvexHeight(at position: CGPoint, stones: [CapturedStone]) -> CGFloat {
        let stoneHeight: CGFloat = 0.4 * 12.0 // Approximate stone height in points
        let contactRadius: CGFloat = 12.0 * 0.9 // Contact radius
        
        var maxSupportHeight: CGFloat = 0.0
        
        // Find supporting stones
        for stone in stones {
            if stone.pos == position { continue } // Skip self
            
            let dx = position.x - stone.pos.x
            let dy = position.y - stone.pos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Check if this stone provides support
            if distance < contactRadius * 1.8 {
                let supportHeight = calculateBiconvexHeight(at: stone.pos, stones: stones.filter { $0.pos != stone.pos })
                let contactStrength = max(0, 1.0 - distance / (contactRadius * 1.8))
                let effectiveHeight = (supportHeight + stoneHeight) * contactStrength
                maxSupportHeight = max(maxSupportHeight, effectiveHeight)
            }
        }
        
        return maxSupportHeight
    }
}

// Physics Model 2: Group Drop + Tilted Surface Physics
struct Physics2: LidPhysics {
    func simulateStones(
        stones: inout [CapturedStone], 
        targetCount: Int,
        bowlRadius: CGFloat, 
        stoneRadius: CGFloat, 
        gameSeed: UInt64,
        animDuration: Double,
        isWhiteStones: Bool
    ) {
        if stones.count > targetCount {
            stones.removeLast(stones.count - targetCount)
        } else if stones.count < targetCount {
            let newStoneCount = targetCount - stones.count
            print("🪨 Physics2: Dropping \(newStoneCount) stones as a group (existing: \(stones.count))")
            
            // Group drop: all new stones land together, then settle
            dropStoneGroup(
                stones: &stones,
                newCount: newStoneCount,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed,
                isWhiteStones: isWhiteStones
            )
        }
    }
    
    // MARK: - Group Drop Physics Implementation
    
    private func dropStoneGroup(
        stones: inout [CapturedStone],
        newCount: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        gameSeed: UInt64,
        isWhiteStones: Bool
    ) {
        var rng = SimpleRNG(seed: gameSeed &+ (isWhiteStones ? 0x77777777 : 0x33333333))
        
        // 1. Choose drop location (random spot within bowl)
        let dropAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
        let dropRadiusFactor = pow(rng.nextUnit(), 1.2) // slight center bias
        let dropRadius = bowlRadius * 0.6 * CGFloat(dropRadiusFactor) // avoid extreme edges
        let dropCenter = CGPoint(
            x: cos(dropAngle) * dropRadius,
            y: sin(dropAngle) * dropRadius
        )
        
        // 2. Drop all new stones near the drop center with small random spread
        var newStones: [CapturedStone] = []
        for i in 0..<newCount {
            let imageName = isWhiteStones ? "clam_\(String(format: "%02d", (i % 14) + 1))" : "stone_black"
            
            // Small spread around drop center
            let spreadAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
            let spreadRadius = stoneRadius * 0.8 * CGFloat(rng.nextUnit()) // tight clustering
            let initialPos = CGPoint(
                x: dropCenter.x + cos(spreadAngle) * spreadRadius,
                y: dropCenter.y + sin(spreadAngle) * spreadRadius
            )
            
            let stone = CapturedStone(isWhite: isWhiteStones, imageName: imageName, pos: initialPos)
            newStones.append(stone)
        }
        
        // 3. Settle all stones (existing + new) using tilted surface physics
        stones.append(contentsOf: newStones)
        settleStones(&stones, bowlRadius: bowlRadius, stoneRadius: stoneRadius)
    }
    
    private func settleStones(_ stones: inout [CapturedStone], bowlRadius: CGFloat, stoneRadius: CGFloat) {
        guard stones.count > 1 else { return }
        
        let maxIterations = 15
        let tiltStrength: CGFloat = 0.008 // constant inward force (tilted surface)
        let transmissionCoeff: CGFloat = 0.7 // energy loss in contact propagation
        
        for iteration in 0..<maxIterations {
            var anyMoved = false
            var forces: [CGPoint] = Array(repeating: .zero, count: stones.count)
            
            // 1. Apply constant center bias (tilted surface - not gravity well)
            for i in 0..<stones.count {
                let pos = stones[i].pos
                let distance = sqrt(pos.x * pos.x + pos.y * pos.y)
                if distance > 0.001 {
                    let centerForce = tiltStrength
                    forces[i].x -= (pos.x / distance) * centerForce
                    forces[i].y -= (pos.y / distance) * centerForce
                }
            }
            
            // 2. Apply biconvex overlap penalties
            for i in 0..<stones.count {
                for j in (i+1)..<stones.count {
                    let posA = stones[i].pos
                    let posB = stones[j].pos
                    let dx = posB.x - posA.x
                    let dy = posB.y - posA.y
                    let distance = sqrt(dx*dx + dy*dy)
                    
                    if distance < stoneRadius * 2.4 { // interaction radius
                        let overlapPenalty = calculateBiconvexOverlapForce(
                            centerDistance: distance,
                            stoneRadius: stoneRadius
                        )
                        
                        if distance > 0.001 {
                            let ux = dx / distance
                            let uy = dy / distance
                            let force = overlapPenalty * 0.3 // scale force
                            
                            forces[i].x -= ux * force
                            forces[i].y -= uy * force
                            forces[j].x += ux * force
                            forces[j].y += uy * force
                        }
                    }
                }
            }
            
            // 3. Apply forces with contact propagation
            for i in 0..<stones.count {
                let force = forces[i]
                let forceMagnitude = sqrt(force.x * force.x + force.y * force.y)
                
                if forceMagnitude > 0.001 {
                    // Reduce force based on how many contacts this stone has (friction)
                    let contactCount = countContacts(stoneIndex: i, stones: stones, stoneRadius: stoneRadius)
                    let frictionReduction = pow(transmissionCoeff, CGFloat(contactCount))
                    
                    let dampedForce = CGPoint(
                        x: force.x * frictionReduction * 0.8, // additional damping
                        y: force.y * frictionReduction * 0.8
                    )
                    
                    stones[i].pos.x += dampedForce.x
                    stones[i].pos.y += dampedForce.y
                    
                    // Keep stones within bowl
                    let distance = sqrt(stones[i].pos.x * stones[i].pos.x + stones[i].pos.y * stones[i].pos.y)
                    let maxDistance = bowlRadius * 0.75
                    if distance > maxDistance {
                        stones[i].pos.x *= maxDistance / distance
                        stones[i].pos.y *= maxDistance / distance
                    }
                    
                    if forceMagnitude > 0.01 {
                        anyMoved = true
                    }
                }
            }
            
            if !anyMoved {
                print("🪨 Physics2: Converged after \(iteration + 1) iterations")
                break
            }
        }
    }
    
    private func calculateBiconvexOverlapForce(centerDistance: CGFloat, stoneRadius: CGFloat) -> CGFloat {
        let overlapPercent = max(0, (2 * stoneRadius - centerDistance) / (2 * stoneRadius))
        
        // Biconvex stone curve: gentle at start, steep in middle, gentle at extreme overlap
        // Modeling 1/8 sphere on each side
        if overlapPercent < 0.2 {
            return overlapPercent * 0.1 // very gentle for natural resting
        } else if overlapPercent < 0.8 {
            return pow(overlapPercent, 3) * 2.0 // steep exponential growth
        } else {
            // Extreme overlap becomes "possible but costly"
            return pow(overlapPercent, 2) * 3.0
        }
    }
    
    private func countContacts(stoneIndex: Int, stones: [CapturedStone], stoneRadius: CGFloat) -> Int {
        let contactDistance = stoneRadius * 2.1
        var count = 0
        let targetPos = stones[stoneIndex].pos
        
        for i in 0..<stones.count {
            if i == stoneIndex { continue }
            let otherPos = stones[i].pos
            let distance = sqrt(pow(targetPos.x - otherPos.x, 2) + pow(targetPos.y - otherPos.y, 2))
            if distance < contactDistance {
                count += 1
            }
        }
        return count
    }
}

// Physics Models 4, 5, 6 continue below...
struct Physics3: LidPhysics {
    func simulateStones(
        stones: inout [CapturedStone], 
        targetCount: Int,
        bowlRadius: CGFloat, 
        stoneRadius: CGFloat, 
        gameSeed: UInt64,
        animDuration: Double,
        isWhiteStones: Bool
    ) {
        if stones.count > targetCount {
            stones.removeLast(stones.count - targetCount)
        } else if stones.count < targetCount {
            let newStoneCount = targetCount - stones.count
            print("🪨 Physics3: Adding \(newStoneCount) stones using energy minimization (existing: \(stones.count))")
            
            // Energy minimization approach with group drop
            energyMinimizationDrop(
                stones: &stones,
                newCount: newStoneCount,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed,
                isWhiteStones: isWhiteStones
            )
        }
    }
    
    // MARK: - Energy Minimization Implementation
    
    private func energyMinimizationDrop(
        stones: inout [CapturedStone],
        newCount: Int,
        bowlRadius: CGFloat,
        stoneRadius: CGFloat,
        gameSeed: UInt64,
        isWhiteStones: Bool
    ) {
        var rng = SimpleRNG(seed: gameSeed)
        
        // 1. Group drop: place new stones near each other
        let dropAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
        let dropRadiusFactor = pow(rng.nextUnit(), 1.3) // center bias
        let dropRadius = bowlRadius * 0.5 * CGFloat(dropRadiusFactor)
        let dropCenter = CGPoint(
            x: cos(dropAngle) * dropRadius,
            y: sin(dropAngle) * dropRadius
        )
        
        // 2. Add new stones with tight clustering
        for i in 0..<newCount {
            let imageName = isWhiteStones ? "clam_\(String(format: "%02d", (i % 14) + 1))" : "stone_black"
            
            let clusterAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
            let clusterRadius = stoneRadius * 0.6 * CGFloat(rng.nextUnit())
            let initialPos = CGPoint(
                x: dropCenter.x + cos(clusterAngle) * clusterRadius,
                y: dropCenter.y + sin(clusterAngle) * clusterRadius
            )
            
            let stone = CapturedStone(isWhite: isWhiteStones, imageName: imageName, pos: initialPos)
            stones.append(stone)
        }
        
        // 3. Energy minimization with simulated annealing
        minimizeSystemEnergy(&stones, bowlRadius: bowlRadius, stoneRadius: stoneRadius)
    }
    
    private func minimizeSystemEnergy(_ stones: inout [CapturedStone], bowlRadius: CGFloat, stoneRadius: CGFloat) {
        guard stones.count > 1 else { return }
        
        let maxIterations = 20
        let initialTemperature: CGFloat = 1.0
        let coolingRate: CGFloat = 0.85
        let tiltConstant: CGFloat = 0.01 // tilted surface constant
        
        var temperature = initialTemperature
        
        for iteration in 0..<maxIterations {
            var totalEnergyChange: CGFloat = 0
            
            // Calculate forces for all stones based on current energy state
            for i in 0..<stones.count {
                let currentEnergy = calculateStoneEnergy(stoneIndex: i, stones: stones, bowlRadius: bowlRadius, stoneRadius: stoneRadius, tiltConstant: tiltConstant)
                
                // Try small perturbations in different directions
                let originalPos = stones[i].pos
                let stepSize: CGFloat = temperature * stoneRadius * 0.2
                
                var bestMove = CGPoint.zero
                var bestEnergyChange: CGFloat = 0
                
                // Test 8 directions + no movement
                let directions = [
                    CGPoint(x: stepSize, y: 0),
                    CGPoint(x: -stepSize, y: 0),
                    CGPoint(x: 0, y: stepSize),
                    CGPoint(x: 0, y: -stepSize),
                    CGPoint(x: stepSize * 0.707, y: stepSize * 0.707),
                    CGPoint(x: -stepSize * 0.707, y: stepSize * 0.707),
                    CGPoint(x: stepSize * 0.707, y: -stepSize * 0.707),
                    CGPoint(x: -stepSize * 0.707, y: -stepSize * 0.707),
                ]
                
                for direction in directions {
                    let testPos = CGPoint(
                        x: originalPos.x + direction.x,
                        y: originalPos.y + direction.y
                    )
                    
                    // Keep within bowl bounds
                    let distance = sqrt(testPos.x * testPos.x + testPos.y * testPos.y)
                    if distance > bowlRadius * 0.8 { continue }
                    
                    stones[i].pos = testPos
                    let newEnergy = calculateStoneEnergy(stoneIndex: i, stones: stones, bowlRadius: bowlRadius, stoneRadius: stoneRadius, tiltConstant: tiltConstant)
                    let energyChange = newEnergy - currentEnergy
                    
                    // Accept if energy decreases, or with probability based on temperature
                    let acceptProbability = energyChange <= 0 ? 1.0 : exp(-energyChange / temperature)
                    if acceptProbability > 0.5 && energyChange < bestEnergyChange {
                        bestEnergyChange = energyChange
                        bestMove = direction
                    }
                }
                
                // Apply best move
                if bestEnergyChange < 0 {
                    stones[i].pos = CGPoint(
                        x: originalPos.x + bestMove.x,
                        y: originalPos.y + bestMove.y
                    )
                    totalEnergyChange += abs(bestEnergyChange)
                } else {
                    stones[i].pos = originalPos // restore if no improvement
                }
            }
            
            // Cool temperature
            temperature *= coolingRate
            
            if totalEnergyChange < 0.001 {
                print("🪨 Physics3: Energy minimization converged after \(iteration + 1) iterations")
                break
            }
        }
    }
    
    private func calculateStoneEnergy(stoneIndex: Int, stones: [CapturedStone], bowlRadius: CGFloat, stoneRadius: CGFloat, tiltConstant: CGFloat) -> CGFloat {
        let pos = stones[stoneIndex].pos
        var totalEnergy: CGFloat = 0
        
        // 1. Gravitational potential energy (tilted surface - constant gradient)
        let distanceFromCenter = sqrt(pos.x * pos.x + pos.y * pos.y)
        totalEnergy += tiltConstant * distanceFromCenter
        
        // 2. Biconvex overlap energy (repulsion)
        for j in 0..<stones.count {
            if j == stoneIndex { continue }
            
            let otherPos = stones[j].pos
            let dx = pos.x - otherPos.x
            let dy = pos.y - otherPos.y
            let distance = sqrt(dx*dx + dy*dy)
            
            if distance < stoneRadius * 2.5 { // interaction range
                let overlapEnergy = calculateBiconvexOverlapEnergy(
                    centerDistance: distance,
                    stoneRadius: stoneRadius
                )
                totalEnergy += overlapEnergy
            }
        }
        
        // 3. Group cohesion energy (recently dropped stones prefer proximity)
        // For simplicity, assume last N stones were dropped together
        let groupSize = min(3, stones.count) // last 3 stones form a group
        if stoneIndex >= stones.count - groupSize {
            for j in max(0, stones.count - groupSize)..<stones.count {
                if j == stoneIndex { continue }
                
                let otherPos = stones[j].pos
                let dx = pos.x - otherPos.x
                let dy = pos.y - otherPos.y
                let distance = sqrt(dx*dx + dy*dy)
                
                // Weak attraction for group cohesion
                totalEnergy += 0.02 * distance
            }
        }
        
        return totalEnergy
    }
    
    private func calculateBiconvexOverlapEnergy(centerDistance: CGFloat, stoneRadius: CGFloat) -> CGFloat {
        let overlapPercent = max(0, (2 * stoneRadius - centerDistance) / (2 * stoneRadius))
        
        // Energy function (higher than force for stability)
        if overlapPercent < 0.2 {
            return overlapPercent * 0.2 // gentle energy increase
        } else if overlapPercent < 0.8 {
            return pow(overlapPercent, 4) * 5.0 // steep energy barrier
        } else {
            return pow(overlapPercent, 3) * 8.0 // very high but finite energy
        }
    }
}

// Physics Models 4, 5, 6 continue below...

struct Physics4: LidPhysics {
    func simulateStones(
        stones: inout [CapturedStone], 
        targetCount: Int,
        bowlRadius: CGFloat, 
        stoneRadius: CGFloat, 
        gameSeed: UInt64,
        animDuration: Double,
        isWhiteStones: Bool
    ) {
        if stones.count > targetCount {
            stones.removeLast(stones.count - targetCount)
        } else if stones.count < targetCount {
            let existingCount = stones.count
            let newStonesCount = targetCount - existingCount
            
            // Add new stones: if multiple stones being added, they all "drop" at the same random spot
            if newStonesCount > 0 {
                var rng = SimpleRNG(seed: gameSeed + UInt64(existingCount))
                
                // Pick a single random "drop point" biased toward center
                let dropAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
                let dropRadiusRandom = pow(rng.nextUnit(), 1.5)  // center bias
                let maxRadius = bowlRadius * 0.7
                let dropRadius = maxRadius * 0.3 * CGFloat(dropRadiusRandom)
                let dropPoint = CGPoint(
                    x: cos(dropAngle) * dropRadius,
                    y: sin(dropAngle) * dropRadius
                )
                
                // Add all new stones at or near the drop point with small random variations
                for _ in 0..<newStonesCount {
                    // Small random offset from drop point for each stone
                    let offsetAngle = 2 * CGFloat.pi * CGFloat(rng.nextUnit())
                    let offsetRadius = 8.0 * CGFloat(rng.nextUnit())  // small spread in points
                    let stonePos = CGPoint(
                        x: dropPoint.x + cos(offsetAngle) * offsetRadius,
                        y: dropPoint.y + sin(offsetAngle) * offsetRadius
                    )
                    
                    if isWhiteStones {
                        let pick = 1 + Int(rng.nextRaw() % 5)
                        stones.append(CapturedStone(isWhite: true, imageName: String(format: "clam_%02d", pick), pos: stonePos))
                    } else {
                        stones.append(CapturedStone(isWhite: false, imageName: "stone_black", pos: stonePos))
                    }
                }
            }
        }
    }
}

// Physics 5: Simple Grid-Based Placement (New Approach)
struct Physics5: LidPhysics {
    func simulateStones(
        stones: inout [CapturedStone], 
        targetCount: Int,
        bowlRadius: CGFloat, 
        stoneRadius: CGFloat, 
        gameSeed: UInt64,
        animDuration: Double,
        isWhiteStones: Bool
    ) {
        print("🔥 Physics 5: Target \(targetCount), Current \(stones.count), isWhite: \(isWhiteStones)")
        
        if stones.count > targetCount {
            stones.removeLast(stones.count - targetCount)
        } else if stones.count < targetCount {
            let existingCount = stones.count
            let newStonesCount = targetCount - existingCount
            
            if newStonesCount > 0 {
                print("🔥 Physics 5: Adding \(newStonesCount) stones using grid approach")
                
                // Create a simple grid of positions across the bowl
                let gridSize = max(3, Int(ceil(sqrt(Double(targetCount)))))  // 3x3, 4x4, 5x5, etc.
                let spacing = (bowlRadius * 1.4) / CGFloat(gridSize)  // Space between grid points
                var gridPositions: [CGPoint] = []
                
                // Generate grid positions
                for row in 0..<gridSize {
                    for col in 0..<gridSize {
                        let x = -bowlRadius * 0.7 + CGFloat(col) * spacing
                        let y = -bowlRadius * 0.7 + CGFloat(row) * spacing
                        let distanceFromCenter = sqrt(x*x + y*y)
                        
                        // Only use positions within the bowl
                        if distanceFromCenter < bowlRadius * 0.8 {
                            gridPositions.append(CGPoint(x: x, y: y))
                        }
                    }
                }
                
                // Shuffle positions based on seed and stone color
                var rng = SimpleRNG(seed: gameSeed &+ (isWhiteStones ? 12345 : 54321))
                var availablePositions = gridPositions
                
                // Shuffle the available positions
                for i in 0..<availablePositions.count {
                    let j = Int(rng.nextRaw()) % availablePositions.count
                    availablePositions.swapAt(i, j)
                }
                
                // Add stones to available positions with collision avoidance
                for i in 0..<min(newStonesCount, availablePositions.count) {
                    let basePos = availablePositions[i]
                    var attempts = 0
                    var finalPos = basePos
                    
                    // Try to find a non-overlapping position
                    while attempts < 10 {
                        // Add some randomness to avoid perfect grid
                        let randomOffset = CGFloat(8.0) // Reduced offset for less overlap
                        let offsetX = (CGFloat(rng.nextUnit()) - 0.5) * randomOffset
                        let offsetY = (CGFloat(rng.nextUnit()) - 0.5) * randomOffset
                        
                        let testPos = CGPoint(
                            x: basePos.x + offsetX,
                            y: basePos.y + offsetY
                        )
                        
                        // Check collision with existing stones
                        let minDistance = stoneRadius * 1.6 // Minimum distance between stone centers
                        var hasCollision = false
                        
                        for existingStone in stones {
                            let dx = testPos.x - existingStone.pos.x
                            let dy = testPos.y - existingStone.pos.y
                            let distance = sqrt(dx*dx + dy*dy)
                            
                            if distance < minDistance {
                                hasCollision = true
                                break
                            }
                        }
                        
                        if !hasCollision {
                            finalPos = testPos
                            break
                        }
                        
                        attempts += 1
                    }
                    
                    print("🔥 Physics 5: Placing stone at (\(finalPos.x), \(finalPos.y)) after \(attempts) attempts")
                    
                    if isWhiteStones {
                        let pick = 1 + Int(rng.nextRaw() % 5)
                        stones.append(CapturedStone(isWhite: true, imageName: String(format: "clam_%02d", pick), pos: finalPos))
                    } else {
                        stones.append(CapturedStone(isWhite: false, imageName: "stone_black", pos: finalPos))
                    }
                }
                
                print("🔥 Physics 5: Final stone count: \(stones.count)")
            }
        }
    }
}
    
// Physics 6: Grid-Based with Less Stacking (Enhanced Anti-Stacking)
struct Physics6: LidPhysics {
    func simulateStones(
        stones: inout [CapturedStone], 
        targetCount: Int,
        bowlRadius: CGFloat, 
        stoneRadius: CGFloat, 
        gameSeed: UInt64,
        animDuration: Double,
        isWhiteStones: Bool
    ) {
        print("🔥 Physics 6: Target \(targetCount), Current \(stones.count), isWhite: \(isWhiteStones)")
        
        if stones.count > targetCount {
            stones.removeLast(stones.count - targetCount)
        } else if stones.count < targetCount {
            let existingCount = stones.count
            let newStonesCount = targetCount - existingCount
            
            if newStonesCount > 0 {
                print("🔥 Physics 6: Adding \(newStonesCount) stones with enhanced anti-stacking")
                
                // Create a larger, sparser grid with outer preference
                let gridSize = max(4, Int(ceil(sqrt(Double(targetCount)) * 1.3)))  // Larger grid for more spacing
                let spacing = (bowlRadius * 1.6) / CGFloat(gridSize)  // More space between grid points
                var gridPositions: [CGPoint] = []
                
                // Generate grid positions with outer preference
                for row in 0..<gridSize {
                    for col in 0..<gridSize {
                        let x = -bowlRadius * 0.8 + CGFloat(col) * spacing
                        let y = -bowlRadius * 0.8 + CGFloat(row) * spacing
                        let distanceFromCenter = sqrt(x*x + y*y)
                        
                        // Only use positions within the bowl - more conservative boundary
                        if distanceFromCenter < bowlRadius * 0.75 { // Reduced from 0.85 to 0.75
                            gridPositions.append(CGPoint(x: x, y: y))
                        }
                    }
                }
                
                // Sort positions by distance from center (outer positions first for less stacking)
                gridPositions.sort { point1, point2 in
                    let dist1 = sqrt(point1.x*point1.x + point1.y*point1.y)
                    let dist2 = sqrt(point2.x*point2.x + point2.y*point2.y)
                    return dist1 > dist2  // Outer positions first
                }
                
                // Shuffle positions based on seed and stone color, but keep some outer preference
                var rng = SimpleRNG(seed: gameSeed &+ (isWhiteStones ? 23456 : 65432))
                var availablePositions = gridPositions
                
                // Partial shuffle to maintain some outer preference
                let shuffleAmount = min(availablePositions.count / 2, 8)  // Only shuffle first half or 8 positions
                for i in 0..<shuffleAmount {
                    let j = i + Int(rng.nextRaw()) % max(1, availablePositions.count - i)
                    availablePositions.swapAt(i, j)
                }
                
                // Add stones to available positions with collision avoidance
                for i in 0..<min(newStonesCount, availablePositions.count) {
                    let basePos = availablePositions[i]
                    
                    // Check for nearby existing stones and adjust position
                    var finalPos = basePos
                    var attempts = 0
                    let maxAttempts = 5
                    let minDistance = stoneRadius * 2.2  // Minimum distance between stone centers
                    
                    while attempts < maxAttempts {
                        var tooClose = false
                        for existingStone in stones {
                            let dx = finalPos.x - existingStone.pos.x
                            let dy = finalPos.y - existingStone.pos.y
                            let distance = sqrt(dx*dx + dy*dy)
                            
                            if distance < minDistance {
                                tooClose = true
                                break
                            }
                        }
                        
                        if !tooClose {
                            break
                        }
                        
                        // Adjust position away from center and add randomness
                        let randomOffset = CGFloat(20.0 + Double(attempts) * 5.0) // Increase offset with attempts
                        let offsetX = (CGFloat(rng.nextUnit()) - 0.5) * randomOffset
                        let offsetY = (CGFloat(rng.nextUnit()) - 0.5) * randomOffset
                        
                        finalPos = CGPoint(
                            x: basePos.x + offsetX,
                            y: basePos.y + offsetY
                        )
                        
                        // Keep within bowl bounds - more conservative to prevent escaping
                        let distFromCenter = sqrt(finalPos.x*finalPos.x + finalPos.y*finalPos.y)
                        let maxSafeDistance = bowlRadius * 0.7 // Reduced from 0.8 to 0.7 for safety
                        if distFromCenter > maxSafeDistance {
                            let scale = maxSafeDistance / distFromCenter
                            finalPos.x *= scale
                            finalPos.y *= scale
                        }
                        
                        attempts += 1
                    }
                    
                    print("🔥 Physics 6: Placing stone at (\(finalPos.x), \(finalPos.y)) after \(attempts) attempts")
                    
                    if isWhiteStones {
                        let pick = 1 + Int(rng.nextRaw() % 5)
                        stones.append(CapturedStone(isWhite: true, imageName: String(format: "clam_%02d", pick), pos: finalPos))
                    } else {
                        stones.append(CapturedStone(isWhite: false, imageName: "stone_black", pos: finalPos))
                    }
                }
                
                print("🔥 Physics 6: Final stone count: \(stones.count)")
            }
        }
    }
}

// Simple, safe linear congruential generator for consistent random seeding
private struct SimpleRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed  // Avoid zero state
    }
    
    mutating func nextRaw() -> UInt32 {
        // Simple LCG with safe operations
        state = state &* 1103515245 &+ 12345
        return UInt32((state >> 16) & 0x7FFF_FFFF)  // Use upper bits, mask to prevent overflow
    }
    
    mutating func nextUnit() -> Double { 
        Double(nextRaw()) / Double(0x7FFF_FFFF)
    }
}

// MARK: - ContentView Extensions
extension ContentView {
    
    // MARK: - Simple capture tracking (direct board counting)
    private func detectCapturesAndUpdateLids(isMovingForward: Bool = true) {
        let currentMove = player.currentIndex
        let currentBoard = player.board.grid
        
        // Count stones currently on the board
        var whitesOnBoard = 0, blacksOnBoard = 0
        for row in currentBoard {
            for cell in row {
                if cell == .white { whitesOnBoard += 1 }
                else if cell == .black { blacksOnBoard += 1 }
            }
        }
        
        // Count stones that have been played by examining the actual move sequence
        var blackStonesMoved = 0, whiteStonesMoved = 0
        
        // Count initial setup stones
        for (stone, _, _) in player.baseSetup {
            if stone == .black { blackStonesMoved += 1 }
            else if stone == .white { whiteStonesMoved += 1 }
        }
        
        // Count actual moves played (excluding passes)
        for i in 0..<currentMove {
            let (stone, coord) = player.moves[i]
            if coord != nil { // not a pass
                if stone == .black { blackStonesMoved += 1 }
                else if stone == .white { whiteStonesMoved += 1 }
            }
        }
        
        // Captured = stones played - stones on board
        let blacksCapturedByWhite = max(0, blackStonesMoved - blacksOnBoard)
        let whitesCapturedByBlack = max(0, whiteStonesMoved - whitesOnBoard)
        
        // Update tallies
        tallyBByW = blacksCapturedByWhite
        tallyWByB = whitesCapturedByBlack
        
        print("🔥 Fixed Capture: move \(currentMove), played B=\(blackStonesMoved) W=\(whiteStonesMoved), onBoard B=\(blacksOnBoard) W=\(whitesOnBoard), captured B=\(blacksCapturedByWhite) W=\(whitesCapturedByBlack)")
        
        // Cache result
        tallyAtMove[currentMove] = (tallyWByB, tallyBByW)

        // Cache the canonical board for this move (run once per move)
        gridAtMove[player.currentIndex] = currentBoard

        // Use actual bowl radius if available, otherwise fall back to reasonable guess
        let bowlR = currentBowlRadius > 0 ? currentBowlRadius : 64.0  // much smaller fallback
        let stoneR = bowlR * 0.3  // stone radius proportional to bowl
        let pull = bowlR * CGFloat(cfg.centerPullK) * 0.5
        
        print("🔧 PHYSICS CALL: Using bowlR=\(bowlR) (currentBowlRadius=\(currentBowlRadius))")

        // Bring lids to the exact target counts
        syncLidsToTallies(bowlRadius: bowlR, stoneRadius: stoneR, centerPull: pull)
    }

    // Ensure `capUL` / `capLR` counts match the tallies using the selected physics model
    private func syncLidsToTallies(bowlRadius: CGFloat, stoneRadius: CGFloat, centerPull: CGFloat) {
        let targetUL = tallyBByW   // black stones captured by white → UL lid (black bowl - contains black stones)
        let targetLR = tallyWByB   // white stones captured by black → LR lid (white bowl - contains white stones)
        
        // DIAGNOSTIC: Check what we expect vs what we have
        print("🔍 DIAGNOSTIC: syncLidsToTallies called for move \(player.currentIndex)")
        print("🔍 Expected counts - UL (black): \(targetUL), LR (white): \(targetLR)")
        print("🔍 Current counts - UL: \(capUL.count), LR: \(capLR.count)")
        print("🔍 Bowl radius: \(bowlRadius)")
        print("🔍 Cache available: \(layoutAtMove[player.currentIndex] != nil)")
        
        // Check if we have cached positions for this move - if so, restore them instead of running physics
        if let layout = layoutAtMove[player.currentIndex] {
            print("🔄 CACHE HIT: Restoring cached positions for move \(player.currentIndex)")
            print("🔄 Cached counts - black: \(layout.blackStones.count), white: \(layout.whiteStones.count)")
            restoreStonePositionsFromCache(layout: layout, bowlRadius: bowlRadius)
            print("🔄 After restore - UL: \(capUL.count), LR: \(capLR.count)")
            return
        }
        
        // Also check if we're being called during a cache restore operation - restore from cache but skip physics
        if isRestoringFromCache {
            print("🔄 CACHE RESTORE MODE: Looking for cache to restore positions")
            if let layout = layoutAtMove[player.currentIndex] {
                print("🔄 CACHE RESTORE MODE: Restoring cached positions")
                restoreStonePositionsFromCache(layout: layout, bowlRadius: bowlRadius)
                return
            } else {
                print("🔄 CACHE RESTORE MODE: No cache found, skipping")
                return
            }
        }
        
        // Get game seed for consistent randomization
        let hashValue = currentFingerprint().hashValue
        let gameSeed = UInt64(hashValue >= 0 ? hashValue : hashValue == Int.min ? Int.max : -hashValue)
        
        // Apply physics based on activeModel
        let oldULCount = capUL.count
        let oldLRCount = capLR.count
        
        // NOTE: Running physics simulation for new move
        
        // Debug logging
        print("🔥 Physics Debug: Using \(activeModel) (raw=\(activePhysicsModelRaw)), UL: \(oldULCount)→\(targetUL), LR: \(oldLRCount)→\(targetLR)")
        print("🔥 Tallies Debug: tallyBByW=\(tallyBByW), tallyWByB=\(tallyWByB), move=\(player.currentIndex)")
        
        switch activeModel {
        case .model1:
            // AGGRESSIVE ANTI-STACKING: Override problematic slider values with better defaults
            let safeRepel = max(0.5, min(8.0, m1_repel)) // Clamp repel to reasonable range
            let safeCenterPull = m1_centerPullK < 0.001 ? 0.05 : m1_centerPullK // Never allow zero center pull
            let safeDamping = m1_damping > 0.85 ? 0.75 : max(0.3, m1_damping) // Prevent excessive damping
            let safeSpacing = max(1.2, min(3.0, m1_spacing)) // Enforce minimum spacing
            let safeRelaxIters = max(150, m1_relaxIters) // More iterations for better settling
            
            print("🔥 v1.4.3-scaling: Applied slider safety overrides - repel:\(safeRepel), centerPull:\(safeCenterPull), damping:\(safeDamping)")
            
            let physics = Physics1(
                repel: safeRepel,
                spacing: safeSpacing, 
                centerPullK: safeCenterPull,
                relaxIters: safeRelaxIters,
                damping: safeDamping,
                stoneStoneK: m1_stoneStoneK,
                stoneLidK: m1_stoneLidK
            )
            // Upper left lid: black stones
            physics.simulateStones(
                stones: &capUL,
                targetCount: targetUL,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed + 1,
                animDuration: cfg.anim,
                isWhiteStones: false
            )
            // Lower right lid: white stones
            physics.simulateStones(
                stones: &capLR,
                targetCount: targetLR,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed + 2,
                animDuration: cfg.anim,
                isWhiteStones: true
            )
        case .model2:
            let physics = Physics2()
            // Upper left lid: black stones
            physics.simulateStones(
                stones: &capUL,
                targetCount: targetUL,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed + 1,
                animDuration: cfg.anim,
                isWhiteStones: false
            )
            // Lower right lid: white stones
            physics.simulateStones(
                stones: &capLR,
                targetCount: targetLR,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed + 2,
                animDuration: cfg.anim,
                isWhiteStones: true
            )
        case .model3:
            let physics = Physics3()
            // Upper left lid: black stones
            physics.simulateStones(
                stones: &capUL,
                targetCount: targetUL,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed + 1,
                animDuration: cfg.anim,
                isWhiteStones: false
            )
            // Lower right lid: white stones
            physics.simulateStones(
                stones: &capLR,
                targetCount: targetLR,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed + 2,
                animDuration: cfg.anim,
                isWhiteStones: true
            )
        case .model4:
            let physics = Physics4()
            // Upper left lid: black stones
            physics.simulateStones(
                stones: &capUL,
                targetCount: targetUL,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed &+ 1000,  // Safe addition for different seed
                animDuration: cfg.anim,
                isWhiteStones: false
            )
            // Lower right lid: white stones
            physics.simulateStones(
                stones: &capLR,
                targetCount: targetLR,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed &+ 50000, // Safe addition for very different seed
                animDuration: cfg.anim,
                isWhiteStones: true
            )
        case .model5:
            let physics = Physics5()
            // Upper left lid: black stones
            physics.simulateStones(
                stones: &capUL,
                targetCount: targetUL,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed &+ 10000,  // Different seed for grid-based
                animDuration: cfg.anim,
                isWhiteStones: false
            )
            // Lower right lid: white stones
            physics.simulateStones(
                stones: &capLR,
                targetCount: targetLR,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed &+ 90000,  // Very different seed for grid-based
                animDuration: cfg.anim,
                isWhiteStones: true
            )
        case .model6:
            let physics = Physics6() // Enhanced grid-based with anti-stacking
            // Upper left lid: black stones
            physics.simulateStones(
                stones: &capUL,
                targetCount: targetUL,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed &+ 15000,  // Different seed for less stacking
                animDuration: cfg.anim,
                isWhiteStones: false
            )
            // Lower right lid: white stones
            physics.simulateStones(
                stones: &capLR,
                targetCount: targetLR,
                bowlRadius: bowlRadius,
                stoneRadius: stoneRadius,
                gameSeed: gameSeed &+ 95000,  // Very different seed for less stacking
                animDuration: cfg.anim,
                isWhiteStones: true
            )
        }
        
        // Cache the positions after physics simulation (using the actual bowl radius!)
        print("🔥 PHYSICS COMPLETE: Final counts after physics - UL: \(capUL.count), LR: \(capLR.count)")
        print("🔥 PHYSICS COMPLETE: Expected - UL: \(targetUL), LR: \(targetLR)")
        cacheCurrentStonePositions(bowlRadius: bowlRadius)
        
        // Note: Animation is handled by BowlView's internal layout system
        // No explicit animation needed here since stones are added directly to the arrays
    }

    // MARK: - Auto-next (5s after game finishes)
    private func scheduleAutoNextIfNeeded() {
        nextTimer?.cancel()
        nextTimer = nil

        guard autoNext else { return }
        let isAtEnd = player.currentIndex >= player.maxIndex
        guard isAtEnd else { return }

        let work = DispatchWorkItem { advanceToNextGame() }
        nextTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }

    private func advanceToNextGame() {
        nextTimer = nil
        guard !app.games.isEmpty else { return }

        if randomNext {
            pickRandomGame()
        } else {
            if let cur = app.selection,
               let idx = app.games.firstIndex(where: { ($0 as AnyObject) === (cur as AnyObject) }) {
                let next = app.games.indices.contains(idx+1) ? app.games[idx+1] : app.games.first!
                app.selection = next
            } else {
                app.selection = app.games.first
            }
        }

        capUL.removeAll()
        capLR.removeAll()
        lastGrid = nil

        if let g = app.selection?.game { player.load(game: g) }
        player.setPlayInterval(uiMoveDelay)
        player.seek(to: 0)
        if player.isPlaying { player.togglePlay() }
        player.togglePlay()

        bowls.refresh(using: player, gameFingerprint: currentFingerprint())
    }

    // MARK: - Keyboard handling
    private func handleKey(_ event: NSEvent) {
        if event.keyCode == 49 { player.togglePlay(); return } // space
        let isShift = event.modifierFlags.contains(.shift)
        if event.keyCode == 123 { stepBack(isShift ? 10 : 1); return }   // left
        if event.keyCode == 124 { stepForward(isShift ? 10 : 1); return } // right
    }

    private func stepForward(_ n: Int) {
        let target = min(player.currentIndex + n, player.maxIndex)
        player.seek(to: target)
    }
    private func stepBack(_ n: Int) {
        let target = max(player.currentIndex - n, 0)
        player.seek(to: target)
    }

    private func pickRandomGame() {
        guard let item = app.games.randomElement() else { return }
        app.selection = item
        player.load(game: item.game)
        if autoNext && !player.isPlaying { player.togglePlay() }
    }

    // MARK: - Log slider mapping (0.2s ... 10.0s)
    private var delayMin: Double { 0.20 }
    private var delayMax: Double { 10.0 }
    private var delayRangeRatio: Double { delayMax / delayMin }

    private func normFromDelay(_ s: Double) -> Double {
        log(s / delayMin) / log(delayRangeRatio)
    }
    private func delayFromNorm(_ t: Double) -> Double {
        delayMin * pow(delayRangeRatio, t)
    }

    // MARK: - Layout math (symmetric top/bottom)
    private func boardLayout(for size: CGSize)
    -> (padH: CGFloat, padTop: CGFloat, padBottom: CGFloat, side: CGFloat, bottomReserved: CGFloat, topInset: CGFloat) {
        let w = size.width
        let h = size.height
        let bottomReserved: CGFloat = 0

        let minGap: CGFloat = 44
        let usableH = max(1, h - bottomReserved - 2 * minGap)
        let side = max(1, min(w, usableH) * 0.92)

        let extra = max(0, usableH - side)
        let topInset  = minGap + extra / 2
        let padBottom = minGap + extra / 2

        let padH  = max(12, (w - side) / 2)
        let padTop = topInset

        return (padH, padTop, padBottom, side, bottomReserved, topInset)
    }
    
    // MARK: - Scale-Independent Position Management
    
    /// Cache the current stone positions in normalized form (scale-independent)
    private func cacheCurrentStonePositions(bowlRadius: CGFloat) {
        guard bowlRadius > 0 else { 
            print("❌ CACHE ERROR: Invalid bowl radius \(bowlRadius)")
            return 
        }
        
        print("💾 CACHE: Starting cache for move \(player.currentIndex) with bowlRadius=\(bowlRadius)")
        print("💾 CACHE: Current stone counts - UL: \(capUL.count), LR: \(capLR.count)")
        
        // Convert absolute positions to normalized positions (-1.0 to 1.0)
        let normalizedBlackStones = capUL.map { stone in
            let normalized = CGPoint(x: stone.pos.x / bowlRadius, y: stone.pos.y / bowlRadius)
            print("💾 CACHE: Black stone absolute(\(stone.pos.x), \(stone.pos.y)) → normalized(\(normalized.x), \(normalized.y))")
            return normalized
        }
        let normalizedWhiteStones = capLR.map { stone in
            let normalized = CGPoint(x: stone.pos.x / bowlRadius, y: stone.pos.y / bowlRadius)
            print("💾 CACHE: White stone absolute(\(stone.pos.x), \(stone.pos.y)) → normalized(\(normalized.x), \(normalized.y))")
            return normalized
        }
        
        let layout = LidLayout(blackStones: normalizedBlackStones, whiteStones: normalizedWhiteStones)
        layoutAtMove[player.currentIndex] = layout
        
        // Also update the normalized positions in the stone objects
        for i in 0..<capUL.count {
            capUL[i].normalizedPos = normalizedBlackStones[i]
        }
        for i in 0..<capLR.count {
            capLR[i].normalizedPos = normalizedWhiteStones[i]
        }
        
        print("💾 CACHE: Completed caching \(normalizedBlackStones.count) black + \(normalizedWhiteStones.count) white stone positions")
        print("💾 CACHE: Cache now has \(layoutAtMove.count) moves cached")
    }
    
    /// Restore stone positions from cached normalized positions (scale-independent)
    private func restoreStonePositionsFromCache(layout: LidLayout, bowlRadius: CGFloat) {
        guard bowlRadius > 0 else { 
            print("❌ RESTORE ERROR: Invalid bowl radius \(bowlRadius)")
            return 
        }
        
        print("🔄 RESTORE: Starting restore with bowlRadius=\(bowlRadius)")
        print("🔄 RESTORE: Target counts - black: \(layout.blackStones.count), white: \(layout.whiteStones.count)")
        print("🔄 RESTORE: Current counts - UL: \(capUL.count), LR: \(capLR.count)")
        
        // Ensure we have the right number of stones
        while capUL.count < layout.blackStones.count {
            let stone = CapturedStone(isWhite: false, imageName: "stone_black")
            capUL.append(stone)
            print("🔄 RESTORE: Added black stone, now \(capUL.count) total")
        }
        while capUL.count > layout.blackStones.count {
            capUL.removeLast()
            print("🔄 RESTORE: Removed black stone, now \(capUL.count) total")
        }
        
        while capLR.count < layout.whiteStones.count {
            let imageName = "clam_\(String(format: "%02d", Int.random(in: 1...14)))"
            let stone = CapturedStone(isWhite: true, imageName: imageName)
            capLR.append(stone)
            print("🔄 RESTORE: Added white stone, now \(capLR.count) total")
        }
        while capLR.count > layout.whiteStones.count {
            capLR.removeLast()
            print("🔄 RESTORE: Removed white stone, now \(capLR.count) total")
        }
        
        // Convert normalized positions back to absolute positions
        for i in 0..<layout.blackStones.count {
            let normalized = layout.blackStones[i]
            let absolutePos = CGPoint(x: normalized.x * bowlRadius, y: normalized.y * bowlRadius)
            capUL[i].pos = absolutePos
            capUL[i].normalizedPos = normalized
            print("🔄 RESTORE: Black stone \(i): normalized(\(normalized.x), \(normalized.y)) → absolute(\(absolutePos.x), \(absolutePos.y))")
        }
        
        for i in 0..<layout.whiteStones.count {
            let normalized = layout.whiteStones[i]
            let absolutePos = CGPoint(x: normalized.x * bowlRadius, y: normalized.y * bowlRadius)
            capLR[i].pos = absolutePos
            capLR[i].normalizedPos = normalized
            print("🔄 RESTORE: White stone \(i): normalized(\(normalized.x), \(normalized.y)) → absolute(\(absolutePos.x), \(absolutePos.y))")
        }
        
        print("🔄 RESTORE: Completed. Final counts - UL: \(capUL.count), LR: \(capLR.count)")
    }
}
