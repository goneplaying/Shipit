//
//  MapExamplePage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import CoreLocation

struct MapExamplePage: View {
    @EnvironmentObject var shipmentDataManager: ShipmentDataManager
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122) // Default: Warsaw, Poland
    @State private var zoomLevel: Double = 5.5 // Country-level zoom
    @State private var startLocation = ""
    @State private var destinationLocation = ""
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeColor: String = Colors.primary.hexString() // Default to primary color
    @State private var activeCardIndex: Int = -1 // Start with -1 to indicate no card selected yet
    @State private var hasSetCountryView = false
    @State private var pickupCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var currentRouteRequestId: UUID = UUID()
    @State private var pendingGeocodeTasks: [UUID: URLSessionDataTask] = [:]
    @State private var pendingRouteTasks: [UUID: URLSessionDataTask] = [:]
    @State private var hasInitializedRoute = false // Track if we've loaded the initial route
    
    private var shipments: [ShipmentData] {
        if filterSettings.useRange {
            return shipmentDataManager.shipments.filter { isWithinRange(shipment: $0) }
        }
        return shipmentDataManager.shipments
    }
    
    private var isLoadingSheetData: Bool {
        shipmentDataManager.isLoading
    }
    
    private var userLocation: CLLocationCoordinate2D? {
        locationManager.location?.coordinate
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                mapWithSlider
            }
            .navigationBarBackButtonHidden(true)
        }
        .onAppear {
            // Refresh data if needed (data is already loaded at app startup)
            if shipmentDataManager.shipments.isEmpty {
                shipmentDataManager.loadData()
            }
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
            // Geocode pickup locations for filtering
            geocodeAllPickupLocations()
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            // Set country view when location is first available
            if !hasSetCountryView, let location = newLocation {
                setCountryView(for: location.coordinate)
                hasSetCountryView = true
            }
        }
        .onChange(of: filterSettings.useRange) { _, _ in
            // Re-filter when range setting changes
            geocodeAllPickupLocations()
        }
        .onChange(of: filterSettings.sliderValue) { _, _ in
            // Re-filter when range distance changes
        }
        .onChange(of: filterSettings.useOwnLocation) { _, _ in
            // Re-filter when location source changes
        }
        .onDisappear {
            // Clear memory when navigating away
            clearMemoryCache()
            locationManager.stopUpdatingLocation()
        }
    }
    
    private func geocodeAllPickupLocations() {
        for shipment in shipmentDataManager.shipments {
            if pickupCoordinates[shipment.id] == nil {
                geocodePickupLocation(shipment: shipment)
            }
        }
    }
    
    private var mapWithSlider: some View {
        ZStack(alignment: .bottom) {
            MapboxMapView(
                centerCoordinate: $centerCoordinate,
                zoomLevel: $zoomLevel,
                routeCoordinates: $routeCoordinates,
                routeColor: $routeColor,
                userLocation: userLocation
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                // Inner shadow at bottom
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0.05), location: 0.0),
                        .init(color: Color.clear, location: 1.0)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 5)
                .allowsHitTesting(false),
                alignment: .bottom
            )
            
            if !shipments.isEmpty {
                shipmentSlider
            }
        }
    }
    
    private var shipmentSlider: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(shipments.enumerated()), id: \.element.id) { index, shipment in
                        cardView(for: shipment, at: index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .coordinateSpace(name: "scroll")
            .scrollTargetLayout()
            .scrollTargetBehavior(.viewAligned)
            .onPreferenceChange(CardVisibilityPreferenceKey.self) { cardData in
                // Add a small delay to ensure layout is complete before determining active card
                // This prevents loading the wrong route on initial load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    handleCardVisibilityChange(cardData: cardData)
                }
            }
            .frame(height: 200)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.95)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    @ViewBuilder
    private func cardView(for shipment: ShipmentData, at index: Int) -> some View {
        RequestCardSlider(shipment: shipment) {
            handlePlaceOrder(for: shipment)
        }
        .id("card-\(index)")
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: CardVisibilityPreferenceKey.self,
                        value: [CardVisibilityData(
                            index: index,
                            minX: geometry.frame(in: .named("scroll")).minX,
                            width: geometry.frame(in: .named("scroll")).width
                        )]
                    )
            }
        )
        // Removed onAppear route loading - let handleCardVisibilityChange determine the active card
    }
    
    private func handleCardVisibilityChange(cardData: [CardVisibilityData]) {
        guard !cardData.isEmpty else { return }
        
        let screenWidth = UIScreen.main.bounds.width
        let centerX = screenWidth / 2
        
        // Find the card closest to center
        var closestIndex = -1
        var minDistance: CGFloat = .greatestFiniteMagnitude
        
        for data in cardData {
            let cardCenter = data.minX + data.width / 2
            let distance = abs(cardCenter - centerX)
            if distance < minDistance {
                minDistance = distance
                closestIndex = data.index
            }
        }
        
        // Update active card and route if changed
        // Always update on first initialization (when activeCardIndex is -1) or when card changes
        if closestIndex >= 0 && closestIndex < shipments.count {
            if activeCardIndex != closestIndex || !hasInitializedRoute {
                activeCardIndex = closestIndex
                hasInitializedRoute = true
                let activeShipment = shipments[closestIndex]
                // Update route color from tripColor
                routeColor = activeShipment.tripColor.isEmpty ? Colors.primary.hexString() : activeShipment.tripColor
                updateRouteForShipment(activeShipment)
            }
        }
    }
    
    private func updateRoute() {
        guard !startLocation.isEmpty && !destinationLocation.isEmpty else {
            routeCoordinates = []
            return
        }
        
        // Generate new request ID
        let requestId = UUID()
        currentRouteRequestId = requestId
        
        // Geocode addresses and get route
        geocodeAddress(startLocation, requestId: requestId) { [requestId] startCoord in
            guard let startCoord = startCoord else { return }
            self.geocodeAddress(self.destinationLocation, requestId: requestId) { [requestId] destCoord in
                guard let destCoord = destCoord else { return }
                self.fetchRoute(from: startCoord, to: destCoord, requestId: requestId)
            }
        }
    }
    
    private func geocodeAddress(_ address: String, requestId: UUID, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        // Cancel any pending geocode tasks for this request
        cancelPendingGeocodeTasks()
        
        // Simple geocoding using Mapbox Geocoding API
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encodedAddress).json?access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [requestId] data, response, error in
            // Check if this request is still current
            DispatchQueue.main.async {
                guard self.currentRouteRequestId == requestId else {
                    // This request is stale, ignore the result
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let features = json["features"] as? [[String: Any]],
                      let firstFeature = features.first,
                      let geometry = firstFeature["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] as? [Double],
                      coordinates.count >= 2 else {
                    completion(nil)
                    return
                }
                
                let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
                completion(coordinate)
                
                // Remove task from pending list
                self.pendingGeocodeTasks.removeValue(forKey: requestId)
            }
        }
        
        // Store task for potential cancellation
        pendingGeocodeTasks[requestId] = task
        task.resume()
    }
    
    private func cancelPendingGeocodeTasks() {
        for (_, task) in pendingGeocodeTasks {
            task.cancel()
        }
        pendingGeocodeTasks.removeAll()
    }
    
    private func fetchRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, requestId: UUID) {
        // Cancel any pending route tasks
        cancelPendingRouteTasks()
        
        // Use Mapbox Directions API to get route with navigation data
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        // Request route with geometries=geojson to get detailed route geometry
        let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/\(start.longitude),\(start.latitude);\(destination.longitude),\(destination.latitude)?geometries=geojson&steps=true&overview=full&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [requestId] data, response, error in
            // Check if this request is still current
            DispatchQueue.main.async {
                guard self.currentRouteRequestId == requestId else {
                    // This request is stale, ignore the result
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let routes = json["routes"] as? [[String: Any]],
                      let firstRoute = routes.first,
                      let geometry = firstRoute["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] as? [[Double]] else {
                    print("Error parsing route data")
                    // Remove task from pending list
                    self.pendingRouteTasks.removeValue(forKey: requestId)
                    return
                }
                
                // Extract coordinates from GeoJSON format [longitude, latitude]
                let routeCoords = coordinates.compactMap { coord -> CLLocationCoordinate2D? in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
                
                self.routeCoordinates = routeCoords
                
                // Remove task from pending list
                self.pendingRouteTasks.removeValue(forKey: requestId)
            }
        }
        
        // Store task for potential cancellation
        pendingRouteTasks[requestId] = task
        task.resume()
    }
    
    private func cancelPendingRouteTasks() {
        for (_, task) in pendingRouteTasks {
            task.cancel()
        }
        pendingRouteTasks.removeAll()
    }
    
    /// Clear cached data to free memory when navigating away (keeps routes and coordinates)
    private func clearMemoryCache() {
        // Cancel all pending network tasks to prevent leaks
        cancelPendingRouteTasks()
        cancelPendingGeocodeTasks()
    }
    
    private func handlePlaceOrder(for shipment: ShipmentData) {
        // Handle place bid action
        print("Place bid for shipment: \(shipment.id)")
        // You can add navigation or other actions here
    }
    
    private func updateRouteForShipment(_ shipment: ShipmentData) {
        // Update text fields
        if !shipment.pickupLocation.isEmpty {
            startLocation = shipment.pickupLocation
        }
        if !shipment.deliveryLocation.isEmpty {
            destinationLocation = shipment.deliveryLocation
        }
        
        // Update route on map
        guard !shipment.pickupLocation.isEmpty && !shipment.deliveryLocation.isEmpty else {
            routeCoordinates = []
            return
        }
        
        // Generate new request ID and cancel any pending requests
        let requestId = UUID()
        currentRouteRequestId = requestId
        
        // Clear route immediately to prevent showing stale routes
        routeCoordinates = []
        
        // Geocode addresses and get route
        geocodeAddress(shipment.pickupLocation, requestId: requestId) { [requestId] startCoord in
            guard let startCoord = startCoord else {
                DispatchQueue.main.async {
                    // Only clear if this is still the current request
                    if self.currentRouteRequestId == requestId {
                        self.routeCoordinates = []
                    }
                }
                return
            }
            self.geocodeAddress(shipment.deliveryLocation, requestId: requestId) { [requestId] destCoord in
                guard let destCoord = destCoord else {
                    DispatchQueue.main.async {
                        // Only clear if this is still the current request
                        if self.currentRouteRequestId == requestId {
                            self.routeCoordinates = []
                        }
                    }
                    return
                }
                self.fetchRoute(from: startCoord, to: destCoord, requestId: requestId)
            }
        }
    }
    
    private func setCountryView(for coordinate: CLLocationCoordinate2D) {
        // Use Mapbox Geocoding API to get country information
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(coordinate.longitude),\(coordinate.latitude).json?types=country&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
            // Fallback: use user location with country zoom level
            centerCoordinate = coordinate
            zoomLevel = 5.5
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]],
                  let countryFeature = features.first,
                  let bbox = countryFeature["bbox"] as? [Double],
                  bbox.count >= 4 else {
                // Fallback: use user location with country zoom level
                DispatchQueue.main.async {
                    self.centerCoordinate = coordinate
                    self.zoomLevel = 5.5
                }
                return
            }
            
            // Calculate center and zoom from bounding box
            let minLon = bbox[0]
            let minLat = bbox[1]
            let maxLon = bbox[2]
            let maxLat = bbox[3]
            
            // Calculate center of country
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            
            // Calculate zoom level to fit the country
            // Formula: zoom = log2(360 / (maxLon - minLon)) - 1
            let lonDiff = maxLon - minLon
            let latDiff = maxLat - minLat
            let maxDiff = max(lonDiff, latDiff)
            
            var calculatedZoom: Double = 5.5
            if maxDiff > 0 {
                // Adjust zoom based on country size
                if maxDiff > 20 {
                    calculatedZoom = 4.0 // Large countries
                } else if maxDiff > 10 {
                    calculatedZoom = 5.0 // Medium countries
                } else if maxDiff > 5 {
                    calculatedZoom = 5.5 // Small-medium countries
                } else {
                    calculatedZoom = 6.0 // Small countries
                }
            }
            
            DispatchQueue.main.async {
                self.centerCoordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
                self.zoomLevel = calculatedZoom
            }
        }.resume()
    }
    
    private func isWithinRange(shipment: ShipmentData) -> Bool {
        // Get reference location (user location or chosen city)
        let referenceLocation: CLLocationCoordinate2D?
        
        if filterSettings.useOwnLocation {
            referenceLocation = locationManager.location?.coordinate
        } else {
            referenceLocation = filterSettings.selectedCityCoordinate
        }
        
        guard let referenceLocation = referenceLocation else {
            // If no reference location, show all
            return true
        }
        
        // Get pickup location coordinate (use cache if available)
        let pickupCoord: CLLocationCoordinate2D?
        if let cached = pickupCoordinates[shipment.id] {
            pickupCoord = cached
        } else {
            // Geocode pickup location (async, will be cached on next check)
            geocodePickupLocation(shipment: shipment)
            return true // Show for now, will be filtered on next update
        }
        
        guard let pickupCoord = pickupCoord else {
            return true // Show if geocoding fails
        }
        
        // Calculate distance in kilometers
        let distance = calculateDistance(from: referenceLocation, to: pickupCoord)
        
        // Check if within range (slider value in km)
        return distance <= filterSettings.sliderValue
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0 // Convert meters to kilometers
    }
    
    private func geocodePickupLocation(shipment: ShipmentData) {
        guard !shipment.pickupLocation.isEmpty else { return }
        
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let encodedAddress = shipment.pickupLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encodedAddress).json?access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else { return }
        
        let shipmentId = shipment.id
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]],
                  let firstFeature = features.first,
                  let geometry = firstFeature["geometry"] as? [String: Any],
                  let coordinates = geometry["coordinates"] as? [Double],
                  coordinates.count >= 2 else {
                return
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
            DispatchQueue.main.async {
                self.pickupCoordinates[shipmentId] = coordinate
            }
        }.resume()
    }
}

// Preference key for tracking card visibility
struct CardVisibilityData: Equatable {
    let index: Int
    let minX: CGFloat
    let width: CGFloat
}

struct CardVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [CardVisibilityData] = []
    static func reduce(value: inout [CardVisibilityData], nextValue: () -> [CardVisibilityData]) {
        value.append(contentsOf: nextValue())
    }
}

#Preview {
    MapExamplePage()
        .environmentObject(ShipmentDataManager.shared)
}
