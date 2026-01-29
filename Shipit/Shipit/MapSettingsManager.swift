//
//  MapSettingsManager.swift
//  Shipit
//
//  Created on 30.12.2025.
//

import Foundation

class MapSettingsManager: ObservableObject {
    static let shared = MapSettingsManager()
    
    @Published var showScaleBar: Bool = false
    
    private let userDefaultsKey = "mapShowScaleBar"
    
    private init() {
        loadSettings()
    }
    
    func saveSettings() {
        UserDefaults.standard.set(showScaleBar, forKey: userDefaultsKey)
    }
    
    private func loadSettings() {
        showScaleBar = UserDefaults.standard.object(forKey: userDefaultsKey) as? Bool ?? false
    }
}
