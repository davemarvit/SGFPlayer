import SwiftUI

/// Chat panel for OGS game communication
struct ChatPanel: View {
    @ObservedObject var ogsClient: OGSClient
    @State private var messageText: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .foregroundColor(.white)
                }
            }
            .padding(10)
            .background(Color.blue.opacity(0.8))

            if isExpanded {
                // Message list
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if ogsClient.chatMessages.isEmpty {
                                Text("No messages yet")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                    .padding()
                            } else {
                                ForEach(ogsClient.chatMessages) { message in
                                    ChatMessageRow(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 200)
                    .background(Color.black.opacity(0.3))
                    .onChange(of: ogsClient.chatMessages.count) { _ in
                        // Auto-scroll to bottom when new message arrives
                        if let lastMessage = ogsClient.chatMessages.last {
                            withAnimation {
                                scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input field
                HStack(spacing: 8) {
                    TextField("Type message...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            sendMessage()
                        }

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ogsClient.currentGameID == nil)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ogsClient.currentGameID == nil ? Color.gray : Color.blue)
                    .cornerRadius(8)
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
            }
        }
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .shadow(radius: 5)
        .onAppear {
            // Start expanded if there are messages
            isExpanded = !ogsClient.chatMessages.isEmpty
        }
    }

    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty,
              let gameID = ogsClient.currentGameID else {
            return
        }

        ogsClient.sendChatMessage(gameID: gameID, message: trimmedMessage)
        messageText = ""
    }
}

/// Individual chat message row
struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Username and timestamp
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if !message.isFromMe {
                        Text(message.username)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(message.isFromMe ? .green : .blue)
                    }
                    Text(message.timeString)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    if message.isFromMe {
                        Text(message.username)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }

                // Message text
                Text(message.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(message.isFromMe ? Color.green.opacity(0.3) : Color.blue.opacity(0.3))
                    .cornerRadius(8)
            }

            if message.isFromMe {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isFromMe ? .trailing : .leading)
    }
}

#Preview {
    ChatPanel(ogsClient: OGSClient())
        .frame(width: 300)
        .padding()
        .background(Color.gray.opacity(0.2))
}
