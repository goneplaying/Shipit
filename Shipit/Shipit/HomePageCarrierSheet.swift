//
//  HomePageCarrierSheet.swift
//  Shipit
//
//  Created by Assistant on 10.01.2026.
//

import SwiftUI

struct HomePageCarrierSheet: View {
    @Binding var searchText: String
    var onSearchTapped: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            HomePageCarrierSheetHeader(
                title: "Looking for a load?",
                placeholder: "What's your destination?",
                text: $searchText,
                onTapped: {
                    onSearchTapped?()
                }
            )
        }
    }
}

#Preview {
    HomePageCarrierSheet(searchText: .constant(""))
}
