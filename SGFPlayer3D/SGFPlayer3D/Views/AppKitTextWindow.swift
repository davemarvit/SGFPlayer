import AppKit
import SwiftUI

class AppKitTextWindowController: NSObject {
    var window: NSWindow?
    var textField: NSTextField?

    func showTestWindow() {
        print("🧪 Creating pure AppKit test window")

        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 200),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AppKit Text Input Test"
        window.isReleasedWhenClosed = false

        // Create text field
        let textField = NSTextField(frame: NSRect(x: 50, y: 100, width: 300, height: 30))
        textField.placeholderString = "Type here (pure AppKit)..."
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.systemFont(ofSize: 16)
        textField.target = self
        textField.action = #selector(textFieldChanged(_:))

        // Create label
        let label = NSTextField(frame: NSRect(x: 50, y: 140, width: 300, height: 20))
        label.stringValue = "Pure AppKit Text Field Test"
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear

        // Create output label
        let outputLabel = NSTextField(frame: NSRect(x: 50, y: 60, width: 300, height: 20))
        outputLabel.stringValue = "Type something above..."
        outputLabel.isEditable = false
        outputLabel.isBordered = false
        outputLabel.backgroundColor = .clear

        // Add to window
        window.contentView?.addSubview(label)
        window.contentView?.addSubview(textField)
        window.contentView?.addSubview(outputLabel)

        // Store references
        self.window = window
        self.textField = textField

        // Show window
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Focus the text field
        DispatchQueue.main.async {
            window.makeFirstResponder(textField)
        }

        print("🧪 AppKit window shown and text field focused")
    }

    @objc func textFieldChanged(_ sender: NSTextField) {
        print("🧪 AppKit text changed: '\(sender.stringValue)'")

        // Update output label if it exists
        if let outputLabel = window?.contentView?.subviews.compactMap({ $0 as? NSTextField }).last {
            outputLabel.stringValue = "You typed: '\(sender.stringValue)'"
        }
    }
}

struct AppKitTextTestButton: View {
    private let windowController = AppKitTextWindowController()

    var body: some View {
        VStack {
            Text("AppKit Text Input Test")
                .font(.title)
                .foregroundColor(.white)

            Button("Open Pure AppKit Test Window") {
                windowController.showTestWindow()
            }
            .padding()

            Text("This will open a separate window using pure AppKit")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 400, height: 200)
        .background(Color.black)
    }
}

#Preview {
    AppKitTextTestButton()
}