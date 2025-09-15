// MARK: - File: AppModel.swift
import AppKit
import Combine
import Foundation

final class AppModel: ObservableObject {
    @Published var folderURL: URL? {
        didSet { persistFolderURL() }
    }
    @Published var games: [SGFGameWrapper] = []
    @Published var selection: SGFGameWrapper? = nil {
        didSet { persistLastGame() }
    }

    // Game cache manager for pre-calculated states
    @Published var gameCacheManager = GameCacheManager()

    private let folderKey = "sgfplayer.folderURL"
    private let lastGameKey = "sgfplayer.lastGame"
    private var cancellables: Set<AnyCancellable> = []

    init() {
        restoreFolderURL()
        if let url = folderURL { loadFolder(url) }
    }

    func promptForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose a folder containing .sgf files"
        if panel.runModal() == .OK, let url = panel.url {
            folderURL = url
            loadFolder(url)
        }
    }

    func reload() {
        if let url = folderURL { loadFolder(url) }
    }

    func selectGame(_ gameWrapper: SGFGameWrapper) {
        selection = gameWrapper
        gameCacheManager.loadGame(gameWrapper.game, fingerprint: gameWrapper.fingerprint)

        // Pre-calculate nearby games in background (limited to prevent crashes)
        if let currentIndex = games.firstIndex(where: { $0.id == gameWrapper.id }) {
            // Pre-calculate only next 2 games to avoid overloading with large folders
            for i in 1...min(2, games.count - currentIndex - 1) {
                let nextIndex = currentIndex + i
                if nextIndex < games.count {
                    let nextGame = games[nextIndex]
                    gameCacheManager.preCalculateGame(nextGame.game, fingerprint: nextGame.fingerprint)
                }
            }
        }
    }

    private func loadFolder(_ url: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            games = []
            selection = nil
            return
        }
        let sgfURLs = items.filter { $0.pathExtension.lowercased() == "sgf" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

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

