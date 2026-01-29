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
    @EnvironmentObject var authService: AuthService
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
                // Load profile data from Firestore when HomePageCarrier appears
                Task {
                    do {
                        try await profileData.loadFromFirestore()
                        // Update email from Auth after loading
                        profileData.updateEmailFromAuth()
                    } catch {
                        // If Firestore load fails, data will remain from UserDefaults
                        print("Failed to load from Firestore: \(error.localizedDescription)")
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
    @EnvironmentObject var authService: AuthService
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
    
    private var shipments: [ShipmentData] {
        if filterSettings.useRange {
            return shipmentDataManager.shipments.filter { isWithinRange(shipment: $0) }
        }
        return shipmentDataManager.shipments
    }
    
    private var userLocation: CLLocationCoordinate2D? {
        locationManager.location?.coordinate
    }
    
    // Get filtered pickup coordinates based on preferences
    private var filteredPickupCoordinates: [CLLocationCoordinate2D] {
        let coords = shipments.compactMap { shipment -> CLLocationCoordinate2D? in
            pickupCoordinates[shipment.id]
        }
        print("📍 filteredPickupCoordinates: \(coords.count) coordinates")
        return coords
    }
    
    // Get all selected shipments for the sheet - ordered by selection (last selected first)
    private var selectedShipmentsData: [ShipmentData] {
        // Use selectionOrder to maintain order (reversed so last selected is first)
        selectionOrder.reversed().compactMap { shipmentId in
            shipments.first { $0.id == shipmentId }
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
        let routes = shipments
            .filter { !selectedShipments.contains($0.id) && !watchedManager.isWatched(requestId: $0.id) }
            .compactMap { shipment -> [CLLocationCoordinate2D]? in
                if let route = previewRoutes[shipment.id] {
                    print("   📍 Including preview route for shipment \(shipment.id): \(route.count) points")
                    return route
                }
                return nil
            }
        print("📊 previewRoutesList: \(routes.count) routes, previewRoutes dict has \(previewRoutes.count) entries")
        return routes
    }
    
    // Get all bookmarked routes (primary color, 2px width)
    private var bookmarkedRoutesList: [[CLLocationCoordinate2D]] {
        let routes = shipments
            .filter { watchedManager.isWatched(requestId: $0.id) && !selectedShipments.contains($0.id) }
            .compactMap { shipment -> [CLLocationCoordinate2D]? in
                if let route = bookmarkedRoutes[shipment.id] {
                    print("   📍 Including bookmarked route for shipment \(shipment.id): \(route.count) points")
                    return route
                }
                return nil
            }
        print("📊 bookmarkedRoutesList: \(routes.count) routes, bookmarkedRoutes dict has \(bookmarkedRoutes.count) entries")
        return routes
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Overlay HomePageShipper when switching
            if showHomePageShipper {
                HomePageShipper()
                    .environmentObject(authService)
                    .environmentObject(ShipmentDataManager.shared)
                    .zIndex(999)
                    .transition(.identity)
            }
            
            ZStack {
            // Map in background
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
            
            // 2nd layer: HomePageCarrierSheet (top buttons)
            VStack {
                // Control buttons at top
                HStack {
                    Button(action: {
                        HapticFeedback.light()
                        // Save that shipper is now the active homepage
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
            }
            .allowsHitTesting(true)
            
            // 3rd layer: HomePageSelectionSheet (above map, below tab bar automatically)
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
                            // Capture selected IDs before clearing
                            let selectedIds = Array(selectedShipments)
                            
                            // Clear selections and dismiss immediately without animation
                            selectedShipments.removeAll()
                            selectionOrder.removeAll()
                            showSelectionSheet = false
                            
                            // Clear all shipment routes
                            shipmentRoutes.removeAll()
                            
                            // Restore preview or bookmarked routes for deselected shipments
                            for shipmentId in selectedIds {
                                if let pickupCoord = pickupCoordinates[shipmentId],
                                   let shipment = shipments.first(where: { $0.id == shipmentId }) {
                                    if watchedManager.isWatched(requestId: shipmentId) {
                                        geocodeDeliveryAndFetchBookmarkedRoute(shipment: shipment, pickupCoord: pickupCoord)
                                    } else {
                                        geocodeDeliveryAndFetchPreviewRoute(shipment: shipment, pickupCoord: pickupCoord)
                                    }
                                }
                            }
                            
                            // Cancel all pending route tasks
                            for (_, task) in pendingRouteTasks {
                                task.cancel()
                            }
                            pendingRouteTasks.removeAll()
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
            
            // 1st layer (top/front): Bottom Toolbar - Hide when routes are selected
            if selectedShipments.isEmpty {
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
            // Cancel all pending geocoding tasks to prevent memory leaks
            cancelPendingGeocodeTasks()
            // Cancel country view task
            countryViewTask?.cancel()
            countryViewTask = nil
            // Cancel pending tasks to free memory (keeps routes and coordinates)
            clearMemoryCache()
        }
        .navigationDestination(isPresented: $showNewRequestPage) {
            NewRequestPage()
        }
        .navigationDestination(isPresented: $showPreferencesPage) {
            ExchangePreferencesPage()
        }
        .navigationDestination(isPresented: $showAddressInput) {
            AddressInputPage(onRouteCalculated: { routeCoordinates, startCoordinate in
                print("🗺️ onRouteCalculated callback - Setting route with \(routeCoordinates.count) points")
                print("   📍 Start coordinate: (\(startCoordinate.latitude), \(startCoordinate.longitude))")
                
                // Set route coordinates, start coordinate, and color
                self.routeCoordinates = routeCoordinates
                self.startCoordinate = startCoordinate
                self.routeColor = Colors.secondary.hexString()
                
                // IMPORTANT: Set this flag to ensure secondary POIs are used
                self.useSecondaryPOIs = true
                
                print("   ✅ Set routeCoordinates, startCoordinate, routeColor, and useSecondaryPOIs = true")
                
                // Focus map on the route with some zoom out (after route is set)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    print("   📍 Focusing map on route")
                    self.focusMapOnRoute(routeCoordinates)
                }
            })
        }
        .onChange(of: showAddressInput) { oldValue, newValue in
            // When AddressInputPage is dismissed, reset flag if route is cleared
            if oldValue == true && newValue == false && routeCoordinates.isEmpty {
                useSecondaryPOIs = false
                startCoordinate = nil
                routeColor = Colors.primary.hexString()
            }
        }
        }
    }
    
    // Map helper functions
    private func geocodeAllPickupLocations() {
        print("🌍 geocodeAllPickupLocations called - \(shipmentDataManager.shipments.count) shipments")
        for shipment in shipmentDataManager.shipments {
            if pickupCoordinates[shipment.id] == nil {
                geocodePickupLocation(shipment: shipment)
            }
        }
        print("🌍 Pickup coordinates now cached: \(pickupCoordinates.count)")
        
        // Defer preview routes and bookmarked routes fetching to give geocoding time to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.fetchAllPreviewRoutes()
            self.fetchAllBookmarkedRoutes()
        }
    }
    
    // Fetch preview routes (thin lines) for all visible unselected shipments
    private func fetchAllPreviewRoutes() {
        print("🗺️ fetchAllPreviewRoutes called")
        print("   Total shipments: \(shipments.count)")
        print("   Selected shipments: \(selectedShipments.count)")
        print("   Pickup coordinates cached: \(pickupCoordinates.count)")
        
        for shipment in shipments where !selectedShipments.contains(shipment.id) {
            if previewRoutes[shipment.id] == nil,
               let pickupCoord = pickupCoordinates[shipment.id] {
                print("   ➡️ Fetching preview route for shipment: \(shipment.id)")
                // Fetch preview route for this shipment
                geocodeDeliveryAndFetchPreviewRoute(shipment: shipment, pickupCoord: pickupCoord)
            } else if previewRoutes[shipment.id] != nil {
                print("   ✅ Preview route already exists for shipment: \(shipment.id)")
            } else {
                print("   ⚠️ No pickup coordinate for shipment: \(shipment.id)")
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
        print("🔖 fetchAllBookmarkedRoutes called")
        print("   Total shipments: \(shipments.count)")
        print("   Bookmarked shipments: \(shipments.filter { watchedManager.isWatched(requestId: $0.id) }.count)")
        print("   Pickup coordinates cached: \(pickupCoordinates.count)")
        
        for shipment in shipments where watchedManager.isWatched(requestId: shipment.id) && !selectedShipments.contains(shipment.id) {
            if bookmarkedRoutes[shipment.id] == nil,
               let pickupCoord = pickupCoordinates[shipment.id] {
                print("   ➡️ Fetching bookmarked route for shipment: \(shipment.id)")
                // Fetch bookmarked route for this shipment
                geocodeDeliveryAndFetchBookmarkedRoute(shipment: shipment, pickupCoord: pickupCoord)
            } else if bookmarkedRoutes[shipment.id] != nil {
                print("   ✅ Bookmarked route already exists for shipment: \(shipment.id)")
            } else {
                print("   ⚠️ No pickup coordinate for bookmarked shipment: \(shipment.id)")
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
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    HomePageCarrier()
        .environmentObject(AuthService())
        .environmentObject(ShipmentDataManager.shared)
}
