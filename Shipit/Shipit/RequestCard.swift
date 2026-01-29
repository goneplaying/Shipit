//
//  RequestCard.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

enum CardStyle {
    case map      // For ExchangeMapPage: 16px padding, rounded corners, full border
    case list     // For ExchangePage: 20px padding, full border
}

struct RequestCard: View {
    let shipment: ShipmentData
    let onPlaceOrder: () -> Void
    var showTopBorder: Bool = true
    var sortOption: String? = nil
    var sortValue: String? = nil
    var rangeDistance: Double? = nil // Distance from reference location to pickup location in km
    var cardStyle: CardStyle = .list // Default to list style
    @ObservedObject private var watchedManager = WatchedRequestsManager.shared
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    
    // Computed properties for styling based on card style
    private var cardPadding: CGFloat {
        cardStyle == .map ? 16 : 20
    }
    
    private var regularFontSize: CGFloat { 16 }
    private var regularLineHeight: CGFloat { 21 }
    private var regularLetterSpacing: CGFloat { -0.31 }
    
    private var cityFontSize: CGFloat { 17 }
    private var cityLineHeight: CGFloat { 22 }
    private var cityLetterSpacing: CGFloat { -0.43 }
    
    private var hasOffers: Bool {
        let offersNum = Int(shipment.offersNumber) ?? 0
        return offersNum > 0
    }
    
    private var isWatched: Bool {
        watchedManager.isWatched(requestId: shipment.id)
    }
    
    // Format title with quantity: always show "Title x quantity"
    private var titleWithQuantity: String {
        let title = shipment.title.isEmpty ? shipment.cargoType : shipment.title
        let quantity = shipment.quantity.isEmpty ? "1" : shipment.quantity
        return "\(title) x \(quantity)"
    }
    
    // Format date field based on pickupDate and deliveryDate
    private var dateFieldText: String {
        let pickupDate = shipment.pickupDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let deliveryDate = shipment.deliveryDate.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if pickupDate.isEmpty && deliveryDate.isEmpty {
            return "Flexible dates"
        } else if !pickupDate.isEmpty && deliveryDate.isEmpty {
            return formatDate(pickupDate)
        } else if pickupDate.isEmpty && !deliveryDate.isEmpty {
            return formatDate(deliveryDate)
        } else {
            // Both dates are set - show range
            return "\(formatDate(pickupDate)) - \(formatDate(deliveryDate))"
        }
    }
    
    // Format offers text with plural
    private var offersText: String {
        let offersNum = Int(shipment.offersNumber) ?? 0
        if offersNum == 1 {
            return "\(offersNum) offer"
        } else {
            return "\(offersNum) offers"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        guard !dateString.isEmpty else {
            return ""
        }
        
        // Try ISO 8601 format first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        // Try ISO 8601 without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        // Try simple date format (e.g., "2026-01-02")
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = simpleFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        // If parsing fails, return the original string
        return dateString
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Body section
            VStack(alignment: .leading, spacing: 4) {
                // Top section: trip color icon, title/cities, bookmark
                HStack(alignment: .top, spacing: 16) {
                    // Trip color icon - 62x62
                    RoundedRectangle(cornerRadius: 12)
                        .fill(shipment.tripColor.isEmpty ? Colors.primary : Color(hex: shipment.tripColor))
                        .frame(width: 62, height: 62)
                        .overlay(
                            LucideIcon(shipment.icon.isEmpty ? IconHelper.shippingbox : shipment.icon, size: 24, color: .white)
                        )
                    
                    // Request header - title above cities
                    VStack(alignment: .leading, spacing: 2) {
                        // Title with quantity - shown above cities (16px, regular, #6c6c6c)
                        Text(titleWithQuantity)
                            .font(.system(size: regularFontSize, weight: .regular))
                            .foregroundColor(Colors.textSecondary)
                            .lineLimit(1)
                            .lineSpacing(regularLineHeight - regularFontSize)
                            .tracking(regularLetterSpacing)
                            .frame(height: 18)
                        
                        // Cities - height: 42px (17px, semibold, #222)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shipment.pickupCity.isEmpty ? shipment.pickupLocation : shipment.pickupCity)
                                .font(.system(size: cityFontSize, weight: .semibold))
                                .foregroundColor(Colors.secondary)
                                .lineSpacing(cityLineHeight - cityFontSize)
                                .tracking(cityLetterSpacing)
                                .frame(height: 20)
                            
                            Text(shipment.deliveryCity.isEmpty ? shipment.deliveryLocation : shipment.deliveryCity)
                                .font(.system(size: cityFontSize, weight: .semibold))
                                .foregroundColor(Colors.secondary)
                                .lineSpacing(cityLineHeight - cityFontSize)
                                .tracking(cityLetterSpacing)
                                .frame(height: 20)
                        }
                        .frame(height: 42)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Bookmark container - 24x24 at top
                    // Filled -> active (watched), Outline -> not active (not watched)
                    VStack(alignment: .trailing, spacing: 0) {
                        Button(action: {
                            watchedManager.toggleWatched(requestId: shipment.id)
                        }) {
                            Group {
                                if isWatched {
                                    // Filled bookmark for active state - using custom SVG asset
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
                        
                        Spacer()
                    }
                    .frame(height: 66)
                }
                
                // Bottom section: spacer, request details
                HStack(alignment: .top, spacing: 16) {
                    // Spacer - 62x62 (matches icon size)
                    Spacer()
                        .frame(width: 62, height: 62)
                    
                    // Request details - no gap between items (spacing: 0)
                    VStack(alignment: .leading, spacing: 0) {
                        // Cargo type (16px, regular, #6c6c6c)
                        Text(shipment.cargoType.isEmpty ? "N/A" : shipment.cargoType)
                            .font(.system(size: regularFontSize, weight: .regular))
                            .foregroundColor(Colors.textSecondary)
                            .lineSpacing(regularLineHeight - regularFontSize)
                            .tracking(regularLetterSpacing)
                        
                        // Date field (16px, regular, #6c6c6c, HStack with spacing 4)
                        HStack(spacing: 4) {
                            if dateFieldText.contains(" - ") {
                                // Date range - split into parts
                                let dateParts = dateFieldText.components(separatedBy: " - ")
                                if dateParts.count == 2 {
                                    Text(dateParts[0])
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                    Text("-")
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                    Text(dateParts[1])
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                } else {
                                    Text(dateFieldText)
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                }
                            } else {
                                Text(dateFieldText)
                                    .font(.system(size: regularFontSize, weight: .regular))
                                    .foregroundColor(Colors.textSecondary)
                                    .lineSpacing(regularLineHeight - regularFontSize)
                                    .tracking(regularLetterSpacing)
                            }
                        }
                        
                        // Distance and weight with range distance
                        HStack(alignment: .center) {
                            // Left: Trip distance and weight (16px, regular, #6c6c6c)
                            HStack(spacing: 4) {
                                // Distance
                                HStack(spacing: 4) {
                                    Text(shipment.tripDistance)
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                    
                                    Text("\(shipment.distanceUnit.isEmpty ? "km" : shipment.distanceUnit),")
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                }
                                
                                // Weight
                                HStack(spacing: 4) {
                                    Text(shipment.totalWeight)
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                    
                                    Text(shipment.weightUnit.isEmpty ? "kg" : shipment.weightUnit)
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                }
                            }
                            
                            Spacer()
                            
                            // Right: Range distance with icon (16px, regular, #6c6c6c, icon 16x16)
                            if let rangeDistance = rangeDistance {
                                HStack(spacing: 8) {
                                    Text(String(format: "%.0f km", rangeDistance))
                                        .font(.system(size: regularFontSize, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .lineSpacing(regularLineHeight - regularFontSize)
                                        .tracking(regularLetterSpacing)
                                    
                                    LucideIcon(IconHelper.radius, size: 16, color: Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Offers section - background #f4f4f4, padding 16px horizontal, 12px vertical, rounded 12
            HStack(alignment: .center, spacing: 0) {
                // Offer data - left side
                if hasOffers {
                    VStack(alignment: .leading, spacing: 2) {
                        // Number of offers (16px, regular, #6c6c6c)
                        Text(offersText)
                            .font(.system(size: regularFontSize, weight: .regular))
                            .foregroundColor(Colors.textSecondary)
                            .lineSpacing(regularLineHeight - regularFontSize)
                            .tracking(regularLetterSpacing)
                        
                        // Price range (17px, regular, #222)
                        let offersNum = Int(shipment.offersNumber) ?? 0
                        if offersNum == 1 {
                            // Single offer - show only minOffer
                            HStack(spacing: 4) {
                                Text(shipment.minOffer.isEmpty ? "0" : shipment.minOffer)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Colors.secondary)
                                
                                Text(shipment.currency.isEmpty ? "PLN" : shipment.currency)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Colors.secondary)
                            }
                        } else {
                            // Multiple offers - show range
                            HStack(spacing: 4) {
                                Text(shipment.minOffer.isEmpty ? "0" : shipment.minOffer)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Colors.secondary)
                                
                                Text("-")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Colors.secondary)
                                
                                Text(shipment.maxOffer.isEmpty ? "0" : shipment.maxOffer)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Colors.secondary)
                                
                                Text(shipment.currency.isEmpty ? "PLN" : shipment.currency)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Colors.secondary)
                            }
                        }
                    }
                } else {
                    // No offers yet
                    Text("No offers yet")
                        .font(.system(size: regularFontSize, weight: .regular))
                        .foregroundColor(Colors.tertiary)
                        .lineSpacing(regularLineHeight - regularFontSize)
                        .tracking(regularLetterSpacing)
                }
                
                Spacer()
                
                // Place a bid button - 120px wide, 40px height, rounded 22px, background #222, text white, 15px medium
                Button(action: onPlaceOrder) {
                    Text("Place a bid")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 40)
                        .background(Colors.secondary)
                        .cornerRadius(22)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Colors.backgroundQuaternary)
            .cornerRadius(12)
        }
        .padding(cardPadding)
        .background(Colors.background)
        .overlay(
            Group {
                if showTopBorder {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Colors.divider)
                }
            },
            alignment: .top
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardStyle == .map ? 16 : 16)
                .stroke(Colors.border, lineWidth: 1)
        )
        .cornerRadius(cardStyle == .map ? 16 : 16)
    }
}

#Preview {
    RequestCard(
        shipment: ShipmentData(
            id: "1",
            userUID: "",
            pickupLocation: "Krótka 2/3a, 81-842 Sopot",
            deliveryLocation: "Kasprzaka 31, 01-234 Warszawa",
            pickupCity: "Sopot",
            deliveryCity: "Warszawa",
            tripDistance: "350",
            distanceUnit: "km",
            cargoType: "Parcels",
            title: "Household Boxes",
            quantity: "10",
            totalWeight: "3",
            weightUnit: "t",
            offersNumber: "2",
            minOffer: "800",
            maxOffer: "1.800",
            currency: "PLN",
            createdAt: "2025-12-29T16:40:00+01:00",
            pickupDate: "2026-01-02",
            deliveryDate: "",
            tripColor: "#D729AE",
            icon: "package",
            totalDimensions: "",
            shippersName: "",
            shippersSurname: "",
            shippersRating: "",
            shippersLanguage: ""
        ),
        onPlaceOrder: {}
    )
    .padding()
}
