//
//  ShipmentDetailsPage.swift
//  Shipit
//
//  Created on 30.12.2025.
//

import SwiftUI
import CoreLocation
import MapboxMaps

struct ShipmentDetailsPage: View {
    let shipment: ShipmentData
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var shipmentDataManager: ShipmentDataManager
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var watchedManager = WatchedRequestsManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @ObservedObject private var profileData = ProfileData.shared
    @State private var selectedTab: DetailsTab = .basicInfo
    @State private var hasCenteredOnRoute = false
    @State private var showCompleteProfile = false
    
    // Map state - show all routes and POIs from HomePageCarrier
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var centerCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122) // Default: Warsaw
    @State private var zoomLevel: Double = 6.0
    @State private var pickupCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var deliveryCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var previewRoutes: [String: [CLLocationCoordinate2D]] = [:]
    @State private var bookmarkedRoutes: [String: [CLLocationCoordinate2D]] = [:]
    @State private var pendingGeocodeTasks: [String: URLSessionDataTask] = [:]
    
    private var isWatched: Bool {
        watchedManager.isWatched(requestId: shipment.id)
    }
    
    private var routeColor: String {
        shipment.tripColor.isEmpty ? "#222222" : shipment.tripColor
    }
    
    private var shipments: [ShipmentData] {
        if filterSettings.useRange {
            return shipmentDataManager.shipments.filter { isWithinRange(shipment: $0) }
        }
        return shipmentDataManager.shipments
    }
    
    private var userLocation: CLLocationCoordinate2D? {
        locationManager.location?.coordinate
    }
    
    // Get filtered pickup coordinates - only the selected shipment
    private var filteredPickupCoordinates: [CLLocationCoordinate2D] {
        if let coord = pickupCoordinates[shipment.id] {
            return [coord]
        }
        return []
    }
    
    // Get preview routes - empty
    private var previewRoutesList: [[CLLocationCoordinate2D]] {
        return []
    }
    
    // Get bookmarked routes - empty
    private var bookmarkedRoutesList: [[CLLocationCoordinate2D]] {
        return []
    }
    
    // Get multiple routes - selected shipment route (double width)
    private var multipleRoutesList: [[CLLocationCoordinate2D]] {
        // Return route from either bookmarked or preview cache
        if let route = bookmarkedRoutes[shipment.id] {
            return [route]
        } else if let route = previewRoutes[shipment.id] {
            return [route]
        }
        return []
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Square map at top (extends under status bar)
                    MapboxMapView(
                        centerCoordinate: $centerCoordinate,
                        zoomLevel: $zoomLevel,
                        routeCoordinates: $routeCoordinates,
                        routeColor: .constant(routeColor),
                        userLocation: userLocation,
                        startCoordinate: nil,
                        useSecondaryPOI: false,
                        allPickupCoordinates: filteredPickupCoordinates,
                        multipleRoutes: multipleRoutesList,
                        previewRoutes: previewRoutesList,
                        bookmarkedRoutes: bookmarkedRoutesList,
                        cameraPadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
                        scaleBarPosition: .bottomLeft
                    )
                    .aspectRatio(3/4, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black.opacity(0.05), Color.clear]),
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: 6)
                        }
                        .allowsHitTesting(false)
                    )
                    .ignoresSafeArea(edges: .top)
                    
                    // Content below map
                    VStack(alignment: .leading, spacing: 0) {
                        Text(shipment.title.isEmpty ? shipment.cargoType : shipment.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.text)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        Text(shipment.cargoType.isEmpty ? "N/A" : shipment.cargoType)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Colors.textSecondary)
                            .lineSpacing(21 - 16)
                            .tracking(-0.1)
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        
                        // Offers section
                        HStack(spacing: 0) {
                            let offersNum = Int(shipment.offersNumber) ?? 0
                            if offersNum > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(offersNum == 1 ? "1 offer" : "\(offersNum) offers")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                        .tracking(-0.31)
                                        .frame(height: 21)
                                    HStack(spacing: 4) {
                                        if offersNum == 1 {
                                            Text(shipment.minOffer.isEmpty ? "0" : shipment.minOffer)
                                        } else {
                                            Text(shipment.minOffer.isEmpty ? "0" : shipment.minOffer)
                                            Text("-")
                                            Text(shipment.maxOffer.isEmpty ? "0" : shipment.maxOffer)
                                        }
                                        Text(shipment.currency.isEmpty ? "PLN" : shipment.currency)
                                    }
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Colors.secondary)
                                    .tracking(-0.43)
                                    .frame(height: 22)
                                }
                            } else {
                                Text("No offers yet")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Colors.textSecondary)
                                    .tracking(-0.31)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                handlePlaceOrder()
                            }) {
                                Text("Place a bid")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 120, height: 40)
                                    .background(RoundedRectangle(cornerRadius: 22).fill(Colors.secondary))
                            }
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 12)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Colors.backgroundQuaternary))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        
                        // Tab bar
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
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        
                        switch selectedTab {
                        case .basicInfo:
                            BasicInfo(shipment: shipment)
                        case .photos:
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Photos")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Colors.text)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                Text("Photos content will go here")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.horizontal, 20)
                            }
                        case .questions:
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Questions")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Colors.text)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                Text("Questions content will go here")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Fixed toolbar overlay (stays at top while scrolling, positioned 62px from top)
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        HapticFeedback.light()
                        dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Colors.secondary)
                                .frame(width: 44, height: 44)
                            LucideIcon(IconHelper.arrowLeft, size: 24, color: .white)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticFeedback.light()
                        watchedManager.toggleWatched(requestId: shipment.id)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Colors.secondary)
                                .frame(width: 44, height: 44)
                            Group {
                                if isWatched {
                                    Image("bookmark-filled")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(Colors.primary)
                                        .frame(width: 24, height: 24)
                                } else {
                                    LucideIcon(IconHelper.bookmark, size: 24, color: .white)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 62)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(true)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
            // Load shipment data if needed
            if shipmentDataManager.shipments.isEmpty {
                shipmentDataManager.loadData()
            }
            
            // Check if route is already cached and center map on it
            if isWatched, let cachedRoute = bookmarkedRoutes[shipment.id] {
                centerMapOnRoute(cachedRoute)
            } else if !isWatched, let cachedRoute = previewRoutes[shipment.id] {
                centerMapOnRoute(cachedRoute)
            }
            
            // Start geocoding pickup locations immediately
            geocodeAllPickupLocations()
        }
        .onChange(of: shipmentDataManager.isLoading) { oldValue, newValue in
            // When loading finishes, start geocoding pickup locations
            if oldValue == true && newValue == false {
                geocodeAllPickupLocations()
            }
        }
        .onChange(of: shipmentDataManager.shipments.count) { oldCount, newCount in
            // When shipment count changes (new shipments loaded), geocode pickup locations
            if newCount > oldCount && newCount > 0 {
                geocodeAllPickupLocations()
            }
        }
        .onChange(of: filterSettings.useRange) { _, _ in
            geocodeAllPickupLocations()
        }
        .onChange(of: previewRoutes[shipment.id]) { _, newRoute in
            // Center map when preview route for selected shipment is loaded
            if !isWatched, let route = newRoute, !hasCenteredOnRoute {
                centerMapOnRoute(route)
            }
        }
        .onChange(of: bookmarkedRoutes[shipment.id]) { _, newRoute in
            // Center map when bookmarked route for selected shipment is loaded
            if isWatched, let route = newRoute, !hasCenteredOnRoute {
                centerMapOnRoute(route)
            }
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
            // Cancel all pending geocoding tasks to prevent memory leaks
            cancelPendingGeocodeTasks()
        }
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
    
    private func handlePlaceOrder() {
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
    
    // Map helper functions - focus on selected shipment
    private func geocodeAllPickupLocations() {
        // Prioritize the selected shipment
        if pickupCoordinates[shipment.id] == nil {
            geocodePickupLocation(shipment: shipment)
        }
        
        // Defer route fetching for the selected shipment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let pickupCoord = self.pickupCoordinates[self.shipment.id] {
                if self.isWatched {
                    self.geocodeDeliveryAndFetchBookmarkedRoute(shipment: self.shipment, pickupCoord: pickupCoord)
                } else {
                    self.geocodeDeliveryAndFetchPreviewRoute(shipment: self.shipment, pickupCoord: pickupCoord)
                }
            }
        }
    }
    
    private func geocodePickupLocation(shipment: ShipmentData) {
        guard !shipment.pickupLocation.isEmpty else { return }
        guard pickupCoordinates[shipment.id] == nil else { return } // Already geocoded
        
        // Cancel any existing task for this shipment
        if let existingTask = pendingGeocodeTasks[shipment.id] {
            existingTask.cancel()
        }
        
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let encodedAddress = shipment.pickupLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encodedAddress).json?access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else { return }
        
        let shipmentId = shipment.id
        let task = URLSession.shared.dataTask(with: url) { [shipmentId] data, response, error in
            DispatchQueue.main.async {
                // Check if task was cancelled
                guard self.pendingGeocodeTasks[shipmentId] != nil else { return }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let features = json["features"] as? [[String: Any]],
                      let firstFeature = features.first,
                      let geometry = firstFeature["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] as? [Double],
                      coordinates.count >= 2 else {
                    self.pendingGeocodeTasks.removeValue(forKey: shipmentId)
                    return
                }
                
                let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
                self.pickupCoordinates[shipmentId] = coordinate
                self.pendingGeocodeTasks.removeValue(forKey: shipmentId)
                
                // After geocoding, fetch preview route or bookmarked route for this shipment
                if let shipment = self.shipments.first(where: { $0.id == shipmentId }) {
                    if self.watchedManager.isWatched(requestId: shipmentId) {
                        self.geocodeDeliveryAndFetchBookmarkedRoute(shipment: shipment, pickupCoord: coordinate)
                    } else {
                        self.geocodeDeliveryAndFetchPreviewRoute(shipment: shipment, pickupCoord: coordinate)
                    }
                }
            }
        }
        
        // Defer state modification to avoid modifying during view update
        DispatchQueue.main.async {
            self.pendingGeocodeTasks[shipmentId] = task
        }
        task.resume()
    }
    
    private func fetchAllPreviewRoutes() {
        for shipment in shipments where !watchedManager.isWatched(requestId: shipment.id) {
            if previewRoutes[shipment.id] == nil,
               let pickupCoord = pickupCoordinates[shipment.id] {
                geocodeDeliveryAndFetchPreviewRoute(shipment: shipment, pickupCoord: pickupCoord)
            }
        }
    }
    
    private func geocodeDeliveryAndFetchPreviewRoute(shipment: ShipmentData, pickupCoord: CLLocationCoordinate2D) {
        guard !shipment.deliveryLocation.isEmpty else { return }
        
        // Check if we already have the delivery coordinate cached
        if let deliveryCoord = deliveryCoordinates[shipment.id] {
            fetchPreviewRoute(from: pickupCoord, to: deliveryCoord, shipmentId: shipment.id)
            return
        }
        
        // Geocode the delivery address
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(shipment.deliveryLocation) { placemarks, error in
            guard error == nil else { return }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                return
            }
            
            let deliveryCoord = location.coordinate
            
            DispatchQueue.main.async {
                // Cache the delivery coordinate
                self.deliveryCoordinates[shipment.id] = deliveryCoord
                
                // Fetch the preview route
                self.fetchPreviewRoute(from: pickupCoord, to: deliveryCoord, shipmentId: shipment.id)
            }
        }
    }
    
    private func fetchPreviewRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, shipmentId: String) {
        let accessToken = MapboxOptions.accessToken
        let coordinates = "\(start.longitude),\(start.latitude);\(end.longitude),\(end.latitude)"
        let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/\(coordinates)?geometries=geojson&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil else {
                return
            }
            
            guard let data = data else { return }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Check for API errors
                if let code = json?["code"] as? String, code != "Ok" {
                    return
                }
                
                guard let routes = json?["routes"] as? [[String: Any]],
                      let firstRoute = routes.first,
                      let geometry = firstRoute["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] as? [[Double]] else {
                    return
                }
                
                // Convert coordinates to CLLocationCoordinate2D
                let routeCoords = coordinates.compactMap { coord -> CLLocationCoordinate2D? in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
                
                DispatchQueue.main.async {
                    // Store preview route
                    self.previewRoutes[shipmentId] = routeCoords
                    
                    // Center map on route if this is the selected shipment
                    if shipmentId == self.shipment.id {
                        self.centerMapOnRoute(routeCoords)
                    }
                }
                
            } catch {
                return
            }
        }
        
        task.resume()
    }
    
    private func fetchAllBookmarkedRoutes() {
        for shipment in shipments where watchedManager.isWatched(requestId: shipment.id) {
            if bookmarkedRoutes[shipment.id] == nil,
               let pickupCoord = pickupCoordinates[shipment.id] {
                geocodeDeliveryAndFetchBookmarkedRoute(shipment: shipment, pickupCoord: pickupCoord)
            }
        }
    }
    
    private func geocodeDeliveryAndFetchBookmarkedRoute(shipment: ShipmentData, pickupCoord: CLLocationCoordinate2D) {
        guard !shipment.deliveryLocation.isEmpty else { return }
        
        // Check if we already have the delivery coordinate cached
        if let deliveryCoord = deliveryCoordinates[shipment.id] {
            fetchBookmarkedRoute(from: pickupCoord, to: deliveryCoord, shipmentId: shipment.id)
            return
        }
        
        // Geocode the delivery address
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(shipment.deliveryLocation) { placemarks, error in
            guard error == nil else { return }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                return
            }
            
            let deliveryCoord = location.coordinate
            
            DispatchQueue.main.async {
                // Cache the delivery coordinate
                self.deliveryCoordinates[shipment.id] = deliveryCoord
                
                // Fetch the bookmarked route
                self.fetchBookmarkedRoute(from: pickupCoord, to: deliveryCoord, shipmentId: shipment.id)
            }
        }
    }
    
    private func fetchBookmarkedRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, shipmentId: String) {
        let accessToken = MapboxOptions.accessToken
        let coordinates = "\(start.longitude),\(start.latitude);\(end.longitude),\(end.latitude)"
        let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/\(coordinates)?geometries=geojson&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil else {
                return
            }
            
            guard let data = data else { return }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Check for API errors
                if let code = json?["code"] as? String, code != "Ok" {
                    return
                }
                
                guard let routes = json?["routes"] as? [[String: Any]],
                      let firstRoute = routes.first,
                      let geometry = firstRoute["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] as? [[Double]] else {
                    return
                }
                
                // Convert coordinates to CLLocationCoordinate2D
                let routeCoords = coordinates.compactMap { coord -> CLLocationCoordinate2D? in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
                
                DispatchQueue.main.async {
                    // Store bookmarked route
                    self.bookmarkedRoutes[shipmentId] = routeCoords
                    
                    // Center map on route if this is the selected shipment
                    if shipmentId == self.shipment.id {
                        self.centerMapOnRoute(routeCoords)
                    }
                }
                
            } catch {
                return
            }
        }
        
        task.resume()
    }
    
    private func cancelPendingGeocodeTasks() {
        for (_, task) in pendingGeocodeTasks {
            task.cancel()
        }
        pendingGeocodeTasks.removeAll()
    }
    
    // Center map on the selected route with 50px padding from every side
    private func centerMapOnRoute(_ routeCoords: [CLLocationCoordinate2D]) {
        guard !routeCoords.isEmpty else { return }
        
        // Calculate bounding box
        let latitudes = routeCoords.map { $0.latitude }
        let longitudes = routeCoords.map { $0.longitude }
        
        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else { return }
        
        // Add padding (50px ~ 20% margin to ensure whole route is visible)
        let paddingFactor = 0.20
        let latDiff = maxLat - minLat
        let lonDiff = maxLon - minLon
        let latPadding = max(latDiff * paddingFactor, 0.02) // minimum padding
        let lonPadding = max(lonDiff * paddingFactor, 0.02)
        
        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // Calculate zoom level to fit the route with padding
        let paddedLatDiff = latDiff + (latPadding * 2)
        let paddedLonDiff = lonDiff + (lonPadding * 2)
        let maxDiff = max(paddedLatDiff, paddedLonDiff)
        
        var calculatedZoom: Double = 7.5
        if maxDiff > 0 {
            if maxDiff > 5 {
                calculatedZoom = 5.0
            } else if maxDiff > 2 {
                calculatedZoom = 6.0
            } else if maxDiff > 1 {
                calculatedZoom = 7.0
            } else if maxDiff > 0.5 {
                calculatedZoom = 7.5
            } else if maxDiff > 0.2 {
                calculatedZoom = 8.0
            } else {
                calculatedZoom = 8.5
            }
        }
        
        // Update map center and zoom
        centerCoordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        zoomLevel = calculatedZoom
        hasCenteredOnRoute = true
    }
    
    private func isWithinRange(shipment: ShipmentData) -> Bool {
        let referenceLocation: CLLocationCoordinate2D?
        
        if filterSettings.useOwnLocation {
            referenceLocation = locationManager.location?.coordinate
        } else {
            referenceLocation = filterSettings.selectedCityCoordinate
        }
        
        guard let referenceLocation = referenceLocation else {
            return true
        }
        
        let pickupCoord: CLLocationCoordinate2D?
        if let cached = pickupCoordinates[shipment.id] {
            pickupCoord = cached
        } else {
            geocodePickupLocation(shipment: shipment)
            return true
        }
        
        guard let pickupCoord = pickupCoord else {
            return true
        }
        
        let distance = calculateDistance(from: referenceLocation, to: pickupCoord)
        return distance <= filterSettings.sliderValue
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0
    }
}
