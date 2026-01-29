//
//  LaunchScreenView.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct LaunchScreenView: View {
    @EnvironmentObject var splashScreenState: SplashScreenStateManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Orange background matching LaunchScreen.storyboard
                Colors.primary
                    .ignoresSafeArea(.all)
                
                // Logo centered
                Image("shipit-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 170, height: 59)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Colors.primary)
        .onAppear {
            print("🎬 [DEBUG] LaunchScreenView: View body rendered and appeared")
        }
    }
}

#Preview {
    LaunchScreenView()
}
