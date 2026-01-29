//
//  AddressInputPage.swift
//  Shipit
//
//  Created on 11.01.2026.
//

import SwiftUI
import CoreLocation
import MapboxMaps

struct AddressInputPage: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var fromAddress: String = ""
    @State private var toAddress: String = ""
    @State private var isGeocodingLocation = false
    @State private var isCalculatingRoute = false
    @FocusState private var focusedField: Field?
    var onRouteCalculated: (([CLLocationCoordinate2D], CLLocationCoordinate2D) -> Void)? // Route coordinates and start coordinate
    
    enum Field {
        case from, to
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Input fields container
            VStack(spacing: 12) {
                // From input field
                AddressInputField(
                    placeholder: "Enter pickup address",
                    text: $fromAddress,
                    leftIcon: IconHelper.location,
                    showRightIcon: true,
                    isActive: focusedField == .from,
                    onRightIconTap: {
                        // Set to "Your location"
                        if locationManager.location != nil {
                            fromAddress = "Your location"
                        }
                    }
                )
                .focused($focusedField, equals: .from)
                
                // To input field
                AddressInputField(
                    placeholder: "Choose destination",
                    text: $toAddress,
                    leftIcon: IconHelper.search,
                    showRightIcon: false,
                    isActive: focusedField == .to,
                    onSubmit: {
                        calculateRoute()
                    }
                )
                .focused($focusedField, equals: .to)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
        }
        .background(Colors.background)
        .scrollDismissesKeyboard(.never)
        .onTapGesture {
            // Prevent tapping outside from dismissing keyboard
        }
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
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
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            // Hide tab bar icons but keep the bar visible
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let tabBar = windowScene.windows.first?.rootViewController?.view.subviews.first(where: { $0 is UITabBar }) as? UITabBar {
                tabBar.items?.forEach { item in
                    item.image = UIImage()
                    item.selectedImage = UIImage()
                }
            }
            
            // Request location permission and get user's coordinates
            locationManager.requestLocationPermission()
            locationManager.startUpdatingLocation()
            
            // Fill from address with "Your location"
            if locationManager.location != nil {
                fromAddress = "Your location"
            }
            
            // Focus on "To" field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .to
            }
        }
        .onDisappear {
            // Restore tab bar icons when leaving the page
            // Note: The actual icons will be restored by the HomePageCarrier's onAppear
        }
        .onChange(of: locationManager.location) { oldValue, newValue in
            // Update from address with "Your location" when location is available
            if fromAddress.isEmpty, newValue != nil {
                fromAddress = "Your location"
            }
        }
    }
    
    private func geocodeLocation(_ coordinate: CLLocationCoordinate2D) {
        guard !isGeocodingLocation else { return }
        isGeocodingLocation = true
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isGeocodingLocation = false
                
                if let error = error {
                    print("Reverse geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("No placemark found")
                    return
                }
                
                // Build address string from placemark: city first, then street and number
                var addressComponents: [String] = []
                
                // Add city first
                if let city = placemark.locality {
                    addressComponents.append(city)
                } else if let name = placemark.name {
                    addressComponents.append(name)
                }
                
                // Add street and number after city
                if let street = placemark.thoroughfare {
                    if let number = placemark.subThoroughfare {
                        addressComponents.append("\(street) \(number)")
                    } else {
                        addressComponents.append(street)
                    }
                }
                
                fromAddress = addressComponents.joined(separator: ", ")
            }
        }
    }
    
    private func calculateRoute() {
        guard !toAddress.isEmpty else { return }
        guard !isCalculatingRoute else { return }
        guard !fromAddress.isEmpty else {
            print("❌ Cannot calculate route: from address is empty")
            return
        }
        
        isCalculatingRoute = true
        HapticFeedback.light()
        
        // Check if "from" is "Your location" and use actual coordinates
        if fromAddress == "Your location" {
            guard let userLocation = locationManager.location else {
                print("❌ User location not available")
                DispatchQueue.main.async {
                    self.isCalculatingRoute = false
                }
                return
            }
            
            let startCoord = userLocation.coordinate
            
            // Geocode the "to" address
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(toAddress) { [self] toPlacemarks, toError in
                if let toError = toError {
                    print("❌ Geocoding error for destination: \(toError.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                    }
                    return
                }
                
                guard let toPlacemark = toPlacemarks?.first,
                      let destinationLocation = toPlacemark.location else {
                    print("❌ No location found for destination: \(toAddress)")
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                    }
                    return
                }
                
                let destinationCoord = destinationLocation.coordinate
                
                // Fetch route from Mapbox Directions API with higher resolution
                let accessToken = MapboxOptions.accessToken
                let coordinates = "\(startCoord.longitude),\(startCoord.latitude);\(destinationCoord.longitude),\(destinationCoord.latitude)"
                let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/\(coordinates)?geometries=geojson&overview=full&access_token=\(accessToken)"
                
                guard let url = URL(string: urlString) else {
                    print("❌ Invalid URL for route")
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                    }
                    return
                }
                
                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                        
                        if let error = error {
                            print("❌ Route fetch error: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let data = data else {
                            print("❌ No route data received")
                            return
                        }
                        
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            
                            // Check for API errors
                            if let code = json?["code"] as? String, code != "Ok" {
                                print("❌ Route API error: \(code)")
                                return
                            }
                            
                            guard let routes = json?["routes"] as? [[String: Any]],
                                  let firstRoute = routes.first,
                                  let geometry = firstRoute["geometry"] as? [String: Any],
                                  let coordinates = geometry["coordinates"] as? [[Double]] else {
                                print("❌ Invalid route response format")
                                return
                            }
                            
                            // Convert coordinates to CLLocationCoordinate2D
                            let routeCoords = coordinates.compactMap { coord -> CLLocationCoordinate2D? in
                                guard coord.count >= 2 else { return nil }
                                return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                            }
                            
                            print("✅ Route calculated from 'Your location' to '\(self.toAddress)': \(routeCoords.count) points")
                            print("   📍 Start coordinate: (\(startCoord.latitude), \(startCoord.longitude))")
                            
                            // Pass route and start coordinate back to HomePageCarrier
                            self.onRouteCalculated?(routeCoords, startCoord)
                            
                            // Dismiss the page
                            self.dismiss()
                            
                        } catch {
                            print("❌ JSON parsing error: \(error.localizedDescription)")
                        }
                    }
                }
                
                task.resume()
            }
            return
        }
        
        let geocoder = CLGeocoder()
        
        // First, geocode the "from" address
        geocoder.geocodeAddressString(fromAddress) { [self] fromPlacemarks, fromError in
            if let fromError = fromError {
                print("❌ Geocoding error for from address: \(fromError.localizedDescription)")
                DispatchQueue.main.async {
                    self.isCalculatingRoute = false
                }
                return
            }
            
            guard let fromPlacemark = fromPlacemarks?.first,
                  let fromLocation = fromPlacemark.location else {
                print("❌ No location found for from address: \(fromAddress)")
                DispatchQueue.main.async {
                    self.isCalculatingRoute = false
                }
                return
            }
            
            let startCoord = fromLocation.coordinate
            
            // Then, geocode the "to" address
            geocoder.geocodeAddressString(toAddress) { [self] toPlacemarks, toError in
                if let toError = toError {
                    print("❌ Geocoding error for destination: \(toError.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                    }
                    return
                }
                
                guard let toPlacemark = toPlacemarks?.first,
                      let destinationLocation = toPlacemark.location else {
                    print("❌ No location found for destination: \(toAddress)")
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                    }
                    return
                }
                
                let destinationCoord = destinationLocation.coordinate
                
                // Fetch route from Mapbox Directions API with higher resolution
                let accessToken = MapboxOptions.accessToken
                let coordinates = "\(startCoord.longitude),\(startCoord.latitude);\(destinationCoord.longitude),\(destinationCoord.latitude)"
                let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/\(coordinates)?geometries=geojson&overview=full&access_token=\(accessToken)"
                
                guard let url = URL(string: urlString) else {
                    print("❌ Invalid URL for route")
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                    }
                    return
                }
                
                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                        
                        if let error = error {
                            print("❌ Route fetch error: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let data = data else {
                            print("❌ No route data received")
                            return
                        }
                        
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            
                            // Check for API errors
                            if let code = json?["code"] as? String, code != "Ok" {
                                print("❌ Route API error: \(code)")
                                return
                            }
                            
                            guard let routes = json?["routes"] as? [[String: Any]],
                                  let firstRoute = routes.first,
                                  let geometry = firstRoute["geometry"] as? [String: Any],
                                  let coordinates = geometry["coordinates"] as? [[Double]] else {
                                print("❌ Invalid route response format")
                                return
                            }
                            
                            // Convert coordinates to CLLocationCoordinate2D
                            let routeCoords = coordinates.compactMap { coord -> CLLocationCoordinate2D? in
                                guard coord.count >= 2 else { return nil }
                                return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                            }
                            
                            print("✅ Route calculated from '\(fromAddress)' to '\(toAddress)': \(routeCoords.count) points")
                            print("   📍 Start coordinate: (\(startCoord.latitude), \(startCoord.longitude))")
                            
                            // Pass route and start coordinate back to HomePageCarrier
                            onRouteCalculated?(routeCoords, startCoord)
                            
                            // Dismiss the page
                            dismiss()
                            
                        } catch {
                            print("❌ JSON parsing error: \(error.localizedDescription)")
                        }
                    }
                }
                
                task.resume()
            }
        }
    }
}

// Custom input field component matching Figma design
struct AddressInputField: View {
    let placeholder: String
    @Binding var text: String
    let leftIcon: String
    let showRightIcon: Bool
    var isActive: Bool = false
    var onRightIconTap: (() -> Void)? = nil
    var onSubmit: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Left icon
            LucideIcon(leftIcon, size: 24, color: Colors.secondary)
                .frame(width: 24, height: 24)
            
            // Text field
            TextField("", text: $text)
                .font(.system(size: 17))
                .foregroundColor(Colors.secondary)
                .placeholder(placeholder, when: $text, color: Colors.textSecondary)
                .submitLabel(.search)
                .onSubmit {
                    onSubmit?()
                }
            
            // Right icon (locate/crosshair) - only for "From" field
            if showRightIcon {
                Button(action: {
                    HapticFeedback.light()
                    onRightIconTap?()
                }) {
                    LucideIcon(IconHelper.crosshair, size: 24, color: Colors.secondary)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 48)
        .background(Colors.backgroundQuaternary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Colors.secondary : Color.clear, lineWidth: isActive ? 2 : 0)
        )
    }
}

#Preview {
    NavigationStack {
        AddressInputPage()
    }
}
