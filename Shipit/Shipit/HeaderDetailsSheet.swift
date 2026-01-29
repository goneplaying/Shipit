//
//  HeaderDetailsSheet.swift
//  Shipit
//
//  Created on 30.12.2025.
//

import SwiftUI

enum DetailsTab: String, CaseIterable {
    case basicInfo = "Basic Info"
    case photos = "Photos"
    case questions = "Questions"
}

struct HeaderDetailsSheet: View {
    let shipment: ShipmentData
    let onBookmarkToggle: () -> Void
    let onClose: () -> Void
    @Binding var selectedTab: DetailsTab
    @ObservedObject private var watchedManager = WatchedRequestsManager.shared
    
    private var isWatched: Bool {
        watchedManager.isWatched(requestId: shipment.id)
    }
    
    // Format title with quantity: always show "Title x quantity"
    private var titleWithQuantity: String {
        let title = shipment.title.isEmpty ? shipment.cargoType : shipment.title
        let quantity = shipment.quantity.isEmpty ? "1" : shipment.quantity
        return "\(title) x \(quantity)"
    }
    
    // Split title into lines for display
    private var titleLines: [String] {
        let fullTitle = shipment.title.isEmpty ? shipment.cargoType : shipment.title
        // Split by spaces and create lines (simple approach - can be improved)
        let words = fullTitle.components(separatedBy: " ")
        if words.count <= 1 {
            return [fullTitle]
        } else {
            // Split into two lines roughly in the middle
            let midPoint = words.count / 2
            let firstLine = words[0..<midPoint].joined(separator: " ")
            let secondLine = words[midPoint..<words.count].joined(separator: " ")
            return [firstLine, secondLine]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Buttons container at top - justify-between
            HStack(alignment: .center) {
                // Close button on left - 44x44, rounded 30px, background #f4f4f4, padding 6px
                Button(action: {
                    HapticFeedback.light()
                    onClose()
                }) {
                    LucideIcon(IconHelper.close, size: 24, color: Colors.text)
                        .frame(width: 24, height: 24)
                }
                .frame(width: 44, height: 44)
                .background(Colors.backgroundQuaternary)
                .clipShape(Circle())
                
                Spacer()
                
                // Right side buttons: map and bookmark
                HStack(spacing: 12) {
                    // Map button - 44x44, rounded 30px, background #f4f4f4, padding 6px
                    Button(action: {
                        HapticFeedback.light()
                        // TODO: Add map action
                    }) {
                        LucideIcon(IconHelper.map, size: 24, color: Colors.text)
                            .frame(width: 24, height: 24)
                    }
                    .frame(width: 44, height: 44)
                    .background(Colors.backgroundQuaternary)
                    .clipShape(Circle())
                    
                    // Bookmark button - 44x44, rounded 30px, background #f4f4f4, padding 6px
                    Button(action: {
                        HapticFeedback.light()
                        onBookmarkToggle()
                    }) {
                        Group {
                            if isWatched {
                                // Filled bookmark for active state
                                Image("bookmark-filled")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(Colors.primary)
                            } else {
                                // Outline bookmark for not active state
                                LucideIcon(IconHelper.bookmark, size: 24, color: Colors.secondary)
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                    .frame(width: 44, height: 44)
                    .background(Colors.backgroundQuaternary)
                    .clipShape(Circle())
                }
            }
            
            // Body section
            VStack(alignment: .leading, spacing: 8) {
                // Topline: trip color icon + cargo type
                HStack(alignment: .center, spacing: 6) {
                    // Trip color icon - 20x20, rounded 10px, padding 4px, icon 12x12
                    RoundedRectangle(cornerRadius: 10)
                        .fill(shipment.tripColor.isEmpty ? Colors.primary : Color(hex: shipment.tripColor))
                        .frame(width: 20, height: 20)
                        .overlay(
                            LucideIcon(shipment.icon.isEmpty ? IconHelper.shippingbox : shipment.icon, size: 12, color: .white)
                        )
                    
                    // Cargo type (16px, regular, #6c6c6c)
                    Text(shipment.cargoType.isEmpty ? "N/A" : shipment.cargoType)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(21 - 16)
                        .tracking(-0.31)
                        .lineLimit(1)
                }
                
                // Title - Large Title/Bold (34px, bold, line height 41, letter spacing 0.4)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(titleLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(Colors.secondary)
                            .lineSpacing(41 - 34)
                            .tracking(0.4)
                    }
                }
            }
            
            // Tab bar - 24px spacing from title
            HStack(spacing: 8) {
                ForEach(DetailsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        HapticFeedback.light()
                        selectedTab = tab
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: selectedTab == tab ? .medium : .regular))
                            .foregroundColor(selectedTab == tab ? .white : Colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTab == tab ? Colors.secondary : Color.clear)
                            )
                    }
                }
            }
            .padding(.top, 8) // 8px spacing from title (matching ExchangePage)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(Colors.background)
    }
}
