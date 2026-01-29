//
//  Styles.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct Colors {
    // Primary Colors
    static let primary = Color(hex: "#FFAD00")
    static let secondary = Color(hex: "#222222")
    static let tertiary = Color(hex: "#6C6C6C")
    
    // Text Colors
    static let text = Color(hex: "#141414")
    static let textSecondary = Color(hex: "#6C6C6C")
    
    // Background Colors
    static let background = Color.white
    static let backgroundSecondary = Color(hex: "#F0F0F0")
    static let backgroundQuaternary = Color(hex: "#F4F4F4")
    
    // Border & Divider Colors
    static let border = Color(hex: "#D5D5D5")
    static let divider = Color(hex: "#E7E7E8")
    
    // Button Colors
    static let button = Color(hex: "#222222")
    
    // Other Colors
    static let grayLight = Color(hex: "#BFBFBF")
    static let bookmarkDisabled = Color(hex: "#D9D9D9")
    
    // UIKit Colors (for navigation bars, etc.)
    static var primaryUIColor: UIColor {
        UIColor(red: 255/255.0, green: 173/255.0, blue: 0/255.0, alpha: 1.0)
    }
    
    static var secondaryUIColor: UIColor {
        UIColor(red: 0x22/255.0, green: 0x22/255.0, blue: 0x22/255.0, alpha: 1.0)
    }
    
    static var textUIColor: UIColor {
        UIColor(red: 0x14/255.0, green: 0x14/255.0, blue: 0x14/255.0, alpha: 1.0)
    }
}
