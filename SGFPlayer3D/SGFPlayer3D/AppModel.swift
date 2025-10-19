// MARK: - File: AppModel.swift
import AppKit
import AVFoundation
import Combine
import Foundation
import SwiftUI

// MARK: - ViewMode Enum
enum ViewMode: String, CaseIterable, Identifiable {
    case view2D = "2D"
    case view3D = "3D"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .view2D: return "2D Board"
        case .view3D: return "3D Board"
        }
    }
}

final class AppModel: ObservableObject {
    // Audio player for stone click sound
    private var stoneClickPlayer: AVAudioPlayer?
    @Published var folderURL: URL? {
        didSet { persistFolderURL() }
    }
    @Published var games: [SGFGameWrapper] = []
    @Published var selection: SGFGameWrapper? = nil {
        didSet { persistLastGame() }
    }

    // Active playlist - either all games or filtered search results
    @Published var activePlaylist: [SGFGameWrapper] = []

    // Game cache manager for pre-calculated states
    @Published var gameCacheManager = GameCacheManager()

    // CENTRALIZED GAME STATE - Shared between 2D and 3D views
    @Published var player = SGFPlayer()

    // View mode selection - persisted across app launches
    @AppStorage("viewMode") var viewMode: ViewMode = .view3D

    // CENTRALIZED OGS COMPONENTS - Shared between 2D and 3D views
    @Published var ogsClient = OGSClient()
    @Published var timeControl = TimeControlManager()
    @Published var ogsGame: OGSGameViewModel?

    // UI State for OGS live play
    @Published var showPreGameOverlay: Bool = false

    private let folderKey = "sgfplayer.folderURL"
    private let lastGameKey = "sgfplayer.lastGame"
    private var cancellables: Set<AnyCancellable> = []

    init() {
        restoreFolderURL()
        if let url = folderURL { loadFolder(url) }
        setupAudio()

        // Initialize OGS game view model with shared dependencies
        ogsGame = OGSGameViewModel(ogsClient: ogsClient, player: player, timeControl: timeControl)
        NSLog("AppModel: 🎮 Initialized OGSGameViewModel")
    }

    private func setupAudio() {
        guard let soundURL = Bundle.main.url(forResource: "Stone_click_1", withExtension: "mp3") else {
            print("❗️ Stone click sound file not found")
            return
        }

        do {
            stoneClickPlayer = try AVAudioPlayer(contentsOf: soundURL)
            stoneClickPlayer?.prepareToPlay()
        } catch {
            print("❗️ Failed to load stone click sound: \(error)")
        }
    }

    func playStoneClickSound() {
        stoneClickPlayer?.play()
    }

    func promptForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose a folder containing .sgf files"

        print("🔍 FOLDER PICKER: About to show panel")
        let result = panel.runModal()
        print("🔍 FOLDER PICKER: Panel result: \(result == .OK ? "OK" : "Cancel"), URL: \(panel.url?.path ?? "none")")

        if result == .OK, let url = panel.url {
            print("🔍 FOLDER PICKER: Setting folderURL to \(url.path)")
            folderURL = url
            loadFolder(url)
        } else {
            print("🔍 FOLDER PICKER: User cancelled or no URL selected")
        }
    }

    func reload() {
        if let url = folderURL { loadFolder(url) }
    }

    func selectGame(_ gameWrapper: SGFGameWrapper) {
        selection = gameWrapper
        gameCacheManager.loadGame(gameWrapper.game, fingerprint: gameWrapper.fingerprint)

        // Load game into centralized player (shared between 2D and 3D views)
        player.load(game: gameWrapper.game)

        // Pre-calculate nearby games in background (limited to prevent crashes)
        if let currentIndex = games.firstIndex(where: { $0.id == gameWrapper.id }) {
            // Pre-calculate only next 2 games to avoid overloading with large folders
            let gamesAhead = games.count - currentIndex - 1
            if gamesAhead > 0 {
                for i in 1...min(2, gamesAhead) {
                    let nextIndex = currentIndex + i
                    if nextIndex < games.count {
                        let nextGame = games[nextIndex]
                        gameCacheManager.preCalculateGame(nextGame.game, fingerprint: nextGame.fingerprint)
                    }
                }
            }
        }
    }

    private func loadFolder(_ url: URL) {
        let fm = FileManager.default

        // Recursively find all .sgf files
        var sgfURLs: [URL] = []
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "sgf" {
                    sgfURLs.append(fileURL)
                }
            }
        }

        // Sort by path
        sgfURLs.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        var parsed: [SGFGameWrapper] = []
        for fileURL in sgfURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                let tree = try SGFParser.parse(text: text)
                let game = SGFGame.from(tree: tree)
                parsed.append(.init(url: fileURL, game: game))
            } catch {
                print("❗️Failed to parse \(fileURL.lastPathComponent):", error)
            }
        }
        games = parsed
        activePlaylist = parsed  // Initialize active playlist with all games

        // Pre-calculate upcoming games in background while setting current selection
        if let first = parsed.first {
            // Try to restore last selected game, otherwise use first game
            let restoredSelection = restoreLastGame(from: parsed) ?? first
            selection = restoredSelection
            gameCacheManager.loadGame(restoredSelection.game, fingerprint: restoredSelection.fingerprint)

            // Start pre-calculating other games in background (limit to prevent crashes with large folders)
            let maxPreCalculate = min(3, parsed.count) // Only pre-calculate first 3 games max
            for index in 1..<maxPreCalculate {
                let gameWrapper = parsed[index]
                gameCacheManager.preCalculateGame(gameWrapper.game, fingerprint: gameWrapper.fingerprint)
            }
        } else {
            selection = nil
        }
    }

    private func persistFolderURL() {
        guard let url = folderURL else {
            UserDefaults.standard.removeObject(forKey: folderKey)
            return
        }
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: folderKey)
        } catch {
            print("❗️Failed to persist folder URL: \(error)")
        }
    }

    private func restoreFolderURL() {
        guard let bookmark = UserDefaults.standard.data(forKey: folderKey) else { return }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
            if url.startAccessingSecurityScopedResource() {
                folderURL = url
            }
        } catch {
            print("❗️Failed to restore folder URL: \(error)")
        }
    }

    private func persistLastGame() {
        guard let selectedGame = selection else {
            UserDefaults.standard.removeObject(forKey: lastGameKey)
            return
        }
        UserDefaults.standard.set(selectedGame.url.lastPathComponent, forKey: lastGameKey)
    }

    private func restoreLastGame(from games: [SGFGameWrapper]) -> SGFGameWrapper? {
        guard let lastGameName = UserDefaults.standard.string(forKey: lastGameKey) else { return nil }
        return games.first { $0.url.lastPathComponent == lastGameName }
    }
}

struct SGFGameWrapper: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let game: SGFGame

    // Generate a stable fingerprint for caching
    var fingerprint: String {
        return url.lastPathComponent + "_" + String(url.path.hashValue)
    }

    static func == (lhs: SGFGameWrapper, rhs: SGFGameWrapper) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}