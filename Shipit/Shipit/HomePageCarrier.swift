//
//  HomePageCarrier.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import UIKit
import CoreLocation
import MapboxMaps

struct HomePageCarrier: View {
    @EnvironmentObject var authService: SupabaseAuthService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileData = ProfileData.shared
    @ObservedObject private var appSettings = AppSettingsManager.shared
    @State private var showCompleteProfile = false
    @State private var hasShownProfileSheet = false
    @State private var selectedTab: Int = 0
    
    init() {
        // Configure tab bar appearance immediately - white background, no transparency
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        
        // Remove border/shadow from tab bar
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        
        // Set normal (inactive) to secondary color, selected (active) to primary color
        appearance.stackedLayoutAppearance.normal.iconColor = Colors.secondaryUIColor
        appearance.stackedLayoutAppearance.selected.iconColor = Colors.primaryUIColor
        
        // Apply to all tab bar styles
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().shadowImage = UIImage()
        UITabBar.appearance().clipsToBounds = true
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                HomeContentCarrierView()
                    .environmentObject(ShipmentDataManager.shared)
            }
            .tabItem {
                LucideIcon.image(IconHelper.home)
            }
            .tag(0)
            
            // Exchange Tab
            NavigationStack {
                ExchangePage()
            }
            .tabItem {
                LucideIcon.image(IconHelper.exchange)
            }
            .tag(1)
            
            // Jobs Tab
            NavigationStack {
                JobsPage()
            }
            .tabItem {
                LucideIcon.image(IconHelper.jobs)
            }
            .tag(2)
            
            // Profile Tab
            NavigationStack {
                MenuPage()
            }
            .tabItem {
                LucideIcon.image(IconHelper.profile)
            }
            .tag(3)
        }
            .onChange(of: selectedTab) { _, _ in
                HapticFeedback.light()
            }
            .onAppear {
                // Save that this is the active homepage
                appSettings.setLastActiveHomePage(.carrier)
            }
            .fullScreenCover(isPresented: $showCompleteProfile) {
                CompleteProfileView(
                    onComplete: {
                        // Profile completed - mark as shown
                        hasShownProfileSheet = true
                    },
                    isPresented: $showCompleteProfile
                )
                .environmentObject(authService)
            }
            .onChange(of: showCompleteProfile) { oldValue, newValue in
                // If sheet is dismissed and profile is still incomplete, allow showing again
                if oldValue == true && newValue == false && !profileData.isProfileComplete() {
                    hasShownProfileSheet = false
                }
            }
            .onAppear {
                // Load profile data from Supabase when HomePageCarrier appears
                Task {
                    do {
                        try await profileData.loadFromSupabase()
                        // Update email from Auth after loading
                        profileData.updateEmailFromAuth()
                    } catch {
                        // If Supabase load fails, data will remain from UserDefaults
                        print("Failed to load from Supabase: \(error.localizedDescription)")
                    }
                }
                
                // Profile sheet is now shown when user taps "Place bid"
                // No longer showing automatically on page load
                // hasShownProfileSheet = false
                // checkAndShowProfileSheet()
            }
            .onChange(of: authService.user) { oldValue, newValue in
                // Profile sheet is now shown when user taps "Place bid"
                // No longer showing automatically after login
                // if newValue != nil && oldValue == nil {
                //     hasShownProfileSheet = false
                //     checkAndShowProfileSheet()
                // }
                // Dismiss HomePageCarrier when user logs out
                if newValue == nil && oldValue != nil {
                    dismiss()
                }
            }
            .onChange(of: profileData.selectedTab) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.firstName) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.lastName) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.companyName) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.nip) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.selectedCountry) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.streetAndNumber) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.postalCode) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.city) { _, _ in
                checkProfileCompletion()
            }
            .onChange(of: profileData.phoneNumber) { _, _ in
                checkProfileCompletion()
            }
    }
    
    private func checkAndShowProfileSheet() {
        // If profile is complete, reset the flag so sheet can show again if data is deleted
        if self.profileData.isProfileComplete() {
            self.hasShownProfileSheet = false
            return
        }
        
        // Show profile completion sheet only if:
        // 1. Required profile data is missing
        // 2. User is logged in
        // 3. Sheet hasn't been shown yet in this session
        guard self.authService.user != nil, !self.hasShownProfileSheet else {
            return
        }
        
        // Use a delay to ensure the view is fully rendered before showing the sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Double-check conditions before showing (in case they changed)
            if !self.profileData.isProfileComplete() && self.authService.user != nil && !self.hasShownProfileSheet {
                self.showCompleteProfile = true
                self.hasShownProfileSheet = true
            }
        }
    }
    
    private func checkProfileCompletion() {
        // Do NOT auto-dismiss the sheet when profile becomes complete
        // The sheet should only close when the user presses the "Save" button
        // If profile becomes incomplete and user is logged in, allow showing the sheet again
        if !self.profileData.isProfileComplete() && self.authService.user != nil {
            // Reset flag so sheet can be shown again if needed
            self.hasShownProfileSheet = false
        }
    }
}

// Separate view for Home content - Carrier version
struct HomeContentCarrierView: View {
    @EnvironmentObject var authService: SupabaseAuthService
    @EnvironmentObject var shipmentDataManager: ShipmentDataManager
    @ObservedObject private var profileData = ProfileData.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @ObservedObject private var appSettings = AppSettingsManager.shared
    @ObservedObject private var watchedManager = WatchedRequestsManager.shared
    @State private var showNewRequestPage = false
    @State private var showHomePageShipper = false
    @State private var showPreferencesPage = false
    @State private var showAddressInput = false
    @State private var searchText = ""
    @State private var cachedFilteredShipmentIds: Set<String> = [] // Cache shipment IDs when preferences are open
    @State private var isPreferencesOpen = false // Track if preferences are being edited
    
    // Map state variables
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122) // Default: Warsaw, Poland
    @State private var zoomLevel: Double = 5.5 // Country-level zoom
    @State private var startLocation = ""
    @State private var destinationLocation = ""
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeColor: String = Colors.primary.hexString() // Default to primary color
    @State private var startCoordinate: CLLocationCoordinate2D? // Start of route for POI marker
    @State private var activeCardIndex: Int = -1
    @State private var hasSetCountryView = false
    @State private var pickupCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var deliveryCoordinates: [String: CLLocationCoordinate2D] = [:] // Store delivery coordinates
    @State private var selectedShipments: Set<String> = [] // Track selected shipment IDs (status true/false)
    @State private var selectionOrder: [String] = [] // Track order of selection (last selected first)
    @State private var shipmentRoutes: [String: [CLLocationCoordinate2D]] = [:] // Store routes per shipment
    @State private var previewRoutes: [String: [CLLocationCoordinate2D]] = [:] // Store preview routes for all POIs (thin lines)
    @State private var bookmarkedRoutes: [String: [CLLocationCoordinate2D]] = [:] // Store routes for bookmarked shipments
    @State private var pendingGeocodeTasks: [String: URLSessionDataTask] = [:]
    @State private var pendingRouteTasks: [String: URLSessionDataTask] = [:] // Keyed by shipmentId
    @State private var hasInitializedRoute = false
    @State private var countryViewTask: URLSessionDataTask?
    @State private var selectedShipmentId: String? // Track which shipment is selected for route display
    @State private var showSelectionSheet = false // Show/hide selection sheet
    @State private var scrollToFirstCard = false // Trigger to scroll to first card
    @State private var useSecondaryPOIs = false // Use secondary POI images (for address input route)
    @State private var geocodeWorkItem: DispatchWorkItem? // Debounce geocoding calls
    @State private var showRouteSheet = false // Show route sheet when route is set
    @State private var routeDistance: Double = 0 // Route distance in km
    
    private var shipments: [ShipmentData] {
        // If preferences are open, use cached filtered shipment IDs to avoid expensive recalculation
        if isPreferencesOpen && !cachedFilteredShipmentIds.isEmpty {
            return shipmentDataManager.shipments.filter { cachedFilteredShipmentIds.contains($0.id) }
        }
        
        // If a trip route is set, filter by distance from the route
        if !routeCoordinates.isEmpty {
            let maxDistanceKm = filterSettings.sliderValue
            let maxDistanceMeters = maxDistanceKm * 1000.0
            
            // Simplify route to reduce calculation time (keep every 10th point for large routes)
            let simplifiedRoute = simplifyRoute(routeCoordinates, maxPoints: 50)
            
            // Create bounding box for quick rejection
            let routeBounds = calculateRouteBounds(simplifiedRoute, bufferKm: maxDistanceKm)
            
            return shipmentDataManager.shipments.filter { shipment in
                // Always show bookmarked/watched shipments regardless of distance
                if watchedManager.isWatched(requestId: shipment.id) {
                    return true
                }
                
                guard let pickupCoord = pickupCoordinates[shipment.id] else { return false }
                
                // Quick bounding box check first (very fast)
                if !isPointInBounds(pickupCoord, bounds: routeBounds) {
                    return false
                }
                
                // Only do precise calculation if within bounding box
                let minDistance = minDistanceFromPointToRoute(point: pickupCoord, route: simplifiedRoute, maxDistance: maxDistanceMeters)
                return minDistance <= maxDistanceMeters
            }
        }
        
        // Otherwise, use the standard range filter
        if filterSettings.useRange {
            return shipmentDataManager.shipments.filter { shipment in
                // Always show bookmarked/watched shipments regardless of range
                if watchedManager.isWatched(requestId: shipment.id) {
                    return true
                }
                return isWithinRange(shipment: shipment)
            }
        }
        
        return shipmentDataManager.shipments
    }
    
    // Update cache with current filtered shipment IDs
    private func updateFilterCache() {
        let filtered = shipments
        cachedFilteredShipmentIds = Set(filtered.map { $0.id })
    }
    
    private var userLocation: CLLocationCoordinate2D? {
        locationManager.location?.coordinate
    }
    
    // Get filtered pickup coordinates based on preferences
    // Always include selected shipments' coordinates regardless of filters
    private var filteredPickupCoordinates: [CLLocationCoordinate2D] {
        var coordinateSet = Set<String>() // Track unique shipment IDs to avoid duplicates
        var coords: [CLLocationCoordinate2D] = []
        
        // First, add all filtered shipments
        for shipment in shipments {
            if let coord = pickupCoordinates[shipment.id] {
                coords.append(coord)
                coordinateSet.insert(shipment.id)
            }
        }
        
        // Then, add all selected shipments (if not already included)
        for shipmentId in selectedShipments {
            if !coordinateSet.contains(shipmentId), let coord = pickupCoordinates[shipmentId] {
                coords.append(coord)
            }
        }
        
        return coords
    }
    
    // Helper function to calculate minimum distance from a point to a route (with early termination)
    private func minDistanceFromPointToRoute(point: CLLocationCoordinate2D, route: [CLLocationCoordinate2D], maxDistance: Double) -> Double {
        guard !route.isEmpty else { return Double.infinity }
        
        var minDistance = Double.infinity
        
        // Check distance to each segment of the route
        for i in 0..<route.count - 1 {
            let segmentStart = route[i]
            let segmentEnd = route[i + 1]
            let distance = distanceFromPointToSegment(point: point, segmentStart: segmentStart, segmentEnd: segmentEnd)
            minDistance = min(minDistance, distance)
            
            // Early termination: if we found a point within range, no need to check further
            if minDistance <= maxDistance {
                return minDistance
            }
        }
        
        return minDistance
    }
    
    // Simplify route by keeping only every Nth point or limiting to maxPoints
    private func simplifyRoute(_ route: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard route.count > maxPoints else { return route }
        
        let step = route.count / maxPoints
        var simplified: [CLLocationCoordinate2D] = []
        
        for i in stride(from: 0, to: route.count, by: max(1, step)) {
            simplified.append(route[i])
        }
        
        // Always include the last point
        if let last = route.last, simplified.last != last {
            simplified.append(last)
        }
        
        return simplified
    }
    
    // Calculate bounding box around the route with buffer
    private func calculateRouteBounds(_ route: [CLLocationCoordinate2D], bufferKm: Double) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !route.isEmpty else {
            return (minLat: -90, maxLat: 90, minLon: -180, maxLon: 180)
        }
        
        var minLat = route[0].latitude
        var maxLat = route[0].latitude
        var minLon = route[0].longitude
        var maxLon = route[0].longitude
        
        for coord in route {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        // Add buffer (approximate: 1 degree ≈ 111 km at equator)
        let bufferDegrees = bufferKm / 111.0
        minLat -= bufferDegrees
        maxLat += bufferDegrees
        minLon -= bufferDegrees
        maxLon += bufferDegrees
        
        return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
    
    // Quick check if point is within bounding box
    private func isPointInBounds(_ point: CLLocationCoordinate2D, bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)) -> Bool {
        return point.latitude >= bounds.minLat &&
               point.latitude <= bounds.maxLat &&
               point.longitude >= bounds.minLon &&
               point.longitude <= bounds.maxLon
    }
    
    // Helper function to calculate distance from a point to a line segment
    private func distanceFromPointToSegment(point: CLLocationCoordinate2D, segmentStart: CLLocationCoordinate2D, segmentEnd: CLLocationCoordinate2D) -> Double {
        let pointLocation = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLocation = CLLocation(latitude: segmentStart.latitude, longitude: segmentStart.longitude)
        let endLocation = CLLocation(latitude: segmentEnd.latitude, longitude: segmentEnd.longitude)
        
        // Calculate the projection of the point onto the line segment
        let segmentLength = startLocation.distance(from: endLocation)
        
        if segmentLength == 0 {
            // Start and end are the same point
            return pointLocation.distance(from: startLocation)
        }
        
        // Calculate the parameter t that represents the projection point on the segment
        let dx = segmentEnd.longitude - segmentStart.longitude
        let dy = segmentEnd.latitude - segmentStart.latitude
        let t = max(0, min(1, ((point.longitude - segmentStart.longitude) * dx + (point.latitude - segmentStart.latitude) * dy) / (dx * dx + dy * dy)))
        
        // Calculate the projected point on the segment
        let projectedLat = segmentStart.latitude + t * dy
        let projectedLon = segmentStart.longitude + t * dx
        let projectedLocation = CLLocation(latitude: projectedLat, longitude: projectedLon)
        
        return pointLocation.distance(from: projectedLocation)
    }
    
    // Get all selected shipments for the sheet - ordered by selection (last selected first)
    // Always use unfiltered shipments to show all selected items regardless of range/filters
    private var selectedShipmentsData: [ShipmentData] {
        // Use selectionOrder to maintain order (reversed so last selected is first)
        selectionOrder.reversed().compactMap { shipmentId in
            shipmentDataManager.shipments.first { $0.id == shipmentId }
        }
    }
    
    // Get all selected routes as separate arrays (not combined)
    private var multipleRoutes: [[CLLocationCoordinate2D]] {
        return selectedShipments.compactMap { shipmentId in
            shipmentRoutes[shipmentId]
        }
    }
    
    // Get all preview routes (thin lines for unselected shipments)
    private var previewRoutesList: [[CLLocationCoordinate2D]] {
        // Get all preview routes, not just from filtered shipments
        // This ensures previously selected routes remain visible when deselected
        previewRoutes
            .filter { shipmentId, _ in
                // Exclude selected and bookmarked routes (they're shown separately)
                !selectedShipments.contains(shipmentId) && !watchedManager.isWatched(requestId: shipmentId)
            }
            .map { $0.value }
    }
    
    // Get all bookmarked routes (primary color, 2px width)
    private var bookmarkedRoutesList: [[CLLocationCoordinate2D]] {
        // Get all bookmarked routes, not just from filtered shipments
        // This ensures bookmarked routes remain visible even after deselection
        bookmarkedRoutes
            .filter { shipmentId, _ in
                // Exclude selected routes (they're shown separately as thick yellow lines)
                watchedManager.isWatched(requestId: shipmentId) && !selectedShipments.contains(shipmentId)
            }
            .map { $0.value }
    }
    
    // MARK: - Body Components
    
    
    private var mapView: some View {
        MapboxMapView(
            centerCoordinate: $centerCoordinate,
            zoomLevel: $zoomLevel,
            routeCoordinates: $routeCoordinates,
            routeColor: $routeColor,
            userLocation: userLocation,
            startCoordinate: useSecondaryPOIs ? startCoordinate : nil,
            useSecondaryPOI: useSecondaryPOIs,
            allPickupCoordinates: filteredPickupCoordinates,
            multipleRoutes: multipleRoutes,
            previewRoutes: previewRoutesList,
            bookmarkedRoutes: bookmarkedRoutesList,
            onPickupMarkerTapped: { tappedCoordinate in
                handlePickupMarkerTap(coordinate: tappedCoordinate)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    
    private var topButtonsLayer: some View {
        VStack {
            // Control buttons at top
            HStack {
                Button(action: {
                    HapticFeedback.light()
                    appSettings.setLastActiveHomePage(.shipper)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showHomePageShipper = true
                    }
                }) {
                    LucideIcon(IconHelper.truck, size: 24, color: .black)
                        .frame(width: 24, height: 24)
                        .padding(6)
                        .frame(width: 44, height: 44)
                        .background(Colors.primary)
                        .cornerRadius(30)
                        .clipped()
                }
                .buttonStyle(.plain)
                .instantFeedback()
                
                Spacer()
                
                Button(action: {
                    HapticFeedback.light()
                    showPreferencesPage = true
                }) {
                    LucideIcon(IconHelper.settings2, size: 24, color: .white)
                        .frame(width: 24, height: 24)
                        .padding(6)
                        .frame(width: 44, height: 44)
                        .background(Colors.secondary)
                        .cornerRadius(30)
                        .clipped()
                }
                .buttonStyle(.plain)
                .instantFeedback()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Locate me button
            HStack {
                Spacer()
                Button(action: {
                    HapticFeedback.light()
                    if let location = locationManager.location {
                        centerCoordinate = location.coordinate
                        zoomLevel = 12
                    }
                }) {
                    LucideIcon(IconHelper.crosshair, size: 24, color: .white)
                        .frame(width: 24, height: 24)
                        .padding(6)
                        .frame(width: 44, height: 44)
                        .background(Colors.secondary)
                        .cornerRadius(30)
                        .clipped()
                }
                .buttonStyle(.plain)
                .instantFeedback()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer()
        }
        .allowsHitTesting(true)
    }
    
    @ViewBuilder
    private var selectionSheet: some View {
        if showSelectionSheet {
            VStack {
                Spacer()
                
                HomePageSelectionSheet(
                    selectedShipments: selectedShipmentsData,
                    pickupCoordinates: pickupCoordinates,
                    scrollToFirst: $scrollToFirstCard,
                    onRemoveShipment: { shipmentId in
                        handleRemoveShipment(shipmentId: shipmentId)
                    },
                    onDismiss: {
                        // Move selected routes back to appropriate collections
                        for (shipmentId, route) in shipmentRoutes {
                            if watchedManager.isWatched(requestId: shipmentId) {
                                // Bookmarked routes go to bookmarkedRoutes (primary color, 2px)
                                bookmarkedRoutes[shipmentId] = route
                            } else {
                                // Regular routes go to previewRoutes (tertiary color, thin)
                                previewRoutes[shipmentId] = route
                            }
                        }
                        
                        // Clear all selections
                        selectedShipments.removeAll()
                        selectionOrder.removeAll()
                        showSelectionSheet = false
                        shipmentRoutes.removeAll()
                        selectedShipmentId = nil
                    }
                )
                .environmentObject(authService)
                .frame(height: 420)
                .background(Color.white)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: -1)
            }
            .offset(y: 28)
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    @ViewBuilder
    private var routeSheet: some View {
        if showRouteSheet {
            VStack {
                
                
                HomePageRouteSheet(
                    isPresented: $showRouteSheet,
                    fromCity: startLocation.isEmpty ? "Start" : startLocation,
                    toCity: destinationLocation.isEmpty ? "Destination" : destinationLocation,
                    distance: String(format: "%.0f", routeDistance),
                    onEditRoute: {
                        showRouteSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAddressInput = true
                        }
                    },
                    onDeleteRoute: {
                        routeCoordinates = []
                        startCoordinate = nil
                        startLocation = ""
                        destinationLocation = ""
                        routeDistance = 0
                        useSecondaryPOIs = false
                        routeColor = Colors.primary.hexString()
                        showRouteSheet = false
                        
                        // Clear preview routes for non-bookmarked shipments
                        // This removes POIs that were only visible along the route
                        clearNonBookmarkedPreviewRoutes()
                        print("🧹 Cleared non-bookmarked preview routes")
                        
                        // Regenerate preview routes for shipments within range after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("🔄 Regenerating preview routes for shipments within range")
                            self.fetchAllPreviewRoutes()
                            self.fetchAllBookmarkedRoutes()
                        }
                        
                        print("🗑️ Route deleted")
                    }
                )
                .frame(height: 122)
                .background(Color.white)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: -1)
            }
            .offset(y: 304)
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    @ViewBuilder
    private var bottomToolbar: some View {
        if selectedShipments.isEmpty && !showRouteSheet {
            VStack {
                Spacer()
                
                HomePageCarrierSheet(
                    searchText: $searchText,
                    onSearchTapped: {
                        showAddressInput = true
                    }
                )
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: -1)
            }
            .allowsHitTesting(true)
        }
    }
    
    private var mainContent: some View {
        ZStack {
            mapView
            topButtonsLayer
            routeSheet
            selectionSheet
            bottomToolbar
        }
    }
    
    var body: some View {
        baseView
            .navigationDestination(isPresented: $showNewRequestPage) {
                NewRequestPage()
            }
            .navigationDestination(isPresented: $showPreferencesPage) {
                ExchangePreferencesPage()
            }
            .onChange(of: showPreferencesPage) { oldValue, newValue in
                handlePreferencesChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: routeCoordinates) { oldValue, newValue in
                handleRouteChange(oldValue: oldValue, newValue: newValue)
            }
            .navigationDestination(isPresented: $showAddressInput, destination: addressInputDestination)
            .onChange(of: showAddressInput) { oldValue, newValue in
                handleAddressInputDismiss(oldValue: oldValue, newValue: newValue)
            }
    }
    
    private var baseView: some View {
        mainContent
        .fullScreenCover(isPresented: $showHomePageShipper) {
            HomePageShipper()
                .environmentObject(authService)
                .environmentObject(ShipmentDataManager.shared)
        }
        .onAppear {
            print("🎬 HomePageCarrier.onAppear")
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
            
            // Load shipment data if needed
            if shipmentDataManager.shipments.isEmpty {
                shipmentDataManager.loadData()
            }
            
            // Start geocoding pickup locations immediately
            geocodeAllPickupLocations()
            
            // If we already have cached preview routes, log them
            if !previewRoutes.isEmpty {
                print("🎯 Cached preview routes found on appear: \(previewRoutes.count)")
                print("   Shipment IDs with cached routes: \(previewRoutes.keys.sorted())")
                // Force a view update to display cached routes
                DispatchQueue.main.async {
                    // Trigger view update by touching a state variable
                    self.showSelectionSheet = self.showSelectionSheet
                }
            }
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
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            if !hasSetCountryView, let location = newLocation {
                setCountryView(for: location.coordinate)
                hasSetCountryView = true
            }
        }
        .onChange(of: filterSettings.useRange) { _, _ in
            geocodeAllPickupLocations()
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
            // Cancel pending geocode work item
            geocodeWorkItem?.cancel()
            geocodeWorkItem = nil
            // Cancel all pending geocoding tasks to prevent memory leaks
            cancelPendingGeocodeTasks()
            // Cancel country view task
            countryViewTask?.cancel()
            countryViewTask = nil
            // Cancel pending tasks to free memory (keeps routes and coordinates)
            clearMemoryCache()
        }
    }
    
    // MARK: - Navigation Handlers
    
    private func handlePreferencesChange(oldValue: Bool, newValue: Bool) {
        if newValue {
            // Preferences opened - set flag to use cached results
            isPreferencesOpen = true
        } else if oldValue && !newValue {
            // Preferences closed - recalculate and update cache
            isPreferencesOpen = false
            // Update cache after preferences close
            DispatchQueue.main.async {
                self.updateFilterCache()
            }
        }
    }
    
    private func handleRouteChange(oldValue: [CLLocationCoordinate2D], newValue: [CLLocationCoordinate2D]) {
        // Update cache when route changes (but not while preferences are open)
        if !isPreferencesOpen {
            DispatchQueue.main.async {
                self.updateFilterCache()
            }
        }
    }
    
    @ViewBuilder
    private func addressInputDestination() -> some View {
        AddressInputPage(onRouteCalculated: { routeCoordinates, startCoordinate, fromCity, toCity, distance in
            print("🗺️ onRouteCalculated callback - Setting route with \(routeCoordinates.count) points")
            print("   📍 Start coordinate: (\(startCoordinate.latitude), \(startCoordinate.longitude))")
            print("   📏 Distance: \(String(format: "%.1f", distance)) km")
            
            // Set route coordinates, start coordinate, and color
            self.routeCoordinates = routeCoordinates
            self.startCoordinate = startCoordinate
            self.routeColor = Colors.secondary.hexString()
            
            // Store city names and distance
            self.startLocation = fromCity
            self.destinationLocation = toCity
            self.routeDistance = distance
            
            // IMPORTANT: Set this flag to ensure secondary POIs are used
            self.useSecondaryPOIs = true
            
            // Clear preview routes for non-bookmarked shipments
            self.clearNonBookmarkedPreviewRoutes()
            print("   🧹 Cleared non-bookmarked preview routes")
            
            // Show route sheet
            self.showRouteSheet = true
            
            print("   ✅ Set routeCoordinates, startCoordinate, routeColor, and useSecondaryPOIs = true")
            
            // Focus map on the route with some zoom out (after route is set)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("   📍 Focusing map on route")
                self.focusMapOnRoute(routeCoordinates)
            }
        })
    }
    
    private func handleAddressInputDismiss(oldValue: Bool, newValue: Bool) {
        // When AddressInputPage is dismissed, reset flag if route is cleared
        if oldValue == true && newValue == false && routeCoordinates.isEmpty {
            useSecondaryPOIs = false
            startCoordinate = nil
            routeColor = Colors.primary.hexString()
        }
    }
    
    // Map helper functions
    private func geocodeAllPickupLocations() {
        // Cancel any pending geocode work to debounce calls
        geocodeWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            // Only geocode shipments that are currently visible (filtered) or selected/bookmarked
            let shipmentsToGeocode = Set(self.shipments.map { $0.id })
                .union(self.selectedShipments)
                .union(Set(self.shipmentDataManager.shipments.filter { self.watchedManager.isWatched(requestId: $0.id) }.map { $0.id }))
            
            for shipment in self.shipmentDataManager.shipments where shipmentsToGeocode.contains(shipment.id) {
                if self.pickupCoordinates[shipment.id] == nil {
                    self.geocodePickupLocation(shipment: shipment)
                }
            }
            
            // Defer preview routes and bookmarked routes fetching to give geocoding time to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.fetchAllPreviewRoutes()
                self.fetchAllBookmarkedRoutes()
            }
        }
        
        geocodeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    // Fetch preview routes (thin lines) for all visible unselected shipments
    private func fetchAllPreviewRoutes() {
        // Only fetch for unselected, unwatched, visible shipments
        let shipmentsToFetch = shipments.filter { 
            !selectedShipments.contains($0.id) && 
            !watchedManager.isWatched(requestId: $0.id) &&
            previewRoutes[$0.id] == nil
        }
        
        for shipment in shipmentsToFetch {
            if let pickupCoord = pickupCoordinates[shipment.id] {
                geocodeDeliveryAndFetchPreviewRoute(shipment: shipment, pickupCoord: pickupCoord)
            }
        }
    }
    
    // Geocode delivery and fetch preview route (thin line)
    private func geocodeDeliveryAndFetchPreviewRoute(shipment: ShipmentData, pickupCoord: CLLocationCoordinate2D) {
        guard !shipment.deliveryLocation.isEmpty else {
            print("Delivery location is empty for shipment \(shipment.id)")
            return
        }
        
        // Check if we already have the delivery coordinate cached
        if let deliveryCoord = deliveryCoordinates[shipment.id] {
            fetchPreviewRoute(from: pickupCoord, to: deliveryCoord, shipmentId: shipment.id)
            return
        }
        
        // Geocode the delivery address
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(shipment.deliveryLocation) { placemarks, error in
            if let error = error {
                print("Geocoding error for delivery (shipment \(shipment.id)): \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("No delivery location found for shipment \(shipment.id)")
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
    
    // Fetch preview route (thin line) for a shipment
    private func fetchPreviewRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, shipmentId: String) {
        print("🗺️ fetchPreviewRoute called for shipment: \(shipmentId)")
        
        let accessToken = MapboxOptions.accessToken
        let coordinates = "\(start.longitude),\(start.latitude);\(end.longitude),\(end.latitude)"
        let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/\(coordinates)?geometries=geojson&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for preview route")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Preview route fetch error for \(shipmentId): \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ No preview route data received for \(shipmentId)")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Check for API errors
                if let code = json?["code"] as? String, code != "Ok" {
                    print("❌ Preview route API error for \(shipmentId): \(code)")
                    return
                }
                
                guard let routes = json?["routes"] as? [[String: Any]],
                      let firstRoute = routes.first,
                      let geometry = firstRoute["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] as? [[Double]] else {
                    print("❌ Invalid preview route response format for \(shipmentId)")
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
                    print("   ✅ Preview route stored for shipment \(shipmentId): \(routeCoords.count) points")
                }
                
            } catch {
                print("❌ JSON parsing error for preview route \(shipmentId): \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    // Fetch bookmarked routes (primary color, 2px width) for all bookmarked shipments
    private func fetchAllBookmarkedRoutes() {
        // Only fetch for bookmarked, unselected, visible shipments that don't have routes yet
        let shipmentsToFetch = shipments.filter { 
            watchedManager.isWatched(requestId: $0.id) &&
            !selectedShipments.contains($0.id) &&
            bookmarkedRoutes[$0.id] == nil
        }
        
        for shipment in shipmentsToFetch {
            if let pickupCoord = pickupCoordinates[shipment.id] {
                geocodeDeliveryAndFetchBookmarkedRoute(shipment: shipment, pickupCoord: pickupCoord)
            }
        }
    }
    
    // Geocode delivery and fetch bookmarked route (primary color, 2px width)
    private func geocodeDeliveryAndFetchBookmarkedRoute(shipment: ShipmentData, pickupCoord: CLLocationCoordinate2D) {
        guard !shipment.deliveryLocation.isEmpty else {
            print("Delivery location is empty for bookmarked shipment \(shipment.id)")
            return
        }
        
        // Check if we already have the delivery coordinate cached
        if let deliveryCoord = deliveryCoordinates[shipment.id] {
            fetchBookmarkedRoute(from: pickupCoord, to: deliveryCoord, shipmentId: shipment.id)
            return
        }
        
        // Geocode the delivery address
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(shipment.deliveryLocation) { placemarks, error in
            if let error = error {
                print("Geocoding error for delivery (bookmarked shipment \(shipment.id)): \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("No delivery location found for bookmarked shipment \(shipment.id)")
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
    
    // Fetch bookmarked route (primary color, 2px width) for a shipment
    private func fetchBookmarkedRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, shipmentId: String) {
        print("🔖 fetchBookmarkedRoute called for shipment: \(shipmentId)")
        
        let accessToken = MapboxOptions.accessToken
        let coordinates = "\(start.longitude),\(start.latitude);\(end.longitude),\(end.latitude)"
        let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/\(coordinates)?geometries=geojson&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for bookmarked route")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Bookmarked route fetch error for \(shipmentId): \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ No bookmarked route data received for \(shipmentId)")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Check for API errors
                if let code = json?["code"] as? String, code != "Ok" {
                    print("❌ Bookmarked route API error for \(shipmentId): \(code)")
                    return
                }
                
                guard let routes = json?["routes"] as? [[String: Any]],
                      let firstRoute = routes.first,
                      let geometry = firstRoute["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] as? [[Double]] else {
                    print("❌ Invalid bookmarked route response format for \(shipmentId)")
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
                    print("   ✅ Bookmarked route stored for shipment \(shipmentId): \(routeCoords.count) points")
                }
                
            } catch {
                print("❌ JSON parsing error for bookmarked route \(shipmentId): \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    private func focusMapOnRoute(_ routeCoordinates: [CLLocationCoordinate2D]) {
        guard !routeCoordinates.isEmpty else { return }
        
        // Calculate bounding box from route coordinates
        var minLat = routeCoordinates[0].latitude
        var maxLat = routeCoordinates[0].latitude
        var minLon = routeCoordinates[0].longitude
        var maxLon = routeCoordinates[0].longitude
        
        for coord in routeCoordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        // Add padding (zoom out more) - 40% padding on each side
        let latPadding = (maxLat - minLat) * 0.4
        let lonPadding = (maxLon - minLon) * 0.4
        
        minLat -= latPadding
        maxLat += latPadding
        minLon -= lonPadding
        maxLon += lonPadding
        
        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // Calculate zoom level based on bounding box size (reduced by 1 to zoom out more)
        let latDiff = maxLat - minLat
        let lonDiff = maxLon - minLon
        let maxDiff = max(latDiff, lonDiff)
        
        var calculatedZoom: Double = 9.0 // Default zoom (reduced from 10.0)
        if maxDiff > 10 {
            calculatedZoom = 4.0 // Reduced from 5.0
        } else if maxDiff > 5 {
            calculatedZoom = 5.0 // Reduced from 6.0
        } else if maxDiff > 2 {
            calculatedZoom = 6.0 // Reduced from 7.0
        } else if maxDiff > 1 {
            calculatedZoom = 7.0 // Reduced from 8.0
        } else if maxDiff > 0.5 {
            calculatedZoom = 8.0 // Reduced from 9.0
        } else if maxDiff > 0.2 {
            calculatedZoom = 9.0 // Reduced from 10.0
        } else if maxDiff > 0.1 {
            calculatedZoom = 10.0 // Reduced from 11.0
        } else {
            calculatedZoom = 11.0 // Reduced from 12.0
        }
        
        // Update map center and zoom
        centerCoordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        zoomLevel = calculatedZoom
    }
    
    private func setCountryView(for coordinate: CLLocationCoordinate2D) {
        // Cancel any existing country view task
        countryViewTask?.cancel()
        
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(coordinate.longitude),\(coordinate.latitude).json?types=country&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
            centerCoordinate = coordinate
            zoomLevel = 5.5
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]],
                  let countryFeature = features.first,
                  let bbox = countryFeature["bbox"] as? [Double],
                  bbox.count >= 4 else {
                DispatchQueue.main.async {
                    // Use the stored task reference to check if still valid
                    guard self.countryViewTask != nil else { return } // Check if cancelled
                    self.centerCoordinate = coordinate
                    self.zoomLevel = 5.5
                    self.countryViewTask = nil
                }
                return
            }
            
            let minLon = bbox[0]
            let minLat = bbox[1]
            let maxLon = bbox[2]
            let maxLat = bbox[3]
            
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            
            let lonDiff = maxLon - minLon
            let latDiff = maxLat - minLat
            let maxDiff = max(lonDiff, latDiff)
            
            var calculatedZoom: Double = 5.5
            if maxDiff > 0 {
                if maxDiff > 20 {
                    calculatedZoom = 4.0
                } else if maxDiff > 10 {
                    calculatedZoom = 5.0
                } else if maxDiff > 5 {
                    calculatedZoom = 5.5
                } else {
                    calculatedZoom = 6.0
                }
            }
            
            DispatchQueue.main.async {
                guard self.countryViewTask != nil else { return } // Check if cancelled
                self.centerCoordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
                self.zoomLevel = calculatedZoom
                self.countryViewTask = nil
            }
        }
        
        countryViewTask = task
        task.resume()
    }
    
    private func isWithinRange(shipment: ShipmentData) -> Bool {
        let referenceLocation: CLLocationCoordinate2D?
        
        if filterSettings.useOwnLocation {
            referenceLocation = locationManager.location?.coordinate
        } else {
            referenceLocation = filterSettings.selectedCityCoordinate
        }
        
        guard let referenceLocation = referenceLocation else {
            // Don't show shipments if reference location is not available yet
            return false
        }
        
        let pickupCoord: CLLocationCoordinate2D?
        if let cached = pickupCoordinates[shipment.id] {
            pickupCoord = cached
        } else {
            // Start geocoding in background, but don't show until ready
            geocodePickupLocation(shipment: shipment)
            return false
        }
        
        guard let pickupCoord = pickupCoord else {
            // Don't show shipments without valid pickup coordinates
            return false
        }
        
        let distance = calculateDistance(from: referenceLocation, to: pickupCoord)
        return distance <= filterSettings.sliderValue
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0
    }
    
    private func geocodePickupLocation(shipment: ShipmentData) {
        guard !shipment.pickupLocation.isEmpty else { return }
        guard pickupCoordinates[shipment.id] == nil else { return } // Already geocoded
        
        print("🌍 Geocoding pickup for shipment \(shipment.id): \(shipment.pickupLocation)")
        
        // Cancel any existing task for this shipment (defer to avoid state modification during view update)
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
                    print("❌ Failed to geocode shipment \(shipmentId)")
                    self.pendingGeocodeTasks.removeValue(forKey: shipmentId)
                    return
                }
                
                let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
                self.pickupCoordinates[shipmentId] = coordinate
                self.pendingGeocodeTasks.removeValue(forKey: shipmentId)
                print("✅ Geocoded shipment \(shipmentId): (\(coordinate.latitude), \(coordinate.longitude))")
                print("📍 Total pickup coordinates now: \(self.pickupCoordinates.count)")
                
                // After geocoding, fetch preview route or bookmarked route for this shipment
                if !self.selectedShipments.contains(shipmentId) {
                    if let shipment = self.shipments.first(where: { $0.id == shipmentId }) {
                        if self.watchedManager.isWatched(requestId: shipmentId) {
                            print("   ➡️ Triggering bookmarked route fetch for \(shipmentId)")
                            self.geocodeDeliveryAndFetchBookmarkedRoute(shipment: shipment, pickupCoord: coordinate)
                        } else {
                            print("   ➡️ Triggering preview route fetch for \(shipmentId)")
                            self.geocodeDeliveryAndFetchPreviewRoute(shipment: shipment, pickupCoord: coordinate)
                        }
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
    
    // Handle removing a shipment (from X button in sheet)
    private func handleRemoveShipment(shipmentId: String) {
        print("🗑️ Remove shipment button tapped for: \(shipmentId)")
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Remove from selected shipments
            selectedShipments.remove(shipmentId)
            
            // Remove from selection order
            selectionOrder.removeAll { $0 == shipmentId }
            
            // Show/hide selection sheet based on whether we have selections
            showSelectionSheet = !selectedShipments.isEmpty
        }
        
        // Remove main route from memory
        shipmentRoutes.removeValue(forKey: shipmentId)
        
        // Restore preview route or bookmarked route for this shipment (if we have coordinates)
        if let pickupCoord = pickupCoordinates[shipmentId],
           let shipment = shipments.first(where: { $0.id == shipmentId }) {
            if watchedManager.isWatched(requestId: shipmentId) {
                geocodeDeliveryAndFetchBookmarkedRoute(shipment: shipment, pickupCoord: pickupCoord)
            } else {
                geocodeDeliveryAndFetchPreviewRoute(shipment: shipment, pickupCoord: pickupCoord)
            }
        }
        
        // Cancel any pending route task for this shipment
        if let pendingTask = pendingRouteTasks[shipmentId] {
            print("   ➡️ Canceling pending route task for: \(shipmentId)")
            pendingTask.cancel()
            pendingRouteTasks.removeValue(forKey: shipmentId)
        }
    }
    
    // Handle when a pickup marker is tapped on the map
    private func handlePickupMarkerTap(coordinate: CLLocationCoordinate2D) {
        // Don't clear address input route on pickup marker tap - only clear when user explicitly closes it
        // (The address input route is independent from POI routes)
        
        // Find the shipment that matches this coordinate
        guard let shipment = shipments.first(where: { shipment in
            if let pickupCoord = pickupCoordinates[shipment.id] {
                // Check if coordinates match (within small tolerance)
                return abs(pickupCoord.latitude - coordinate.latitude) < 0.0001 &&
                       abs(pickupCoord.longitude - coordinate.longitude) < 0.0001
            }
            return false
        }) else {
            print("❌ No shipment found for tapped coordinate: (\(coordinate.latitude), \(coordinate.longitude))")
            return
        }
        
        print("📍 POI marker tapped for shipment: \(shipment.id)")
        print("   Before toggle - Selected shipments: \(selectedShipments)")
        print("   Before toggle - Routes in memory: \(shipmentRoutes.keys.sorted())")
        
        // Toggle selection status
        if selectedShipments.contains(shipment.id) {
            // Second tap - deselect and remove route
            print("   ➡️ Deselecting shipment: \(shipment.id)")
            handleRemoveShipment(shipmentId: shipment.id)
        } else {
            // First tap - select and fetch route
            print("   ➡️ Selecting shipment: \(shipment.id)")
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedShipments.insert(shipment.id)
                
                // Remove preview route or bookmarked route for this shipment (it will be replaced with main route)
                previewRoutes.removeValue(forKey: shipment.id)
                bookmarkedRoutes.removeValue(forKey: shipment.id)
                
                // Add to selection order (append to end, will be shown first due to reverse)
                selectionOrder.append(shipment.id)
                
                print("   ✅ Shipment selected: \(shipment.id)")
                
                // Trigger scroll to first card (the newly selected one)
                scrollToFirstCard = true
                
                // Show/hide selection sheet based on whether we have selections
                showSelectionSheet = !selectedShipments.isEmpty
            }
            
            // Geocode delivery location and fetch route
            geocodeDeliveryAndFetchRoute(shipment: shipment, pickupCoord: coordinate)
            
            print("   After selection - Selected shipments: \(selectedShipments)")
            print("   After selection - Routes in memory: \(shipmentRoutes.keys.sorted())")
            print("   After selection - Selection order: \(selectionOrder)")
        }
    }
    
    private func geocodeDeliveryAndFetchRoute(shipment: ShipmentData, pickupCoord: CLLocationCoordinate2D) {
        guard !shipment.deliveryLocation.isEmpty else {
            print("Delivery location is empty")
            return
        }
        
        // Check if we already have the delivery coordinate cached
        if let deliveryCoord = deliveryCoordinates[shipment.id] {
            fetchRoute(from: pickupCoord, to: deliveryCoord, shipmentId: shipment.id)
            return
        }
        
        // Geocode the delivery address
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(shipment.deliveryLocation) { placemarks, error in
            if let error = error {
                print("Geocoding error for delivery: \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("No delivery location found")
                return
            }
            
            let deliveryCoord = location.coordinate
            
            DispatchQueue.main.async {
                // Cache the delivery coordinate
                self.deliveryCoordinates[shipment.id] = deliveryCoord
                
                // Fetch the route
                self.fetchRoute(from: pickupCoord, to: deliveryCoord, shipmentId: shipment.id)
            }
        }
    }
    
    private func fetchRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, shipmentId: String) {
        print("🛣️ fetchRoute called for shipment: \(shipmentId)")
        
        // Cancel any pending route task for this specific shipment
        if let pendingTask = pendingRouteTasks[shipmentId] {
            print("   ⚠️ Canceling existing route task for: \(shipmentId)")
            pendingTask.cancel()
            pendingRouteTasks.removeValue(forKey: shipmentId)
        }
        
        // Build Mapbox Directions API URL using the same access token as the map
        let accessToken = MapboxOptions.accessToken
        let coordinates = "\(start.longitude),\(start.latitude);\(end.longitude),\(end.latitude)"
        let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/\(coordinates)?geometries=geojson&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for route")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Route fetch error for \(shipmentId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.pendingRouteTasks.removeValue(forKey: shipmentId)
                }
                return
            }
            
            guard let data = data else {
                print("❌ No route data received for \(shipmentId)")
                DispatchQueue.main.async {
                    self.pendingRouteTasks.removeValue(forKey: shipmentId)
                }
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Check for API errors
                if let code = json?["code"] as? String, code != "Ok" {
                    if let message = json?["message"] as? String {
                        print("❌ Route API error for \(shipmentId): \(code) - \(message)")
                    } else {
                        print("❌ Route API error for \(shipmentId): \(code)")
                    }
                    DispatchQueue.main.async {
                        self.pendingRouteTasks.removeValue(forKey: shipmentId)
                    }
                    return
                }
                
                guard let routes = json?["routes"] as? [[String: Any]],
                      let firstRoute = routes.first,
                      let geometry = firstRoute["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] as? [[Double]] else {
                    print("❌ Invalid route response format for \(shipmentId)")
                    DispatchQueue.main.async {
                        self.pendingRouteTasks.removeValue(forKey: shipmentId)
                    }
                    return
                }
                
                // Convert coordinates to CLLocationCoordinate2D
                let routeCoords = coordinates.compactMap { coord -> CLLocationCoordinate2D? in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
                
                DispatchQueue.main.async {
                    print("   📥 Route response received for \(shipmentId) (\(routeCoords.count) points)")
                    print("   📋 Currently selected shipments: \(self.selectedShipments)")
                    print("   📋 Pending route tasks: \(self.pendingRouteTasks.keys.sorted())")
                    
                    // Check if this shipment is still selected and task hasn't been cancelled
                    guard self.selectedShipments.contains(shipmentId) else {
                        // Shipment was deselected, ignore the result
                        print("   ⚠️ Shipment \(shipmentId) was deselected, ignoring route result")
                        self.pendingRouteTasks.removeValue(forKey: shipmentId)
                        return
                    }
                    
                    guard self.pendingRouteTasks[shipmentId] != nil else {
                        // Task was cancelled, ignore the result
                        print("   ⚠️ Route task for shipment \(shipmentId) was cancelled")
                        return
                    }
                    
                    // Store route for this specific shipment
                    self.shipmentRoutes[shipmentId] = routeCoords
                    self.pendingRouteTasks.removeValue(forKey: shipmentId)
                    print("   ✅ Route stored for shipment \(shipmentId): \(routeCoords.count) points")
                    print("   📋 Routes now in memory: \(self.shipmentRoutes.keys.sorted())")
                }
                
            } catch {
                print("❌ JSON parsing error for \(shipmentId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.pendingRouteTasks.removeValue(forKey: shipmentId)
                }
            }
        }
        
        // Store task for potential cancellation (keyed by shipmentId)
        pendingRouteTasks[shipmentId] = task
        print("   ▶️ Starting route task for: \(shipmentId)")
        task.resume()
    }
    
    private func cancelPendingGeocodeTasks() {
        for (_, task) in pendingGeocodeTasks {
            task.cancel()
        }
        pendingGeocodeTasks.removeAll()
    }
    
    /// Clear cached data to free memory (keeps routes and coordinates)
    private func clearMemoryCache() {
        // Cancel pending network tasks to prevent leaks
        for (_, task) in pendingRouteTasks {
            task.cancel()
        }
        pendingRouteTasks.removeAll()
        
        // Cancel geocoding tasks
        cancelPendingGeocodeTasks()
    }
    
    /// Clear preview routes for non-bookmarked shipments
    private func clearNonBookmarkedPreviewRoutes() {
        let bookmarkedIds = watchedManager.watchedRequestIds
        previewRoutes = previewRoutes.filter { bookmarkedIds.contains($0.key) }
    }
}

#Preview {
    HomePageCarrier()
        .environmentObject(SupabaseAuthService.shared)
        .environmentObject(ShipmentDataManager.shared)
}
