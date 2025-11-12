import SwiftUI

struct SimpleTextTestView: View {
    @State private var testText: String = ""
    @FocusState private var isTextFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Simple Text Input Test")
                .font(.title)
                .foregroundColor(.white)

            Text("Current text: '\(testText)'")
                .foregroundColor(.yellow)
                .font(.caption)

            // Most basic SwiftUI TextField
            TextField("Type here...", text: $testText)
                .focused($isTextFocused)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            Button("Focus Text Field") {
                isTextFocused = true
            }

            Button("Clear Text") {
                testText = ""
            }

            Text("Focus state: \(isTextFocused ? "YES" : "NO")")
                .foregroundColor(.cyan)
        }
        .frame(width: 400, height: 300)
        .background(Color.black)
        .onAppear {
            print("🧪 SimpleTextTestView appeared")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFocused = true
            }
        }
        .onChange(of: testText) { _, newValue in
            print("🧪 Text changed to: '\(newValue)'")
        }
        .onChange(of: isTextFocused) { _, focused in
            print("🧪 Focus changed to: \(focused)")
        }
    }
}

#Preview {
    SimpleTextTestView()
}