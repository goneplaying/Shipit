//
//  ScrollableToolbarModifier.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

// PreferenceKey to track scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Helper view to track scroll position
struct ScrollViewOffsetTracker: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).minY
                )
        }
        .frame(height: 0)
    }
}

// Helper function to add scroll tracking to any ScrollView content
extension View {
    func trackScrollOffset(titleDisplayMode: Binding<NavigationBarItem.TitleDisplayMode>, threshold: CGFloat = -50) -> some View {
        self
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                // When scrolled down, value becomes negative
                let newMode: NavigationBarItem.TitleDisplayMode = value < threshold ? .inline : .large
                
                if titleDisplayMode.wrappedValue != newMode {
                    titleDisplayMode.wrappedValue = newMode
                }
            }
    }
}
