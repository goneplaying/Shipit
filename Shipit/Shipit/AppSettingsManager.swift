//
//  AppSettingsManager.swift
//  Shipit
//
//  Created by Assistant on 10.01.2026.
//

import SwiftUI

enum HomePageType: String {
    case carrier = "carrier"
    case shipper = "shipper"
}

class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()
    
    @Published var lastActiveHomePage: HomePageType {
        didSet {
            saveLastActiveHomePage()
        }
    }
    
    private let userDefaultsKey = "lastActiveHomePage"
    
    private init() {
        // Load from UserDefaults, default to shipper if not set
        if let savedType = UserDefaults.standard.string(forKey: userDefaultsKey),
           let homePageType = HomePageType(rawValue: savedType) {
            lastActiveHomePage = homePageType
        } else {
            lastActiveHomePage = .shipper // Default to shipper
        }
    }
    
    private func saveLastActiveHomePage() {
        UserDefaults.standard.set(lastActiveHomePage.rawValue, forKey: userDefaultsKey)
    }
    
    func setLastActiveHomePage(_ type: HomePageType) {
        lastActiveHomePage = type
    }
}
