//
//  BasicInfo.swift
//  Shipit
//
//  Created on 30.12.2025.
//

import SwiftUI

struct BasicInfo: View {
    let shipment: ShipmentData
    var distanceToPickup: Double? = nil // Optional distance to pickup location
    
    // Format pickup city with country
    private var pickupCityText: String {
        let city = shipment.pickupCity.isEmpty ? shipment.pickupLocation : shipment.pickupCity
        // Extract country code if available, otherwise default to "PL"
        return "\(city), PL"
    }
    
    // Format delivery city with country
    private var deliveryCityText: String {
        let city = shipment.deliveryCity.isEmpty ? shipment.deliveryLocation : shipment.deliveryCity
        // Extract country code if available, otherwise default to "PL"
        return "\(city), PL"
    }
    
    // Format trip distance - returns tuple for split display
    private var tripDistanceParts: (value: String, unit: String) {
        let distance = shipment.tripDistance.isEmpty ? "0" : shipment.tripDistance
        let unit = shipment.distanceUnit.isEmpty ? "km" : shipment.distanceUnit
        return (distance, unit)
    }
    
    // Format distance to pickup - returns tuple for split display
    private var distanceToPickupParts: (value: String, unit: String)? {
        if let distance = distanceToPickup {
            return (String(format: "%.0f", distance), "km")
        }
        return nil
    }
    
    // Format "Listed" date - show "Yesterday" if created yesterday, otherwise formatted date
    private var listedText: String {
        guard !shipment.createdAt.isEmpty else {
            return "N/A"
        }
        
        // Try to parse the date
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        
        var date: Date?
        if let parsedDate = isoFormatter.date(from: shipment.createdAt) {
            date = parsedDate
        } else {
            isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
            date = isoFormatter.date(from: shipment.createdAt)
        }
        
        guard let createdDate = date else {
            return "N/A"
        }
        
        // Check if it's yesterday
        let calendar = Calendar.current
        if calendar.isDateInYesterday(createdDate) {
            return "Yesterday"
        }
        
        // Format as dd.MM.yyyy
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd.MM.yyyy"
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        return displayFormatter.string(from: createdDate)
    }
    
    // Format pickup date
    private var pickupDateText: String {
        guard !shipment.pickupDate.isEmpty else {
            return "Flexible dates"
        }
        
        // Try ISO 8601 format first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        
        if let date = isoFormatter.date(from: shipment.pickupDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        // Try ISO 8601 without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = isoFormatter.date(from: shipment.pickupDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        // Try simple date format (e.g., "2026-01-02")
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = simpleFormatter.date(from: shipment.pickupDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        return shipment.pickupDate
    }
    
    // Format delivery date
    private var deliveryDateText: String {
        guard !shipment.deliveryDate.isEmpty else {
            return "Flexible dates"
        }
        
        // Try ISO 8601 format first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        
        if let date = isoFormatter.date(from: shipment.deliveryDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        // Try ISO 8601 without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = isoFormatter.date(from: shipment.deliveryDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        // Try simple date format (e.g., "2026-01-02")
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = simpleFormatter.date(from: shipment.deliveryDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            return displayFormatter.string(from: date)
        }
        
        return shipment.deliveryDate
    }
    
    // Format total weight - returns tuple for split display
    private var totalWeightParts: (value: String, unit: String) {
        let weight = shipment.totalWeight.isEmpty ? "0" : shipment.totalWeight
        let unit = shipment.weightUnit.isEmpty ? "t" : shipment.weightUnit
        return (weight, unit)
    }
    
    // Format shipper name - split into first name and last initial with period
    private var shipperNameParts: (firstName: String, lastInitial: String)? {
        let firstName = shipment.shippersName.trimmingCharacters(in: .whitespacesAndNewlines)
        let surname = shipment.shippersSurname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !firstName.isEmpty else {
            return nil
        }
        
        // Get first letter of surname if available, with period
        let lastInitial = surname.isEmpty ? "" : "\(String(surname.prefix(1)))."
        return (firstName, lastInitial)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pickup
            InfoRow(
                icon: IconHelper.location,
                label: "Pickup",
                value: pickupCityText
            )
            
            // Destination
            InfoRow(
                icon: IconHelper.flag,
                label: "Destination",
                value: deliveryCityText
            )
            
            // Trip Distance (with rotated arrow-up-from-dot icon)
            InfoRowWithSplitValue(
                icon: IconHelper.arrowUpFromDot,
                label: "Trip Distance",
                value: tripDistanceParts.value,
                unit: tripDistanceParts.unit,
                iconRotation: 90
            )
            
            // Distance to Pickup
            if let distanceParts = distanceToPickupParts {
                InfoRowWithSplitValue(
                    icon: IconHelper.radius,
                    label: "Distance to Pickup",
                    value: distanceParts.value,
                    unit: distanceParts.unit
                )
            } else {
                InfoRow(
                    icon: IconHelper.radius,
                    label: "Distance to Pickup",
                    value: "N/A"
                )
            }
            
            // Listed
            InfoRow(
                icon: IconHelper.clock,
                label: "Listed",
                value: listedText
            )
            
            // Pickup Date
            InfoRow(
                icon: IconHelper.calendarArrowUp,
                label: "Pickup Date",
                value: pickupDateText
            )
            
            // Delivery Date
            InfoRow(
                icon: IconHelper.calendarArrowDown,
                label: "Delivery Date",
                value: deliveryDateText
            )
            
            // Total Weight
            InfoRowWithSplitValue(
                icon: IconHelper.weight,
                label: "Total Weight",
                value: totalWeightParts.value,
                unit: totalWeightParts.unit
            )
            
            // Dimensions
            InfoRow(
                icon: IconHelper.rulerDimensionLine,
                label: "Dimensions",
                value: shipment.totalDimensions.isEmpty ? "N/A" : shipment.totalDimensions
            )
            
            // Shipper
            if let nameParts = shipperNameParts {
                InfoRowWithSplitValue(
                    icon: IconHelper.person,
                    label: "Shipper",
                    value: nameParts.firstName,
                    unit: nameParts.lastInitial
                )
            } else {
                InfoRow(
                    icon: IconHelper.person,
                    label: "Shipper",
                    value: "N/A"
                )
            }
            
            // Shipper Rating
            InfoRow(
                icon: IconHelper.userStar,
                label: "Shipper Rating",
                value: shipment.shippersRating.isEmpty ? "N/A" : shipment.shippersRating
            )
            
            // Shipper's Language
            InfoRow(
                icon: IconHelper.languages,
                label: "Shipper's Language",
                value: shipment.shippersLanguage.isEmpty ? "N/A" : shipment.shippersLanguage
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Colors.background)
    }
}

// Helper view for info rows
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var iconRotation: Double = 0
    
    var body: some View {
        HStack(alignment: .center) {
            // Icon and label
            HStack(spacing: 12) {
                if iconRotation != 0 {
                    LucideIcon(icon, size: 20, color: Colors.textSecondary)
                        .rotationEffect(.degrees(iconRotation))
                } else {
                    LucideIcon(icon, size: 20, color: Colors.textSecondary)
                }
                
                Text(label)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(hex: "#222222"))
            }
            
            Spacer()
            
            // Value
            Text(value)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Color(hex: "#6c6c6c"))
        }
    }
}

// Helper view for info rows with split values (e.g., "1.200" and "km" with 4px gap)
struct InfoRowWithSplitValue: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    var iconRotation: Double = 0
    
    var body: some View {
        HStack(alignment: .center) {
            // Icon and label
            HStack(spacing: 12) {
                if iconRotation != 0 {
                    LucideIcon(icon, size: 20, color: Colors.textSecondary)
                        .rotationEffect(.degrees(iconRotation))
                } else {
                    LucideIcon(icon, size: 20, color: Colors.textSecondary)
                }
                
                Text(label)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(hex: "#222222"))
            }
            
            Spacer()
            
            // Split value with 4px gap
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(hex: "#6c6c6c"))
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(hex: "#6c6c6c"))
                }
            }
        }
    }
}
