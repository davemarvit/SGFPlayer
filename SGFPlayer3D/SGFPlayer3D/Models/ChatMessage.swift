import Foundation

/// Represents a chat message in an OGS game
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let username: String
    let message: String
    let timestamp: Date
    let isFromMe: Bool

    init(username: String, message: String, timestamp: Date = Date(), isFromMe: Bool = false) {
        self.id = UUID()
        self.username = username
        self.message = message
        self.timestamp = timestamp
        self.isFromMe = isFromMe
    }

    /// Formatted timestamp for display (e.g., "14:23")
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
