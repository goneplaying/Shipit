//
//  InstantButtonStyle.swift
//  Shipit
//
//  Created on 29.01.2026.
//

import SwiftUI

/// Button style that provides instant visual feedback on tap
/// Eliminates perceived delay by responding immediately to touch
struct InstantButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Minimal button style with no visual feedback (for custom button implementations)
struct NoFeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

extension View {
    /// Apply instant feedback button style
    func instantFeedback() -> some View {
        self.buttonStyle(InstantButtonStyle())
    }
}
