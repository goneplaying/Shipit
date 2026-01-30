//
//  HomePageShipper.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import UIKit
import CoreLocation

struct HomePageShipper: View {
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
                HomeContentView()
                    .environmentObject(ShipmentDataManager.shared)
            }
            .tabItem {
                LucideIcon.image(IconHelper.home)
            }
            .tag(0)
            
            // Shipments Tab
            NavigationStack {
                ShipmentsPage()
            }
            .tabItem {
                LucideIcon.image(IconHelper.shipments)
            }
            .tag(1)
            
            // Profile Tab
            NavigationStack {
                MenuPage()
            }
            .tabItem {
                LucideIcon.image(IconHelper.profile)
            }
            .tag(2)
        }
            .onChange(of: selectedTab) { _, _ in
                HapticFeedback.light()
            }
            .onAppear {
                // Save that this is the active homepage
                appSettings.setLastActiveHomePage(.shipper)
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
                // Load profile data from Supabase when HomePageShipper appears
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
                // Dismiss HomePageShipper when user logs out
                if newValue == nil && oldValue != nil {
                    dismiss()
                }
            }
            .onChange(of: profileData.selectedTab) { _, _ in
                // When profile type changes, recheck if sheet should be shown
                checkProfileCompletion()
            }
            .onChange(of: profileData.firstName) { _, _ in
                // When profile data changes, recheck if sheet should be shown
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

// Separate view for Home content - Shipper version
struct HomeContentView: View {
    @EnvironmentObject var authService: SupabaseAuthService
    @EnvironmentObject var shipmentDataManager: ShipmentDataManager
    @ObservedObject private var profileData = ProfileData.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @ObservedObject private var appSettings = AppSettingsManager.shared
    @State private var showNewRequestPage = false
    @State private var showHomePageCarrier = false
    
    // Map state variables
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122) // Default: Warsaw, Poland
    @State private var zoomLevel: Double = 5.5 // Country-level zoom
    @State private var startLocation = ""
    @State private var destinationLocation = ""
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeColor: String = Colors.primary.hexString() // Default to primary color
    @State private var activeCardIndex: Int = -1
    @State private var hasSetCountryView = false
    @State private var pickupCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var currentRouteRequestId: UUID = UUID()
    @State private var pendingGeocodeTasks: [UUID: URLSessionDataTask] = [:]
    @State private var pendingRouteTasks: [UUID: URLSessionDataTask] = [:]
    @State private var hasInitializedRoute = false
    
    private var shipments: [ShipmentData] {
        if filterSettings.useRange {
            return shipmentDataManager.shipments.filter { isWithinRange(shipment: $0) }
        }
        return shipmentDataManager.shipments
    }
    
    private var userLocation: CLLocationCoordinate2D? {
        locationManager.location?.coordinate
    }
    
    var body: some View {
        ZStack {
            // Map in background
            MapboxMapView(
                centerCoordinate: $centerCoordinate,
                zoomLevel: $zoomLevel,
                routeCoordinates: $routeCoordinates,
                routeColor: $routeColor,
                userLocation: userLocation
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            
            // Control buttons at top
            VStack {
                HStack {
                    Button(action: {
                        HapticFeedback.light()
                        // Save that carrier is now the active homepage
                        appSettings.setLastActiveHomePage(.carrier)
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            showHomePageCarrier = true
                        }
                    }) {
                        LucideIcon(IconHelper.shipments, size: 24, color: .black)
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
                        showNewRequestPage = true
                    }) {
                        LucideIcon(IconHelper.plus, size: 24, color: .white)
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
        }
        .fullScreenCover(isPresented: $showHomePageCarrier) {
            HomePageCarrier()
                .environmentObject(authService)
                .environmentObject(ShipmentDataManager.shared)
        }
        .onAppear {
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
            geocodeAllPickupLocations()
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
            // Clear memory when navigating away
            clearMemoryCache()
        }
        .navigationDestination(isPresented: $showNewRequestPage) {
            NewRequestPage()
        }
    }
    
    // Map helper functions
    private func geocodeAllPickupLocations() {
        for shipment in shipmentDataManager.shipments {
            if pickupCoordinates[shipment.id] == nil {
                geocodePickupLocation(shipment: shipment)
            }
        }
    }
    
    private func setCountryView(for coordinate: CLLocationCoordinate2D) {
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(coordinate.longitude),\(coordinate.latitude).json?types=country&access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
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
                DispatchQueue.main.async {
                    self.centerCoordinate = coordinate
                    self.zoomLevel = 5.5
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
                self.centerCoordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
                self.zoomLevel = calculatedZoom
            }
        }.resume()
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
        
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let encodedAddress = shipment.pickupLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encodedAddress).json?access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else { return }
        
        let shipmentId = shipment.id
        let task = URLSession.shared.dataTask(with: url) { [shipmentId] data, response, error in
            DispatchQueue.main.async {
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
                self.pickupCoordinates[shipmentId] = coordinate
            }
        }
        task.resume()
    }
    
    /// Clear cached data to free memory when navigating away (keeps routes and coordinates)
    private func clearMemoryCache() {
        // Cancel all pending network tasks to prevent leaks
        for (_, task) in pendingRouteTasks {
            task.cancel()
        }
        pendingRouteTasks.removeAll()
        
        for (_, task) in pendingGeocodeTasks {
            task.cancel()
        }
        pendingGeocodeTasks.removeAll()
    }
}



#Preview {
    HomePageShipper()
        .environmentObject(SupabaseAuthService.shared)
        .environmentObject(ShipmentDataManager.shared)
}
