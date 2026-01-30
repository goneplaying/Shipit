//
//  ExchangePage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import CoreLocation
import Foundation

struct ExchangePage: View {
    @EnvironmentObject var shipmentDataManager: ShipmentDataManager
    @EnvironmentObject var authService: SupabaseAuthService
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var watchedManager = WatchedRequestsManager.shared
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @ObservedObject private var profileData = ProfileData.shared
    @State private var selectedTab: ExchangeTab = .all
    @State private var scrollOffset: CGFloat = 0
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    @State private var pickupCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var shipmentCountries: [String: (pickupCountry: String?, deliveryCountry: String?)] = [:]
    @State private var showCompleteProfile = false
    
    private var shipments: [ShipmentData] {
        shipmentDataManager.shipments
    }
    
    private var isLoadingSheetData: Bool {
        shipmentDataManager.isLoading
    }
    
    enum ExchangeTab: String, CaseIterable {
        case all = "All"
        case watched = "Watched"
        case placedOrders = "Placed Orders"
    }
    
    var filteredShipments: [ShipmentData] {
        var baseShipments: [ShipmentData]
        
        // Apply tab filter
        switch selectedTab {
        case .all:
            baseShipments = shipments
        case .watched:
            baseShipments = shipments.filter { watchedManager.isWatched(requestId: $0.id) }
        case .placedOrders:
            // TODO: Filter placed orders
            baseShipments = shipments
        }
        
        // Apply range filter only for "All" tab if enabled
        if selectedTab == .all && filterSettings.locationSource != nil {
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
        let categoryManager = CategoryFilterManager.shared
        if !categoryManager.isAllSelected {
            baseShipments = baseShipments.filter { shipment in
                matchesCategoryFilter(shipment: shipment)
            }
        }
        
        // Apply sorting
        return sortShipments(baseShipments)
    }
    
    // Group shipments by section based on sort type
    var groupedShipments: [(section: String, shipments: [ShipmentData])] {
        // Use filteredShipments which is already sorted
        // The grouping functions preserve the sorted order within each group
        let sorted = filteredShipments
        
        switch filterSettings.sortType {
        case .distanceToPickup:
            return groupByDistanceToPickup(sorted)
        case .dateOfCreation:
            return groupByDateOfCreation(sorted)
        case .pickupDate:
            return groupByPickupDate(sorted)
        case .tripDistance:
            return groupByTripDistance(sorted)
        }
    }
    
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
        
        if date1 < date2 {
            return .orderedAscending
        } else if date1 > date2 {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    private func compareByPickupDate(_ shipment1: ShipmentData, _ shipment2: ShipmentData) -> ComparisonResult {
        let date1 = parseDate(shipment1.pickupDate)
        let date2 = parseDate(shipment2.pickupDate)
        
        if date1 < date2 {
            return .orderedAscending
        } else if date1 > date2 {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    private func compareByTripDistance(_ shipment1: ShipmentData, _ shipment2: ShipmentData) -> ComparisonResult {
        // Parse distance strings (assuming format like "123.5 km" or just "123.5")
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
        guard !dateString.isEmpty else {
            return Date.distantPast
        }
        
        // Try ISO 8601 format first (e.g., "2025-12-29T16:40:00+01:00")
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try ISO 8601 without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try simple date format (e.g., "2026-01-02")
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = simpleFormatter.date(from: dateString) {
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
    
    // MARK: - Grouping Functions
    
    private func groupByDistanceToPickup(_ shipments: [ShipmentData]) -> [(section: String, shipments: [ShipmentData])] {
        // Get reference location
        let referenceLocation: CLLocationCoordinate2D?
        if filterSettings.useOwnLocation {
            referenceLocation = locationManager.location?.coordinate
        } else {
            referenceLocation = filterSettings.selectedCityCoordinate
        }
        
        guard let referenceLocation = referenceLocation else {
            return [("All", shipments)]
        }
        
        var under50: [ShipmentData] = []
        var above100: [ShipmentData] = []
        var between: [ShipmentData] = []
        
        for shipment in shipments {
            guard let pickupCoord = pickupCoordinates[shipment.id] else {
                // If coordinate not available, put in "Above 100 km"
                above100.append(shipment)
                continue
            }
            
            let distance = calculateDistance(from: referenceLocation, to: pickupCoord)
            
            if distance < 50 {
                under50.append(shipment)
            } else if distance > 100 {
                above100.append(shipment)
            } else {
                between.append(shipment)
            }
        }
        
        var groups: [(section: String, shipments: [ShipmentData])] = []
        if !under50.isEmpty {
            groups.append(("Distance to pickup under 50 km", under50))
        }
        if !between.isEmpty {
            groups.append(("Distance to pickup 50-100 km", between))
        }
        if !above100.isEmpty {
            groups.append(("Above 100 km", above100))
        }
        
        return groups
    }
    
    private func groupByDateOfCreation(_ shipments: [ShipmentData]) -> [(section: String, shipments: [ShipmentData])] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Group shipments by their creation date
        var dateGroups: [Date: [ShipmentData]] = [:]
        
        for shipment in shipments {
            let createdAt = parseDate(shipment.createdAt)
            let createdDate = calendar.startOfDay(for: createdAt)
            
            if dateGroups[createdDate] == nil {
                dateGroups[createdDate] = []
            }
            dateGroups[createdDate]?.append(shipment)
        }
        
        // Sort dates in descending order (newest first)
        let sortedDates = dateGroups.keys.sorted(by: >)
        
        // Create groups with formatted date strings
        var groups: [(section: String, shipments: [ShipmentData])] = []
        for date in sortedDates {
            if let shipmentsForDate = dateGroups[date], !shipmentsForDate.isEmpty {
                let dateString = dateFormatter.string(from: date)
                groups.append((dateString, shipmentsForDate))
            }
        }
        
        return groups
    }
    
    private func groupByPickupDate(_ shipments: [ShipmentData]) -> [(section: String, shipments: [ShipmentData])] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        let nextWeekEnd = calendar.date(byAdding: .day, value: 14, to: startOfWeek)!
        
        var thisWeek: [ShipmentData] = []
        var nextWeek: [ShipmentData] = []
        var later: [ShipmentData] = []
        
        for shipment in shipments {
            let pickupDate = parseDate(shipment.pickupDate)
            
            if pickupDate >= startOfWeek && pickupDate < endOfWeek {
                thisWeek.append(shipment)
            } else if pickupDate >= endOfWeek && pickupDate < nextWeekEnd {
                nextWeek.append(shipment)
            } else {
                later.append(shipment)
            }
        }
        
        var groups: [(section: String, shipments: [ShipmentData])] = []
        if !thisWeek.isEmpty {
            groups.append(("Pickup date this week", thisWeek))
        }
        if !nextWeek.isEmpty {
            groups.append(("Next week", nextWeek))
        }
        if !later.isEmpty {
            groups.append(("Later", later))
        }
        
        return groups
    }
    
    private func groupByTripDistance(_ shipments: [ShipmentData]) -> [(section: String, shipments: [ShipmentData])] {
        // Local trips: under 50 km (same country)
        // National trips: >= 50 km AND same country in pickup and delivery location
        // International trips: Different country in pickup and delivery location
        let localThreshold: Double = 50.0
        
        var local: [ShipmentData] = []
        var national: [ShipmentData] = []
        var international: [ShipmentData] = []
        
        for shipment in shipments {
            let distance = parseDistance(shipment.tripDistance)
            let countries = shipmentCountries[shipment.id]
            
            // Check if we have country information
            if let pickupCountry = countries?.pickupCountry,
               let deliveryCountry = countries?.deliveryCountry {
                // Compare countries
                if pickupCountry == deliveryCountry {
                    // Same country
                    if distance < localThreshold {
                        local.append(shipment)
                    } else {
                        // >= 50 km and same country = National trips
                        national.append(shipment)
                    }
                } else {
                    // Different countries = International trips
                    international.append(shipment)
                }
            } else {
                // Country information not available yet, geocode if needed
                if countries == nil {
                    geocodeShipmentCountries(shipment: shipment)
                }
                // For now, put in local if distance < 50, otherwise national (will be corrected once geocoded)
                if distance < localThreshold {
                    local.append(shipment)
                } else {
                    national.append(shipment)
                }
            }
        }
        
        var groups: [(section: String, shipments: [ShipmentData])] = []
        if !local.isEmpty {
            groups.append(("Local trips", local))
        }
        if !national.isEmpty {
            groups.append(("National trips", national))
        }
        if !international.isEmpty {
            groups.append(("International trips", international))
        }
        
        return groups
    }
    
    private func geocodeShipmentCountries(shipment: ShipmentData) {
        let shipmentId = shipment.id
        
        // Geocode pickup location
        if !shipment.pickupLocation.isEmpty {
            geocodeCountry(address: shipment.pickupLocation) { country in
                DispatchQueue.main.async {
                    var countries = self.shipmentCountries[shipmentId] ?? (pickupCountry: nil, deliveryCountry: nil)
                    countries.pickupCountry = country
                    self.shipmentCountries[shipmentId] = countries
                }
            }
        }
        
        // Geocode delivery location
        if !shipment.deliveryLocation.isEmpty {
            geocodeCountry(address: shipment.deliveryLocation) { country in
                DispatchQueue.main.async {
                    var countries = self.shipmentCountries[shipmentId] ?? (pickupCountry: nil, deliveryCountry: nil)
                    countries.deliveryCountry = country
                    self.shipmentCountries[shipmentId] = countries
                }
            }
        }
    }
    
    private func geocodeCountry(address: String, completion: @escaping (String?) -> Void) {
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encodedAddress).json?access_token=\(accessToken)"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]],
                  let firstFeature = features.first else {
                completion(nil)
                return
            }
            
            // Look for country in context array
            if let context = firstFeature["context"] as? [[String: Any]] {
                for item in context {
                    if let id = item["id"] as? String, id.hasPrefix("country.") {
                        // Extract country code from id (format: "country.XX")
                        let countryCode = String(id.dropFirst("country.".count)).uppercased()
                        completion(countryCode)
                        return
                    }
                }
            }
            
            // Fallback: try to extract from place_name (last component is usually country)
            if let placeName = firstFeature["place_name"] as? String {
                let components = placeName.components(separatedBy: ",")
                if let lastComponent = components.last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    // This is a fallback - country name, not code
                    // But we can use it as a simple comparison
                    completion(lastComponent)
                    return
                }
            }
            
            completion(nil)
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
            // Don't show shipments if reference location is not available yet
            return false
        }
        
        // Get pickup location coordinate (use cache if available)
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
        
        // Calculate distance in kilometers
        let distance = calculateDistance(from: referenceLocation, to: pickupCoord)
        
        // Check if within range (slider value in km)
        return distance <= filterSettings.sliderValue
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
        
        // Extract numeric value from weight string
        // Replace comma with dot for decimal separator (European format)
        let normalizedWeight = cleanedWeight.replacingOccurrences(of: ",", with: ".")
        
        // Extract only digits and decimal point using Scanner for better parsing
        let scanner = Scanner(string: normalizedWeight)
        scanner.locale = Locale(identifier: "en_US_POSIX")
        
        guard let weightValue = scanner.scanDouble() else {
            return nil
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
        let categoryManager = CategoryFilterManager.shared
        
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
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Content
                contentView
            }
        }
        .navigationTitle("Exchange")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Map Icon - Navigate to ExchangeMap
                NavigationLink(destination: ExchangeMapPage()) {
                    LucideIcon(IconHelper.map, size: 24, color: Colors.text)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Sort Icon - Navigate to ExchangeSortingPage
                    NavigationLink(destination: ExchangeSortingPage()) {
                        LucideIcon(IconHelper.sort, size: 24, color: Colors.text)
                    }
                    
                    // Settings Icon - Navigate to ExchangePreferencesPage
                    NavigationLink(destination: ExchangePreferencesPage()) {
                        LucideIcon(IconHelper.settings2, size: 24, color: Colors.text)
                    }
                }
            }
        }
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            // Refresh data if needed (data is already loaded at app startup)
            if shipmentDataManager.shipments.isEmpty {
                shipmentDataManager.loadData()
            }
            // Request location permission if using device location
            if filterSettings.locationSource == .device {
                locationManager.requestLocationPermission()
                locationManager.startUpdatingLocation()
            }
            // Geocode pickup locations for filtering
            geocodeAllPickupLocations()
        }
        .onChange(of: filterSettings.locationSource) { _, newValue in
            if newValue == .device {
                locationManager.requestLocationPermission()
                locationManager.startUpdatingLocation()
            } else {
                locationManager.stopUpdatingLocation()
            }
        }
        .onChange(of: filterSettings.sliderValue) { _, _ in
            // Re-filter when range changes
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
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
    
    private func geocodeAllPickupLocations() {
        for shipment in shipments {
            if pickupCoordinates[shipment.id] == nil {
                geocodePickupLocation(shipment: shipment)
            }
            // Also geocode countries for trip distance grouping
            if shipmentCountries[shipment.id] == nil {
                geocodeShipmentCountries(shipment: shipment)
            }
        }
    }
    
    private var contentView: some View {
        Group {
            if isLoadingSheetData {
                loadingView
            } else if filteredShipments.isEmpty {
                emptyStateView
            } else {
                shipmentsListView
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("No requests available")
                .font(.callout)
                .foregroundColor(Colors.text)
            Spacer()
        }
    }
    
    private var shipmentsListView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Track scroll position at the top
                ScrollViewOffsetTracker()
                
                // Tab bar
                tabBarView
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
            ForEach(Array(groupedShipments.enumerated()), id: \.offset) { sectionIndex, group in
                shipmentSectionView(sectionIndex: sectionIndex, group: group)
            }
        }
        .padding(.vertical, 0)
        }
        .id("\(filterSettings.sortType.rawValue)-\(filterSettings.sortOrder.rawValue)")
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            handleScrollOffsetChange(value)
        }
    }
    
    private func shipmentSectionView(sectionIndex: Int, group: (section: String, shipments: [ShipmentData])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            VStack(alignment: .leading, spacing: 0) {
                Text(group.section.uppercased())
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Colors.textSecondary)
                    .tracking(-0.08)
                    .lineLimit(1)
                    .padding(.leading, 20)
                    .padding(.bottom, 8)
                    .padding(.top, sectionIndex == 0 ? 4 : 0) // No gap between sections
                
                // Divider under section headline
                Rectangle()
                    .fill(Color(hex: "#E5E5EA"))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12) // 12px margin after divider
            }
            
            // Section content
            VStack(spacing: 0) {
                ForEach(Array(group.shipments.enumerated()), id: \.element.id) { index, shipment in
                    RequestCardList(
                        shipment: shipment,
                        onPlaceOrder: {
                            handlePlaceOrder(for: shipment)
                        },
                        showTopBorder: true,
                        sortOption: filterSettings.sortType.rawValue,
                        sortValue: getSortValue(for: shipment),
                        rangeDistance: getRangeDistance(for: shipment)
                    )
                }
            }
        }
    }
    
    private func handleScrollOffsetChange(_ value: CGFloat) {
        // value represents the top of the content relative to scroll view
        // When at top: value is positive (content below scroll view top)
        // When scrolled: value becomes negative (content above scroll view top)
        scrollOffset = value
        
        // Adjust threshold based on tab bar height + padding
        // Tab bar is ~60px + padding, so threshold around -70 to -80
        let threshold: CGFloat = -50
        let shouldUseInline = value < threshold
        let newMode: NavigationBarItem.TitleDisplayMode = shouldUseInline ? .inline : .large
        
        if titleDisplayMode != newMode {
            titleDisplayMode = newMode
        }
    }
    
    private var tabBarView: some View {
        HStack(spacing: 8) {
            ForEach(ExchangeTab.allCases, id: \.self) { tab in
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
            return formatDate(shipment.createdAt)
            
        case .pickupDate:
            // Format pickupDate
            return formatDate(shipment.pickupDate)
            
        case .tripDistance:
            return shipment.tripDistance
        }
    }
    
    private func getRangeDistance(for shipment: ShipmentData) -> Double? {
        // Get reference location (user location or chosen city)
        let referenceLocation: CLLocationCoordinate2D?
        if filterSettings.locationSource == .device {
            referenceLocation = locationManager.location?.coordinate
        } else {
            referenceLocation = filterSettings.selectedCityCoordinate
        }
        
        guard let referenceLocation = referenceLocation else {
            return nil
        }
        
        // Get pickup location coordinate
        guard let pickupCoord = pickupCoordinates[shipment.id] else {
            // Geocode if not available
            geocodePickupLocation(shipment: shipment)
            return nil
        }
        
        // Calculate distance in kilometers
        return calculateDistance(from: referenceLocation, to: pickupCoord)
    }
    
    private func formatDate(_ dateString: String) -> String {
        guard !dateString.isEmpty else {
            return "N/A"
        }
        
        // Try ISO 8601 format first (e.g., "2025-12-29T16:40:00+01:00")
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
}

#Preview {
    NavigationStack {
        ExchangePage()
            .environmentObject(ShipmentDataManager.shared)
    }
}
