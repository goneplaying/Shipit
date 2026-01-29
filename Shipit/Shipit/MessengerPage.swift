//
//  MessengerPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct MessengerPage: View {
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    var body: some View {
        ZStack {
            Colors.background
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Text("Messenger")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Colors.text)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
        }
        .navigationTitle("Messenger")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        MessengerPage()
    }
}
