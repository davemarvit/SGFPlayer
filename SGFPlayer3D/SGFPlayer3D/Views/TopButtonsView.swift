//
//  TopButtonsView.swift
//  SGFPlayer3D
//
//  Created by Claude Code on 2025-11-19.
//  Extracted from ContentView as part of incremental refactoring.
//

import SwiftUI

/// Overlay view for top buttons (settings button in upper left)
struct TopButtonsView: View {
    @Binding var isPanelOpen: Bool
    var buttonsVisible: Bool

    var body: some View {
        VStack {
            HStack {
                // Settings button (upper left)
                Button {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        isPanelOpen.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .imageScale(.large)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)
                .padding(.top, 20)
                .opacity(buttonsVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: buttonsVisible ? 0.2 : 0.5), value: buttonsVisible)

                Spacer()
            }
            Spacer()
        }
    }
}

#Preview {
    TopButtonsView(isPanelOpen: .constant(false), buttonsVisible: true)
}
