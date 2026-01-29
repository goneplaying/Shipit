//
//  HelpSupportPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct HelpSupportPage: View {
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    var body: some View {
        ZStack {
            Colors.background
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Text("Help & Support")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Colors.text)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        HelpSupportPage()
    }
}
