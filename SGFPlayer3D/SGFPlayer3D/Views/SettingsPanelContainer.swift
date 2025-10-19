// MARK: - SettingsPanelContainer
// Manages settings panel presentation with slide-in transition
//
// Extracted from ContentView3D.swift (Phase 3)
// Original lines: 393-418 (26 lines)

import SwiftUI

struct SettingsPanelContainer: View {
    @Binding var showSettings: Bool
    @EnvironmentObject var app: AppModel
    @ObservedObject var player: SGFPlayer
    @ObservedObject var settingsVM: SettingsViewModel
    @ObservedObject var soundManager: SoundManager
    @ObservedObject var ogsClient: OGSClient
    @Binding var isPlaying: Bool
    @Binding var randomNext: Bool
    @Binding var autoStartOnLaunch: Bool
    @Binding var loopGames: Bool
    @Binding var playbackSpeed: Double

    // Callbacks
    let onGameSelected: (SGFGameWrapper) -> Void
    let onJitterChanged: () -> Void
    let onSearchResultsChanged: (([SGFGameWrapper]) -> Void)?

    var body: some View {
        HStack {
            SettingsPanelView3D(
                isPanelOpen: $showSettings,
                app: app,
                player: player,
                settingsVM: settingsVM,
                soundManager: soundManager,
                ogsClient: ogsClient,
                autoPlay: $isPlaying,
                randomNext: $randomNext,
                autoStartOnLaunch: $autoStartOnLaunch,
                loopGames: $loopGames,
                playbackSpeed: $playbackSpeed,
                onGameSelected: onGameSelected,
                onJitterChanged: onJitterChanged,
                onSearchResultsChanged: onSearchResultsChanged
            )
            .transition(.move(edge: .leading))

            Spacer()
        }
        .zIndex(100)
    }
}
