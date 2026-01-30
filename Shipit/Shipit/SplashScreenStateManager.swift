//
//  SplashScreenStateManager.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import UIKit

enum SplashScreenState {
    case firstStep
    case secondStep
    case finished
}

class SplashScreenStateManager: ObservableObject {
    @Published var state: SplashScreenState = .firstStep {
        didSet {
            print("🔄 [DEBUG] SplashScreenStateManager: State changed from \(oldValue) to \(state)")
        }
    }
    
    init() {
        print("🏁 [DEBUG] SplashScreenStateManager: Initialized with state: \(state)")
    }
    
    func dismiss() async {
        print("⏳ [DEBUG] SplashScreenStateManager: Starting dismiss countdown with preloading")
        
        // Preload critical components during splash screen
        await preloadComponents()
        
        // Wait for minimum splash duration (1.5 seconds total for smoother experience)
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        await MainActor.run {
            print("✅ [DEBUG] SplashScreenStateManager: Preloading complete, changing state to .finished")
            withAnimation {
                self.state = .finished
            }
        }
    }
    
    private func preloadComponents() async {
        print("🚀 [DEBUG] SplashScreenStateManager: Preloading app components")
        
        // Preload on background thread to not block UI
        await Task.detached(priority: .userInitiated) {
            // Warm up the text rendering system
            let _ = NSAttributedString(string: "Preload", attributes: [
                .font: UIFont.systemFont(ofSize: 17)
            ])
            
            // Warm up number formatter (used in phone number input)
            let _ = NumberFormatter()
            
            // Warm up date formatter (used in shipment display)
            let _ = DateFormatter()
            
            print("✅ [DEBUG] SplashScreenStateManager: Text and formatting systems preloaded")
        }.value
        
        // Preload on main thread (UI-related)
        await MainActor.run {
            // Force UITextInputTraits initialization
            let _ = UITextField()
            
            print("✅ [DEBUG] SplashScreenStateManager: UI input systems preloaded")
        }
    }
}
