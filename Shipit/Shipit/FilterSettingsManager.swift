//
//  FilterSettingsManager.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import Foundation
import CoreLocation
import Combine

enum SortType: String, CaseIterable {
    case distanceToPickup = "Distance to pickup"
    case dateOfCreation = "Date of creation"
    case pickupDate = "Pickup date"
    case tripDistance = "Trip distance"
}

enum SortOrder: String, CaseIterable {
    case closestFirst = "Closest first"
    case farthestFirst = "Farthest first"
    case newestFirst = "Newest first"
    case oldestFirst = "Oldest first"
    case earliestFirst = "Earliest first"
    case latestFirst = "Latest first"
    case shortestFirst = "Shortest first"
    case longestFirst = "Longest first"
}

enum LocationSource: String, CaseIterable {
    case device = "Device"
    case place = "Place"
}

enum WeightFilter: String, CaseIterable {
    case to500kg = "to 500 kg"
    case to1t = "to 1 t"
    case to2t = "to 2 t"
    case over2t = "over 2 t"
    
    var maxWeightInKg: Double? {
        switch self {
        case .to500kg:
            return 500
        case .to1t:
            return 1000
        case .to2t:
            return 2000
        case .over2t:
            return nil // No upper limit
        }
    }
}

class FilterSettingsManager: ObservableObject {
    static let shared = FilterSettingsManager()
    
    @Published var sortType: SortType = .distanceToPickup
    @Published var sortOrder: SortOrder = .closestFirst
    @Published var locationSource: LocationSource? = .device
    @Published var useRange: Bool = true
    @Published var useOwnLocation: Bool = true
    @Published var sliderValue: Double = 200
    @Published var selectedCity: String = ""
    @Published var selectedCityCoordinate: CLLocationCoordinate2D?
    @Published var requestWithNoOfferOnly: Bool = false
    @Published var weightFilter: WeightFilter? = nil
    
    // Computed properties to maintain backward compatibility
    var effectiveUseRange: Bool {
        locationSource != nil
    }
    
    var effectiveUseOwnLocation: Bool {
        locationSource == .device
    }
    
    private let userDefaultsKey = "filterSettings"
    
    private init() {
        loadSettings()
    }
    
    func saveSettings() {
        // Update useRange and useOwnLocation based on locationSource
        useRange = locationSource != nil
        useOwnLocation = locationSource == .device
        
        let settings: [String: Any] = [
            "sortType": sortType.rawValue,
            "sortOrder": sortOrder.rawValue,
            "locationSource": locationSource?.rawValue ?? "",
            "useRange": useRange,
            "useOwnLocation": useOwnLocation,
            "sliderValue": sliderValue,
            "selectedCity": selectedCity,
            "selectedCityLat": selectedCityCoordinate?.latitude ?? 0,
            "selectedCityLon": selectedCityCoordinate?.longitude ?? 0,
            "requestWithNoOfferOnly": requestWithNoOfferOnly,
            "weightFilter": weightFilter?.rawValue ?? ""
        ]
        UserDefaults.standard.set(settings, forKey: userDefaultsKey)
    }
    
    private func loadSettings() {
        if let settings = UserDefaults.standard.dictionary(forKey: userDefaultsKey) {
            if let sortTypeString = settings["sortType"] as? String,
               let loadedSortType = SortType(rawValue: sortTypeString) {
                sortType = loadedSortType
            }
            if let sortOrderString = settings["sortOrder"] as? String,
               let loadedSortOrder = SortOrder(rawValue: sortOrderString) {
                sortOrder = loadedSortOrder
            }
            
            // Validate that sortOrder is valid for the current sortType
            let availableOrders = getAvailableSortOrders(for: sortType)
            if !availableOrders.contains(sortOrder) {
                // Reset to first available order if current order is invalid
                sortOrder = availableOrders.first ?? .closestFirst
            }
            
            // Load locationSource if available, otherwise derive from old settings
            if let locationSourceString = settings["locationSource"] as? String,
               let loadedLocationSource = LocationSource(rawValue: locationSourceString) {
                locationSource = loadedLocationSource
            } else {
                // Backward compatibility: derive from old useRange and useOwnLocation
                let oldUseRange = settings["useRange"] as? Bool ?? true
                let oldUseOwnLocation = settings["useOwnLocation"] as? Bool ?? true
                if oldUseRange {
                    locationSource = oldUseOwnLocation ? .device : .place
                } else {
                    // Default to device if useRange was false
                    locationSource = .device
                }
            }
            
            useRange = settings["useRange"] as? Bool ?? true
            useOwnLocation = settings["useOwnLocation"] as? Bool ?? true
            sliderValue = settings["sliderValue"] as? Double ?? 200
            selectedCity = settings["selectedCity"] as? String ?? ""
            requestWithNoOfferOnly = settings["requestWithNoOfferOnly"] as? Bool ?? false
            
            if let weightFilterString = settings["weightFilter"] as? String,
               let loadedWeightFilter = WeightFilter(rawValue: weightFilterString) {
                weightFilter = loadedWeightFilter
            } else {
                weightFilter = nil
            }
            
            if let lat = settings["selectedCityLat"] as? Double,
               let lon = settings["selectedCityLon"] as? Double,
               lat != 0 && lon != 0 {
                selectedCityCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        } else {
            // No saved settings - ensure default is device
            locationSource = .device
        }
    }
    
    func getAvailableSortOrders(for sortType: SortType) -> [SortOrder] {
        switch sortType {
        case .distanceToPickup:
            return [.closestFirst, .farthestFirst]
        case .dateOfCreation:
            return [.newestFirst, .oldestFirst]
        case .pickupDate:
            return [.earliestFirst, .latestFirst]
        case .tripDistance:
            return [.shortestFirst, .longestFirst]
        }
    }
}
