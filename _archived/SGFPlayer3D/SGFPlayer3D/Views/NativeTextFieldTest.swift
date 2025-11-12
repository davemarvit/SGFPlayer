import SwiftUI
import AppKit

struct NativeTextFieldTest: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        print("🔧 Creating native NSTextField")
        let textField = NSTextField()

        // Basic configuration
        textField.stringValue = text
        textField.placeholderString = "Type here (native NSTextField)..."
        textField.delegate = context.coordinator

        // Essential properties for input
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.systemFont(ofSize: 16)

        // Input handling
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textDidChange(_:))

        // AGGRESSIVE focus management - force this to work in SwiftUI context
        textField.focusRingType = .default
        textField.refusesFirstResponder = false
        textField.needsDisplay = true

        // Force focus after a delay to override SwiftUI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = textField.window {
                print("🔧 Forcing text field to become first responder")
                window.makeFirstResponder(textField)
                textField.becomeFirstResponder()
            }
        }

        print("🔧 NSTextField configured with aggressive focus - editable: \(textField.isEditable), selectable: \(textField.isSelectable)")

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
        var parent: NativeTextFieldTest

        init(_ parent: NativeTextFieldTest) {
            self.parent = parent
        }

        @objc func textDidChange(_ sender: NSTextField) {
            print("🔧 textDidChange: '\(sender.stringValue)'")
            parent.text = sender.stringValue
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                print("🔧 controlTextDidChange: '\(textField.stringValue)'")
                parent.text = textField.stringValue
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            print("🔧 Text field began editing")
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            print("🔧 Text field ended editing")
        }
    }
}

struct NativeTextTestView: View {
    @State private var testText: String = ""
    @State private var focusField: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Native NSTextField Test")
                .font(.title)
                .foregroundColor(.white)

            Text("Current text: '\(testText)'")
                .foregroundColor(.yellow)
                .font(.caption)

            NativeTextFieldTest(text: $testText)
                .frame(width: 300, height: 30)

            Button("Clear") {
                testText = ""
            }

            Text("Length: \(testText.count)")
                .foregroundColor(.cyan)
        }
        .frame(width: 400, height: 200)
        .background(Color.black)
        .onAppear {
            print("🔧 NativeTextTestView appeared")
        }
        .onChange(of: testText) { _, newValue in
            print("🔧 State text changed: '\(newValue)'")
        }
    }
}

#Preview {
    NativeTextTestView()
}