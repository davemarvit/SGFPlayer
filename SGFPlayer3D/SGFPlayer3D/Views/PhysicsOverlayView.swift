//
//  PhysicsOverlayView.swift
//  SGFPlayer3D
//
//  Created by Claude Code on 2025-11-19.
//  Extracted from ContentView as part of incremental refactoring.
//

import SwiftUI

/// Overlay view for physics demonstration panel
struct PhysicsOverlayView: View {
    @Binding var showPhysicsDemo: Bool

    var body: some View {
        Group {
            if showPhysicsDemo {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea()

                    PhysicsIntegrationDemo()
                        .frame(width: 800, height: 900)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .shadow(radius: 20)

                    VStack {
                        HStack {
                            Spacer()
                            Button("Close Demo") {
                                showPhysicsDemo = false
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                        Spacer()
                    }
                }
                .zIndex(20)
            }
        }
    }
}

#Preview {
    PhysicsOverlayView(showPhysicsDemo: .constant(true))
}
