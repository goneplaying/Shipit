//
//  LocationCacheManager.swift
//  Shipit
//
//  Created on 30.12.2025.
//

import Foundation
import CoreLocation

class LocationCacheManager: ObservableObject {
    static let shared = LocationCacheManager()
    
    // Cache for pickup and delivery coordinates
    private var pickupCoordinates: [String: CLLocationCoordinate2D] = [:]
    private var deliveryCoordinates: [String: CLLocationCoordinate2D] = [:]
    // Cache for routes (array of coordinates)
    private var routes: [String: [CLLocationCoordinate2D]] = [:]
    
    private let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
    private let userDefaultsPickupKey = "cachedPickupCoordinates"
    private let userDefaultsDeliveryKey = "cachedDeliveryCoordinates"
    private let userDefaultsRoutesKey = "cachedRoutes"
    
    private var isPreloading = false
    private let geocodingQueue = DispatchQueue(label: "com.shipit.geocoding", qos: .utility)
    private let semaphore = DispatchSemaphore(value: 5) // Limit concurrent requests
    
    private init() {
        loadCachedCoordinates()
    }
    
    // Get cached pickup coordinate
    func getPickupCoordinate(for shipmentId: String) -> CLLocationCoordinate2D? {
        return pickupCoordinates[shipmentId]
    }
    
    // Get cached delivery coordinate
    func getDeliveryCoordinate(for shipmentId: String) -> CLLocationCoordinate2D? {
        return deliveryCoordinates[shipmentId]
    }
    
    // Cache pickup coordinate
    func cachePickupCoordinate(for shipmentId: String, coordinate: CLLocationCoordinate2D) {
        pickupCoordinates[shipmentId] = coordinate
        saveCachedCoordinates()
    }
    
    // Cache delivery coordinate
    func cacheDeliveryCoordinate(for shipmentId: String, coordinate: CLLocationCoordinate2D) {
        deliveryCoordinates[shipmentId] = coordinate
        saveCachedCoordinates()
    }
    
    // Get cached route
    func getRoute(for shipmentId: String) -> [CLLocationCoordinate2D]? {
        return routes[shipmentId]
    }
    
    // Cache route
    func cacheRoute(for shipmentId: String, route: [CLLocationCoordinate2D]) {
        routes[shipmentId] = route
        saveCachedRoutes()
    }
    
    // Preload all locations for shipments in background
    func preloadLocations(for shipments: [ShipmentData]) {
        guard !isPreloading else { return }
        isPreloading = true
        
        geocodingQueue.async { [weak self] in
            guard let self = self else { return }
            
            var newPickupCoords: [String: CLLocationCoordinate2D] = [:]
            var newDeliveryCoords: [String: CLLocationCoordinate2D] = [:]
            
            let group = DispatchGroup()
            
            for shipment in shipments {
                // Geocode pickup location if not cached
                if self.pickupCoordinates[shipment.id] == nil && !shipment.pickupLocation.isEmpty {
                    group.enter()
                    self.semaphore.wait()
                    self.geocodeAddress(shipment.pickupLocation) { coordinate in
                        if let coord = coordinate {
                            newPickupCoords[shipment.id] = coord
                        }
                        self.semaphore.signal()
                        group.leave()
                    }
                }
                
                // Geocode delivery location if not cached
                if self.deliveryCoordinates[shipment.id] == nil && !shipment.deliveryLocation.isEmpty {
                    group.enter()
                    self.semaphore.wait()
                    self.geocodeAddress(shipment.deliveryLocation) { coordinate in
                        if let coord = coordinate {
                            newDeliveryCoords[shipment.id] = coord
                        }
                        self.semaphore.signal()
                        group.leave()
                    }
                }
            }
            
            // Wait for all geocoding to complete
            group.wait()
            
            // Update caches
            DispatchQueue.main.async {
                self.pickupCoordinates.merge(newPickupCoords) { (_, new) in new }
                self.deliveryCoordinates.merge(newDeliveryCoords) { (_, new) in new }
                self.saveCachedCoordinates()
                self.isPreloading = false
                print("Location preloading complete. Cached \(self.pickupCoordinates.count) pickup and \(self.deliveryCoordinates.count) delivery locations")
            }
        }
    }
    
    // Geocode a single address
    private func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
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
                  let firstFeature = features.first,
                  let geometry = firstFeature["geometry"] as? [String: Any],
                  let coordinates = geometry["coordinates"] as? [Double],
                  coordinates.count >= 2 else {
                completion(nil)
                return
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
            completion(coordinate)
        }.resume()
    }
    
    // Save cached coordinates to UserDefaults
    private func saveCachedCoordinates() {
        // Convert CLLocationCoordinate2D to [String: [String: Double]] for storage
        var pickupDict: [String: [String: Double]] = [:]
        for (id, coord) in pickupCoordinates {
            pickupDict[id] = ["lat": coord.latitude, "lon": coord.longitude]
        }
        
        var deliveryDict: [String: [String: Double]] = [:]
        for (id, coord) in deliveryCoordinates {
            deliveryDict[id] = ["lat": coord.latitude, "lon": coord.longitude]
        }
        
        if let pickupData = try? JSONSerialization.data(withJSONObject: pickupDict),
           let deliveryData = try? JSONSerialization.data(withJSONObject: deliveryDict) {
            UserDefaults.standard.set(pickupData, forKey: userDefaultsPickupKey)
            UserDefaults.standard.set(deliveryData, forKey: userDefaultsDeliveryKey)
        }
    }
    
    // Load cached coordinates from UserDefaults
    private func loadCachedCoordinates() {
        if let pickupData = UserDefaults.standard.data(forKey: userDefaultsPickupKey),
           let pickupDict = try? JSONSerialization.jsonObject(with: pickupData) as? [String: [String: Double]] {
            for (id, coordDict) in pickupDict {
                if let lat = coordDict["lat"], let lon = coordDict["lon"] {
                    pickupCoordinates[id] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }
        
        if let deliveryData = UserDefaults.standard.data(forKey: userDefaultsDeliveryKey),
           let deliveryDict = try? JSONSerialization.jsonObject(with: deliveryData) as? [String: [String: Double]] {
            for (id, coordDict) in deliveryDict {
                if let lat = coordDict["lat"], let lon = coordDict["lon"] {
                    deliveryCoordinates[id] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }
        
        print("Loaded \(pickupCoordinates.count) cached pickup and \(deliveryCoordinates.count) cached delivery locations")
        
        // Load cached routes
        loadCachedRoutes()
    }
    
    // Save cached routes to UserDefaults
    private func saveCachedRoutes() {
        // Convert [CLLocationCoordinate2D] to [[String: Double]] for storage
        var routesDict: [String: [[String: Double]]] = [:]
        for (id, route) in routes {
            routesDict[id] = route.map { coord in
                ["lat": coord.latitude, "lon": coord.longitude]
            }
        }
        
        if let routesData = try? JSONSerialization.data(withJSONObject: routesDict) {
            UserDefaults.standard.set(routesData, forKey: userDefaultsRoutesKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // Load cached routes from UserDefaults
    private func loadCachedRoutes() {
        if let routesData = UserDefaults.standard.data(forKey: userDefaultsRoutesKey),
           let routesDict = try? JSONSerialization.jsonObject(with: routesData) as? [String: [[String: Double]]] {
            for (id, routeArray) in routesDict {
                let routeCoords = routeArray.compactMap { coordDict -> CLLocationCoordinate2D? in
                    guard let lat = coordDict["lat"], let lon = coordDict["lon"] else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                if !routeCoords.isEmpty {
                    routes[id] = routeCoords
                }
            }
        }
        
        print("Loaded \(routes.count) cached routes")
    }
    
    /// Clear in-memory cache to free memory (keeps UserDefaults cache)
    func clearMemoryCache() {
        pickupCoordinates.removeAll()
        deliveryCoordinates.removeAll()
        routes.removeAll()
        print("Cleared in-memory location cache")
    }
    
    /// Clear all cache including UserDefaults (more aggressive)
    func clearAllCache() {
        clearMemoryCache()
        UserDefaults.standard.removeObject(forKey: userDefaultsPickupKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsDeliveryKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsRoutesKey)
        UserDefaults.standard.synchronize()
        print("Cleared all location cache (memory and disk)")
    }
}
