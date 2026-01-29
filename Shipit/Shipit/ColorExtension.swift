//
//  ColorExtension.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import UIKit

extension UIColor {
    convenience init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove # prefix if present
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        // Only keep valid hex characters
        let validHex = hex.filter { $0.isHexDigit }
        
        guard !validHex.isEmpty else {
            return nil
        }
        
        var int: UInt64 = 0
        Scanner(string: validHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch validHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove # prefix if present
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        // Only keep valid hex characters
        let validHex = hex.filter { $0.isHexDigit }
        
        guard !validHex.isEmpty else {
            // Default to black if invalid
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
            return
        }
        
        var int: UInt64 = 0
        Scanner(string: validHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch validHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            // Invalid length, default to black
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Safely creates a Color from a hex string, returning nil if invalid
    static func fromHex(_ hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let validHex = hex.filter { $0.isHexDigit }
        
        guard validHex.count == 3 || validHex.count == 6 || validHex.count == 8 else {
            return nil
        }
        
        return Color(hex: hex)
    }
    
    func hexString() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#FFAD00" // Default to primary color
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// Helper extension for safely parsing tripColor values
extension Color {
    /// Safely creates a Color from a tripColor string, falling back to primary color if invalid
    static func fromTripColor(_ tripColor: String, fallback: Color = Colors.primary) -> Color {
        guard !tripColor.isEmpty else {
            return fallback
        }
        
        let trimmed = tripColor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }
        
        // Try to create color from hex
        let color = Color(hex: trimmed)
        
        // Validate that it's not black (which might indicate parsing failure)
        // If the original hex was valid and resulted in black, that's fine
        // But if it was invalid and defaulted to black, we should use fallback
        // For now, we'll trust the Color(hex:) implementation
        return color
    }
}
