//
//  TermsConditionsView.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct TermsConditionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Track scroll position at the top
                        ScrollViewOffsetTracker()
                        Text("Please read these terms and conditions carefully before using our service.")
                            .foregroundColor(Colors.text)
                        
                        Text("1. Acceptance of Terms")
                            .font(.headline)
                            .foregroundColor(Colors.text)
                        
                        Text("By accessing and using this service, you accept and agree to be bound by the terms and provision of this agreement.")
                            .foregroundColor(Colors.text)
                        
                        Text("2. Use License")
                            .font(.headline)
                            .foregroundColor(Colors.text)
                        
                        Text("Permission is granted to temporarily use this service for personal, non-commercial transitory viewing only.")
                            .foregroundColor(Colors.text)
                        
                        Text("3. Disclaimer")
                            .font(.headline)
                            .foregroundColor(Colors.text)
                        
                        Text("The materials on this service are provided on an 'as is' basis. We make no warranties, expressed or implied.")
                            .foregroundColor(Colors.text)
                    }
                    .padding()
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    let threshold: CGFloat = -50
                    let newMode: NavigationBarItem.TitleDisplayMode = value < threshold ? .inline : .large
                    if titleDisplayMode != newMode {
                        titleDisplayMode = newMode
                    }
                }
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(titleDisplayMode)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        LucideIcon(IconHelper.close, size: 24)
                            .foregroundColor(Colors.text)
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}

#Preview {
    TermsConditionsView()
}
