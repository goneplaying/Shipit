//
//  ShipmentsPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct ShipmentsPage: View {
    @State private var showNewShipment = false
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    var body: some View {
        ZStack {
            Colors.background
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Text("Shipments")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Colors.text)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
        }
        .navigationTitle("Shipments")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showNewShipment = true
                }) {
                    LucideIcon(IconHelper.plus, size: 24)
                        .foregroundColor(Colors.text)
                }
            }
        }
        .toolbarColorScheme(.light, for: .navigationBar)
        .sheet(isPresented: $showNewShipment) {
            // Placeholder for new shipment creation view
            Text("New Shipment")
                .navigationTitle("New Shipment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showNewShipment = false
                        }
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        ShipmentsPage()
    }
}
