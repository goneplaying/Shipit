//
//  RequestCardSlider.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct RequestCardSlider: View {
    let shipment: ShipmentData
    let onPlaceOrder: () -> Void
    @ObservedObject private var watchedManager = WatchedRequestsManager.shared
    
    private var hasOffers: Bool {
        !shipment.offersNumber.isEmpty && shipment.offersNumber != "0"
    }
    
    private var isWatched: Bool {
        watchedManager.isWatched(requestId: shipment.id)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Request section - height: 62px
            HStack(alignment: .bottom, spacing: 16) {
                // Thumbnail image placeholder - 62x62
                RoundedRectangle(cornerRadius: 12)
                    .fill(Colors.backgroundSecondary)
                    .frame(width: 62, height: 62)
                
                // Request data - height: 62px, aligned to bottom (justify-end in Figma)
                VStack(alignment: .leading, spacing: 2) {
                    // Topline: quantity, cargoType, weight - height: 18px
                    HStack(spacing: 4) {
                        Text(shipment.quantity.isEmpty ? "1" : shipment.quantity)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Colors.textSecondary)
                        
                        Text("\(shipment.cargoType),")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Colors.textSecondary)
                        
                        Text(shipment.totalWeight)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Colors.textSecondary)
                    }
                    .frame(height: 18)
                    
                    // Cities - height: 42px (20px per city + 2px gap)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shipment.pickupCity.isEmpty ? shipment.pickupLocation : shipment.pickupCity)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Colors.secondary)
                            .frame(height: 20)
                        
                        Text(shipment.deliveryCity.isEmpty ? shipment.deliveryLocation : shipment.deliveryCity)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Colors.secondary)
                            .frame(height: 20)
                    }
                    .frame(height: 42)
                }
                .frame(height: 62, alignment: .bottom)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Bookmark and distance column - height: 62px, justify-between
                VStack(alignment: .trailing, spacing: 0) {
                    // Bookmark icon - 24x24
                    // Filled -> active (watched), Outline -> not active (not watched)
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
                                LucideIcon(IconHelper.bookmark, size: 30, color: Colors.secondary)
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                    
                    Spacer()
                    
                    // Distance - height: 18px
                    Text(shipment.tripDistance)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Colors.textSecondary)
                        .frame(height: 18)
                }
                .frame(height: 62)
            }
            .frame(height: 62)
            
            // Offers section - height: 40px
            HStack(alignment: .center) {
                // Offer data - height: 40px
                VStack(alignment: .leading, spacing: 2) {
                    if hasOffers {
                        // Number of offers - height: 18px
                        HStack(spacing: 4) {
                            Text(shipment.offersNumber)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Colors.secondary)
                            
                            Text("offers")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Colors.secondary)
                        }
                        .frame(height: 18)
                        
                        // Price range - height: 20px
                        HStack(spacing: 4) {
                            Text(shipment.minOffer.isEmpty ? "0" : shipment.minOffer)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Colors.secondary)
                            
                            Text("–")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Colors.secondary)
                            
                            Text(shipment.maxOffer.isEmpty ? "0" : shipment.maxOffer)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Colors.secondary)
                            
                            Text(shipment.currency.isEmpty ? "PLN" : shipment.currency)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Colors.secondary)
                        }
                        .frame(height: 20)
                    } else {
                        // No offers yet - single line
                        Text("No offers yet")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Colors.secondary)
                            .frame(height: 18)
                    }
                }
                .frame(height: 40)
                
                Spacer()
                
                // Place order button - 120x40
                Button(action: onPlaceOrder) {
                    Text("Place bid")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 40)
                        .background(Colors.button)
                        .cornerRadius(22)
                }
            }
            .frame(height: 40)
        }
        .padding(16)
        .background(Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.border, lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .frame(width: 362, height: 150)
    }
}

#Preview {
    RequestCardSlider(
        shipment: ShipmentData(
            id: "1",
            userUID: "",
            pickupLocation: "Krótka 2/3a, 81-842 Sopot",
            deliveryLocation: "Kasprzaka 31, 01-234 Warszawa",
            pickupCity: "Sopot",
            deliveryCity: "Warszawa",
            tripDistance: "350",
            distanceUnit: "km",
            cargoType: "container",
            title: "Household Boxes",
            quantity: "1",
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
