//
//  ExchangePreferencesPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import CoreLocation

struct ExchangePreferencesPage: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @ObservedObject private var categoryManager = CategoryFilterManager.shared
    @State private var isLoadingCity = false
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    var body: some View {
        ZStack {
            Colors.backgroundQuaternary
                .ignoresSafeArea()
            
            List {
                Section {
                    // Use location of dropdown
                    HStack {
                        Text("Use location of")
                            .foregroundColor(Colors.text)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { filterSettings.locationSource ?? .device },
                            set: { newValue in
                                filterSettings.locationSource = newValue
                                filterSettings.saveSettings()
                            }
                        )) {
                            ForEach(LocationSource.allCases, id: \.self) { source in
                                Text(source.rawValue).tag(source)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(Colors.text)
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    
                    // Show choose city when Place is selected
                    if filterSettings.locationSource == .place {
                        NavigationLink(destination: ChooseLocationView(selectedCity: $filterSettings.selectedCity, selectedCoordinate: $filterSettings.selectedCityCoordinate)) {
                            HStack {
                                Text("Choose city")
                                    .foregroundColor(Colors.text)
                                Spacer()
                                if isLoadingCity {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text(filterSettings.selectedCity.isEmpty ? "Loading..." : filterSettings.selectedCity)
                                        .foregroundColor(Colors.textSecondary)
                                        .font(.callout)
                                }
                            }
                            .frame(minHeight: 40)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    }
                    
                    // Pickups slider (shown when location source is selected)
                    if filterSettings.locationSource != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            let locationText = filterSettings.locationSource == .device ? "device location" : "chosen location"
                            Text("Pickups \(Int(filterSettings.sliderValue)) km from \(locationText)")
                                .foregroundColor(Colors.text)
                                .font(.callout)
                            
                            Slider(value: Binding(
                                get: { filterSettings.sliderValue },
                                set: { newValue in
                                    // Round to nearest 10
                                    filterSettings.sliderValue = round(newValue / 10) * 10
                                }
                            ), in: 0...10000, step: 10)
                                .tint(Colors.primary)
                        }
                        .frame(minHeight: 40)
                        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 12, trailing: 20))
                    }
                } header: {
                    Text("Range")
                } footer: {
                    Text("Range defines the area within which pickup locations are displayed.")
                }
                
                Section {
                    // Weight filter dropdown
                    HStack {
                        Text("Weight")
                            .foregroundColor(Colors.text)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { filterSettings.weightFilter },
                            set: { newValue in
                                filterSettings.weightFilter = newValue
                                filterSettings.saveSettings()
                            }
                        )) {
                            Text("All").tag(WeightFilter?.none)
                            ForEach(WeightFilter.allCases, id: \.self) { weightFilter in
                                Text(weightFilter.rawValue).tag(WeightFilter?.some(weightFilter))
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(Colors.text)
                        .frame(width: 150)
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                } header: {
                    Text("Weight")
                }
                
                Section {
                    // Selected categories link
                    NavigationLink(destination: CategoriesPage()) {
                        HStack {
                            Text("Selected categories")
                                .foregroundColor(Colors.text)
                            Spacer()
                            Text(categoryManager.isAllSelected ? "All" : "\(categoryManager.selectedCount) of \(categoryManager.totalCount)")
                                .foregroundColor(Colors.textSecondary)
                                .font(.callout)
                        }
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                } header: {
                    Text("Categories")
                }
                
                Section {
                    // Requests with no offer only toggle
                    HStack {
                        Text("Requests with no offer only")
                            .foregroundColor(Colors.text)
                        Spacer()
                        Toggle("", isOn: $filterSettings.requestWithNoOfferOnly)
                            .labelsHidden()
                            .tint(Colors.primary)
                            .onChange(of: filterSettings.requestWithNoOfferOnly) { _, _ in
                                HapticFeedback.light()
                            }
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                } header: {
                    Text("Pricing")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    HapticFeedback.light()
                    dismiss()
                }) {
                    LucideIcon(IconHelper.arrowLeft, size: 24, color: Colors.text)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .bottomBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
            if filterSettings.locationSource == .device {
                fetchCityFromLocation()
            }
            // Validate sortOrder is valid for current sortType
            let availableOrders = filterSettings.getAvailableSortOrders(for: filterSettings.sortType)
            if !availableOrders.contains(filterSettings.sortOrder) {
                if let firstOrder = availableOrders.first {
                    filterSettings.sortOrder = firstOrder
                    filterSettings.saveSettings()
                }
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if filterSettings.locationSource == .device, let location = newLocation {
                fetchCityFromLocation(location: location.coordinate)
            }
        }
        .onChange(of: filterSettings.locationSource) { _, newValue in
            filterSettings.saveSettings()
            if newValue == .device {
                fetchCityFromLocation()
            }
        }
        .onChange(of: filterSettings.sliderValue) { _, _ in
            filterSettings.saveSettings()
        }
        .onChange(of: filterSettings.selectedCity) { _, _ in
            filterSettings.saveSettings()
        }
        .onChange(of: filterSettings.requestWithNoOfferOnly) { _, _ in
            filterSettings.saveSettings()
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
            filterSettings.saveSettings()
        }
    }
    
    private func fetchCityFromLocation(location: CLLocationCoordinate2D? = nil) {
        let coordinate = location ?? locationManager.location?.coordinate
        
        guard let coordinate = coordinate else {
            // Request location if not available
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
            return
        }
        
        isLoadingCity = true
        reverseGeocode(coordinate: coordinate) { cityName in
            DispatchQueue.main.async {
                if let cityName = cityName {
                    self.filterSettings.selectedCity = cityName
                    if self.filterSettings.locationSource == .device {
                        self.filterSettings.selectedCityCoordinate = coordinate
                    }
                    self.filterSettings.saveSettings()
                } else {
                    self.filterSettings.selectedCity = "Unknown Location"
                }
                self.isLoadingCity = false
            }
        }
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(coordinate.longitude),\(coordinate.latitude).json?access_token=\(accessToken)&types=place"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]],
                  let firstFeature = features.first,
                  let placeName = firstFeature["place_name"] as? String else {
                completion(nil)
                return
            }
            
            // Extract city name from place_name (format: "City, Region, Country")
            let components = placeName.components(separatedBy: ",")
            let cityName = components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? placeName
            
            completion(cityName)
        }.resume()
    }
}

// Placeholder view for Choose Location
struct ChooseLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCity: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Text("Choose Location")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Mapbox location selection will be implemented here")
                    .font(.callout)
                    .foregroundColor(Colors.textSecondary)
                    .padding(.top, 8)
                Spacer()
            }
        }
        .navigationTitle("Choose Location")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        ExchangePreferencesPage()
    }
}
