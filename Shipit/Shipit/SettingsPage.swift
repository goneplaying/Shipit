//
//  SettingsPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct SettingsPage: View {
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    @State private var isClearingCache = false
    @State private var isClearingTripColor = false
    @State private var isClearingIcon = false
    @State private var showCacheClearedAlert = false
    @State private var cacheClearMessage = ""
    @ObservedObject private var mapSettings = MapSettingsManager.shared
    @ObservedObject private var shipmentDataManager = ShipmentDataManager.shared
    
    var body: some View {
        ZStack {
            Colors.backgroundQuaternary
                .ignoresSafeArea()
            
            List {
                Section {
                    Toggle(isOn: $mapSettings.showScaleBar) {
                        Text("Show Scale Bar")
                            .foregroundColor(Colors.text)
                    }
                    .onChange(of: mapSettings.showScaleBar) { _, _ in
                        HapticFeedback.light()
                        mapSettings.saveSettings()
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    
                    Button(action: {
                        HapticFeedback.light()
                        clearMapboxCache()
                    }) {
                        HStack {
                            Text("Clear Mapbox Cache")
                                .foregroundColor(Colors.text)
                            Spacer()
                            if isClearingCache {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Colors.textSecondary))
                            }
                        }
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .disabled(isClearingCache)
                } header: {
                    Text("Map")
                }
                
                Section {
                    Button(action: {
                        HapticFeedback.light()
                        clearTripColorCache()
                    }) {
                        HStack {
                            Text("Delete TripColor from Cache")
                                .foregroundColor(Colors.text)
                            Spacer()
                            if isClearingTripColor {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Colors.textSecondary))
                            }
                        }
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .disabled(isClearingTripColor)
                    
                    Button(action: {
                        HapticFeedback.light()
                        clearIconCache()
                    }) {
                        HStack {
                            Text("Delete Icon from Cache")
                                .foregroundColor(Colors.text)
                            Spacer()
                            if isClearingIcon {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Colors.textSecondary))
                            }
                        }
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .disabled(isClearingIcon)
                } header: {
                    Text("Data Cache")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Cache Cleared", isPresented: $showCacheClearedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cacheClearMessage)
        }
    }
    
    private func clearMapboxCache() {
        isClearingCache = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            MapboxCacheManager.shared.clearCache { success, message in
                DispatchQueue.main.async {
                    isClearingCache = false
                    cacheClearMessage = message
                    showCacheClearedAlert = true
                }
            }
        }
    }
    
    private func clearTripColorCache() {
        isClearingTripColor = true
        
        shipmentDataManager.clearTripColorCache { success, message in
            DispatchQueue.main.async {
                isClearingTripColor = false
                cacheClearMessage = message
                showCacheClearedAlert = true
            }
        }
    }
    
    private func clearIconCache() {
        isClearingIcon = true
        
        shipmentDataManager.clearIconCache { success, message in
            DispatchQueue.main.async {
                isClearingIcon = false
                cacheClearMessage = message
                showCacheClearedAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsPage()
    }
}
