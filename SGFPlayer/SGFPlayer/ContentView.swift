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

struct ContentView: View {
    @EnvironmentObject var app: AppModel
    @StateObject private var player = SGFPlayer()
    @StateObject private var bowls = PlayerCapturesAdapter()

    @State private var isPanelOpen: Bool = false
    @State private var marginPercent: CGFloat = 0.041

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
        case model1 = 1, model2 = 2, model3 = 3, model4 = 4
        var id: Int { rawValue }
        var label: String { "Physics \(rawValue)" }
        var storagePrefix: String { "m\(rawValue)_" }
    }

    @AppStorage("activePhysicsModel") private var activePhysicsModelRaw: Int = PhysicsModel.model1.rawValue
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
    @AppStorage("m1_damping") private var m1_damping: Double = 0.90
    @AppStorage("m1_wallK") private var m1_wallK: Double = 0.50
    @AppStorage("m1_anim") private var m1_anim: Double = 0.14

    // --- Model 2
    @AppStorage("m2_repel") private var m2_repel: Double = 1.60
    @AppStorage("m2_spacing") private var m2_spacing: Double = 2.12
    @AppStorage("m2_centerPullK") private var m2_centerPullK: Double = 0.0028
    @AppStorage("m2_relaxIters") private var m2_relaxIters: Int = 12
    @AppStorage("m2_pressureRadiusXR") private var m2_pressureRadiusXR: Double = 2.6
    @AppStorage("m2_pressureKFactor") private var m2_pressureKFactor: Double = 0.25
    @AppStorage("m2_maxStepXR") private var m2_maxStepXR: Double = 0.06
    @AppStorage("m2_damping") private var m2_damping: Double = 0.90
    @AppStorage("m2_wallK") private var m2_wallK: Double = 0.50
    @AppStorage("m2_anim") private var m2_anim: Double = 0.14

    // --- Model 3
    @AppStorage("m3_repel") private var m3_repel: Double = 1.60
    @AppStorage("m3_spacing") private var m3_spacing: Double = 2.12
    @AppStorage("m3_centerPullK") private var m3_centerPullK: Double = 0.0028
    @AppStorage("m3_relaxIters") private var m3_relaxIters: Int = 12
    @AppStorage("m3_pressureRadiusXR") private var m3_pressureRadiusXR: Double = 2.6
    @AppStorage("m3_pressureKFactor") private var m3_pressureKFactor: Double = 0.25
    @AppStorage("m3_maxStepXR") private var m3_maxStepXR: Double = 0.06
    @AppStorage("m3_damping") private var m3_damping: Double = 0.90
    @AppStorage("m3_wallK") private var m3_wallK: Double = 0.50
    @AppStorage("m3_anim") private var m3_anim: Double = 0.14

    // --- Model 4
    @AppStorage("m4_repel") private var m4_repel: Double = 1.60
    @AppStorage("m4_spacing") private var m4_spacing: Double = 2.12
    @AppStorage("m4_centerPullK") private var m4_centerPullK: Double = 0.0028
    @AppStorage("m4_relaxIters") private var m4_relaxIters: Int = 12
    @AppStorage("m4_pressureRadiusXR") private var m4_pressureRadiusXR: Double = 2.6
    @AppStorage("m4_pressureKFactor") private var m4_pressureKFactor: Double = 0.25
    @AppStorage("m4_maxStepXR") private var m4_maxStepXR: Double = 0.06
    @AppStorage("m4_damping") private var m4_damping: Double = 0.90
    @AppStorage("m4_wallK") private var m4_wallK: Double = 0.50
    @AppStorage("m4_anim") private var m4_anim: Double = 0.14

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
    }

    private var cfg: LidPhysics {
        switch activeModel {
        case .model1: return .init(
            repel: m1_repel, spacing: m1_spacing, centerPullK: m1_centerPullK, relaxIters: m1_relaxIters,
            pressureRadiusXR: m1_pressureRadiusXR, pressureKFactor: m1_pressureKFactor,
            maxStepXR: m1_maxStepXR, damping: m1_damping, wallK: m1_wallK, anim: m1_anim
        )
        case .model2: return .init(
            repel: m2_repel, spacing: m2_spacing, centerPullK: m2_centerPullK, relaxIters: m2_relaxIters,
            pressureRadiusXR: m2_pressureRadiusXR, pressureKFactor: m2_pressureKFactor,
            maxStepXR: m2_maxStepXR, damping: m2_damping, wallK: m2_wallK, anim: m2_anim
        )
        case .model3: return .init(
            repel: m3_repel, spacing: m3_spacing, centerPullK: m3_centerPullK, relaxIters: m3_relaxIters,
            pressureRadiusXR: m3_pressureRadiusXR, pressureKFactor: m3_pressureKFactor,
            maxStepXR: m3_maxStepXR, damping: m3_damping, wallK: m3_wallK, anim: m3_anim
        )
        case .model4: return .init(
            repel: m4_repel, spacing: m4_spacing, centerPullK: m4_centerPullK, relaxIters: m4_relaxIters,
            pressureRadiusXR: m4_pressureRadiusXR, pressureKFactor: m4_pressureKFactor,
            maxStepXR: m4_maxStepXR, damping: m4_damping, wallK: m4_wallK, anim: m4_anim
        )
        }
    }

    @State private var uiMoveDelay: Double = 0.75   // seconds
    @State private var debugLayout = false

    // Advanced disclosure state
    @State private var advancedExpanded: Bool = false
    @State private var advStonesOpen:   Bool = true
    @State private var advGridOpen:     Bool = true
    @State private var advShadowsOpen:  Bool = false
    @State private var advBowlOpen:     Bool = true

    // --- Captured stones in lids ---
    private struct CapturedStone: Identifiable {
        let id = UUID()
        let isWhite: Bool
        let imageName: String  // "stone_black" or "clam_0X"
        var pos: CGPoint       // relative to lid center, in points of the view
    }
    @State private var capUL: [CapturedStone] = [] // white stones captured by black → upper-left lid
    @State private var capLR: [CapturedStone] = [] // black stones captured by white → lower-right lid
    @State private var lastGrid: [[Stone?]]? = nil

    // Cumulative capture tallies and per-move cache (so jumping is stable)
    @State private var tallyWByB: Int = 0   // white stones captured by black
    @State private var tallyBByW: Int = 0   // black stones captured by white
    @State private var tallyAtMove: [Int:(w:Int,b:Int)] = [0:(0,0)]
    @State private var gridAtMove: [Int : [[Stone?]]] = [:]   // cached canonical boards by move
    @State private var lastIndex: Int = 0

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
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(app.games.isEmpty)
                    .opacity(app.games.isEmpty ? 0.5 : 1.0)

                    Spacer()
                }
                .padding(.leading, 12)
                .padding(.top, 40)
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
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.trailing, 12)
                .padding(.top, 40)
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

            // NEW: seed bowls deterministically for the newly-selected game
            bowls.refresh(using: player, gameFingerprint: currentFingerprint())
        }
        .onChange(of: player.currentIndex) { _, _ in
            // If we’ve seen this move before, restore exact tallies + grid and sync lids.
            if let t = tallyAtMove[player.currentIndex],
               let g = gridAtMove[player.currentIndex] {

                tallyWByB = t.w
                tallyBByW = t.b
                lastGrid = g

                // quick geometry guess; true sizes will be reapplied next render pass
                let boardSideGuess: CGFloat = 640
                let lidSizeGuess = boardSideGuess * lidScale
                let bowlR = lidSizeGuess * 0.46
                let stoneSize = lidSizeGuess * 0.58
                let stoneR = stoneSize * 0.5
                let pull = lidSizeGuess * CGFloat(cfg.centerPullK)
                syncLidsToTallies(bowlRadius: bowlR, stoneRadius: stoneR, centerPull: pull)

                scheduleAutoNextIfNeeded()
                bowls.refresh(using: player, gameFingerprint: currentFingerprint())
                return
            }

            // First time at this move: compute deltas, then cache truth.
            detectCapturesAndUpdateLids()
            tallyAtMove[player.currentIndex] = (tallyWByB, tallyBByW)
            gridAtMove[player.currentIndex] = player.board.grid

            scheduleAutoNextIfNeeded()
            bowls.refresh(using: player, gameFingerprint: currentFingerprint())
        }
        .onChange(of: player.isPlaying) { _, _ in
            scheduleAutoNextIfNeeded()
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

                    // Folder hint capsule
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .frame(height: 110)
                        .overlay(
                            Text("Pick a folder of SGF files.")
                                .foregroundStyle(.secondary)
                        )

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
                        Button(player.isPlaying ? "||" : ">") { player.togglePlay() }
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
                            DisclosureGroup("Stones") {
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

                            // GRID & LIDS -------------------------------------------------------
                            DisclosureGroup("Grid & Lids") {
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

                            // SHADOWS -----------------------------------------------------------
                            DisclosureGroup("Shadows") {
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

                            // PHYSICS ENGINES ---------------------------------------------------
                            DisclosureGroup("Bowl physics") {
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
                                    physicsEditor(title: "Physics 1",
                                                  isActive: activeModel == .model1,
                                                  repel: $m1_repel,
                                                  spacing: $m1_spacing,
                                                  centerPullK: $m1_centerPullK,
                                                  relaxIters: $m1_relaxIters,
                                                  pressureRadiusXR: $m1_pressureRadiusXR,
                                                  pressureKFactor: $m1_pressureKFactor,
                                                  maxStepXR: $m1_maxStepXR,
                                                  damping: $m1_damping,
                                                  wallK: $m1_wallK,
                                                  anim: $m1_anim)

                                    physicsEditor(title: "Physics 2",
                                                  isActive: activeModel == .model2,
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
                                }
                                .padding(.top, 6)
                            }

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
        repel: Binding<Double>,
        spacing: Binding<Double>,
        centerPullK: Binding<Double>,
        relaxIters: Binding<Int>,
        pressureRadiusXR: Binding<Double>,
        pressureKFactor: Binding<Double>,
        maxStepXR: Binding<Double>,
        damping: Binding<Double>,
        wallK: Binding<Double>,
        anim: Binding<Double>
    ) -> some View {
        DisclosureGroup(title) {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Repulsion"); Spacer(); Text(String(format: "%.2f", repel.wrappedValue)).monospacedDigit() }
                Slider(value: repel, in: 0.25...6.00, step: 0.01).controlSize(.large) // doubled (0.5→3.0) → (0.25→6.0)

                HStack { Text("Target spacing (× radius)"); Spacer(); Text(String(format: "%.2f", spacing.wrappedValue)).monospacedDigit() }
                Slider(value: spacing, in: 0.10...4.80, step: 0.01).controlSize(.large) // doubled

                HStack { Text("Center pull (× lid size)"); Spacer(); Text(String(format: "%.4f", centerPullK.wrappedValue)).monospacedDigit() }
                Slider(value: centerPullK, in: 0.0000...0.0120, step: 0.0001).controlSize(.large) // doubled

                // --- NEW “spread / squish” controls (ranges doubled) ---
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
                    let ulStones = capUL.map { s in
                        BowlView.LidStone(id: s.id, imageName: s.imageName, offset: s.pos)
                    }
                    let lrStones = capLR.map { s in
                        BowlView.LidStone(id: s.id, imageName: s.imageName, offset: s.pos)
                    }

                    // UL bowl with tunables from ACTIVE physics model
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
                        relaxIterations: cfg.relaxIters,
                        // spread/squish
                        pressureRadiusXR: CGFloat(cfg.pressureRadiusXR),
                        pressureKFactor:  CGFloat(cfg.pressureKFactor),
                        maxStepXR:        CGFloat(cfg.maxStepXR),
                        damping:          CGFloat(cfg.damping),
                        wallK:            CGFloat(cfg.wallK),
                        animDuration:     cfg.anim
                    )

                    // LR bowl with same ACTIVE physics model
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
                        relaxIterations: cfg.relaxIters,
                        pressureRadiusXR: CGFloat(cfg.pressureRadiusXR),
                        pressureKFactor:  CGFloat(cfg.pressureKFactor),
                        maxStepXR:        CGFloat(cfg.maxStepXR),
                        damping:          CGFloat(cfg.damping),
                        wallK:            CGFloat(cfg.wallK),
                        animDuration:     cfg.anim
                    )

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
                        let meta = parts.compactMap { $0 }.joined(separator: "    •    ")

                        Text(meta)
                            .font(.system(size: fontSize))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .truncationMode(.tail)
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

    // MARK: - Capture detection + lid physics (tally-based; stable under scrubbing)
    private func detectCapturesAndUpdateLids() {
        let cur = player.board.grid
        let prev = lastGrid ?? cur
        lastGrid = cur
        guard cur.count == prev.count, !cur.isEmpty else { return }

        // Net differences from prev→cur (works for scrubbing or stepping)
        var removedWhites = 0, removedBlacks = 0
        var restoredWhites = 0, restoredBlacks = 0

        for y in 0..<cur.count {
            let w = min(cur[y].count, prev[y].count)
            for x in 0..<w {
                switch (prev[y][x], cur[y][x]) {
                case (.white, nil): removedWhites += 1
                case (.black, nil): removedBlacks += 1
                case (nil, .white): restoredWhites += 1
                case (nil, .black): restoredBlacks += 1
                default: break
                }
            }
        }

        // Update cumulative tallies (can go up or down when scrubbing)
        tallyWByB = max(0, tallyWByB + removedWhites - restoredWhites)
        tallyBByW = max(0, tallyBByW + removedBlacks - restoredBlacks)
        tallyAtMove[player.currentIndex] = (tallyWByB, tallyBByW)

        // Cache the canonical board for this move (run once per move)
        gridAtMove[player.currentIndex] = cur

        // Quick geometry guess (true sizes will be reapplied next render pass)
        let boardSideGuess: CGFloat = 640
        let lidSizeGuess = boardSideGuess * lidScale
        let bowlR = lidSizeGuess * 0.46
        let stoneSize = lidSizeGuess * 0.58
        let stoneR = stoneSize * 0.5
        let pull = lidSizeGuess * CGFloat(cfg.centerPullK)

        // Bring lids to the exact target counts
        syncLidsToTallies(bowlRadius: bowlR, stoneRadius: stoneR, centerPull: pull)
    }

    // Ensure `capUL` / `capLR` counts match the tallies; animate changes; quick settle.
    private func syncLidsToTallies(bowlRadius: CGFloat, stoneRadius: CGFloat, centerPull: CGFloat) {
        // One quick local settle
        func settle(_ stones: inout [CapturedStone]) {
            guard !stones.isEmpty else { return }
            let iters = max(1, cfg.relaxIters)
            let minD   = stoneRadius * CGFloat(cfg.spacing)
            let repelK = CGFloat(cfg.repel)

            for _ in 0..<iters {
                // pairwise repulsion
                for i in 0..<stones.count {
                    for j in (i+1)..<stones.count {
                        var dx = stones[j].pos.x - stones[i].pos.x
                        var dy = stones[j].pos.y - stones[i].pos.y
                        var d  = sqrt(dx*dx + dy*dy)
                        if d < 0.0001 { d = 0.0001; dx = minD; dy = 0 }
                        if d < minD {
                            let push = (minD - d) * 0.5 * repelK
                            let ux = dx / d, uy = dy / d
                            stones[i].pos.x -= ux * push
                            stones[i].pos.y -= uy * push
                            stones[j].pos.x += ux * push
                            stones[j].pos.y += uy * push
                        }
                    }
                }
                // center pull + soft wall
                for k in 0..<stones.count {
                    var nx = stones[k].pos.x
                    var ny = stones[k].pos.y
                    nx += (-nx) * centerPull
                    ny += (-ny) * centerPull
                    let r = sqrt(nx*nx + ny*ny)
                    let maxR = max(0.0, bowlRadius - stoneRadius)
                    if r > maxR {
                        let s = maxR / r
                        nx *= s; ny *= s
                    }
                    // simple velocity damping (implicit) scaled by cfg.damping:
                    stones[k].pos = CGPoint(x: nx * CGFloat(cfg.damping), y: ny * CGFloat(cfg.damping))
                }
            }
        }

        let targetUL = tallyWByB   // white stones captured by black → UL lid
        let targetLR = tallyBByW   // black stones captured by white → LR lid

        // UL lid
        if capUL.count > targetUL {
            capUL.removeLast(capUL.count - targetUL)
            withAnimation(.easeOut(duration: 0.12)) { capUL = capUL }
        } else if capUL.count < targetUL {
            let need = targetUL - capUL.count
            for _ in 0..<need {
                let a = Double.random(in: 0..<(Double.pi * 2))
                let r = Double.random(in: 0...Double(bowlRadius * 0.15))
                let start = CGPoint(x: CGFloat(cos(a))*CGFloat(r), y: CGFloat(sin(a))*CGFloat(r))
                let pick = Int.random(in: 1...5)
                capUL.append(CapturedStone(isWhite: true,
                                           imageName: String(format: "clam_%02d", pick),
                                           pos: start))
            }
            settle(&capUL)
            withAnimation(.easeOut(duration: cfg.anim)) { capUL = capUL }
        }

        // LR lid
        if capLR.count > targetLR {
            capLR.removeLast(capLR.count - targetLR)
            withAnimation(.easeOut(duration: 0.12)) { capLR = capLR }
        } else if capLR.count < targetLR {
            let need = targetLR - capLR.count
            for _ in 0..<need {
                let a = Double.random(in: 0..<(Double.pi * 2))
                let r = Double.random(in: 0...Double(bowlRadius * 0.15))
                let start = CGPoint(x: CGFloat(cos(a))*CGFloat(r), y: CGFloat(sin(a))*CGFloat(r))
                capLR.append(CapturedStone(isWhite: false, imageName: "stone_black", pos: start))
            }
            settle(&capLR)
            withAnimation(.easeOut(duration: cfg.anim)) { capLR = capLR }
        }
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
    private let delayMin: Double = 0.20
    private let delayMax: Double = 10.0
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
}
