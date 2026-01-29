//
//  JobsPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct JobsPage: View {
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    var body: some View {
        ZStack {
            Colors.background
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Text("Jobs")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Colors.text)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
        }
        .navigationTitle("Jobs")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        JobsPage()
    }
}
