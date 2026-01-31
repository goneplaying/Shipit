//
//  ShipmentDataManager.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//  Updated for Supabase: 30.01.2026
//

import Foundation
import Combine

class ShipmentDataManager: ObservableObject {
    static let shared = ShipmentDataManager()
    
    @Published private(set) var shipments: [ShipmentData] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdateDate: Date?
    
    // Migration flag: Set to true to use Supabase, false to use Google Sheets
    private let useSupabase = true
    
    private let spreadsheetId = "1W52gwfN0gX64LNt3bE_vBFG87tM3XBYAuxyaA5jUExU"
    private let tripColorSpreadsheetId = "16Vyn1tjACIjvOBt1J5M5QeIsC5VsDOF2FDRCHfW00vU"
    private let userDefaultsKey = "cachedShipments"
    private let lastUpdateKey = "lastShipmentUpdate"
    private let tripColorMapKey = "cachedTripColorMap"
    private let iconMapKey = "cachedIconMap"
    
    private var supabaseService: SupabaseShipmentService?
    
    private init() {
        if useSupabase {
            // Supabase mode: Initialize service on main actor
            Task { @MainActor in
                supabaseService = SupabaseShipmentService.shared
            }
        } else {
            // Google Sheets mode: Load cached data first
            loadCachedData()
            // Load tripColor and icon data from cache first, then update from spreadsheet
            loadCachedTripColorData()
            loadTripColorData() // This will update the cache in the background
        }
    }
    
    func loadData() {
        if useSupabase {
            loadFromSupabase()
        } else {
            loadFromGoogleSheets()
        }
    }
    
    /// Load shipments from Supabase (on-demand)
    private func loadFromSupabase() {
        guard !isLoading else { return }
        
        guard let service = supabaseService else {
            print("❌ SupabaseShipmentService not initialized yet")
            return
        }
        
        Task { @MainActor in
            isLoading = true
            
            do {
                print("🔄 Fetching shipments from Supabase...")
                try await service.fetchShipments()
                
                // Copy data once (no live binding)
                shipments = service.shipments
                lastUpdateDate = Date()
                
                print("✅ Loaded \(shipments.count) shipments from Supabase")
                
                // Start preloading locations in background
                LocationCacheManager.shared.preloadLocations(for: shipments)
            } catch {
                print("❌ Error loading from Supabase: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    /// Load shipments from Google Sheets (original method)
    private func loadFromGoogleSheets() {
        guard !isLoading else { return }
        isLoading = true
        
        let urlString = "https://docs.google.com/spreadsheets/d/\(spreadsheetId)/export?format=csv"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
            
            guard let data = data,
                  let csvString = String(data: data, encoding: .utf8) else {
                print("Error loading Google Sheet data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let parsedShipments = self.parseCSVData(csvString)
            
            DispatchQueue.main.async {
                self.shipments = parsedShipments
                self.lastUpdateDate = Date()
                self.saveCachedData()
                
                // Apply tripColor and icons from tripColor spreadsheet after loading shipments
                self.applyTripColorData()
                self.applyIconData()
                
                // Start preloading locations in background
                LocationCacheManager.shared.preloadLocations(for: parsedShipments)
            }
        }.resume()
    }
    
    private var tripColorMap: [String: String] = [:] // Maps cargoType to tripColor
    private var iconMap: [String: String] = [:] // Maps cargoType to icon
    
    private func loadTripColorData() {
        // Use standard export URL format with gid
        let urlString = "https://docs.google.com/spreadsheets/d/\(tripColorSpreadsheetId)/export?format=csv&gid=0"
        
        guard let url = URL(string: urlString) else {
            print("Error: Invalid tripColor spreadsheet URL")
            return
        }
        
        var request = URLRequest(url: url)
        // Set user agent to avoid some Google blocking
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let data = data,
                  let csvString = String(data: data, encoding: .utf8) else {
                print("Error loading tripColor spreadsheet: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Check if we got HTML instead of CSV (Google login/error page)
            if csvString.contains("<!DOCTYPE html") || csvString.contains("<html") || csvString.contains("DOCTYPE") || csvString.contains("body{") {
                print("❌ Error: Received HTML instead of CSV. The spreadsheet may require authentication or the export URL is incorrect.")
                print("💡 Make sure the spreadsheet is publicly accessible (Anyone with the link can view)")
                print("📋 Trying alternative export URL format...")
                
                // Try alternative URL format
                self.tryAlternativeTripColorExport()
                return
            }
            
            // Parse the CSV data
            self.parseTripColorCSV(csvString)
        }.resume()
    }
    
    /// Try alternative export URL format if the first one fails
    private func tryAlternativeTripColorExport() {
        // Try the gviz format which sometimes works better
        let urlString = "https://docs.google.com/spreadsheets/d/\(tripColorSpreadsheetId)/gviz/tq?tqx=out:csv&gid=0"
        
        guard let url = URL(string: urlString) else {
            print("❌ Error: Invalid alternative tripColor spreadsheet URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let data = data,
                  let csvString = String(data: data, encoding: .utf8) else {
                print("❌ Error loading tripColor spreadsheet with alternative URL: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Check if we still got HTML
            if csvString.contains("<!DOCTYPE html") || csvString.contains("<html") || csvString.contains("DOCTYPE") || csvString.contains("body{") {
                print("❌ Error: Alternative URL also returned HTML. The spreadsheet must be publicly accessible.")
                print("💡 Please ensure the spreadsheet at https://docs.google.com/spreadsheets/d/\(self.tripColorSpreadsheetId)/edit is set to 'Anyone with the link can view'")
                return
            }
            
            // Parse the CSV data
            self.parseTripColorCSV(csvString)
        }.resume()
    }
    
    /// Parse tripColor CSV data (extracted to separate function for reuse)
    private func parseTripColorCSV(_ csvString: String) {
        // Parse tripColor data - find cargoType column and tripColor column
        let rows = csvString.components(separatedBy: "\n")
        guard rows.count > 1 else {
            print("Error: tripColor spreadsheet is empty")
            return
        }
        
        // Parse header row to find column indices
        let headerRow = rows[0]
        let headerColumns = self.parseCSVRow(headerRow)
        
        print("📊 Spreadsheet headers (\(headerColumns.count) columns): \(headerColumns.enumerated().map { "\($0.offset):'\($0.element)'" }.joined(separator: ", "))")
        
        // Find indices for cargoType, tripColor, and icon columns
        var cargoTypeIndex: Int?
        var tripColorIndex: Int?
        var iconIndex: Int?
        
        for (index, header) in headerColumns.enumerated() {
            let headerLower = header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if headerLower.contains("cargotype") || headerLower == "cargo type" || headerLower == "cargo_type" {
                cargoTypeIndex = index
                print("✅ Found cargoType column at index \(index): '\(header)'")
            } else if headerLower.contains("tripcolor") || headerLower.contains("trip color") || headerLower.contains("trip_color") || headerLower == "color" {
                tripColorIndex = index
                print("✅ Found tripColor column at index \(index): '\(header)'")
            } else if headerLower.contains("icon") {
                iconIndex = index
                print("✅ Found icon column at index \(index): '\(header)'")
            }
        }
        
        // If not found by name, try common column positions (cargoType usually at column 9/index 9, tripColor at column 26/index 26)
        if cargoTypeIndex == nil {
            cargoTypeIndex = headerColumns.count > 9 ? 9 : nil
        }
        if tripColorIndex == nil {
            tripColorIndex = headerColumns.count > 26 ? 26 : (headerColumns.count > 1 ? 1 : nil)
        }
        // Try to find icon column by position if not found by name
        if iconIndex == nil {
            print("⚠️ Icon column not found by name, searching all headers...")
            // Try to find icon column by checking all headers for "icon" keyword (case-insensitive)
            for (idx, header) in headerColumns.enumerated() {
                let testHeader = header.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if testHeader == "icon" || testHeader.contains("icon") {
                    iconIndex = idx
                    print("📍 Icon column found at index \(idx) by searching headers (header: '\(header)')")
                    break
                }
            }
            // If still not found, try common positions
            // Common positions: right after tripColor (index 27), or at index 1, 2
            if iconIndex == nil {
                // Try position right after tripColor if tripColor was found
                if let colorIdx = tripColorIndex, headerColumns.count > colorIdx + 1 {
                    let nextIdx = colorIdx + 1
                    iconIndex = nextIdx
                    print("📍 Icon column defaulting to index \(nextIdx) (right after tripColor at \(colorIdx), header: '\(headerColumns[nextIdx])')")
                } else {
                    // Try positions 1, 2, 27 as fallback
                    for idx in [1, 2, 27] where headerColumns.count > idx {
                        iconIndex = idx
                        print("📍 Icon column defaulting to index \(idx) (header: '\(headerColumns[idx])')")
                        break
                    }
                }
            }
        } else {
            print("📍 Icon column found at index \(iconIndex!) by name (header: '\(headerColumns[iconIndex!])')")
        }
        
        if iconIndex == nil {
            print("❌ Icon column not found in spreadsheet. Available headers: \(headerColumns.joined(separator: ", "))")
        } else {
            print("✅ Using icon column at index \(iconIndex!)")
        }
        
        guard let cargoIdx = cargoTypeIndex, let colorIdx = tripColorIndex else {
            print("Error: Could not find cargoType or tripColor columns in spreadsheet")
            return
        }
        
        var colorMap: [String: String] = [:]
        var iconMapTemp: [String: String] = [:]
        
        // Parse data rows
        for i in 1..<rows.count {
            let row = rows[i]
            if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let columns = self.parseCSVRow(row)
            
            if columns.count > max(cargoIdx, colorIdx) {
                let cargoType = columns[cargoIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                let tripColor = columns[colorIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cargoType.isEmpty && !tripColor.isEmpty {
                    colorMap[cargoType] = tripColor
                }
            }
            
            // Parse icon if icon column found
            if let iconIdx = iconIndex {
                if columns.count > iconIdx {
                    let cargoType = columns.count > cargoIdx ? columns[cargoIdx].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    let icon = columns[iconIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cargoType.isEmpty && !icon.isEmpty {
                        // Strip "lucide/" prefix if present
                        let cleanIcon = stripLucidePrefix(from: icon)
                        iconMapTemp[cargoType] = cleanIcon
                        if i <= 5 { // Only print first 5 for debugging
                            print("📝 Row \(i): Parsed icon for cargoType '\(cargoType)': '\(cleanIcon)' (from '\(icon)')")
                        }
                    } else {
                        if i <= 5 && !cargoType.isEmpty {
                            print("⚠️ Row \(i): Icon is empty for cargoType '\(cargoType)'")
                        }
                    }
                } else {
                    if i <= 5 {
                        print("⚠️ Row \(i): Icon column index \(iconIdx) found but row has only \(columns.count) columns")
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.tripColorMap = colorMap
            self.iconMap = iconMapTemp
            print("✅ Loaded \(colorMap.count) tripColor mappings and \(iconMapTemp.count) icon mappings from spreadsheet (cargoType -> tripColor/icon)")
            if !iconMapTemp.isEmpty {
                print("📋 Icon mappings loaded: \(iconMapTemp.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
            } else {
                print("⚠️ No icon mappings found in spreadsheet. iconIndex: \(iconIndex != nil ? String(iconIndex!) : "nil"), cargoIdx: \(cargoIdx)")
            }
            
            // Save to cache for faster loading next time
            self.saveCachedTripColorData()
            
            // Apply tripColor and icons to existing shipments if they're already loaded
            if !self.shipments.isEmpty {
                self.applyTripColorData()
                self.applyIconData()
            } else {
                print("ℹ️ Shipments not loaded yet, icons will be applied when shipments are loaded")
            }
        }
    }
    
    private func applyTripColorData() {
        guard !tripColorMap.isEmpty && !shipments.isEmpty else { return }
        
        var updatedCount = 0
        let updatedShipments = shipments.map { shipment -> ShipmentData in
            // Check if there's a tripColor for this cargoType
            let cargoType = shipment.cargoType.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newTripColor = tripColorMap[cargoType], !newTripColor.isEmpty {
                // Only update if current tripColor is different or empty
                if shipment.tripColor != newTripColor {
                    updatedCount += 1
                    // Create new ShipmentData instance with updated tripColor
                    return ShipmentData(
                        id: shipment.id,
                        userUID: shipment.userUID,
                        pickupLocation: shipment.pickupLocation,
                        deliveryLocation: shipment.deliveryLocation,
                        pickupCity: shipment.pickupCity,
                        deliveryCity: shipment.deliveryCity,
                        tripDistance: shipment.tripDistance,
                        distanceUnit: shipment.distanceUnit,
                        cargoType: shipment.cargoType,
                        title: shipment.title,
                        quantity: shipment.quantity,
                        totalWeight: shipment.totalWeight,
                        weightUnit: shipment.weightUnit,
                        offersNumber: shipment.offersNumber,
                        minOffer: shipment.minOffer,
                        maxOffer: shipment.maxOffer,
                        currency: shipment.currency,
                        createdAt: shipment.createdAt,
                        pickupDate: shipment.pickupDate,
                        deliveryDate: shipment.deliveryDate,
                        tripColor: newTripColor, // Use tripColor from tripColor spreadsheet based on cargoType
                        icon: shipment.icon, // Keep existing icon
                        totalDimensions: shipment.totalDimensions,
                        shippersName: shipment.shippersName,
                        shippersSurname: shipment.shippersSurname,
                        shippersRating: shipment.shippersRating,
                        shippersLanguage: shipment.shippersLanguage
                    )
                }
            }
            return shipment
        }
        
        if updatedCount > 0 {
            shipments = updatedShipments
            saveCachedData()
            print("✅ Updated tripColor for \(updatedCount) shipment(s) based on cargoType from tripColor spreadsheet")
        }
    }
    
    private func applyIconData() {
        guard !iconMap.isEmpty && !shipments.isEmpty else {
            print("⚠️ applyIconData: iconMap is empty (\(iconMap.count)) or shipments is empty (\(shipments.count))")
            return
        }
        
        var updatedShipments: [ShipmentData] = []
        var updatedCount = 0
        var matchedCargoTypes = Set<String>()
        
        for shipment in shipments {
            // Check if there's an icon for this cargoType (case-insensitive, trimmed)
            let cargoType = shipment.cargoType.trimmingCharacters(in: .whitespacesAndNewlines)
            let cargoTypeLower = cargoType.lowercased()
            
            // Try exact match first
            var matchedIcon: String? = iconMap[cargoType]
            
            // If no exact match, try case-insensitive match
            if matchedIcon == nil {
                for (mapCargoType, mapIcon) in iconMap {
                    if mapCargoType.lowercased() == cargoTypeLower {
                        matchedIcon = mapIcon
                        matchedCargoTypes.insert(mapCargoType)
                        break
                    }
                }
            } else {
                matchedCargoTypes.insert(cargoType)
            }
            
            if let newIcon = matchedIcon, !newIcon.isEmpty {
                // Always update if icon is different or empty
                if shipment.icon != newIcon {
                    updatedCount += 1
                    // Create new ShipmentData instance with updated icon
                    let updatedShipment = ShipmentData(
                        id: shipment.id,
                        userUID: shipment.userUID,
                        pickupLocation: shipment.pickupLocation,
                        deliveryLocation: shipment.deliveryLocation,
                        pickupCity: shipment.pickupCity,
                        deliveryCity: shipment.deliveryCity,
                        tripDistance: shipment.tripDistance,
                        distanceUnit: shipment.distanceUnit,
                        cargoType: shipment.cargoType,
                        title: shipment.title,
                        quantity: shipment.quantity,
                        totalWeight: shipment.totalWeight,
                        weightUnit: shipment.weightUnit,
                        offersNumber: shipment.offersNumber,
                        minOffer: shipment.minOffer,
                        maxOffer: shipment.maxOffer,
                        currency: shipment.currency,
                        createdAt: shipment.createdAt,
                        pickupDate: shipment.pickupDate,
                        deliveryDate: shipment.deliveryDate,
                        tripColor: shipment.tripColor,
                        icon: newIcon, // Use icon from spreadsheet based on cargoType
                        totalDimensions: shipment.totalDimensions,
                        shippersName: shipment.shippersName,
                        shippersSurname: shipment.shippersSurname,
                        shippersRating: shipment.shippersRating,
                        shippersLanguage: shipment.shippersLanguage
                    )
                    updatedShipments.append(updatedShipment)
                    print("🔄 Updating icon for cargoType '\(cargoType)' to '\(newIcon)'")
                } else {
                    updatedShipments.append(shipment)
                }
            } else {
                updatedShipments.append(shipment)
                if !cargoType.isEmpty {
                    print("⚠️ No icon found for cargoType '\(cargoType)' in iconMap. Available cargoTypes: \(Array(iconMap.keys).joined(separator: ", "))")
                }
            }
        }
        
        if updatedCount > 0 {
            shipments = updatedShipments
            saveCachedData()
            print("✅ Updated icon for \(updatedCount) shipment(s) based on cargoType. Matched cargoTypes: \(Array(matchedCargoTypes).joined(separator: ", "))")
        } else {
            print("⚠️ No icons were updated. iconMap has \(iconMap.count) entries, shipments has \(shipments.count) entries")
        }
    }
    
    private func parseCSVData(_ csvString: String) -> [ShipmentData] {
        let rows = csvString.components(separatedBy: "\n")
        guard rows.count > 1 else { return [] }
        
        var parsedShipments: [ShipmentData] = []
        
        for i in 1..<rows.count {
            let row = rows[i]
            if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let columns = parseCSVRow(row)
            
            if columns.count >= 4 {
                // Column mapping: A=0(id), B=1(userUID), C=2(pickupLocation), D=3(deliveryLocation),
                // E=4(pickupCity), F=5(deliveryCity), G=6(tripDistance), H=7(distanceUnit), I=8(title),
                // J=9(cargoType), K=10(quantity), L=11(totalWeight), M=12(weightUnit), N=13(totalDimensions),
                // O=14(offersNumber), P=15(minOffer), Q=16(maxOffer), R=17(currency), S=18(status), T=19(createdAt), U=20(pickupDate), V=21(deliveryDate), W=22(shippersName), X=23(shippersSurname), Y=24(shippersRating), Z=25(shippersLanguage), AA=26(tripColor), AB=27(icon)
                let shipment = ShipmentData(
                    id: columns.count > 0 ? columns[0].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    userUID: columns.count > 1 ? columns[1].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    pickupLocation: columns.count > 2 ? columns[2].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    deliveryLocation: columns.count > 3 ? columns[3].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    pickupCity: columns.count > 4 ? columns[4].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    deliveryCity: columns.count > 5 ? columns[5].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    tripDistance: columns.count > 6 ? columns[6].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    distanceUnit: columns.count > 7 ? columns[7].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    cargoType: columns.count > 9 ? columns[9].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    title: columns.count > 8 ? columns[8].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    quantity: columns.count > 10 ? columns[10].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    totalWeight: columns.count > 11 ? columns[11].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    weightUnit: columns.count > 12 ? columns[12].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    offersNumber: columns.count > 14 ? columns[14].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    minOffer: columns.count > 15 ? columns[15].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    maxOffer: columns.count > 16 ? columns[16].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    currency: columns.count > 17 ? columns[17].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    createdAt: columns.count > 19 ? columns[19].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    pickupDate: columns.count > 20 ? columns[20].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    deliveryDate: columns.count > 21 ? columns[21].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    tripColor: columns.count > 26 ? columns[26].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    icon: "", // Icon will be set from tripColor spreadsheet based on cargoType
                    totalDimensions: columns.count > 13 ? columns[13].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    shippersName: columns.count > 22 ? columns[22].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    shippersSurname: columns.count > 23 ? columns[23].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    shippersRating: columns.count > 24 ? columns[24].trimmingCharacters(in: .whitespacesAndNewlines) : "",
                    shippersLanguage: columns.count > 25 ? columns[25].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                )
                
                parsedShipments.append(shipment)
            }
        }
        
        return parsedShipments
    }
    
    /// Strip "lucide/" prefix from icon names (e.g., "lucide/package" -> "package")
    private func stripLucidePrefix(from iconName: String) -> String {
        let trimmed = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("lucide/") {
            return String(trimmed.dropFirst(7)) // Remove "lucide/" (7 characters)
        }
        return trimmed
    }
    
    private func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for character in row {
            if character == "\"" {
                insideQuotes.toggle()
            } else if character == "," && !insideQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(character)
            }
        }
        result.append(currentField) // Add last field
        return result
    }
    
    private func saveCachedData() {
        if let encoded = try? JSONEncoder().encode(shipments) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            UserDefaults.standard.set(lastUpdateDate, forKey: lastUpdateKey)
        }
    }
    
    func clearTripColorCache(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(false, "Failed to clear tripColor cache")
                }
                return
            }
            
            // Load cached shipments
            guard let data = UserDefaults.standard.data(forKey: self.userDefaultsKey),
                  let decoded = try? JSONDecoder().decode([ShipmentData].self, from: data) else {
                DispatchQueue.main.async {
                    completion(false, "No cached data found")
                }
                return
            }
            
            // Clear tripColor from all shipments by creating new instances with empty tripColor
            var clearedCount = 0
            let clearedShipments = decoded.map { shipment -> ShipmentData in
                if !shipment.tripColor.isEmpty {
                    clearedCount += 1
                    // Create new ShipmentData instance with empty tripColor
                    return ShipmentData(
                        id: shipment.id,
                        userUID: shipment.userUID,
                        pickupLocation: shipment.pickupLocation,
                        deliveryLocation: shipment.deliveryLocation,
                        pickupCity: shipment.pickupCity,
                        deliveryCity: shipment.deliveryCity,
                        tripDistance: shipment.tripDistance,
                        distanceUnit: shipment.distanceUnit,
                        cargoType: shipment.cargoType,
                        title: shipment.title,
                        quantity: shipment.quantity,
                        totalWeight: shipment.totalWeight,
                        weightUnit: shipment.weightUnit,
                        offersNumber: shipment.offersNumber,
                        minOffer: shipment.minOffer,
                        maxOffer: shipment.maxOffer,
                        currency: shipment.currency,
                        createdAt: shipment.createdAt,
                        pickupDate: shipment.pickupDate,
                        deliveryDate: shipment.deliveryDate,
                        tripColor: "", // Clear tripColor
                        icon: shipment.icon, // Keep icon
                        totalDimensions: shipment.totalDimensions,
                        shippersName: shipment.shippersName,
                        shippersSurname: shipment.shippersSurname,
                        shippersRating: shipment.shippersRating,
                        shippersLanguage: shipment.shippersLanguage
                    )
                }
                return shipment
            }
            
            // Save back to cache
            if let encoded = try? JSONEncoder().encode(clearedShipments) {
                UserDefaults.standard.set(encoded, forKey: self.userDefaultsKey)
                UserDefaults.standard.synchronize()
                
                // Update in-memory shipments
                DispatchQueue.main.async {
                    self.shipments = clearedShipments
                    
                    let message = clearedCount > 0 
                        ? "Cleared tripColor from \(clearedCount) cached shipment(s)"
                        : "No tripColor values found in cache"
                    completion(true, message)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Failed to save updated cache")
                }
            }
        }
    }
    
    func clearIconCache(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(false, "Failed to clear icon cache")
                }
                return
            }
            
            // Load cached shipments
            guard let data = UserDefaults.standard.data(forKey: self.userDefaultsKey),
                  let decoded = try? JSONDecoder().decode([ShipmentData].self, from: data) else {
                DispatchQueue.main.async {
                    completion(false, "No cached data found")
                }
                return
            }
            
            // Clear icon from all shipments by creating new instances with empty icon
            var clearedCount = 0
            let clearedShipments = decoded.map { shipment -> ShipmentData in
                if !shipment.icon.isEmpty {
                    clearedCount += 1
                    // Create new ShipmentData instance with empty icon
                    return ShipmentData(
                        id: shipment.id,
                        userUID: shipment.userUID,
                        pickupLocation: shipment.pickupLocation,
                        deliveryLocation: shipment.deliveryLocation,
                        pickupCity: shipment.pickupCity,
                        deliveryCity: shipment.deliveryCity,
                        tripDistance: shipment.tripDistance,
                        distanceUnit: shipment.distanceUnit,
                        cargoType: shipment.cargoType,
                        title: shipment.title,
                        quantity: shipment.quantity,
                        totalWeight: shipment.totalWeight,
                        weightUnit: shipment.weightUnit,
                        offersNumber: shipment.offersNumber,
                        minOffer: shipment.minOffer,
                        maxOffer: shipment.maxOffer,
                        currency: shipment.currency,
                        createdAt: shipment.createdAt,
                        pickupDate: shipment.pickupDate,
                        deliveryDate: shipment.deliveryDate,
                        tripColor: shipment.tripColor, // Keep tripColor
                        icon: "", // Clear icon
                        totalDimensions: shipment.totalDimensions,
                        shippersName: shipment.shippersName,
                        shippersSurname: shipment.shippersSurname,
                        shippersRating: shipment.shippersRating,
                        shippersLanguage: shipment.shippersLanguage
                    )
                }
                return shipment
            }
            
            // Save back to cache
            if let encoded = try? JSONEncoder().encode(clearedShipments) {
                UserDefaults.standard.set(encoded, forKey: self.userDefaultsKey)
                UserDefaults.standard.synchronize()
                
                // Update in-memory shipments
                DispatchQueue.main.async {
                    self.shipments = clearedShipments
                    
                    let message = clearedCount > 0 
                        ? "Cleared icon from \(clearedCount) cached shipment(s)"
                        : "No icon values found in cache"
                    completion(true, message)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Failed to save updated cache")
                }
            }
        }
    }
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ShipmentData].self, from: data) {
            shipments = decoded
            
            // Start preloading locations for cached data
            LocationCacheManager.shared.preloadLocations(for: decoded)
        }
        
        if let date = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date {
            lastUpdateDate = date
        }
    }
    
    /// Load tripColor and icon mappings from cache
    private func loadCachedTripColorData() {
        // Load tripColor map
        if let tripColorData = UserDefaults.standard.data(forKey: tripColorMapKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: tripColorData) {
            tripColorMap = decoded
            print("✅ Loaded \(decoded.count) tripColor mappings from cache")
        }
        
        // Load icon map
        if let iconData = UserDefaults.standard.data(forKey: iconMapKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: iconData) {
            iconMap = decoded
            print("✅ Loaded \(decoded.count) icon mappings from cache")
            
            // Apply cached icons to shipments if they're already loaded
            if !shipments.isEmpty {
                applyIconData()
            }
        }
    }
    
    /// Save tripColor and icon mappings to cache
    private func saveCachedTripColorData() {
        // Save tripColor map
        if let encoded = try? JSONEncoder().encode(tripColorMap) {
            UserDefaults.standard.set(encoded, forKey: tripColorMapKey)
        }
        
        // Save icon map
        if let encoded = try? JSONEncoder().encode(iconMap) {
            UserDefaults.standard.set(encoded, forKey: iconMapKey)
        }
        
        UserDefaults.standard.synchronize()
        print("💾 Saved tripColor and icon mappings to cache")
    }
    
    // MARK: - Supabase CRUD Operations
    
    /// Create a new shipment (Supabase only)
    func createShipment(_ shipment: ShipmentData) async throws -> ShipmentData {
        guard useSupabase else {
            throw NSError(domain: "ShipmentDataManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Create operation only available in Supabase mode"])
        }
        
        guard let service = supabaseService else {
            throw NSError(domain: "ShipmentDataManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Supabase service not initialized"])
        }
        
        let createdShipment = try await service.createShipment(shipment)
        print("✅ Created shipment: \(createdShipment.id)")
        return createdShipment
    }
    
    /// Update an existing shipment (Supabase only)
    func updateShipment(_ shipment: ShipmentData) async throws {
        guard useSupabase else {
            throw NSError(domain: "ShipmentDataManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Update operation only available in Supabase mode"])
        }
        
        guard let service = supabaseService else {
            throw NSError(domain: "ShipmentDataManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Supabase service not initialized"])
        }
        
        try await service.updateShipment(shipment)
        print("✅ Updated shipment: \(shipment.id)")
    }
    
    /// Delete a shipment (Supabase only)
    func deleteShipment(_ shipmentId: String) async throws {
        guard useSupabase else {
            throw NSError(domain: "ShipmentDataManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Delete operation only available in Supabase mode"])
        }
        
        guard let service = supabaseService else {
            throw NSError(domain: "ShipmentDataManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Supabase service not initialized"])
        }
        
        try await service.deleteShipment(shipmentId)
        print("✅ Deleted shipment: \(shipmentId)")
    }
}
