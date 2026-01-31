//
//  SupabaseShipmentService.swift
//  Shipit
//
//  Created on 30.01.2026.
//

import Foundation
import Supabase
import Combine

@MainActor
class SupabaseShipmentService: ObservableObject {
    static let shared = SupabaseShipmentService()
    
    @Published private(set) var shipments: [ShipmentData] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let client: SupabaseClient
    private var realtimeChannel: RealtimeChannelV2?
    private var cancellables = Set<AnyCancellable>()
    private var insertTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var deleteTask: Task<Void, Never>?
    
    // Cache for cargo types (tripColor and icon mapping)
    private var cargoTypeCache: [String: CargoTypeInfo] = [:]
    
    struct CargoTypeInfo: Codable {
        let tripColor: String
        let icon: String
    }
    
    private init() {
        self.client = SupabaseAuthService.shared.client
        
        // Load cargo types cache on init
        Task {
            await loadCargoTypes()
        }
    }
    
    // MARK: - Real-time Subscriptions
    
    /// Subscribe to real-time shipment updates
    func subscribeToShipments() async {
        // Unsubscribe from previous channel if exists
        await unsubscribeFromShipments()
        
        // Create new channel for shipments
        let channel = client.realtimeV2.channel("shipments")
        
        // Listen to INSERT events
        let insertChanges = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "shipments"
        )
        
        // Listen to UPDATE events
        let updateChanges = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "shipments"
        )
        
        // Listen to DELETE events
        let deleteChanges = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "shipments"
        )
        
        // Subscribe to the channel
        try? await channel.subscribeWithError()
        
        // Handle INSERT events
        insertTask = Task { [weak self] in
            guard let self = self else { return }
            for await change in insertChanges {
                print("🔴 Real-time INSERT: \(change.record)")
                await self.handleRealtimeInsert(change.record)
            }
        }
        
        // Handle UPDATE events
        updateTask = Task { [weak self] in
            guard let self = self else { return }
            for await change in updateChanges {
                print("🟡 Real-time UPDATE: \(change.record)")
                await self.handleRealtimeUpdate(change.record)
            }
        }
        
        // Handle DELETE events
        deleteTask = Task { [weak self] in
            guard let self = self else { return }
            for await change in deleteChanges {
                print("🔵 Real-time DELETE: \(change.oldRecord)")
                await self.handleRealtimeDelete(change.oldRecord)
            }
        }
        
        realtimeChannel = channel
        print("✅ Subscribed to real-time shipments updates")
    }
    
    /// Unsubscribe from real-time updates
    func unsubscribeFromShipments() async {
        // Cancel all listening tasks
        insertTask?.cancel()
        updateTask?.cancel()
        deleteTask?.cancel()
        insertTask = nil
        updateTask = nil
        deleteTask = nil
        
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
            print("👋 Unsubscribed from real-time shipments updates")
        }
    }
    
    // MARK: - Real-time Event Handlers
    
    private func handleRealtimeInsert(_ record: [String: AnyJSON]) async {
        do {
            let shipment = try parseShipmentFromJSON(record)
            
            // Check if shipment already exists
            if !shipments.contains(where: { $0.id == shipment.id }) {
                shipments.insert(shipment, at: 0) // Add to beginning
                print("✅ Added new shipment: \(shipment.id)")
            }
        } catch {
            print("❌ Error parsing real-time INSERT: \(error)")
        }
    }
    
    private func handleRealtimeUpdate(_ record: [String: AnyJSON]) async {
        do {
            let updatedShipment = try parseShipmentFromJSON(record)
            
            // Find and update existing shipment
            if let index = shipments.firstIndex(where: { $0.id == updatedShipment.id }) {
                shipments[index] = updatedShipment
                print("✅ Updated shipment: \(updatedShipment.id)")
            } else {
                // If not found, add it (might be filtered in initially)
                shipments.insert(updatedShipment, at: 0)
                print("✅ Added updated shipment: \(updatedShipment.id)")
            }
        } catch {
            print("❌ Error parsing real-time UPDATE: \(error)")
        }
    }
    
    private func handleRealtimeDelete(_ record: [String: AnyJSON]) async {
        // Extract ID from old record
        if let idValue = record["id"],
           case .string(let id) = idValue {
            shipments.removeAll(where: { $0.id == id })
            print("✅ Deleted shipment: \(id)")
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Fetch all shipments based on user role
    func fetchShipments() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let userId = SupabaseAuthService.shared.user?.id else {
            let errorMsg = "User not authenticated - cannot fetch shipments"
            print("❌ \(errorMsg)")
            errorMessage = errorMsg
            throw NSError(domain: "SupabaseShipmentService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        print("👤 Fetching shipments for user: \(userId)")
        
        // Fetch ALL shipments (everyone sees everything)
        // user_uid just tracks who created each shipment
        print("📥 Fetching ALL active shipments...")
        let shipmentRecords: [ShipmentRecord]
        
        do {
            shipmentRecords = try await client
                .from("shipments")
                .select()
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("📦 Received \(shipmentRecords.count) shipment records from Supabase")
            
            // Convert to ShipmentData
            let newShipments = shipmentRecords.map { convertToShipmentData($0) }
            
            // Only update if data actually changed to prevent triggering unnecessary observers
            let hasChanged = shipments.count != newShipments.count || 
                             Set(shipments.map { $0.id }) != Set(newShipments.map { $0.id })
            
            if hasChanged || shipments.isEmpty {
                shipments = newShipments
                print("✅ Fetched \(shipments.count) shipments - DATA CHANGED")
            } else {
                print("📊 Shipments unchanged (\(shipments.count) items), skipping update")
            }
            
            print("✅ Fetch complete")
            
            // Log first shipment if available
            if let first = shipments.first {
                print("   First shipment: \(first.pickupCity) → \(first.deliveryCity)")
            }
        } catch {
            print("❌ Error fetching shipments from Supabase: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Create a new shipment
    func createShipment(_ shipment: ShipmentData) async throws -> ShipmentData {
        guard let userId = SupabaseAuthService.shared.user?.id else {
            throw NSError(domain: "SupabaseShipmentService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let record = ShipmentRecord(
            id: nil,
            userUid: userId.uuidString,
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
            totalDimensions: shipment.totalDimensions,
            offersNumber: shipment.offersNumber,
            minOffer: shipment.minOffer,
            maxOffer: shipment.maxOffer,
            currency: shipment.currency,
            pickupDate: shipment.pickupDate,
            deliveryDate: shipment.deliveryDate,
            tripColor: nil, // Will be auto-populated by trigger
            icon: nil, // Will be auto-populated by trigger
            shippersName: shipment.shippersName,
            shippersSurname: shipment.shippersSurname,
            shippersRating: shipment.shippersRating,
            shippersLanguage: shipment.shippersLanguage,
            status: "active",
            createdAt: nil,
            updatedAt: nil
        )
        
        let createdRecord: ShipmentRecord = try await client
            .from("shipments")
            .insert(record)
            .select()
            .single()
            .execute()
            .value
        
        let createdShipment = convertToShipmentData(createdRecord)
        print("✅ Created shipment: \(createdShipment.id)")
        
        return createdShipment
    }
    
    /// Update an existing shipment
    func updateShipment(_ shipment: ShipmentData) async throws {
        let record = ShipmentRecord(
            id: shipment.id,
            userUid: shipment.userUID,
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
            totalDimensions: shipment.totalDimensions,
            offersNumber: shipment.offersNumber,
            minOffer: shipment.minOffer,
            maxOffer: shipment.maxOffer,
            currency: shipment.currency,
            pickupDate: shipment.pickupDate,
            deliveryDate: shipment.deliveryDate,
            tripColor: shipment.tripColor,
            icon: shipment.icon,
            shippersName: shipment.shippersName,
            shippersSurname: shipment.shippersSurname,
            shippersRating: shipment.shippersRating,
            shippersLanguage: shipment.shippersLanguage,
            status: "active",
            createdAt: nil,
            updatedAt: nil
        )
        
        try await client
            .from("shipments")
            .update(record)
            .eq("id", value: shipment.id)
            .execute()
        
        print("✅ Updated shipment: \(shipment.id)")
    }
    
    /// Delete a shipment
    func deleteShipment(_ shipmentId: String) async throws {
        try await client
            .from("shipments")
            .delete()
            .eq("id", value: shipmentId)
            .execute()
        
        print("✅ Deleted shipment: \(shipmentId)")
    }
    
    // MARK: - Cargo Types
    
    /// Load cargo types (tripColor and icon mappings)
    private func loadCargoTypes() async {
        do {
            let records: [CargoTypeRecord] = try await client
                .from("cargo_types")
                .select()
                .execute()
                .value
            
            cargoTypeCache = Dictionary(uniqueKeysWithValues: records.map { 
                ($0.cargoType, CargoTypeInfo(tripColor: $0.tripColor, icon: $0.icon))
            })
            
            print("✅ Loaded \(cargoTypeCache.count) cargo type mappings")
        } catch {
            print("❌ Error loading cargo types: \(error)")
        }
    }
    
    /// Get tripColor and icon for a cargo type
    func getCargoTypeInfo(_ cargoType: String) -> CargoTypeInfo? {
        return cargoTypeCache[cargoType]
    }
    
    // MARK: - Helper Methods
    
    private func convertToShipmentData(_ record: ShipmentRecord) -> ShipmentData {
        return ShipmentData(
            id: record.id ?? UUID().uuidString,
            userUID: record.userUid,
            pickupLocation: record.pickupLocation,
            deliveryLocation: record.deliveryLocation,
            pickupCity: record.pickupCity,
            deliveryCity: record.deliveryCity,
            tripDistance: record.tripDistance ?? "",
            distanceUnit: record.distanceUnit ?? "km",
            cargoType: record.cargoType,
            title: record.title,
            quantity: record.quantity ?? "",
            totalWeight: record.totalWeight ?? "",
            weightUnit: record.weightUnit ?? "kg",
            offersNumber: record.offersNumber ?? "0",
            minOffer: record.minOffer ?? "",
            maxOffer: record.maxOffer ?? "",
            currency: record.currency ?? "PLN",
            createdAt: formatDate(record.createdAt),
            pickupDate: record.pickupDate ?? "",
            deliveryDate: record.deliveryDate ?? "",
            tripColor: record.tripColor ?? "#6B7280",
            icon: record.icon ?? "package",
            totalDimensions: record.totalDimensions ?? "",
            shippersName: record.shippersName ?? "",
            shippersSurname: record.shippersSurname ?? "",
            shippersRating: record.shippersRating ?? "",
            shippersLanguage: record.shippersLanguage ?? ""
        )
    }
    
    private func parseShipmentFromJSON(_ json: [String: AnyJSON]) throws -> ShipmentData {
        let data = try JSONSerialization.data(withJSONObject: json.mapValues { $0.value })
        let record = try JSONDecoder().decode(ShipmentRecord.self, from: data)
        return convertToShipmentData(record)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Data Models

struct ShipmentRecord: Codable {
    let id: String?
    let userUid: String
    let pickupLocation: String
    let deliveryLocation: String
    let pickupCity: String
    let deliveryCity: String
    let tripDistance: String?
    let distanceUnit: String?
    let cargoType: String
    let title: String
    let quantity: String?
    let totalWeight: String?
    let weightUnit: String?
    let totalDimensions: String?
    let offersNumber: String?
    let minOffer: String?
    let maxOffer: String?
    let currency: String?
    let pickupDate: String?
    let deliveryDate: String?
    let tripColor: String?
    let icon: String?
    let shippersName: String?
    let shippersSurname: String?
    let shippersRating: String?
    let shippersLanguage: String?
    let status: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userUid = "user_uid"
        case pickupLocation = "pickup_location"
        case deliveryLocation = "delivery_location"
        case pickupCity = "pickup_city"
        case deliveryCity = "delivery_city"
        case tripDistance = "trip_distance"
        case distanceUnit = "distance_unit"
        case cargoType = "cargo_type"
        case title
        case quantity
        case totalWeight = "total_weight"
        case weightUnit = "weight_unit"
        case totalDimensions = "total_dimensions"
        case offersNumber = "offers_number"
        case minOffer = "min_offer"
        case maxOffer = "max_offer"
        case currency
        case pickupDate = "pickup_date"
        case deliveryDate = "delivery_date"
        case tripColor = "trip_color"
        case icon
        case shippersName = "shippers_name"
        case shippersSurname = "shippers_surname"
        case shippersRating = "shippers_rating"
        case shippersLanguage = "shippers_language"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CargoTypeRecord: Codable {
    let id: String
    let cargoType: String
    let tripColor: String
    let icon: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case cargoType = "cargo_type"
        case tripColor = "trip_color"
        case icon
    }
}

struct ProfileRecord: Codable {
    let id: String
    let userType: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userType = "usertype"
    }
}
