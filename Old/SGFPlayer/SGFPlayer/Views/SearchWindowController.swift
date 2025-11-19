import AppKit
import SwiftUI

class SearchWindowController: NSObject, ObservableObject {
    private var window: NSWindow?
    private var textField: NSTextField?
    private var tableView: NSTableView?
    private weak var appModel: AppModel?

    @Published var searchText: String = ""
    @Published var isWindowOpen: Bool = false
    @Published var filteredGames: [SGFGameWrapper] = []

    var onSearchComplete: (([SGFGameWrapper]) -> Void)?

    init(appModel: AppModel) {
        self.appModel = appModel
        super.init()
    }

    func showSearchWindow() {
        if window != nil {
            window?.orderFront(nil)
            window?.makeKey()
            return
        }

        print("🔍 Creating pure AppKit search window")

        // Create search window
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Game Search"
        window.isReleasedWhenClosed = false
        window.level = .floating

        // Create container view
        let containerView = NSView(frame: window.contentView?.bounds ?? NSRect())

        // Search label
        let searchLabel = NSTextField(frame: NSRect(x: 20, y: 240, width: 360, height: 20))
        searchLabel.stringValue = "Search for games by player name:"
        searchLabel.isEditable = false
        searchLabel.isBordered = false
        searchLabel.backgroundColor = .clear
        searchLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)

        // Search text field
        let textField = NSTextField(frame: NSRect(x: 20, y: 210, width: 360, height: 24))
        textField.placeholderString = "Type player name... (press Enter to apply and close)"
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.target = self
        textField.action = #selector(applySearchAndClose(_:))
        textField.delegate = self

        // Results table
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 20, width: 360, height: 180))
        let tableView = NSTableView()

        // Configure table
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("GameColumn"))
        column.title = "Games"
        column.width = 340
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true

        // Add all views
        containerView.addSubview(searchLabel)
        containerView.addSubview(textField)
        containerView.addSubview(scrollView)

        window.contentView = containerView

        // Store references
        self.window = window
        self.textField = textField
        self.tableView = tableView

        // Set delegate for window close
        window.delegate = self

        // Initialize with all games
        updateFilteredGames()

        // Show window
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textField)

        isWindowOpen = true
        print("🔍 Search window created and shown")
    }

    func hideSearchWindow() {
        window?.orderOut(nil)
        isWindowOpen = false
    }

    @objc private func searchTextChanged(_ sender: NSTextField) {
        let newText = sender.stringValue
        print("🔍 Search text: '\(newText)'")

        DispatchQueue.main.async {
            self.searchText = newText
            self.updateFilteredGames()
        }
    }

    @objc private func applySearchAndClose(_ sender: NSTextField) {
        print("🔍 Enter pressed - applying search and closing")
        applySearchResults()
        hideSearchWindow()
    }

    private func applySearchResults() {
        print("🔍 Applying search results: \(filteredGames.count) games")
        onSearchComplete?(filteredGames)
    }

    private func updateTableView() {
        tableView?.reloadData()
    }

    private func updateFilteredGames() {
        guard let appModel = appModel else {
            filteredGames = []
            return
        }

        if searchText.isEmpty {
            filteredGames = Array(appModel.games)
        } else {
            filteredGames = appModel.games.filter { gameWrapper in
                let info = gameWrapper.game.info
                let blackPlayer = info.playerBlack?.lowercased() ?? ""
                let whitePlayer = info.playerWhite?.lowercased() ?? ""
                let searchLower = searchText.lowercased()
                return blackPlayer.contains(searchLower) || whitePlayer.contains(searchLower)
            }
        }

        updateTableView()
    }

}

// MARK: - NSTextField Delegate (for live filtering)
extension SearchWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            let newText = textField.stringValue
            print("🔍 Live filtering: '\(newText)'")

            DispatchQueue.main.async {
                self.searchText = newText
                self.updateFilteredGames()
            }
        }
    }
}

// MARK: - NSTableView DataSource & Delegate
extension SearchWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredGames.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("GameCell")

        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = identifier

            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.font = NSFont.systemFont(ofSize: 13)

            cellView?.addSubview(textField)
            cellView?.textField = textField

            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        if row < filteredGames.count {
            let game = filteredGames[row]
            let info = game.game.info
            let blackPlayer = info.playerBlack ?? "?"
            let whitePlayer = info.playerWhite ?? "?"
            cellView?.textField?.stringValue = "\(blackPlayer) vs \(whitePlayer)"
        }

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let selectedRow = tableView.selectedRow

        if selectedRow >= 0 && selectedRow < filteredGames.count {
            let selectedGame = filteredGames[selectedRow]

            DispatchQueue.main.async {
                self.appModel?.selection = selectedGame
                print("🔍 Selected game: \(selectedGame.game.info.playerBlack ?? "?") vs \(selectedGame.game.info.playerWhite ?? "?")")
            }
        }
    }
}

// MARK: - NSWindow Delegate
extension SearchWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        isWindowOpen = false
    }
}