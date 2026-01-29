//
//  SplashScreenStateManager.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

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
        print("⏳ [DEBUG] SplashScreenStateManager: Starting dismiss countdown (2 seconds)")
        // Wait for app initialization
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await MainActor.run {
            print("✅ [DEBUG] SplashScreenStateManager: Countdown finished, changing state to .finished")
            withAnimation {
                self.state = .finished
            }
        }
    }
}
