//
//  ExchangeMap.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import CoreLocation

struct ExchangeMap: View {
    @EnvironmentObject var shipmentDataManager: ShipmentDataManager
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var watchedManager = WatchedRequestsManager.shared
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @ObservedObject private var categoryManager = CategoryFilterManager.shared
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122) // Default: Warsaw, Poland
    @State private var zoomLevel: Double = 5.5 // Country-level zoom
    @State private var startLocation = ""
    @State private var destinationLocation = ""
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeColor: String = Colors.primary.hexString() // Default to primary color
    @State private var activeCardIndex: Int = -1 // Start with -1 to indicate no card selected yet
    @State private var hasSetCountryView = false
    @State private var pickupCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var shipmentCountries: [String: (pickupCountry: String?, deliveryCountry: String?)] = [:]
    @State private var currentRouteRequestId: UUID = UUID()
    @State private var pendingGeocodeTasks: [UUID: URLSessionDataTask] = [:]
    @State private var pendingRouteTasks: [UUID: URLSessionDataTask] = [:]
    @State private var hasInitializedRoute = false // Track if we've loaded the initial route
    
    private var shipments: [ShipmentData] {
        shipmentDataManager.shipments
    }
    
    private var isLoadingSheetData: Bool {
        shipmentDataManager.isLoading
    }
    
    // Use the same filteredShipments logic from ExchangePage
    var filteredShipments: [ShipmentData] {
        var baseShipments: [ShipmentData] = shipments
        
        // Apply range filter if enabled
        if filterSettings.locationSource != nil {
            baseShipments = baseShipments.filter { shipment in
                isWithinRange(shipment: shipment)
            }
        }
        
        // Apply pricing filter - show only requests with no offers if enabled
        if filterSettings.requestWithNoOfferOnly {
            baseShipments = baseShipments.filter { shipment in
                shipment.offersNumber.isEmpty || shipment.offersNumber == "0"
            }
        }
        
        // Apply weight filter if enabled
        if let weightFilter = filterSettings.weightFilter {
            baseShipments = baseShipments.filter { shipment in
                matchesWeightFilter(shipment: shipment, filter: weightFilter)
            }
        }
        
        // Apply category filter if enabled
        if !categoryManager.isAllSelected {
            baseShipments = baseShipments.filter { shipment in
                matchesCategoryFilter(shipment: shipment)
            }
        }
        
        // Apply sorting
        return sortShipments(baseShipments)
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
            // Initialize route color from first filtered shipment's tripColor
            // This ensures the first route uses the correct color before it's drawn
            updateRouteColorFromFirstCard()
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            // Set country view when location is first available
            if !hasSetCountryView, let location = newLocation {
                setCountryView(for: location.coordinate)
                hasSetCountryView = true
            }
        }
        .onChange(of: filterSettings.locationSource) { _, newValue in
            if newValue == .device {
                locationManager.requestLocationPermission()
                locationManager.startUpdatingLocation()
            } else {
                locationManager.stopUpdatingLocation()
            }
            // Update route color when filters change
            updateRouteColorFromFirstCard()
        }
        .onChange(of: filterSettings.sliderValue) { _, _ in
            // Re-filter when range distance changes
            updateRouteColorFromFirstCard()
        }
        .onChange(of: filterSettings.requestWithNoOfferOnly) { _, _ in
            // Re-filter when pricing filter changes
            updateRouteColorFromFirstCard()
        }
        .onChange(of: filterSettings.weightFilter) { _, _ in
            // Re-filter when weight filter changes
            updateRouteColorFromFirstCard()
        }
        .onChange(of: categoryManager.selectedCategories) { _, _ in
            // Re-filter when categories change
            updateRouteColorFromFirstCard()
        }
        .onChange(of: shipmentDataManager.isLoading) { oldValue, newValue in
            // Update route color when data finishes loading
            // When isLoading changes from true to false, data is ready
            if oldValue == true && newValue == false && !hasInitializedRoute {
                updateRouteColorFromFirstCard()
            }
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
            // Clear memory when navigating away
            clearMemoryCache()
        }
    }
    
    private func geocodeAllPickupLocations() {
        for shipment in shipments {
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
            
            if !filteredShipments.isEmpty {
                shipmentSlider
            }
        }
    }
    
    private var shipmentSlider: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(filteredShipments.enumerated()), id: \.element.id) { index, shipment in
                        cardView(for: shipment, at: index)
                    }
                }
                .padding(.horizontal, 20)
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
            .frame(height: 300) // Increased to fit RequestCard content
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
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .frame(width: 362)
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
        if closestIndex >= 0 && closestIndex < filteredShipments.count {
            if activeCardIndex != closestIndex || !hasInitializedRoute {
                let activeShipment = filteredShipments[closestIndex]
                // Update route color from tripColor BEFORE updating the route
                // This ensures the route is drawn with the correct color
                let newRouteColor = activeShipment.tripColor.isEmpty ? Colors.primary.hexString() : activeShipment.tripColor
                
                // Set route color synchronously first
                routeColor = newRouteColor
                
                // Update state
                activeCardIndex = closestIndex
                hasInitializedRoute = true
                
                // Update route - color is already set, so route will use correct color
                updateRouteForShipment(activeShipment)
            }
        }
    }
    
    private func updateRouteColorFromFirstCard() {
        // Update route color from first filtered shipment's tripColor
        // This ensures the route color matches the first card before it's drawn
        // Only update if route hasn't been initialized yet to avoid unnecessary updates
        guard !hasInitializedRoute else { return }
        
        let shipments = filteredShipments
        if !shipments.isEmpty {
            let firstShipment = shipments[0]
            let newColor = firstShipment.tripColor.isEmpty ? Colors.primary.hexString() : firstShipment.tripColor
            // Always set the route color, even if it's the same, to ensure it's initialized
            routeColor = newColor
        }
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
    
    // MARK: - Helper functions from ExchangePage
    
    private func sortShipments(_ shipments: [ShipmentData]) -> [ShipmentData] {
        let sorted = shipments.sorted { shipment1, shipment2 in
            let comparison: ComparisonResult
            
            switch filterSettings.sortType {
            case .distanceToPickup:
                comparison = compareByDistanceToPickup(shipment1, shipment2)
            case .dateOfCreation:
                comparison = compareByDateOfCreation(shipment1, shipment2)
            case .pickupDate:
                comparison = compareByPickupDate(shipment1, shipment2)
            case .tripDistance:
                comparison = compareByTripDistance(shipment1, shipment2)
            }
            
            // Apply sort order
            switch filterSettings.sortOrder {
            case .closestFirst, .newestFirst, .earliestFirst, .shortestFirst:
                return comparison == .orderedAscending
            case .farthestFirst, .oldestFirst, .latestFirst, .longestFirst:
                return comparison == .orderedDescending
            }
        }
        
        return sorted
    }
    
    private func compareByDistanceToPickup(_ shipment1: ShipmentData, _ shipment2: ShipmentData) -> ComparisonResult {
        // Get reference location (user location or chosen city)
        let referenceLocation: CLLocationCoordinate2D?
        if filterSettings.locationSource == .device {
            referenceLocation = locationManager.location?.coordinate
        } else {
            referenceLocation = filterSettings.selectedCityCoordinate
        }
        
        guard let referenceLocation = referenceLocation else {
            return .orderedSame
        }
        
        let coord1 = pickupCoordinates[shipment1.id]
        let coord2 = pickupCoordinates[shipment2.id]
        
        // If coordinates not available, put at end
        guard let coord1 = coord1 else { return .orderedDescending }
        guard let coord2 = coord2 else { return .orderedAscending }
        
        let distance1 = calculateDistance(from: referenceLocation, to: coord1)
        let distance2 = calculateDistance(from: referenceLocation, to: coord2)
        
        if distance1 < distance2 {
            return .orderedAscending
        } else if distance1 > distance2 {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    private func compareByDateOfCreation(_ shipment1: ShipmentData, _ shipment2: ShipmentData) -> ComparisonResult {
        let date1 = parseDate(shipment1.createdAt)
        let date2 = parseDate(shipment2.createdAt)
        return date1.compare(date2)
    }
    
    private func compareByPickupDate(_ shipment1: ShipmentData, _ shipment2: ShipmentData) -> ComparisonResult {
        let date1 = parseDate(shipment1.pickupDate)
        let date2 = parseDate(shipment2.pickupDate)
        return date1.compare(date2)
    }
    
    private func compareByTripDistance(_ shipment1: ShipmentData, _ shipment2: ShipmentData) -> ComparisonResult {
        let distance1 = parseDistance(shipment1.tripDistance)
        let distance2 = parseDistance(shipment2.tripDistance)
        
        if distance1 < distance2 {
            return .orderedAscending
        } else if distance1 > distance2 {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let cleaned = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return Date.distantPast
        }
        
        // Try ISO 8601 format with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        
        if let date = isoFormatter.date(from: cleaned) {
            return date
        }
        
        // Try ISO 8601 without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = isoFormatter.date(from: cleaned) {
            return date
        }
        
        // Try simple date format (e.g., "2026-01-02")
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = simpleFormatter.date(from: cleaned) {
            return date
        }
        
        // If parsing fails, return distant past
        return Date.distantPast
    }
    
    private func parseDistance(_ distanceString: String) -> Double {
        // Remove "km" and whitespace, then parse as double
        let cleaned = distanceString.replacingOccurrences(of: "km", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0.0
    }
    
    private func matchesWeightFilter(shipment: ShipmentData, filter: WeightFilter) -> Bool {
        // Parse weight from shipment
        let weightInKg = parseWeightToKg(weight: shipment.totalWeight, unit: shipment.weightUnit)
        
        guard let weightInKg = weightInKg else {
            // If weight cannot be parsed, include it (show all)
            return true
        }
        
        // Check against filter
        if let maxWeight = filter.maxWeightInKg {
            // Filter has an upper limit (to 500 kg, to 1 t, to 2 t)
            return weightInKg <= maxWeight
        } else {
            // Filter is "over 2 t" - no upper limit, but must be > 2000 kg
            return weightInKg > 2000
        }
    }
    
    private func parseWeightToKg(weight: String, unit: String) -> Double? {
        // Remove whitespace
        let cleanedWeight = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedWeight.isEmpty {
            return nil
        }
        
        // Extract numeric value from weight string
        // Replace comma with dot for decimal separator (European format)
        let normalizedWeight = cleanedWeight.replacingOccurrences(of: ",", with: ".")
        
        // Extract numeric value - try direct conversion first, then use Scanner if needed
        var weightValue: Double = 0.0
        
        // Try direct conversion first (handles most cases)
        if let directValue = Double(normalizedWeight) {
            weightValue = directValue
        } else {
            // Fallback to Scanner for more complex parsing
            let scanner = Scanner(string: normalizedWeight)
            scanner.locale = Locale(identifier: "en_US_POSIX")
            
            // Use modern Scanner API (iOS 13+)
            if let scannedValue = scanner.scanDouble() {
                weightValue = scannedValue
            } else {
                return nil
            }
        }
        
        // Determine conversion factor based on unit (1 t = 1000 kg)
        let unitLower = cleanedUnit.lowercased()
        
        var conversionFactor: Double = 1.0 // Default: kg
        
        if unitLower == "t" || unitLower == "ton" || unitLower == "tons" || 
           unitLower == "tonne" || unitLower == "tonnes" {
            // Tonnes: 1 t = 1000 kg
            conversionFactor = 1000.0
        } else if unitLower == "g" || unitLower == "gram" || unitLower == "grams" {
            // Grams: 1 g = 0.001 kg
            conversionFactor = 0.001
        } else if unitLower == "kg" || unitLower == "kilogram" || unitLower == "kilograms" || unitLower.isEmpty {
            // Already in kg or no unit specified (assume kg)
            conversionFactor = 1.0
        }
        
        // Calculate weight in kg: weightValue * conversionFactor
        // Example: 1.5 t = 1.5 * 1000 = 1500 kg
        let weightInKg = weightValue * conversionFactor
        
        return weightInKg
    }
    
    private func matchesCategoryFilter(shipment: ShipmentData) -> Bool {
        // If all categories are selected, show all shipments
        if categoryManager.isAllSelected {
            return true
        }
        
        // Map cargoType to CargoCategory
        guard let category = CategoryFilterManager.mapCargoTypeToCategory(shipment.cargoType) else {
            // If cargoType doesn't match any category, check if "Other" is selected
            return categoryManager.selectedCategories.contains(.other)
        }
        
        // Check if the mapped category is in the selected categories
        return categoryManager.selectedCategories.contains(category)
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
            return shipment.tripDistance // Fallback to trip distance
            
        case .dateOfCreation:
            // Format createdAt date
            let date = parseDate(shipment.createdAt)
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter.string(from: date)
            
        case .pickupDate:
            // Format pickupDate
            if shipment.pickupDate.isEmpty {
                return "Flexible"
            }
            let date = parseDate(shipment.pickupDate)
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter.string(from: date)
            
        case .tripDistance:
            // Return trip distance with unit
            return "\(shipment.tripDistance) \(shipment.distanceUnit)"
        }
    }
    
    private func getRangeDistance(for shipment: ShipmentData) -> Double? {
        // Calculate distance from reference location to pickup location
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
}

#Preview {
    ExchangeMap()
        .environmentObject(ShipmentDataManager.shared)
}
