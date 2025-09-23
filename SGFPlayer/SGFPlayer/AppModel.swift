// MARK: - File: AppModel.swift
import AppKit
import Combine
import Foundation

final class AppModel: ObservableObject {
    @Published var folderURL: URL? {
        didSet { handleFolderChange() }
    }
    @Published var games: [SGFGameWrapper] = []
    @Published var selection: SGFGameWrapper? = nil {
        didSet { fileSystemService.persistLastSelectedGame(selection) }
    }

    // Game cache manager for pre-calculated states
    @Published var gameCacheManager = GameCacheManager()

    // File system service for folder and file management
    private let fileSystemService = FileSystemService()
    private var cancellables: Set<AnyCancellable> = []

    init() {
        folderURL = fileSystemService.currentFolderURL
        if let url = folderURL { loadFolder(url) }
    }

    func promptForFolder() {
        print("🔍 APP MODEL: promptForFolder() called")
        let result = fileSystemService.promptForFolder()

        switch result {
        case .selected(let url):
            print("🔍 APP MODEL: Folder selected: \(url.path)")
            folderURL = url
            loadFolder(url)
        case .cancelled:
            print("🔍 APP MODEL: User cancelled folder selection")
        case .error(let error):
            print("❗️ APP MODEL: Folder selection error: \(error.localizedDescription)")
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
        print("🔍 APP MODEL: loadFolder() called with: \(url.path)")
        do {
            let gameWrappers = try fileSystemService.loadGamesFromCurrentFolder()
            print("🔍 APP MODEL: Found \(gameWrappers.count) games in folder")
            games = gameWrappers

            // Pre-calculate upcoming games in background while setting current selection
            if let first = gameWrappers.first {
                print("🔍 APP MODEL: Setting first game as selection: \(first.url.lastPathComponent)")
                // Try to restore last selected game, otherwise use first game
                let restoredSelection = fileSystemService.restoreLastSelectedGame(from: gameWrappers) ?? first
                selection = restoredSelection
                gameCacheManager.loadGame(restoredSelection.game, fingerprint: restoredSelection.fingerprint)

                // Start pre-calculating other games in background (limit to prevent crashes with large folders)
                let maxPreCalculate = min(3, gameWrappers.count) // Only pre-calculate first 3 games max
                for index in 1..<maxPreCalculate {
                    let gameWrapper = gameWrappers[index]
                    gameCacheManager.preCalculateGame(gameWrapper.game, fingerprint: gameWrapper.fingerprint)
                }
            } else {
                print("🔍 APP MODEL: No games found in folder")
                selection = nil
            }
        } catch {
            print("❗️ APP MODEL: Failed to load folder: \(error.localizedDescription)")
            games = []
            selection = nil
        }
    }

    private func handleFolderChange() {
        if let url = folderURL {
            let result = fileSystemService.setCurrentFolder(url)
            switch result {
            case .selected(_):
                // Success - folder set and persisted
                break
            case .cancelled:
                // This shouldn't happen in programmatic setting
                break
            case .error(let error):
                print("❗️ APP MODEL: Failed to set folder: \(error.localizedDescription)")
            }
        }
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

