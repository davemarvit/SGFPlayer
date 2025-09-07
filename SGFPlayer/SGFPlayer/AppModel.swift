// MARK: - File: AppModel.swift
import AppKit
import Combine
import Foundation

final class AppModel: ObservableObject {
    @Published var folderURL: URL? {
        didSet { persistFolderURL() }
    }
    @Published var games: [SGFGameWrapper] = []
    @Published var selection: SGFGameWrapper? = nil

    private let folderKey = "sgfplayer.folderURL"
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
        selection = parsed.first
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
}

struct SGFGameWrapper: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let game: SGFGame

    static func == (lhs: SGFGameWrapper, rhs: SGFGameWrapper) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

