//
//  ExchangeSortingPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct ExchangeSortingPage: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var filterSettings = FilterSettingsManager.shared
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    var body: some View {
        ZStack {
            Colors.backgroundQuaternary
                .ignoresSafeArea()
            
            List {
                Section {
                    // Date of creation
                    Button(action: {
                        filterSettings.sortType = .dateOfCreation
                        filterSettings.saveSettings()
                    }) {
                        HStack {
                            Text("Date of creation")
                                .foregroundColor(Colors.text)
                            Spacer()
                            if filterSettings.sortType == .dateOfCreation {
                                LucideIcon(IconHelper.checkmark, size: 22)
                                    .foregroundColor(Colors.primary)
                            }
                        }
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    
                    // Distance to pickup
                    Button(action: {
                        filterSettings.sortType = .distanceToPickup
                        filterSettings.saveSettings()
                    }) {
                        HStack {
                            Text("Distance to pickup")
                                .foregroundColor(Colors.text)
                            Spacer()
                            if filterSettings.sortType == .distanceToPickup {
                                LucideIcon(IconHelper.checkmark, size: 22)
                                    .foregroundColor(Colors.primary)
                            }
                        }
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    
                    // Trip distance
                    Button(action: {
                        filterSettings.sortType = .tripDistance
                        filterSettings.saveSettings()
                    }) {
                        HStack {
                            Text("Trip distance")
                                .foregroundColor(Colors.text)
                            Spacer()
                            if filterSettings.sortType == .tripDistance {
                                LucideIcon(IconHelper.checkmark, size: 22)
                                    .foregroundColor(Colors.primary)
                            }
                        }
                    }
                    .frame(minHeight: 40)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                } header: {
                    Text("Sorting by")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Sorting")
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
            // Reset to first available order option when sort type changes
            let availableOrders = filterSettings.getAvailableSortOrders(for: filterSettings.sortType)
            if let firstOrder = availableOrders.first {
                filterSettings.sortOrder = firstOrder
            }
            filterSettings.saveSettings()
        }
        .onChange(of: filterSettings.sortType) { _, newValue in
            // Reset to first available order option when sort type changes
            let availableOrders = filterSettings.getAvailableSortOrders(for: newValue)
            if let firstOrder = availableOrders.first {
                filterSettings.sortOrder = firstOrder
            }
            filterSettings.saveSettings()
        }
    }
}

#Preview {
    NavigationStack {
        ExchangeSortingPage()
    }
}
