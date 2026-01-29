//
//  LocationManager.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var lastUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 1.0 // Reduce throttle to 1 second for smoother map movement
    private var activeObservers = 0
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        // Use best accuracy for map tracking
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Update more frequently for smoother map experience
        locationManager.distanceFilter = 5 // meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        activeObservers += 1
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        if activeObservers == 1 {
        locationManager.startUpdatingLocation()
        }
    }
    
    func stopUpdatingLocation() {
        activeObservers = max(0, activeObservers - 1)
        if activeObservers == 0 {
        locationManager.stopUpdatingLocation()
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Throttle location updates to reduce energy consumption
        let now = Date()
        if let lastUpdate = lastUpdateTime, now.timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            return
        }
        lastUpdateTime = now
        
        DispatchQueue.main.async {
            self.location = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if (self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways) && self.activeObservers > 0 {
                self.locationManager.startUpdatingLocation()
            }
        }
    }
}
