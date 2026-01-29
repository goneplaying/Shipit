//
//  HapticFeedback.swift
//  Shipit
//
//  Created on 30.12.2025.
//

import UIKit

struct HapticFeedback {
    /// Provides light haptic feedback for interactive elements
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Provides medium haptic feedback
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Provides heavy haptic feedback
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Provides selection haptic feedback (for pickers, switches, etc.)
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// Provides notification haptic feedback (for success, warning, error)
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
