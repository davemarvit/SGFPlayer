// MARK: - Game Search View
// Extracted from SettingsPanelView to reduce complexity

import SwiftUI
import AppKit

// FIXED: Using pure AppKit NSTextField since SwiftUI TextField has input issues

struct GameSelectionSection: View {
    @ObservedObject var app: AppModel
    @State private var searchText: String = ""
    @State private var searchResults: [SGFGameWrapper] = []
    @FocusState private var isSearchFocused: Bool
    @StateObject private var searchController: SearchWindowController

    var onSearchResultsChanged: (([SGFGameWrapper]) -> Void)? = nil

    init(app: AppModel, onSearchResultsChanged: (([SGFGameWrapper]) -> Void)? = nil) {
        self.app = app
        self.onSearchResultsChanged = onSearchResultsChanged
        self._searchController = StateObject(wrappedValue: SearchWindowController(appModel: app))
        print("🔍 GameSelectionSection INIT called - games count: \(app.games.count)")
    }

    var filteredGames: [SGFGameWrapper] {
        if searchResults.isEmpty {
            return Array(app.games)
        } else {
            return searchResults
        }
    }

    var body: some View {
        print("🔍 GameSelectionSection body rendering - searchText: '\(searchText)'")
        return VStack(alignment: .leading, spacing: 8) {
            // Search using AppKit window (workaround for SwiftUI text input issues)
            VStack(alignment: .leading, spacing: 4) {
                Text("Game Search:")
                    .foregroundColor(.white)
                    .font(.caption)

                Button("🔍 Open Search Window") {
                    searchController.onSearchComplete = { results in
                        searchResults = results
                        onSearchResultsChanged?(results)
                        print("🔍 Applied \(results.count) search results to panel and navigation")
                    }
                    searchController.showSearchWindow()
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(6)

                if searchController.isWindowOpen {
                    Text("Search window is open - type and press Enter")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else if !searchResults.isEmpty {
                    Text("Showing \(searchResults.count) search results")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                } else {
                    Text("Click to search by player name")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .onAppear {
                print("🔍 TextField appeared")
            }
            .onChange(of: searchText) { _, newValue in
                print("🔍 Search text changed: '\(newValue)'")
            }
            .onChange(of: isSearchFocused) { _, focused in
                print("🔍 Search focus changed: \(focused)")
            }

            // Game list with dark styling (scrollable)
            if !filteredGames.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, gameWrapper in
                            GameListItem(
                                gameWrapper: gameWrapper,
                                isSelected: app.selection?.id == gameWrapper.id,
                                onTap: { app.selection = gameWrapper }
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 200)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.3))
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                Text("No games available or no matches found")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.3))
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            }

            // Show metadata only if there's a selection
            if let selection = app.selection {
                GameMetadataView(gameWrapper: selection)
            }
        }
    }
}

struct GameListItem: View {
    let gameWrapper: SGFGameWrapper
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let playerInfo = formatGameDisplayText(gameWrapper.game.info)

        HStack {
            Text(playerInfo)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? Color.cyan.opacity(0.9) : .white.opacity(0.9))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.cyan.opacity(0.15) : Color.clear)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct GameMetadataView: View {
    let gameWrapper: SGFGameWrapper

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Game information
            let info = gameWrapper.game.info
            let moveCount = gameWrapper.game.moves.count

            HStack {
                Text("Moves: \(moveCount)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                if let date = info.date {
                    Text("Date: \(date)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            if let result = info.result {
                Text("Result: \(result)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

        }
        .padding(.top, 4)
    }
}

private func formatGameDisplayText(_ info: SGFGame.Info) -> String {
    let blackPlayer = info.playerBlack ?? "?"
    let whitePlayer = info.playerWhite ?? "?"
    return "\(blackPlayer) vs \(whitePlayer)"
}

// MARK: - Working AppKit Search Field (fixes SwiftUI text input issue)
struct WorkingSearchField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        print("✅ Creating working AppKit search field")
        let textField = NSTextField()
        textField.placeholderString = "Search players..."
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textChanged(_:))
        textField.focusRingType = .default
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: WorkingSearchField

        init(_ parent: WorkingSearchField) {
            self.parent = parent
        }

        @objc func textChanged(_ sender: NSTextField) {
            print("✅ Search text changed: '\(sender.stringValue)'")
            parent.text = sender.stringValue
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                print("✅ Search control changed: '\(textField.stringValue)'")
                parent.text = textField.stringValue
            }
        }
    }
}

// MARK: - AppKit TextField Implementation with proper workarounds (LEGACY)
struct AppKitSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onFocusChange: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        print("🔍 AppKitSearchField makeNSView called")
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.isContinuous = true
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textChanged(_:))

        // Enable focus and proper input handling
        textField.focusRingType = .default
        textField.needsDisplay = true

        print("🔍 NSTextField configured - isEditable: \(textField.isEditable)")
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.placeholderString = placeholder

        // CRITICAL FIX from Stack Overflow: Update coordinator reference
        context.coordinator.parent = self
        print("🔍 updateNSView called - text: '\(text)', coordinator updated")
    }

    func makeCoordinator() -> Coordinator {
        print("🔍 AppKitSearchField makeCoordinator called")
        return Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AppKitSearchField

        init(_ parent: AppKitSearchField) {
            self.parent = parent
            print("🔍 Coordinator INIT - parent text: '\(parent.text)'")
        }

        @objc func textChanged(_ sender: NSTextField) {
            print("🔍 textChanged action called - new text: '\(sender.stringValue)'")
            parent.text = sender.stringValue
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                print("🔍 controlTextDidChange called - new text: '\(textField.stringValue)'")
                parent.text = textField.stringValue
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            print("🔍 controlTextDidBeginEditing called")
            parent.onFocusChange?(true)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            print("🔍 controlTextDidEndEditing called")
            parent.onFocusChange?(false)
        }

        // Additional delegate methods for better input handling
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            print("🔍 doCommandBy called with selector: \(commandSelector)")
            return false // Allow normal processing
        }
    }
}