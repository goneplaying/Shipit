//
//  HomePageSelectionSheet.swift
//  Shipit
//
//  Created by Assistant on 10.01.2026.
//

import SwiftUI
import CoreLocation

struct HomePageSelectionSheet: View {
    let selectedShipments: [ShipmentData]
    let pickupCoordinates: [String: CLLocationCoordinate2D]
    @Binding var scrollToFirst: Bool
    let onRemoveShipment: (String) -> Void
    let onDismiss: (() -> Void)?
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var watchedManager = WatchedRequestsManager.shared
    @ObservedObject private var profileData = ProfileData.shared
    @State private var showCompleteProfile = false
    
    init(
        selectedShipments: [ShipmentData],
        pickupCoordinates: [String: CLLocationCoordinate2D],
        scrollToFirst: Binding<Bool>,
        onRemoveShipment: @escaping (String) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.selectedShipments = selectedShipments
        self.pickupCoordinates = pickupCoordinates
        self._scrollToFirst = scrollToFirst
        self.onRemoveShipment = onRemoveShipment
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with close button
            HStack(alignment: .center) {
                Text("Your selection")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Colors.text)
                    .tracking(0.38)
                
                Spacer()
                
                // Close button
                Button(action: {
                    HapticFeedback.light()
                    onDismiss?()
                }) {
                    Circle()
                        .fill(Colors.backgroundQuaternary)
                        .frame(width: 40, height: 40)
                        .overlay(
                            LucideIcon(IconHelper.close, size: 24, color: Colors.text)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 0)
            
            // Horizontal scrollable cards
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(selectedShipments.enumerated()), id: \.element.id) { index, shipment in
                            cardView(for: shipment, at: index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                }
                .coordinateSpace(name: "scroll")
                .scrollTargetLayout()
                .scrollTargetBehavior(.viewAligned)
                .frame(height: 260)
                .onChange(of: scrollToFirst) { oldValue, newValue in
                    if newValue {
                        // Scroll to first card (index 0)
                        withAnimation {
                            proxy.scrollTo("card-0", anchor: .leading)
                        }
                        // Reset trigger
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToFirst = false
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.top, 0)
        .padding(.bottom, 100)
        .background(Color.white)
        .sheet(isPresented: $showCompleteProfile) {
            CompleteProfileView(
                onComplete: {
                    // Profile completed - dismiss the sheet
                },
                isPresented: $showCompleteProfile
            )
            .environmentObject(authService)
        }
    }
    
    private func handlePlaceOrder(for shipment: ShipmentData) {
        // Check if profile is complete before allowing bid placement
        if !profileData.isProfileComplete() {
            HapticFeedback.light()
            showCompleteProfile = true
        } else {
            // Profile is complete, proceed with bid placement
            HapticFeedback.light()
            print("Place bid for shipment: \(shipment.id)")
            // TODO: Implement actual bid placement logic
        }
    }
    
    @ViewBuilder
    private func cardView(for shipment: ShipmentData, at index: Int) -> some View {
        RequestCardMap(
            shipment: shipment,
            onPlaceOrder: {
                handlePlaceOrder(for: shipment)
            },
            sortOption: filterSettings.sortType.rawValue,
            sortValue: getSortValue(for: shipment),
            rangeDistance: getRangeDistance(for: shipment)
        )
        .id("card-\(index)")
        .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
        .frame(width: 362)
        .overlay(
            HStack(spacing: 0) {
                // Bookmark button
                Button(action: {
                    watchedManager.toggleWatched(requestId: shipment.id)
                }) {
                    Group {
                        if watchedManager.isWatched(requestId: shipment.id) {
                            Image("bookmark-filled")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(Colors.primary)
                        } else {
                            LucideIcon(IconHelper.bookmark, size: 24, color: Colors.secondary)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                }
                
                // Remove button
                Button(action: {
                    onRemoveShipment(shipment.id)
                }) {
                    LucideIcon(IconHelper.close, size: 24, color: Colors.secondary)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(10)
                }
            }
            .padding(6),
            alignment: .topTrailing
        )
    }
    
    private func getSortValue(for shipment: ShipmentData) -> String {
        switch filterSettings.sortType {
        case .distanceToPickup:
            // Calculate distance to pickup
            let referenceLocation: CLLocationCoordinate2D?
            if filterSettings.useOwnLocation {
                referenceLocation = locationManager.location?.coordinate
            } else {
                referenceLocation = filterSettings.selectedCityCoordinate
            }
            
            if let referenceLocation = referenceLocation,
               let pickupCoord = pickupCoordinates[shipment.id] {
                let distance = calculateDistance(from: referenceLocation, to: pickupCoord)
                return String(format: "%.0f km", distance)
            }
            return shipment.tripDistance
            
        case .dateOfCreation:
            let date = parseDate(shipment.createdAt)
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter.string(from: date)
            
        case .pickupDate:
            if shipment.pickupDate.isEmpty {
                return "Flexible"
            }
            let date = parseDate(shipment.pickupDate)
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter.string(from: date)
            
        case .tripDistance:
            return "\(shipment.tripDistance) \(shipment.distanceUnit)"
        }
    }
    
    private func getRangeDistance(for shipment: ShipmentData) -> Double? {
        let referenceLocation: CLLocationCoordinate2D?
        if filterSettings.useOwnLocation {
            referenceLocation = locationManager.location?.coordinate
        } else {
            referenceLocation = filterSettings.selectedCityCoordinate
        }
        
        guard let referenceLocation = referenceLocation,
              let pickupCoord = pickupCoordinates[shipment.id] else {
            return nil
        }
        
        return calculateDistance(from: referenceLocation, to: pickupCoord)
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0 // Convert to km
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let cleaned = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return Date.distantPast
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        
        if let date = isoFormatter.date(from: cleaned) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = isoFormatter.date(from: cleaned) {
            return date
        }
        
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = simpleFormatter.date(from: cleaned) {
            return date
        }
        
        return Date.distantPast
    }
}

#Preview {
    HomePageSelectionSheet(
        selectedShipments: [],
        pickupCoordinates: [:],
        scrollToFirst: .constant(false),
        onRemoveShipment: { _ in },
        onDismiss: nil
    )
}
